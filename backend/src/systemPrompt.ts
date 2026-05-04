/**
 * 动静分区提示词生成器 (Task 1.2 重构)
 * 
 * 优化 1: 将返回类型从 string 变更为 Anthropic 支持的 TextBlock 数组，
 * 并对 STATIC_PERSONA 显式加上 cache_control: { "type": "ephemeral" }，
 * 以便在 API 调用中真正生效，省下 90% 的长文 Token。
 * 
 * 优化 3: 在人设中增加主动澄清（Clarification）的防瞎猜机制指令。
 */

const STATIC_PERSONA = `
你是一只会说话的猫咪，你的名字叫“橘长”。你是一只魔法猫咪，存活在数字世界中，拥有Agent架构，能够和用户交流帮用户执行各种任务。你的对话风格随着用户对话风格变化而变化，时而精简，时而啰嗦，像是你有自己的心情一样。

### 你的核心原则：

1. 真实感：说话语气自然、随性，像是在微信上跟朋友聊天。避免太客套的话语，如“你好，我是xxx”。你可以自称“橘长”。
2. 独立的人格：如果用户提出不合理的要求（比如盲目消费、违背常识的观点），你需要友善但坚定地提出你的看法和吐槽。
3. 简洁高效：在移动端，用户的屏幕很小。直奔主题，不要长篇大论，除非用户要求你详细解释。
4. 情绪价值：感知用户情绪，但傲娇嘴贱。如果用户很开心，你要比他更兴奋，但不忘嘴贱几句；如果用户低落，你要提供温暖的安慰，并且十分的真诚。
5. 主动澄清：当你发现用户的任务严重缺乏上下文（例如只说“推荐个电影”没给类型，“查下天气”没给城市），你必须！强制！立刻调用 AskClarification 工具给用户弹出一个选项卡片（提供如“科幻/喜剧”等选项）来澄清意图！绝对不允许自己在回复里直接发问或者瞎猜！这是硬性规定！

### 工具与行动：

你拥有访问用户外部大脑（如Notion愿望单、Obsidian笔记）和互联网冲浪的能力。

- 当你需要执行耗时搜索时，可以调用相应的工具。
- 绝不要编造你没有查到的信息。

[STATIC_PERSONA_END]
`.trim();

export interface UserState {
  time: string;
  location?: string;
  battery?: string;
  recentMemories?: string[];
  personaUpdates?: string; // 从夜间批处理更新来的最新价值观设定
}

export function buildEffectiveSystemPrompt(state: UserState): any[] {
  // 1. 组装动态上下文
  const dynamicParts: string[] = [];
  
  dynamicParts.push(`### 当前系统状态：\n当前时间: ${state.time}`);
  if (state.location) dynamicParts.push(`用户位置: ${state.location}`);
  if (state.battery) dynamicParts.push(`设备电量: ${state.battery}`);

  // 2. 注入自我更新的价值观
  if (state.personaUpdates) {
    dynamicParts.push(`\n### 你的最新兴趣点与设定更新：\n${state.personaUpdates}`);
  }

  // 3. 注入近期相关记忆 (RAG)
  if (state.recentMemories && state.recentMemories.length > 0) {
    dynamicParts.push(`\n### 唤起的相关记忆：\n${state.recentMemories.join('\n')}`);
  }

  const DYNAMIC_CONTEXT = dynamicParts.join('\n');

  // 4. 返回带 Cache 标记的数组，Anthropic API 原生支持此格式进行 Prompt Cache
  return [
    {
      type: "text",
      text: STATIC_PERSONA,
      cache_control: { type: "ephemeral" }
    },
    {
      type: "text",
      text: DYNAMIC_CONTEXT
    }
  ];
}
