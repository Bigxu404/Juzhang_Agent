import { AgentState } from '../websocket/AgentState';
import { Trace } from '../utils/logger';

export enum PermissionLevel {
  AUTO_ALLOW = 1,
  NOTIFY_AFTER = 2,
  REQUIRE_APPROVAL = 3
}

export interface Tool {
  name: string;
  description: string;
  schema: any;
  permissionLevel: PermissionLevel;
  execute: (input: any, ctx?: AgentContext) => Promise<any>;
}

export type AgentEvent = 
  | { type: 'tool_start'; toolName: string; input: any }
  | { type: 'tool_end'; toolName: string; result: any }
  | { type: 'text_chunk'; text: string }
  | { type: 'error'; message: string }
  | { type: 'agent_finish'; finalResponse: string };

export interface AgentContext {
  sessionId: string;
  userId: string;
  apiKey?: string;
  modelName?: string;
  requestPermission: (toolName: string, desc: string) => Promise<boolean>;
  sendState: (status: AgentState | string, desc: string) => void;
  sendChunk: (text: string) => Promise<void>;
  sendEvent: (event: AgentEvent) => void;
  history: any[];
  trace?: Trace;
}
