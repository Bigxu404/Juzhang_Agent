description: 这是一份极高颗粒度的开发计划清单，细化到具体的文件、接口、提示词策略和数据库表设计，作为开发阶段的执行看板。

# 移动端 Agent 产品开发计划 (DEVELOPMENT_PLAN.md)

本计划表将整个系统的开发工作拆解为**函数级、接口级和配置级**的微小任务 (Epics -> Tasks -> Sub-tasks)，严格确保每个任务具备清晰的前置依赖和可被独立验证的成果。

---

## Phase 1: 核心大脑与基础通讯 (The Brain & The Spine)
**目标**：跑通后端的 Agent Loop，实现动态提示词加载，并与一个模拟的客户端通过 WebSocket 完成状态同步。不涉及复杂MCP和多Agent。

### Epic 1.1: 基础服务脚手架与长连接
- [x] **Task 1.1.1: Node.js 服务初始化**
  - **实现细节**：使用 Express 或 Hono 初始化后端，配置 TypeScript 编译环境。
  - **验收标准**：服务可启动，`GET /health` 返回 200 OK。
- [x] **Task 1.1.2: WebSocket 状态机实现**
  - **实现细节**：集成 `Socket.IO`。定义并实现协议中的事件：`MESSAGE` (接收), `CHUNK` (文本流), `AGENT_STATE` (状态变更)。
  - **验收标准**：可以通过 Postman 或简单网页客户端连上 WS，并收到服务端的欢迎信息。

### Epic 1.2: System Prompt 与人格引擎基础 (Persona V1)
- [x] **Task 1.2.1: 动静分区提示词生成器**
  - **参考**：CC源码 `buildEffectiveSystemPrompt`。
  - **实现细节**：编写 `systemPrompt.ts`。定义 `STATIC_PERSONA` (独立人格约束、活人感要求) 和 `DYNAMIC_CONTEXT` (时间、系统状态、短期记忆拼接点)。
  - **验收标准**：给定任意用户状态，函数能正确拼装出包含分隔符的 Prompt 字符串。
- [x] **Task 1.2.2: LLM 客户端封装 (支持 Prompt Cache)**
  - **实现细节**：使用 Anthropic SDK（或 Vercel AI SDK）。明确在 `STATIC_PERSONA` 结尾处打上 Cache 标记 (`{"type": "ephemeral"}`)，以复用长文本人设。
  - **验收标准**：发起的请求在 API 面板中能看到 Cache Hit 指标提升。

### Epic 1.3: 单体 Agent ReAct 循环
- [x] **Task 1.3.1: 基础 Agent Loop 引擎**
  - **实现细节**：实现 `runAgent()` 函数。接收用户输入 -> 调用 LLM -> 判断 `tool_calls` 或 `text` -> 解析结果 -> 追加到 History。
  - **验收标准**：纯文本问答可跑通。
- [x] **Task 1.3.2: 工具注册表与执行分发器**
  - **实现细节**：定义标准化的 `Tool` 接口（包含 `name, description, schema, execute`）。实现 `ToolDispatcher` 模块。
  - **验收标准**：提供一个 Dummy 工具（如 `GetTime`），Agent 能自主决定调用并在循环内获得结果。

---

## Phase 2: Harness 安全拦截与 MCP 沙箱 (The Hands & The Shield)
**目标**：接通外部世界（Notion/Readwise等），并实现强有力的“操作前阻断确认”机制。

### Epic 2.1: 权限大脑 (Harness)
- [x] **Task 2.1.1: 工具权限分级定义**
  - **实现细节**：修改 `Tool` 接口，增加 `permissionLevel` 字段（1: 自动放行, 2: 事后通知, 3: 强制拦截）。
- [x] **Task 2.1.2: WebSocket 权限拦截器 (Interceptor)**
  - **实现细节**：在 `ToolDispatcher` 触发工具前插入拦截逻辑。若遇到 Level 3 工具，挂起（Suspend）当前 Agent Loop（Promise pending），通过 WebSocket 向客户端下发 `PERMISSION_REQ`。
  - **验收标准**：模拟触发高危工具，后端终端暂停输出，直到收到来自 WS 的 `PERMISSION_RES(ALLOW)` 才继续执行。
- [x] **Task 2.1.3: 拒绝熔断器 (Denial Tracker)**
  - **参考**：CC源码 `denialTracking.ts`。
  - **实现细节**：如果在同一次会话中连续被拒绝 3 次，直接终止 Agent Loop，并返回文本“好的，那我们先不操作这个了”。

### Epic 2.2: MCP Notion 集成 (MVP 级沙箱)
- [x] **Task 2.2.1: MCP Client 初始化**
  - **实现细节**：使用 `@modelcontextprotocol/sdk` 连接 Notion MCP Server（可使用官方或社区实现）。
  - **验收标准**：后端能够成功连接 Notion 并获取 Database List。
