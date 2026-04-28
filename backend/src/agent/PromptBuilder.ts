import { AgentContext } from '../types';
import { buildEffectiveSystemPrompt } from '../systemPrompt';
import { runPreAgentRouter } from '../memory/preAgentRouter';
import { compressHistoryIfNeeded } from '../memory/workingMemory';
import { AgentState } from '../websocket/AgentState';
import { LLMMessage } from './llm/LLMAdapter';

export class PromptBuilder {
  constructor(private ctx: AgentContext) {}

  async buildMessages(query: string): Promise<LLMMessage[]> {
    this.ctx.sendState(AgentState.WORKING, '提取长期记忆中...');
    
    const memSpan = this.ctx.trace?.startSpan('preAgentRouter');
    const episodicMemoryContext = await runPreAgentRouter(query, this.ctx.userId);
    memSpan?.end({ memoryContextLength: episodicMemoryContext.length });

    this.ctx.sendState(AgentState.WORKING, '分析需求中...');
    
    await compressHistoryIfNeeded(this.ctx);

    const systemPromptBlocks = buildEffectiveSystemPrompt({
      time: new Date().toLocaleString(),
      personaUpdates: "最新兴趣：喜欢看科幻电影", 
      recentMemories: [episodicMemoryContext]
    });

    const systemMsg = systemPromptBlocks.map((b: any) => b.text).join('\n\n');

    const messages: LLMMessage[] = [
      { role: 'system', content: systemMsg },
      ...this.ctx.history.map(m => {
          // Normalize existing history to LLMMessage
          return {
              role: m.role,
              content: m.content,
              tool_calls: m.tool_calls,
              tool_call_id: m.tool_call_id
          } as LLMMessage;
      }),
      { role: 'user', content: query }
    ];

    return messages;
  }
}
