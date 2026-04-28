import { memoryManager, MemoryMetadata } from './DatabaseMemory';
import { prisma } from '../utils/db';
import { logger } from '../utils/logger';

/**
 * Task 3.2.3: 主动检索节点 (Pre-Agent Router)
 * 在主 Agent Loop 处理新的用户输入之前，对输入进行 Embedding 检索，提取相关的历史情节记忆 (Episodic Memory)。
 */
export async function runPreAgentRouter(query: string, userId: string): Promise<string> {
    try {
        console.log(`[Pre-Agent Router] Searching episodic memory for: "${query}"...`);
        
        // 搜索前 3 条最相关的记忆片段
        const topMemories: MemoryMetadata[] = await memoryManager.searchMemory(query, userId, 3);
        
        if (topMemories.length === 0) {
            return "无相关的长期记忆。";
        }
        
        // 组装记忆上下文返回
        const memoryStrings = topMemories.map((mem, index) => {
            const dateStr = new Date(mem.timestamp).toLocaleString();
            return `[${index + 1}] (${dateStr}) ${mem.content}`;
        });
        
        return "相关的历史情节记忆:\n" + memoryStrings.join("\n");
    } catch (error: any) {
        logger.warn('PRE_AGENT_ROUTER_FAILED', { error: error.message });
        console.error('[Pre-Agent Router] Vector Search failed, degrading to local keyword match...');
        
        try {
            // 优雅降级：直接从数据库中取最近 20 条消息，在内存中做简单的包含匹配
            const recentMessages = await prisma.message.findMany({
                where: { role: 'user' },
                orderBy: { createdAt: 'desc' },
                take: 20
            });
            
            const matched = recentMessages.filter(m => m.content.includes(query) || query.includes(m.content));
            if (matched.length > 0) {
                const degradedStrings = matched.slice(0, 3).map((mem, i) => `[降级召回${i + 1}] ${mem.content}`);
                return "相关的近期对话记忆 (降级匹配):\n" + degradedStrings.join("\n");
            }
            return "无相关的近期记忆 (降级)。";
        } catch (degradeError: any) {
            logger.error('PRE_AGENT_ROUTER_DEGRADE_FAILED', { error: degradeError.message });
            return "长期记忆检索服务暂时不可用。";
        }
    }
}
