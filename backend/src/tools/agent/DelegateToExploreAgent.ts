import { Tool, PermissionLevel } from '../../types';
import { runExploreAgent } from '../../agent/exploreAgent';
import { AgentState } from '../../websocket/AgentState';

export const DelegateToExploreAgentTool: Tool = {
  name: 'DelegateToExploreAgent',
  description: '派发只读的探索子代理（Explore Subagent）去互联网冲浪、搜索或总结。适合处理需要查资料或了解最新资讯的任务。',
  schema: {
    type: 'object',
    properties: {
      task: { type: 'string' },
      reason: { type: 'string', description: "执行此工具的原因和依据（必填，用于系统可观测性）" }
    },
    required: ['task', 'reason']
  },
  permissionLevel: PermissionLevel.AUTO_ALLOW,
  execute: async (input, ctx) => {
    if (ctx) {
      ctx.sendState(AgentState.SEARCHING, `派发代理冲浪: ${input.task}...`);
    }
    const result = await runExploreAgent(input.task, ctx);
    return { result };
  }
};
