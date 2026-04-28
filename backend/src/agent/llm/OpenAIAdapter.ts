import OpenAI from 'openai';
import { LLMAdapter, LLMMessage, LLMResponse } from './LLMAdapter';
import { Tool } from '../../types';

export class OpenAIAdapter implements LLMAdapter {
  private client: OpenAI;

  constructor(apiKey: string, baseURL?: string) {
    this.client = new OpenAI({ apiKey, baseURL });
  }

  async chat(
    messages: LLMMessage[], 
    tools: Tool[], 
    modelName: string, 
    onChunk?: (text: string) => Promise<void>
  ): Promise<LLMResponse> {
    const openaiTools = tools.map(t => ({
      type: 'function',
      function: {
        name: t.name,
        description: t.description,
        parameters: t.schema || (t as any).input_schema
      }
    }));

    const openaiMessages = messages.map(m => {
        // OpenAI does not support array of contents natively for tool_result the way anthropic does,
        // but here we align it if needed, or assume standard OpenAI format is used.
        if (m.role === 'user' && Array.isArray(m.content) && m.content[0]?.type === 'tool_result') {
            return {
                role: 'tool',
                tool_call_id: m.content[0].tool_use_id,
                content: m.content[0].content
            };
        }
        
        // Ensure assistant messages with tool calls use the correct OpenAI format
        if (m.role === 'assistant' && m.tool_calls && Array.isArray(m.tool_calls)) {
            const formattedToolCalls = m.tool_calls.map((tc: any) => {
                if (tc.type === 'function') return tc; // already formatted
                return {
                    id: tc.id,
                    type: 'function',
                    function: {
                        name: tc.name,
                        arguments: typeof tc.input === 'string' ? tc.input : JSON.stringify(tc.input)
                    }
                };
            });
            return {
                ...m,
                tool_calls: formattedToolCalls
            };
        }

        return m;
    });

    const response = await this.client.chat.completions.create({
      model: modelName,
      messages: openaiMessages as any,
      tools: openaiTools.length > 0 ? (openaiTools as any) : undefined,
      stream: true,
    });

    let fullText = "";
    let toolCallsRaw: any[] = [];

    for await (const chunk of response) {
      const delta = chunk.choices[0]?.delta;
      
      if (delta?.content) {
        fullText += delta.content;
        if (onChunk) {
          // Send the chunk immediately instead of waiting for the full text!
          // We bypass server.ts's typing delay by just calling onChunk directly with the new tokens
          // But wait, server.ts's ctx.sendChunk takes text and loops over it.
          // To make it real-time without breaking server.ts, we can just let it loop,
          // but the chunks are small so the typing animation will just act as a slight buffer.
          await onChunk(delta.content);
        }
      }

      if (delta?.tool_calls) {
        for (const tc of delta.tool_calls) {
          if (!toolCallsRaw[tc.index]) {
            toolCallsRaw[tc.index] = { id: tc.id, type: tc.type, function: { name: tc.function?.name || "", arguments: tc.function?.arguments || "" } };
          } else {
            if (tc.function?.name) toolCallsRaw[tc.index].function.name += tc.function.name;
            if (tc.function?.arguments) toolCallsRaw[tc.index].function.arguments += tc.function.arguments;
          }
        }
      }
    }

    const toolCalls = [];
    for (const tc of toolCallsRaw) {
      if (tc) {
        toolCalls.push({
          id: tc.id,
          name: tc.function.name,
          input: JSON.parse(tc.function.arguments || "{}")
        });
      }
    }

    return { text: fullText, toolCalls, rawResponse: { content: fullText, tool_calls: toolCallsRaw.length > 0 ? toolCallsRaw : undefined } };
  }

  formatToolResult(toolCallId: string, result: string): LLMMessage {
    return {
      role: 'tool',
      tool_call_id: toolCallId,
      content: result
    };
  }

  formatToolCallsForHistory(rawResponse: any): LLMMessage {
    // OpenAI needs the exact raw assistant message with tool_calls injected back
    return rawResponse;
  }
}
