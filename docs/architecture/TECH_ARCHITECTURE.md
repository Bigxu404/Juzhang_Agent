description: 详细定义了iOS Agent产品的端云分离技术架构、核心组件、模块间通讯协议及部署方案，为后续拆解开发任务提供坚实的技术底座。

# iOS Agent 产品技术架构 (TECH_ARCHITECTURE.md)

## 1. 架构总览：端云分离 (Client-Server Split)

本产品采用 **“瘦客户端 (iOS) + 强服务端 (Node.js/Python)”** 的端云分离架构。
- **iOS 客户端** 负责承担用户的“感官”与交互界面，包括 Share Extension 灵感收集、极简聊天 UI、以及系统级触觉与通知反馈。
- **服务端** 负责扮演“大脑”，运行 Agentic 核心循环、记忆引擎（Persona & Vector DB）以及 MCP（Model Context Protocol）的连接沙箱。

这样设计的原因是：iOS 后台机制极其严苛，如果把长时间的“互联网冲浪”和多次调用 LLM 的 Agent 循环放在本地跑，一旦应用退到后台极易被系统 Kill，且长文本 RAG 在移动端算力和流量成本过高。云端统筹能确保“夜间冲浪”和复杂工具编排的安全稳定。

---

## 2. 核心组件设计

### 2.1 服务端架构 (The Agent Core & MCP Hub)

服务端是整个系统的主干，包含以下核心服务：

#### A. Coordinator Engine (多Agent协同层)
基于 Anthropic 的“简单可组合”设计理念（参考 `building-effective-agents.md`）和 Claude Code 源码：
- **Router / Coordinator Agent**：接收 iOS 的 WebSocket 消息，负责与用户对话。当需要处理复杂任务（如：总结长文、全网比价）时，不自己执行，而是启动 Subagent。
- **Explore Subagent (冲浪专属)**：纯后台的“阅读工具人”。使用低延迟、廉价的模型（如 Claude Haiku 或 Gemini Flash）。严格运行在只读模式下（`disallowedTools: [FILE_WRITE, MCP_WRITE]`），避免越权修改数据。
- **Action Subagent (操作专属)**：高权限代理，专职调用 MCP 写入外部数据库。

#### B. Context & Memory Manager (上下文与记忆管理层)
- **Session Working Memory (短期会话)**：基于 Redis 缓存最近的 N 轮对话历史。
- **Vector DB (情景记忆)**：集成 Pinecone 或 Qdrant 存储用户的流水账事件（如：“帮我把鞋加进了清单”），按需检索 (RAG)。
- **Semantic Memory (画像系统)**：存储 `Persona.md`，使用 Prompt Cache 技术将固定的人设/工具配置锁定在 LLM 缓存层，节省 90% Token 成本。
- **Reflection Job (夜间批处理)**：定期通过定时任务 (Cron) 将当天的对话提炼成兴趣更新，微调 `Persona.md` 以实现“自我价值观更新”。

#### C. MCP Client Hub (外部工具沙箱)
- 独立服务/进程，安全管理用户授权的第三方 Token (例如 Notion OAuth)。
- 通过官方或社区提供的 `@modelcontextprotocol/sdk` 连接远程知识库。
- **原子化工具接口**：封装如 `QueryNotionDB`, `AppendNotionBlock` 的原子方法供 Action Subagent 使用。

#### D. Harness & Security (权限拦截层)
- 实现类似 CC 的六层安检：所有 MCP 的写入操作（如修改 Notion 页面）必须挂起当前循环，通过 WebSocket 向 iOS 下发 `PermissionRequest` 指令，等待用户通过。

### 2.2 iOS 客户端架构 (The Body & Senses)

客户端采用全 Swift / SwiftUI 构建，深度融合 iOS 原生特性：

#### A. Main App (主界面交互)
- 极简的 Chat UI，支持 WebSocket 接收流式返回（Typewriter 动画）。
- 支持多模态附件上传（直接拍照、选相册）。
- **状态感知栏 (State Indicator)**：实时监听服务端的 Subagent 状态（“正在全网比价…”、“正在写入Notion…”），配合 Haptic 触觉反馈增强活人感。

#### B. Share Extension (系统级分享拦截器)
- 注册针对 URL (`public.url`) 和 Text (`public.plain-text`) 的分享菜单拦截。
- 提供 Mini Chat View：用户可以在不打开主 App 的情况下一键将网页 URL 丢给服务端的 Explore Subagent 并附加一句“帮我总结”。

#### C. Notification & Background Tasks (主动交互机制)
- APNs 推送集成互动式通知，接收从服务端下发的高潮反馈（“比价完成，[查看结果]”）。
- Background Fetch 辅助拉取最新状态（备用）。

---

## 3. 通信与数据流 (Data Flow)

整个系统的运转主要依赖以下通讯协议：

### 3.1 核心对话流 (WebSocket)
- **iOS -> Server**: `{"type": "MESSAGE", "content": "帮我看看这个鞋", "attachments": [{"type": "image", "data": "..."}]}`
- **Server -> iOS (Status)**: `{"type": "AGENT_STATE", "status": "WORKING", "description": "正在启动冲浪代理全网搜索..."}`
- **Server -> iOS (Stream)**: `{"type": "CHUNK", "text": "这鞋确实挺好看的，而且我看了下..."}`
- **Server -> iOS (Permission)**: `{"type": "PERMISSION_REQ", "tool": "NotionAppend", "desc": "是否允许我将鞋存入你的心愿单？"}`
- **iOS -> Server**: `{"type": "PERMISSION_RES", "action": "ALLOW"}`

### 3.2 离线收集流 (REST API)
Share Extension 因生命周期极短，采用 HTTP 短链接：
- **Extension -> Server**: `POST /api/share/ingest` (Payload: `{url: "...", note: "总结重点"}`)
- 服务器返回 HTTP 202 (Accepted)，将任务塞入后台队列，然后由 Explore Subagent 慢慢啃，完成后通过 APNs 推送结果给用户的 iOS 设备。

---

## 4. 关键技术选型建议

| 模块 | 推荐选型 | 理由 |
| :--- | :--- | :--- |
| **客户端语言** | Swift / SwiftUI | 原生极简UI、易于集成Share Extension和Haptic Feedback |
| **服务端语言** | Node.js (TypeScript) | 生态极其丰富，LangChain / Vercel AI SDK 极其成熟，MCP 官方 SDK 就是 TS 的。 |
| **大语言模型** | Gemini 1.5 Flash (快) + Claude 3.5 Sonnet / Opus (思考) | Gemini 多模态长上下文处理优秀；Claude 在工具调用和 Agentic 推理上最强，参考 *Vibe Physics*。 |
| **记忆向量库** | Pinecone 或 Qdrant (云端) | 快速存储和检索 Episodic Memory，免去自建开销。 |
| **持久化通讯** | Socket.IO 或标准 WebSocket | 支持流式文本和Agent状态（思考中、工具调用中）下发。 |
| **外部扩展** | Notion API / Readwise | 作为 MVP 阶段的核心 MCP 接入点，验证从阅读到记录的闭环。 |

---

这个技术框架明确了“谁干什么、怎么沟通”，是指导我们把虚幻的“活人感朋友”落地的蓝图。接下来我们将基于此框架，拆分成详细的开发需求 List。
