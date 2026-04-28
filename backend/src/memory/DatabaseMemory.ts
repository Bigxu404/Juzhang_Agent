import { prisma } from '../utils/db';
import OpenAI from 'openai';
import dotenv from 'dotenv';
import crypto from 'crypto';

dotenv.config();

// Task 3.2.1: 定义 Pinecone 的 Metadata 结构
export interface MemoryMetadata {
    sessionId: string;
    userId: string;
    timestamp: number;
    eventType: string; // 例如: "USER_QUERY", "AGENT_REFLECTION", "TOOL_ACTION"
    content: string;   // 具体的记忆内容
}

export class MemoryManager {
    private openai: OpenAI | null = null;

    constructor() {
        if (process.env.OPENAI_API_KEY) {
            this.openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
        } else {
            console.warn('[OpenAI] Missing OPENAI_API_KEY. Embeddings will be mocked.');
        }
    }

    private async getEmbedding(text: string): Promise<number[]> {
        if (!this.openai) {
            // 返回一个固定维度的 Mock 向量用于本地跑通测试 (通常 Pinecone 索引建立的是 1536 维对于 text-embedding-3-small)
            return Array(1536).fill(0.1); 
        }
        try {
            const response = await this.openai.embeddings.create({
                model: "text-embedding-3-small",
                input: text,
            });
            return response.data[0].embedding;
        } catch (error) {
            console.error('[OpenAI] Embedding error:', error);
            return Array(1536).fill(0.1); 
        }
    }

    public async saveMemory(metadata: MemoryMetadata): Promise<void> {
        try {
            const embedding = await this.getEmbedding(metadata.content);
            
            await prisma.memory.create({
                data: {
                    userId: metadata.userId,
                    content: metadata.content,
                    embedding: JSON.stringify(embedding)
                }
            });
            console.log(`[Database Memory] Successfully saved memory for user ${metadata.userId}`);
        } catch (error) {
            console.error('[Database Memory] Save memory failed:', error);
        }
    }

    public async searchMemory(query: string, userId: string, limit: number = 3): Promise<MemoryMetadata[]> {
        try {
            const queryEmbedding = await this.getEmbedding(query);
            
            // 获取该用户的所有记忆
            const allMemories = await prisma.memory.findMany({
                where: { userId }
            });

            if (allMemories.length === 0) return [];

            // 在 Node.js 内存中进行简单的余弦相似度计算 (对于 MVP 的小数据量完全够用)
            const scoredMemories = allMemories.map(mem => {
                const memEmbedding = JSON.parse(mem.embedding) as number[];
                const score = this.cosineSimilarity(queryEmbedding, memEmbedding);
                return { ...mem, score };
            });

            // 排序并取 Top K
            scoredMemories.sort((a, b) => b.score - a.score);
            const topMemories = scoredMemories.slice(0, limit);

            return topMemories.map(mem => ({
                sessionId: "db-session",
                userId: mem.userId,
                timestamp: mem.createdAt.getTime(),
                eventType: "DATABASE_MEMORY",
                content: mem.content
            }));
        } catch (error) {
            console.error('[Database Memory] Search memory failed:', error);
            return [];
        }
    }

    private cosineSimilarity(vecA: number[], vecB: number[]): number {
        let dotProduct = 0;
        let normA = 0;
        let normB = 0;
        for (let i = 0; i < vecA.length; i++) {
            dotProduct += vecA[i] * vecB[i];
            normA += vecA[i] * vecA[i];
            normB += vecB[i] * vecB[i];
        }
        if (normA === 0 || normB === 0) return 0;
        return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
    }
}

export const memoryManager = new MemoryManager();
