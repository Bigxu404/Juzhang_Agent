description: 将整个架构蓝图拆分为具体的可执行开发需求，分为服务端核心（Node.js）和客户端原生（SwiftUI）两部分，每个阶段均明确了关键输出物和验收标准。

# 移动端Agent产品需求拆解清单 (REQUIREMENTS_LIST.md)

以下清单基于 `TECH_ARCHITECTURE.md`，将MVP阶段的系统开发拆分为可独立验收的具体开发任务：

## Phase 1: 核心基础底座 (服务端先行)
这是整个Agent的心智核心，跑通单人对话、简单的上下文保持和MCP的写入拦截机制。

### 1.1 项目初始化与长连接 (Backend)
- **任务说明**：搭建Node.js (TypeScript) 后端环境，集成 Socket.IO。
- **输出物**：可接受 WebSocket 连接、并具有基础消息路由的框架代码。
- **参考**：构建一个基于事件的状态下发模型，支持流式文本返回（`AGENT_STATE`, `CHUNK`）。

### 1.2 Agent Core Loop (Backend)
- **任务说明**：基于 `@ai-sdk/core` 或 LangGraph，实现一个单体的大模型调用循环（包含工具回调）。
- **输出物**：一个可以根据用户指令自动进行多步思考（ReAct）的单体 Agent。支持简单的 `WebSearchTool`（直接放行）。
- **参考**：`PRD_01_Agent_Core_Loop.md` 提到的感知、规划、执行、响应四阶段。

### 1.3 MCP Notion 集成与拦截器 (Backend)
- **任务说明**：集成 MCP 客户端（比如连接官方的Notion SDK或社区版Notion MCP），实现 `AppendNotionBlock` 原子工具。
- **输出物**：
  1. Notion Token 安全存储逻辑。
  2. 实现六层安检中的 Level 3（拦截写入）。当调用 `AppendNotionBlock` 时，挂起循环并向测试客户端发送 `PERMISSION_REQ`。
- **参考**：`PRD_04_MCP_Client_Integration.md` 和 `cc_source_analysis` 中 Harness 的安全思想。

### 1.4 Persona.md 与 Prompt Cache (Backend)
- **任务说明**：编写极具“活人感”和“批判性”的 `Base System Prompt`，实现动态和静态提示词分离。
- **输出物**：一套支持缓存命中的 Prompt 组装函数（类似 CC 的 `buildEffectiveSystemPrompt`），静态的人设在顶端。
- **参考**：`PRD_02_Memory_and_Persona.md` 的独立人格模式设计。

---

## Phase 2: 多Agent协同与记忆系统
在单体Agent稳定的基础上，引入Coordinator指挥子Agent处理复杂耗时任务。

### 2.1 Coordinator 与 Explore Subagent (Backend)
- **任务说明**：将单体 Agent 升级为 Coordinator 主路由，为其注册 `AgentTool` 用于后台启动 `Explore Subagent`（比如查重或冲浪）。
- **输出物**：当用户请求长文总结或比价时，主Agent通过发状态信令“正在帮你查...”并在后台起另一个模型实例执行只读搜索。
- **参考**：`cc_source_analysis/11_第五章_Agent系统__AI如何指挥AI.md`，使用廉价模型、移除沉重人设（`omitClaudeMd: true`）提升查阅速度。

### 2.2 Vector DB 短期/情景记忆接入 (Backend)
- **任务说明**：接入本地或云端向量数据库（Pinecone等），处理 Episodic Memory 的检索与写入。
- **输出物**：当对话历史超长时，触发 RAG 检索，提取相关背景作为上下文输入。
- **参考**：`PRD_02_Memory_and_Persona.md` 中关于“告别金鱼记忆”的设计。

### 2.3 定时价值观反思 (Backend - Cron)
- **任务说明**：编写夜间定时任务脚本，分析 `Working Memory`，提炼用户兴趣，更新内部的 `Persona.md`。
- **输出物**：当用户多次提及某个话题后，系统能自动修正人设提示词，实现“我越来越懂你”。

---

## Phase 3: iOS 原生躯干 (客户端)
打磨具备极致移动端体验的App。

### 3.1 极简 SwiftUI 对话壳子 (iOS)
- **任务说明**：用 SwiftUI 创建主界面，实现基于 WebSocket 的双向通讯。
- **输出物**：能流畅展示流式打字效果（Typewriter），并且在接收到 `AGENT_STATE` 时显示平滑的状态进度条的聊天流界面。

### 3.2 权限拦截 UI 与 Haptic 震动 (iOS)
- **任务说明**：处理服务端的 `PERMISSION_REQ`，显示美观的交互式拦截卡片（“Agent想写入Notion”）；并在关键节点植入 Haptic 反馈。
- **输出物**：用户能通过点击界面卡片完成“允许/拒绝”闭环。
- **参考**：`PRD_03_iOS_Native_Infrastructure.md` 活人感UI设计。

### 3.3 Share Extension 灵感收集插件 (iOS)
- **任务说明**：开发 iOS Share Extension，拦截 Safari 或其他 App 的 URL 和文本分享。
- **输出物**：在系统分享菜单中点击本App后，弹出轻量输入框，输入需求后点击发送，调用服务端的 `POST /api/share/ingest` 进行离线冲浪处理。
- **参考**：`PRD_03_iOS_Native_Infrastructure.md` Share Extension 部分。

### 3.4 交互式推送 (APNs) (iOS & Backend)
- **任务说明**：在 iOS 端注册通知，服务端完成离线任务（如比价/摘要）后通过 APNs 下发带有快捷操作的通知。
- **输出物**：锁屏界面收到“帮你总结好了”的推送，点击按钮可直接触发写入MCP或开启下一轮对话。

---

## MVP 验证验收标准
1. **活人对话与冲浪**：在 iOS App 内，用户说“查一下最新《沙丘》电影评分”，界面平滑展示“正在后台搜索…”（由Explore Subagent完成），随后主Agent用自带的特定语气回复。
2. **MCP 安全写入**：接着用户说“把我刚才发你的淘宝鞋链接存到Notion愿望单”，iOS界面弹出授权卡片，同意后，Notion里成功出现该条目。
3. **全局灵感分享**：用户在系统自带的浏览器看长文，通过Share Extension分享给App并附言“总结”，半分钟后收到App的系统推送通知其完成。
4. **长效记忆**：第二天用户随口问“昨天那个鞋多少钱来着？”，Agent能准确依靠记忆提取回答。