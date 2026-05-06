import { AgentContext } from '../types';
import { buildEffectiveSystemPrompt } from '../systemPrompt';
import { runPreAgentRouter } from '../memory/preAgentRouter';
import { compressHistoryIfNeeded } from '../memory/workingMemory';
import { AgentState } from '../websocket/AgentState';
import { LLMMessage } from './llm/LLMAdapter';

export class PromptBuilder {
  constructor(private ctx: AgentContext) {}

  async buildMessages(query: string): Promise<LLMMessage[]> {
    // 移除不必要的伪装状态，保持前端界面清爽
    // this.ctx.sendState(AgentState.WORKING, '提取长期记忆中...');
    
    const memSpan = this.ctx.trace?.startSpan('preAgentRouter');
    const episodicMemoryContext = await runPreAgentRouter(query, this.ctx.userId);
    memSpan?.end({ memoryContextLength: episodicMemoryContext.length });

    // this.ctx.sendState(AgentState.WORKING, '分析需求中...');
    
    await compressHistoryIfNeeded(this.ctx);

    // 优化一：KV Cache 保护（分离静态与动态上下文）
    // 静态部分（人设）在系统提示词前面，动态部分（时间、记忆）在尾部，以最大化命中大模型 KV 缓存
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
      })
    ];

    // If the last message in history is the user query, we might want to append attachments to it
    // But since we just pushed the user message to history in server.ts, it's already there.
    // Let's find the last user message and append the attachment info to it.
    if (this.ctx.currentAttachments && this.ctx.currentAttachments.length > 0) {
      for (let i = messages.length - 1; i >= 0; i--) {
        if (messages[i].role === 'user') {
          messages[i].content += `\n\n[系统通知] 用户刚刚发送了 ${this.ctx.currentAttachments.length} 个附件，已安全存放到你的宿主机本地。你可以直接调用文件或办公相关的 MCP 工具读取处理它们。文件绝对路径如下：\n` + 
          this.ctx.currentAttachments.join('\n');
          break;
        }
      }
    }

    return messages;
  }
}
