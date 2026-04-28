import { ToolDispatcher } from '../tools/ToolDispatcher';
import { AgentContext } from '../types';
import { runPostSessionHook } from '../memory/postSessionHook';
import { prisma } from '../utils/db';
import { normalizeModelName } from '../utils/modelName';
import { logger } from '../utils/logger';
import { sessionMutex } from '../utils/mutex';

import { AgentState } from '../websocket/AgentState';
import { OpenAIAdapter } from './llm/OpenAIAdapter';
import { AnthropicAdapter } from './llm/AnthropicAdapter';
import { PromptBuilder } from './PromptBuilder';
import { AgentLoop } from './AgentLoop';

export async function runAgent(
  query: string,
  dispatcher: ToolDispatcher,
  ctx: AgentContext,
  maxSteps: number = 5
) {
  const userApiKey = ctx.apiKey;
  
  if (!userApiKey || userApiKey.trim() === '') {
    await ctx.sendChunk('\n(系统提示：请先前往“设置”页面配置您的 API Key，唤醒我的大脑。)');
    return;
  }

  const modelName = normalizeModelName(ctx.modelName) || normalizeModelName(process.env.MODEL_NAME) || 'MiniMax-M2.7';
  
  // Decide which adapter to use based on env or modelName.
  // For MVP, if it contains "claude", use Anthropic, else use OpenAI/MiniMax.
  const primaryAdapter = modelName.toLowerCase().includes('claude') || process.env.DEFAULT_LLM_PROVIDER === 'anthropic'
    ? new AnthropicAdapter(userApiKey)
    : new OpenAIAdapter(userApiKey, 'https://api.minimax.chat/v1');
    
  // As a fallback, we define a dummy OpenAI adapter (or any secondary configured adapter)
  // that points to a known reliable endpoint or cheaper model if the primary fails.
  const fallbackAdapter = new OpenAIAdapter(process.env.FALLBACK_API_KEY || userApiKey, 'https://api.openai.com/v1');

  const trace = logger.createTrace(ctx.sessionId, ctx.userId, query);
  ctx.trace = trace;

  try {
    const promptBuilder = new PromptBuilder(ctx);
    const messages = await promptBuilder.buildMessages(query);
    const initialMessagesLength = messages.length;

    const agentLoop = new AgentLoop([primaryAdapter, fallbackAdapter], dispatcher, ctx, maxSteps);
    const { finalResponseStr, finalToolCalls } = await agentLoop.run(messages, modelName);

    // Save ALL new messages (assistant and tool results) to DB
    await sessionMutex.runExclusive(ctx.sessionId, async () => {
      const newMessages = messages.slice(initialMessagesLength);
      for (const msg of newMessages) {
        let contentStr = "";
        if (typeof msg.content === 'string') {
          contentStr = msg.content;
        } else if (Array.isArray(msg.content)) {
          contentStr = msg.content.map((b: any) => b.text || JSON.stringify(b)).join('\n');
        }

        let toolCallsStr: string | null = null;
        if (msg.role === 'assistant' && msg.tool_calls && msg.tool_calls.length > 0) {
          toolCallsStr = JSON.stringify(msg.tool_calls);
        } else if (msg.role === 'tool' && msg.tool_call_id) {
          toolCallsStr = JSON.stringify({ id: msg.tool_call_id });
        }

        await prisma.message.create({
          data: {
            sessionId: ctx.sessionId,
            role: msg.role as string,
            content: contentStr,
            toolCalls: toolCallsStr
          }
        });
      }
    });

    await runPostSessionHook(ctx.sessionId, ctx.userId, query, finalResponseStr, ctx.modelName);
    trace.end({ finalResponseLength: finalResponseStr.length, steps: finalToolCalls.length });

  } catch (error: any) {
    logger.error('RUN_AGENT_FAILED', { error: error.message });
    await ctx.sendChunk(`\n(运行错误: ${error.message})`);
    trace.end({ error: error.message });
  }
}
