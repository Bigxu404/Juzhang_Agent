import { ToolDispatcher } from './tools/ToolDispatcher';
import { runAgent } from './agent/runAgent';
import { AgentContext } from './types';
import { AgentState } from './websocket/AgentState';
import { AskClarificationTool } from './tools/agent/AskClarification';

async function main() {
  const dispatcher = new ToolDispatcher();
  dispatcher.register(AskClarificationTool);

  const ctx: AgentContext = {
    sessionId: 'test-session',
    userId: 'test-user',
    apiKey: process.env.MINIMAX_API_KEY || 'dummy-key',
    modelName: 'MiniMax-M2.7',
    requestPermission: async (tool, desc) => true,
    sendState: (state, desc) => console.log(`[STATE] ${state}: ${desc}`),
    sendChunk: async (text) => process.stdout.write(text),
    sendEvent: (event) => console.log(`[EVENT] ${JSON.stringify(event)}`),
    history: []
  };

  console.log("Starting test...");
  await runAgent("帮我买个包", dispatcher, ctx);
  console.log("\nTest complete.");
}

main().catch(console.error);