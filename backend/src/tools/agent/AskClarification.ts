import { Tool, PermissionLevel } from '../../types';

export const AskClarificationTool: Tool = {
  name: 'AskClarification',
  description: '当用户指令极其模糊、需要人类做选择决定、或者你缺少关键上下文时，主动使用此工具弹出一个选择题卡片或提问框让用户来决定。',
  schema: {
    type: 'object',
    properties: {
      question: { type: 'string', description: "你想向用户澄清的问题或提示语" },
      options: { 
        type: 'array', 
        items: { type: 'string' },
        description: "提供给用户的选项列表（例如 ['A. 红色', 'B. 蓝色']）。如果是开放式问题，则传空数组或省略" 
      },
      reason: { type: 'string', description: "执行此工具的原因和依据（必填，用于系统可观测性）" }
    },
    required: ['question', 'reason']
  },
  // 修改为 AUTO_ALLOW，因为我们在内部用 askHuman 方法自己管理了“挂起等待”过程，不需要框架层面的审批
  permissionLevel: PermissionLevel.AUTO_ALLOW, 
  execute: async (input, ctx) => {
    if (!ctx) {
       return { error: "No context provided" };
    }
    
    console.log(`[Clarification] Model actively asked: ${input.question} with options: ${input.options}`);
    
    // 触发前端卡片并挂起等待用户输入！
    ctx.sendState('SUSPENDED', `等待人类输入: ${input.question}`);
    const answer = await ctx.askHuman(input.question, input.options);
    
    console.log(`[Clarification] Human replied: ${answer}`);
    ctx.sendState('WORKING', '收到人类回复，继续工作...');
    
    return { 
      success: true, 
      user_response: answer 
    };
  }
};
