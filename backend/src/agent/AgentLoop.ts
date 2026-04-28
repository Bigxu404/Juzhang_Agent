import { ToolDispatcher } from '../tools/ToolDispatcher';
import { AgentContext } from '../types';
import { AgentState } from '../websocket/AgentState';
import { LLMAdapter, LLMMessage, LLMResponse } from './llm/LLMAdapter';
import { logger } from '../utils/logger';

export class AgentLoop {
  constructor(
    private adapters: LLMAdapter[],
    private dispatcher: ToolDispatcher,
    private ctx: AgentContext,
    private maxSteps: number = 5
  ) {}

  async run(messages: LLMMessage[], modelName: string): Promise<{ finalResponseStr: string, finalToolCalls: any[] }> {
    let finalResponseStr = "";
    let finalToolCalls: any[] = [];
    const tools = this.dispatcher.getAvailableTools() as any[];

    for (let step = 0; step < this.maxSteps; step++) {
      const llmSpan = this.ctx.trace?.startSpan('llm_inference', { step });
      try {
        this.ctx.sendState(AgentState.THINKING, '思考中...');

        let response: LLMResponse | null = null;
        let activeAdapter: LLMAdapter = this.adapters[0];

        for (let i = 0; i < this.adapters.length; i++) {
          try {
            activeAdapter = this.adapters[i];
            response = await activeAdapter.chat(
              messages,
              tools,
              modelName,
              async (chunk) => {
                await this.ctx.sendChunk(chunk);
                this.ctx.sendEvent({ type: 'text_chunk', text: chunk });
                finalResponseStr += chunk;
              }
            );
            break; // success
          } catch (err: any) {
            logger.warn('LLM_ADAPTER_FAILED', { adapterIndex: i, error: err.message });
            if (i === this.adapters.length - 1) {
              throw err; // All adapters failed
            }
            this.ctx.sendState(AgentState.THINKING, '正在切换备用大脑...');
            this.ctx.sendEvent({ type: 'text_chunk', text: '\n(主大脑连接异常，正在切换备用大脑...)\n' });
            finalResponseStr += '\n(主大脑连接异常，正在切换备用大脑...)\n';
          }
        }

        if (!response) {
            throw new Error("No response from LLM Adapters");
        }

        if (response.toolCalls.length === 0) {
          llmSpan?.end({ toolCallsCount: 0, responseLength: finalResponseStr.length });
          messages.push({ role: 'assistant', content: response.text });
          break;
        } else {
          llmSpan?.end({ toolCallsCount: response.toolCalls.length });
          finalToolCalls.push(...response.toolCalls);
          messages.push(activeAdapter.formatToolCallsForHistory(response.rawResponse));
        }

        for (const tc of response.toolCalls) {
          const { id, name, input } = tc;
          
          this.ctx.sendState(AgentState.WORKING, `正在执行: ${name}...`);
          const resultStr = await this.dispatcher.dispatch(name, input, this.ctx);
          
          messages.push(activeAdapter.formatToolResult(id, resultStr));
        }
      } catch (e: any) {
        llmSpan?.end({ error: e.message });
        if (e.message === 'DENIAL_LIMIT_REACHED') {
          const msg = '\n好的，由于连续多次取消授权，我已经停止了该操作。我们聊点别的吧。';
          await this.ctx.sendChunk(msg);
          finalResponseStr += msg;
          break;
        }
        await this.ctx.sendChunk(`\n(发生系统错误: ${e.message})`);
        finalResponseStr += `\n(发生系统错误: ${e.message})`;
        break;
      }
    }

    if (finalResponseStr === "") {
        await this.ctx.sendChunk('\n(思考步骤过多，已强制终止。)');
        this.ctx.sendEvent({ type: 'error', message: '思考步骤过多，已强制终止。' });
        finalResponseStr = "思考步骤过多，已强制终止。";
    }

    this.ctx.sendEvent({ type: 'agent_finish', finalResponse: finalResponseStr });

    return { finalResponseStr, finalToolCalls };
  }
}
