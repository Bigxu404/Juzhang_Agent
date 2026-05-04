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
    // 为方便测试，如果没有提供 API Key，直接进行本地 Mock 流式输出，模拟 Agent 框架运行
    await ctx.sendState(AgentState.THINKING, '思考中...');
    await new Promise(r => setTimeout(r, 1000));
    await ctx.sendState(AgentState.WORKING, '调用工具：全网搜索');
    await new Promise(r => setTimeout(r, 1500));
    await ctx.sendState(AgentState.SUCCESS, '任务执行完成');
    await new Promise(r => setTimeout(r, 500));
    await ctx.sendChunk('你好！我是 MiniMax 2.7 驱动的数字老友。虽然你还没有配置真实的 API Key，但我为你模拟了一次完整的 Agent 思考和工具调用流程，这证明了前后端打通是完全正常的！你可以去设置页配置真实的 Key 来解锁完全体。');
    await ctx.sendState(AgentState.IDLE, '等待输入...');
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
  // 优化：在国内环境如果强连 api.openai.com 会导致 30 秒超时挂起，改用配置的备用或直接失败。
  const fallbackAdapter = new OpenAIAdapter(process.env.FALLBACK_API_KEY || userApiKey, process.env.FALLBACK_BASE_URL || 'https://api.minimax.chat/v1');

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

        // 防止某些大模型返回的 role 为 undefined
        const safeRole = msg.role ? String(msg.role) : 'assistant';

        await prisma.message.create({
          data: {
            sessionId: ctx.sessionId,
            role: safeRole,
            content: contentStr,
            toolCalls: toolCallsStr
          }
        });
      }
    });

    await runPostSessionHook(ctx.sessionId, ctx.userId, query, finalResponseStr, ctx.modelName, userApiKey);
    trace.end({ finalResponseLength: finalResponseStr.length, steps: finalToolCalls.length });

  } catch (error: any) {
    logger.error('RUN_AGENT_FAILED', { error: error.message });
    await ctx.sendChunk(`\n(运行错误: ${error.message})`);
    trace.end({ error: error.message });
  }
}
