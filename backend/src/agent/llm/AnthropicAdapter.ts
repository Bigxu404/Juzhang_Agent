import Anthropic from '@anthropic-ai/sdk';
import { LLMAdapter, LLMMessage, LLMResponse } from './LLMAdapter';
import { Tool } from '../../types';

export class AnthropicAdapter implements LLMAdapter {
  private client: Anthropic;

  constructor(apiKey: string) {
    this.client = new Anthropic({ apiKey });
  }

  async chat(
    messages: LLMMessage[], 
    tools: Tool[], 
    modelName: string, 
    onChunk?: (text: string) => Promise<void>
  ): Promise<LLMResponse> {
    const anthropicTools = tools.map(t => ({
      name: t.name,
      description: t.description,
      input_schema: t.schema || (t as any).input_schema
    }));

    // Extract system messages for Anthropic
    const systemMsg = messages
        .filter(m => m.role === 'system')
        .map(m => m.content)
        .join('\n\n');

    const filteredMessages = messages.filter(m => m.role !== 'system');

    const response = await this.client.messages.create({
      model: modelName,
      max_tokens: 1024,
      system: systemMsg,
      messages: filteredMessages as any,
      tools: anthropicTools.length > 0 ? (anthropicTools as any) : undefined
    });

    const tcRaw = response.content.filter((c: any) => c.type === 'tool_use');
    const texts = response.content.filter((c: any) => c.type === 'text');

    let textStr = "";
    for (const t of texts) {
      textStr += (t as any).text;
      if (onChunk) await onChunk((t as any).text);
    }

    const toolCalls = tcRaw.map((tc: any) => ({
      id: tc.id,
      name: tc.name,
      input: tc.input
    }));

    return { text: textStr, toolCalls, rawResponse: response.content };
  }

  formatToolResult(toolCallId: string, result: string): LLMMessage {
    return {
      role: 'user',
      content: [{ type: 'tool_result', tool_use_id: toolCallId, content: result }] as any
    };
  }

  formatToolCallsForHistory(rawResponse: any): LLMMessage {
    return { role: 'assistant', content: rawResponse };
  }
}
