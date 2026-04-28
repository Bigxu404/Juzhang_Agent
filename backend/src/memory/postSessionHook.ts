import { memoryManager } from './DatabaseMemory';
import { prisma } from '../utils/db';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.MINIMAX_API_KEY || process.env.OPENAI_API_KEY || 'dummy',
  baseURL: process.env.MINIMAX_API_KEY ? 'https://api.minimax.chat/v1' : undefined
});

/**
 * Task 3.2.2: 会话流水账写入钩子 (Post-Session Hook)
 * 在每次 Agent Loop 结束后，将关键的信息提取并存入向量数据库作为长期情节记忆 (Episodic Memory)。
 */
export async function runPostSessionHook(sessionId: string, userId: string, query: string, agentResponse: string, userModelName?: string) {
    try {
        console.log(`[Post-Session Hook] Analyzing conversation for episodic memory...`);
        
        // 1. 生成会话 AI 标题（如果当前还是默认的"新对话"）
        try {
            const session = await prisma.session.findUnique({ where: { id: sessionId } });
            if (session && session.title === '新对话' && query.length > 1) {
                console.log(`[Post-Session Hook] Generating AI title for new session...`);
                const modelName = userModelName || process.env.MODEL_NAME || 'abab6.5s-chat';
                const response = await openai.chat.completions.create({
                    model: modelName,
                    messages: [
                        { role: 'system', content: '你是一个精炼的助手。请为下面的对话生成一个极短的标题（最多不超过 10 个字），不要加书名号或任何标点符号。直接输出标题文本。' },
                        { role: 'user', content: `用户说: ${query}\n助手回复: ${agentResponse.substring(0, 200)}` }
                    ],
                    max_tokens: 20
                });
                const aiTitle = response.choices[0].message.content?.trim();
                if (aiTitle && aiTitle.length > 0) {
                    await prisma.session.update({
                        where: { id: sessionId },
                        data: { title: aiTitle.substring(0, 15) }
                    });
                    console.log(`[Post-Session Hook] Session title updated to: ${aiTitle}`);
                }
            }
        } catch (e) {
            console.error(`[Post-Session Hook] Failed to generate AI title:`, e);
        }

        // 2. 原有的记忆写入逻辑
        const summary = `用户诉求: ${query}\nAgent响应: ${agentResponse}`;

        // 仅在对话包含有效信息时存入记忆（例如过滤掉简单的问候）
        if (query.length > 5) {
            await memoryManager.saveMemory({
                sessionId: sessionId,
                userId: userId,
                timestamp: Date.now(),
                eventType: "USER_INTERACTION",
                content: summary
            });
            console.log(`[Post-Session Hook] Memory saved for session ${sessionId}`);
        } else {
            console.log(`[Post-Session Hook] Interaction too short, skipped memory save.`);
        }
    } catch (error) {
        console.error('[Post-Session Hook] Error:', error);
    }
}
