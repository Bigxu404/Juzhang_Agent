import express from 'express';
import { prisma } from '../utils/db';
import { normalizeModelName } from '../utils/modelName';

export const userRouter = express.Router();

// 获取当前用户信息
userRouter.get('/me', async (req, res) => {
  try {
    const userId = (req as any).userId; // 需要鉴权中间件
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, username: true, apiKey: true, modelName: true, subModelName: true }
    });
    res.json(user);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 更新用户配置 (API Key 和 模型)
userRouter.put('/config', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { apiKey, modelName, subModelName } = req.body;
    
    const dataToUpdate: any = {};
    if (apiKey !== undefined) dataToUpdate.apiKey = apiKey;
    if (modelName !== undefined) dataToUpdate.modelName = normalizeModelName(modelName);
    if (subModelName !== undefined) dataToUpdate.subModelName = normalizeModelName(subModelName);
    
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: dataToUpdate,
      select: { id: true, username: true, apiKey: true, modelName: true, subModelName: true }
    });

    res.json(updatedUser);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 获取当前用户的记忆列表
userRouter.get('/memories', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const limitRaw = Number(req.query.limit);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 200) : 50;

    const memories = await prisma.memory.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit
    });

    res.json(memories);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 删除某条记忆
userRouter.delete('/memories/:id', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const memory = await prisma.memory.findUnique({ where: { id: req.params.id } });
    if (!memory || memory.userId !== userId) {
      return res.status(404).json({ error: 'Memory not found' });
    }

    await prisma.memory.delete({ where: { id: req.params.id } });
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 清空当前用户所有记忆
userRouter.delete('/memories', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const result = await prisma.memory.deleteMany({ where: { userId } });
    res.json({ success: true, deleted: result.count });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 获取当前用户技能列表
userRouter.get('/skills', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const skills = await prisma.skill.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' }
    });
    res.json(skills);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 创建用户技能
userRouter.post('/skills', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { name, description, content } = req.body ?? {};
    if (!name || !description || !content) {
      return res.status(400).json({ error: 'name, description and content are required' });
    }

    const created = await prisma.skill.create({
      data: {
        userId,
        name: String(name).trim(),
        description: String(description).trim(),
        content: String(content)
      }
    });
    res.status(201).json(created);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 更新技能启用状态
userRouter.patch('/skills/:id', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const { isActive } = req.body ?? {};
    if (typeof isActive !== 'boolean') {
      return res.status(400).json({ error: 'isActive(boolean) is required' });
    }

    const skill = await prisma.skill.findUnique({ where: { id: req.params.id } });
    if (!skill || skill.userId !== userId) {
      return res.status(404).json({ error: 'Skill not found' });
    }

    const updated = await prisma.skill.update({
      where: { id: req.params.id },
      data: { isActive }
    });
    res.json(updated);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 删除技能
userRouter.delete('/skills/:id', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const skill = await prisma.skill.findUnique({ where: { id: req.params.id } });
    if (!skill || skill.userId !== userId) {
      return res.status(404).json({ error: 'Skill not found' });
    }

    await prisma.skill.delete({ where: { id: req.params.id } });
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 获取 MCP 外部授权状态（当前先返回可扩展的 Provider 列表）
userRouter.get('/mcp/providers', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const notionConfigured = Boolean(process.env.NOTION_MCP_COMMAND);
    const providers = [
      {
        id: 'notion',
        name: 'Notion',
        description: '同步笔记检索与写入能力',
        connected: notionConfigured
      },
      {
        id: 'github',
        name: 'GitHub',
        description: '代码仓库与 Issue 管理（预留）',
        connected: false
      }
    ];

    res.json({ providers });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 发起 MCP 授权（MVP: 返回授权说明，后续可接 OAuth/扫码）
userRouter.post('/mcp/authorize', async (req, res) => {
  try {
    const userId = (req as any).userId;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const providerId = String(req.body?.providerId || '').trim();
    if (!providerId) {
      return res.status(400).json({ error: 'providerId is required' });
    }

    if (providerId === 'notion') {
      const configured = Boolean(process.env.NOTION_MCP_COMMAND);
      if (configured) {
        return res.json({
          success: true,
          connected: true,
          message: 'Notion MCP 已在服务端配置并可用。'
        });
      }
      return res.json({
        success: false,
        connected: false,
        message: 'Notion MCP 尚未在服务端配置。请先设置 NOTION_MCP_COMMAND / NOTION_MCP_ARGS。'
      });
    }

    return res.json({
      success: false,
      connected: false,
      message: `${providerId} 授权能力暂未开放。`
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});
