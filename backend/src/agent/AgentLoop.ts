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
                if (this.ctx.signal?.aborted) {
                    throw new Error("AbortError");
                }
                await this.ctx.sendChunk(chunk);
                this.ctx.sendEvent({ type: 'text_chunk', text: chunk });
                finalResponseStr += chunk;
              },
              this.ctx.signal
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
          
          // Debug Mode: 发送调用参数卡片到前端
          const debugStart = `\n<tool>【调用链路监控】开始执行\n目标工具: ${name}\n请求参数: ${JSON.stringify(input, null, 2)}</tool>\n`;
          await this.ctx.sendChunk(debugStart);
          finalResponseStr += debugStart;
          
          const startTime = Date.now();
          const resultStr = await this.dispatcher.dispatch(name, input, this.ctx);
          const duration = Date.now() - startTime;
          
          let isError = false;
          try {
            const parsedResult = JSON.parse(resultStr);
            if (parsedResult && parsedResult.error) {
              isError = true;
            }
          } catch (err) {
            // Not JSON, assume not our structured error
          }

          // Debug Mode: 发送调用结果卡片到前端
          const debugEnd = `\n<tool>【调用链路监控】执行完毕\n状态: ${isError ? '失败' : '成功'}\n耗时: ${duration}ms\n返回预览: \n${resultStr.length > 500 ? resultStr.substring(0, 500) + "..." : resultStr}</tool>\n`;
          await this.ctx.sendChunk(debugEnd);
          finalResponseStr += debugEnd;
          
          messages.push(activeAdapter.formatToolResult(id, resultStr));

          // 强制反思机制 (Reflection)
          if (isError) {
            const reflectionPrompt = `系统提示：你刚才调用的工具 \`${name}\` 执行失败。报错信息如上所示。
在进行下一次尝试之前，你必须先输出一段 \`<reflection>\`（反思），明确写出：
1. 为什么会报错？
2. 你打算怎么修改参数或调用其他工具来解决这个问题？
只有在完成反思后，你才能再次调用工具。`;
            messages.push({ role: 'user', content: reflectionPrompt });
          }
        }
      } catch (e: any) {
        llmSpan?.end({ error: e.message });
        if (e.message === 'AbortError' || e.name === 'AbortError') {
          const msg = '\n[已由用户中断]';
          await this.ctx.sendChunk(msg);
          finalResponseStr += msg;
          break;
        }
        if (e.message === 'DENIAL_LIMIT_REACHED') {
          const msg = '\n好的，由于连续多次取消授权，我已经停止了该操作。我们聊点别的吧。';
          await this.ctx.sendChunk(msg);
          finalResponseStr += msg;
          break;
        }
        
        // Debug Mode: 捕获报错卡片
        const debugErr = `\n<tool>【调用链路监控】系统异常\n错误类型: ${e.name || 'Error'}\n报错详情: ${e.message}\n请检查网络环境或提供商服务是否稳定。</tool>\n`;
        await this.ctx.sendChunk(debugErr);
        finalResponseStr += debugErr;
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