- [x] **Task 2.2.2: 原子工具提取与注册**
  - **实现细节**：将 MCP 暴露的工具过滤并注册到我们自己的 `ToolDispatcher` 中。暴露 `AppendNotionBlock` (Level 3) 和 `SearchNotion` (Level 1)。

---

## Phase 3: 多Agent协同与价值观更新 (The Coordinator & Reflection)
**目标**：摆脱大模型单兵作战，实现分工。让产品能“冲浪”和“进化”。

### Epic 3.1: Coordinator 与 Explore Subagent
- [x] **Task 3.1.1: Subagent 派发器 (AgentTool)**
  - **实现细节**：创建一个叫 `DelegateToExploreAgent` 的工具。当主 Agent 发现需要查资料时，调用此工具。
- [x] **Task 3.1.2: Explore Agent 实例配置**
  - **实现细节**：为 Explore Agent 配置独立的只读 Prompt（“你是一个快速信息提取员，绝对不能写数据”），仅赋予 `WebSearch` 和 `WebFetch` 工具。
  - **验收标准**：主 Agent 发出“正在搜索”的 WS 状态，等待 Explore Agent 异步返回结果后，主 Agent 根据结果给出回答。

### Epic 3.2: 记忆存储与检索 (Episodic Memory)
- [x] **Task 3.2.1: 向量数据库初始化**
  - **实现细节**：集成 Pinecone 客户端，定义 Metadata 结构 (`{ sessionId, timestamp, eventType }`)。
- [x] **Task 3.2.2: 会话流水账写入钩子 (Post-Session Hook)**
  - **实现细节**：每次长会话结束后，异步触发小模型（Haiku/Flash）对会话进行“事件化总结”，并写入 Pinecone。
- [x] **Task 3.2.3: 主动检索节点 (Pre-Agent Router)**
  - **实现细节**：在用户每次发言进入主 Agent Loop 前，先将其 Query 进行 Embedding 检索，召回 Top-3 记忆注入到 `DYNAMIC_CONTEXT` 中。

### Epic 3.3: 夜间冲浪与价值观更新 (Persona Mutation)
- [x] **Task 3.3.1: 兴趣点提炼脚本 (Reflection Job)**
  - **实现细节**：编写定时任务。读取过去 24 小时的 Working Memory，提取新的关注点（如：“用户最近迷上了机械键盘”）。
- [x] **Task 3.3.2: 自动冲浪并更新 Persona (Proactive Update)**
  - **实现细节**：自动启动 Explore Subagent 对新关注点进行广度搜索。将搜索到的前沿信息交由主模型凝练，生成一段新的“人设指令”（如：“作为朋友，你可以适时讨论各大轴体的手感”），并持久化到用户的 `Persona.md` 中。

---

## Phase 4: iOS 原生客户端 (The Physical Body)
**目标**：为用户提供最终的活人感交互界面。

### Epic 4.1: 基础聊天界面与 WS 通信
- [x] **Task 4.1.1: iOS 项目与 WebSocket 库集成**
  - **实现细节**：创建 SwiftUI 项目，引入 `Starscream` 或其他可靠的 WebSocket 客户端。
- [x] **Task 4.1.2: 流式打字机 UI 组件**
  - **实现细节**：解析 `CHUNK` 帧，以自然延迟 (模拟人类打字) 渲染文本。实现 Markdown 基础解析。
- [x] **Task 4.1.3: 活人感状态栏与触觉反馈**
  - **实现细节**：解析 `AGENT_STATE` 帧。当处于 `WORKING` 时，显示动态进度指示器（类似岛屿展开）；调用 `UIImpactFeedbackGenerator` 进行震动。

### Epic 4.2: 拦截确认卡片 (Permission UI)
- [x] **Task 4.2.1: 交互式授权弹窗**
  - **实现细节**：接收到 `PERMISSION_REQ` 时，通过 `.sheet` 或定制 Alert 弹出高危操作警示（包括操作描述、涉及的工具）。包含明确的【同意】和【拒绝】按钮，通过 WS 发回结果。

### Epic 4.3: 系统级灵感捕获 (Share Extension)
- [x] **Task 4.3.1: Share Extension Target 创建**
  - **实现细节**：在 Xcode 中添加 Share Extension，配置 Info.plist 拦截 URL 和纯文本。
- [x] **Task 4.3.2: 极简输入框与离线发送**
  - **实现细节**：编写定制的 `ShareViewController`。提取用户附加的附言，将 URL 和附言通过 `URLSession` POST 到后端的 `/api/share/ingest` 接口。并在发送成功后自动关闭 Extension。
- [x] **Task 4.3.3: APNs 远程交互式推送**
  - **实现细节**：集成 APNs。当后端处理完分享的内容并总结后，给 iOS 设备发推送（“阅读摘要已生成，存入Notion了”）。
