import { Tool } from '../../types';

export interface LLMResponse {
  text: string;
  toolCalls: { id: string; name: string; input: any }[];
  rawResponse: any;
}

export interface LLMMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string | any[];
  tool_call_id?: string;
  tool_calls?: any[];
}

export interface LLMAdapter {
  chat(
    messages: LLMMessage[], 
    tools: Tool[], 
    modelName: string, 
    onChunk?: (text: string) => Promise<void>
  ): Promise<LLMResponse>;

  formatToolResult(toolCallId: string, result: string): LLMMessage;
  formatToolCallsForHistory(rawResponse: any): LLMMessage;
}
