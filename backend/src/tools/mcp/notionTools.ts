import { Tool, PermissionLevel } from '../../types';

export const SearchNotionTool: Tool = {
  name: 'SearchNotion',
  description: '搜索用户的Notion笔记库和愿望清单内容',
  schema: {
    type: 'object',
    properties: {
      query: { type: 'string' },
      reason: { type: 'string', description: "执行此工具的原因和依据（必填，用于系统可观测性）" }
    },
    required: ['query', 'reason']
  },
  permissionLevel: PermissionLevel.AUTO_ALLOW,
  execute: async (input) => {
    // MVP Mock
    console.log(`[MCP Notion] Searching for: ${input.query}`);
    return { results: [`找到关于 ${input.query} 的笔记。`] };
  }
};

export const AppendNotionBlockTool: Tool = {
  name: 'AppendNotionBlock',
  description: '将内容追加到用户的Notion文档（非常适合存入灵感或商品链接）',
  schema: {
    type: 'object',
    properties: {
      content: { type: 'string' },
      reason: { type: 'string', description: "执行此工具的原因和依据（必填，用于系统可观测性）" }
    },
    required: ['content', 'reason']
  },
  permissionLevel: PermissionLevel.REQUIRE_APPROVAL, // MUST prompt user
  execute: async (input) => {
    // MVP Mock
    console.log(`[MCP Notion] Appended block: ${input.content}`);
    return { success: true, message: "写入成功" };
  }
};
