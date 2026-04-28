import express from 'express';
import http from 'http';
import { Server, Socket } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import { ToolDispatcher } from './tools/ToolDispatcher';
import { SearchNotionTool, AppendNotionBlockTool } from './tools/mcp/notionTools';
import { DelegateToExploreAgentTool } from './tools/agent/DelegateToExploreAgent';
import { AskClarificationTool } from './tools/agent/AskClarification';
import { McpClientManager } from './tools/mcp/McpClientManager';
import { runAgent } from './agent/runAgent';
import { AgentContext } from './types';
import { authRouter } from './api/auth';
import { userRouter } from './api/user';
import { prisma } from './utils/db';
import { sessionMutex } from './utils/mutex';
import jwt from 'jsonwebtoken';

import { AgentState } from './websocket/AgentState';

import { runExploreAgent } from './agent/exploreAgent';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev';

// HTTP 鉴权中间件
const authMiddleware = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    (req as any).userId = decoded.userId;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

// 挂载鉴权路由
app.use('/api/auth', authRouter);
app.use('/api/user', authMiddleware, userRouter);

// Task 4.3.2 & 4.3.3: 离线发送接口与 APNs 占位
app.post('/api/share/ingest', async (req, res) => {
  const { url, text, deviceToken } = req.body;
  console.log(`[Share Extension] Received payload:`, { url, text });
  
  // 异步触发 Explore Agent 去处理总结和归档逻辑
  (async () => {
    try {
      const taskDesc = `请阅读并总结此链接的内容: ${url}。用户附言: ${text || '无'}`;
      const result = await runExploreAgent(taskDesc);
      console.log(`[Share Extension] Finished processing shared content for ${url}. Result: ${result}`);
      
      if (deviceToken) {
        console.log(`[APNs Mock] Sending push notification to ${deviceToken}: "阅读摘要已生成，存入Notion了"`);
      }
    } catch (e) {
      console.error(`[Share Extension] Error processing content:`, e);
    }
  })();

  res.status(200).json({ success: true, message: 'Content ingested successfully' });
});

// Setup Tool Dispatcher globally
const dispatcher = new ToolDispatcher();
dispatcher.register(SearchNotionTool);
dispatcher.register(AppendNotionBlockTool);
dispatcher.register(DelegateToExploreAgentTool);
dispatcher.register(AskClarificationTool);

// Task 2.2: MCP Integration
const mcpManager = new McpClientManager(dispatcher);
if (process.env.NOTION_MCP_COMMAND) {
  // e.g. NOTION_MCP_COMMAND="node"
  // e.g. NOTION_MCP_ARGS="/path/to/mcp-server-notion/build/index.js arg1"
  const args = process.env.NOTION_MCP_ARGS ? process.env.NOTION_MCP_ARGS.split(' ') : [];
  mcpManager.connect(process.env.NOTION_MCP_COMMAND, args).catch(console.error);
} else {
  console.log('[Server] NOTION_MCP_COMMAND not provided in .env, using mock Notion tools.');
}

// WS 鉴权中间件
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) {
    return next(new Error('Authentication error: Token missing'));
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    const user = await prisma.user.findUnique({ where: { id: decoded.userId } });
    if (!user) {
      return next(new Error('Authentication error: User not found'));
    }
    // 将用户信息挂载到 socket 上
    (socket as any).user = user;
    next();
  } catch (err) {
    next(new Error('Authentication error: Invalid token'));
  }
});

