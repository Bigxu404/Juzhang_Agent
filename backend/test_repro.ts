import { runAgent } from './src/agent/runAgent';
import { ToolDispatcher } from './src/tools/ToolDispatcher';
import { AgentContext } from './src/types';

async function test() {
  const dispatcher = new ToolDispatcher();
  const ctx: AgentContext = {
    sessionId: 'test-session',
    userId: 'test-user',
    apiKey: 'test-key',
    modelName: 'MiniMax-M2.7',
    requestPermission: async () => true,
    sendState: () => {},
    sendChunk: async () => {},
    sendEvent: () => {},
    history: []
  };

  try {
    await runAgent('最近有什么更新跟我说说看', dispatcher, ctx);
  } catch (e) {
    console.error('TEST CAUGHT ERROR:', e);
  }
}

test();
