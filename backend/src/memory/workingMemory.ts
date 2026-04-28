import OpenAI from 'openai';
import { AgentContext } from '../types';

const openai = new OpenAI({
  apiKey: process.env.MINIMAX_API_KEY || process.env.OPENAI_API_KEY || 'dummy',
  baseURL: process.env.MINIMAX_API_KEY ? 'https://api.minimax.chat/v1' : undefined
});

const TOKEN_LIMIT = 4000; // 假设阈值为 4000 字符估算

export async function compressHistoryIfNeeded(ctx: AgentContext): Promise<void> {
  // 简单估算 token (1 char ≈ 1 token for Chinese, roughly)
  let currentLength = 0;
  for (const msg of ctx.history) {
    if (typeof msg.content === 'string') {
      currentLength += msg.content.length;
    } else if (Array.isArray(msg.content)) {
      for (const block of msg.content) {
        if (block.text) currentLength += block.text.length;
        if (block.content) currentLength += block.content.length;
      }
    }
  }

  if (currentLength > TOKEN_LIMIT && ctx.history.length > 4) {
    console.log(`[Working Memory] History length ${currentLength} exceeds limit ${TOKEN_LIMIT}. Compressing...`);
    
    // 取出前 N 条消息进行压缩
    const messagesToCompress = ctx.history.slice(0, ctx.history.length - 2);
    const recentMessages = ctx.history.slice(ctx.history.length - 2);
    
    const textToCompress = messagesToCompress.map(m => `${m.role}: ${JSON.stringify(m.content)}`).join('\n');
    
    try {
      const modelName = process.env.MODEL_NAME || 'abab6.5s-chat';
      const response = await openai.chat.completions.create({
        model: modelName,
        messages: [
          { role: 'system', content: '请将以下对话历史压缩为 JSON 格式，必须包含两个字段：\n1. "summary": 对话的简短摘要和关键事实。\n2. "uncompleted_tasks": 用户尚未完成或明确交办给你的任务列表（字符串数组）。\n除了 JSON 对象外不要输出任何其他文本。' },
          { role: 'user', content: textToCompress }
        ]
      });
      
      const content = response.choices[0].message.content || '{}';
      let summaryText = '压缩失败';
      let tasksText = '无';
      try {
        const stateObj = JSON.parse(content);
        summaryText = stateObj.summary || '无摘要';
        tasksText = Array.isArray(stateObj.uncompleted_tasks) && stateObj.uncompleted_tasks.length > 0 
          ? stateObj.uncompleted_tasks.join('; ') 
          : '无';
      } catch(err) {
        console.warn('[Working Memory] JSON parse failed, using raw content');
        summaryText = content;
      }
      
      const structuredContent = `[历史摘要]: ${summaryText}\n[未完成任务]: ${tasksText}`;
      console.log(`[Working Memory] Compressed state:\n${structuredContent}`);
      
      // 替换历史记录
      ctx.history.length = 0;
      ctx.history.push({ role: 'assistant', content: structuredContent });
      ctx.history.push(...recentMessages);
      
    } catch (e) {
      console.error('[Working Memory] Compression failed:', e);
    }
  }
}
