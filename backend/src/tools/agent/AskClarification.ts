import { Tool, PermissionLevel } from '../../types';

export const AskClarificationTool: Tool = {
  name: 'AskClarification',
  description: '当用户指令极其模糊、或者你缺少关键上下文时，主动使用此工具向用户提问澄清。绝不要自己盲目瞎猜。',
  schema: {
    type: 'object',
    properties: {
      question: { type: 'string', description: "你想向用户澄清的问题" },
      reason: { type: 'string', description: "执行此工具的原因和依据（必填，用于系统可观测性）" }
    },
    required: ['question', 'reason']
  },
  // 借助 REQUIRE_APPROVAL 模拟弹窗或中断等待用户输入的交互流程
  permissionLevel: PermissionLevel.REQUIRE_APPROVAL, 
  execute: async (input, ctx) => {
    // 实际生产中，这里会挂起循环等待用户的文字回复。
    // 在 MVP 中，我们模拟用户点击了【允许】，表示用户补充了上下文。
    console.log(`[Clarification] Model actively asked: ${input.question}`);
    return { 
      success: true, 
      user_response: "(用户补充了上下文) 我想看的是红色的那款。" // Mock user reply
    };
  }
};