io.on('connection', async (socket: Socket) => {
  const user = (socket as any).user;
  console.log(`[WS] Client connected: ${socket.id}, User: ${user.username}`);

  // 为用户查找或创建一个活跃的 Session
  let session = await prisma.session.findFirst({
    where: { userId: user.id },
    orderBy: { updatedAt: 'desc' }
  });

  if (!session) {
    session = await prisma.session.create({
      data: {
        userId: user.id,
        title: '新对话'
      }
    });
  }

  // 加载历史消息
  const dbMessages = await prisma.message.findMany({
    where: { sessionId: session.id },
    orderBy: { createdAt: 'asc' }
  });

  // 将数据库消息转换为 Agent 需要的格式
  const history: any[] = dbMessages.map(msg => {
    if (msg.role === 'assistant' && msg.toolCalls) {
      return {
        role: msg.role,
        content: msg.content,
        tool_calls: JSON.parse(msg.toolCalls)
      };
    } else if (msg.role === 'tool' && msg.toolCalls) {
      return {
        role: msg.role,
        content: msg.content,
        tool_call_id: JSON.parse(msg.toolCalls).id
      };
    }
    return {
      role: msg.role,
      content: msg.content
    };
  });

  let pendingPermissionResolve: ((approved: boolean) => void) | null = null;

  const ctx: AgentContext = {
    sessionId: session.id, // 使用真实的数据库 Session ID
    userId: user.id,       // 传入真实的用户 ID
    apiKey: user.apiKey || undefined,
    modelName: user.modelName || undefined,
    requestPermission: async (toolName: string, desc: string) => {
      socket.emit('PERMISSION_REQ', { tool: toolName, desc });
      return new Promise<boolean>((resolve) => {
        pendingPermissionResolve = resolve;
      });
    },
    sendState: (status: AgentState | string, desc: string) => {
      socket.emit('AGENT_STATE', { status, description: desc });
    },
    sendChunk: async (text: string) => {
      const chars = Array.from(text);
      for (const char of chars) {
        socket.emit('CHUNK', { text: char });
        let delay = 30;
        if (['，', '。', '！', '？', '；', '：', ',', '.', '!', '?', ';', ':'].includes(char)) {
          delay = 300;
        } else if (['\n'].includes(char)) {
          delay = 500;
        }
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    },
    sendEvent: (event) => {
      socket.emit('AGENT_EVENT', event);
    },
    history
  };

  socket.emit('AGENT_STATE', { status: AgentState.IDLE, description: 'Agent is ready.' });
  if (history.length === 0) {
    socket.emit('CHUNK', { text: `你好，${user.username}！我是你的数字老友，有什么我可以帮你的吗？` });
  } else {
    socket.emit('SESSION_LOADED', { messages: history });
  }

  socket.on('MESSAGE', async (payload: { content: string, attachments?: any[] }) => {
    console.log(`[WS] Received MESSAGE from ${user.username}:`, payload.content);
    
    // 保存用户消息到数据库
    await sessionMutex.runExclusive(session!.id, async () => {
      await prisma.message.create({
        data: {
          sessionId: session!.id,
          role: 'user',
          content: payload.content
        }
      });
    });

    // Call the Agent ReAct loop
    await runAgent(payload.content, dispatcher, ctx);
    
    socket.emit('AGENT_STATE', { status: AgentState.IDLE, description: '等待输入...' });
  });

  socket.on('CLEAR_CHAT', async () => {
    console.log(`[WS] Received CLEAR_CHAT from ${user.username}, creating new session.`);
    session = await prisma.session.create({
      data: {
        userId: user.id,
        title: '新对话'
      }
    });
    ctx.sessionId = session.id;
    ctx.history.length = 0;
    socket.emit('AGENT_STATE', { status: AgentState.IDLE, description: 'Agent is ready.' });
    socket.emit('CHUNK', { text: `你好，${user.username}！这是全新的对话，有什么我可以帮你的吗？` });
  });

  socket.on('GET_SESSIONS', async () => {
    console.log(`[WS] Received GET_SESSIONS from ${user.username}`);
    const sessions = await prisma.session.findMany({
      where: { userId: user.id },
      orderBy: { updatedAt: 'desc' }
    });
    socket.emit('SESSIONS_LIST', sessions);
  });

  socket.on('LOAD_SESSION', async (payload: { sessionId: string }) => {
    console.log(`[WS] Received LOAD_SESSION ${payload.sessionId} from ${user.username}`);
    const loadedSession = await prisma.session.findUnique({
      where: { id: payload.sessionId }
    });
    if (loadedSession && loadedSession.userId === user.id) {
      session = loadedSession;
      ctx.sessionId = session.id;
      
      const dbMessages = await prisma.message.findMany({
        where: { sessionId: session.id },
        orderBy: { createdAt: 'asc' }
      });

      ctx.history = dbMessages.map(msg => {
        if (msg.role === 'assistant' && msg.toolCalls) {
          return { role: msg.role, content: msg.content, tool_calls: JSON.parse(msg.toolCalls) };
        } else if (msg.role === 'tool' && msg.toolCalls) {
          return { role: msg.role, content: msg.content, tool_call_id: JSON.parse(msg.toolCalls).id };
        }
        return { role: msg.role, content: msg.content };
      });
      
      socket.emit('SESSION_LOADED', { sessionId: session.id, messages: ctx.history });
    }
  });

  socket.on('PERMISSION_RES', (payload: { action: 'ALLOW' | 'DENY' }) => {
    console.log(`[WS] Received PERMISSION_RES from ${socket.id}: ${payload.action}`);
    if (pendingPermissionResolve) {
      pendingPermissionResolve(payload.action === 'ALLOW');
      pendingPermissionResolve = null;
    }
  });

  socket.on('disconnect', () => {
    console.log(`[WS] Client disconnected: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`[Server] Mobile Agent Backend Core loop running on port ${PORT}`);
});
