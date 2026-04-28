description: 该PRD定义了产品的核心Agentic循环机制，提出了端云切割的最佳实践架构，以及借鉴Claude Code的多Agent协同指挥系统。

# PRD 01: Agent Core Loop & Coordinator Engine

## 1. 产品定位与目标
本模块是整个iOS数字朋友产品的“中央大脑”。
目标是实现一套**具有自我纠错、任务拆解以及工具调用能力的Agentic架构**。通过引入类似Claude Code的Coordinator模式，支持“主Agent统筹 + 子Agent执行”的协同模式，以最少的延迟和成本处理移动端复杂的阅读、冲浪和灵感记录任务。

## 2. 架构决策：端云切割建议 (Client-Server Split)
经过对移动端性能、大模型调用延迟以及MCP（Model Context Protocol）集成的综合考量，建议采用**“瘦客户端（感官层） + 强服务端（大脑层）”**的切割架构：

### 2.1 为什么不在iOS端直连大模型做Agent Loop？
- **上下文体积与成本失控**：Agentic架构的精髓在于带着长上下文（工作记忆、长对话记录）多次循环。如果在iOS端发起，每次`Action`后都需要把几万Token的网络返回通过移动网络重新发给LLM，延迟和流量消耗巨大。
- **MCP网络环境限制**：某些MCP（如Obsidian的本地文件、某些内网部署的数据库）需要在有固定IP或更稳定网络环境的服务器上运行，而手机经常切换网络，容易导致工具调用失败。
- **后台冲浪能力受限**：iOS后台任务（Background Task）时间极短且严格受限。你要的“Agent自己去互联网冲浪”如果在iOS端跑，App一切回后台就会被系统杀掉。

### 2.2 推荐的切割方案
- **iOS 客户端（The Body & Senses）**：
  - 负责多模态采集：语音录入、Share Extension截取网页URL或图片、系统状态（地理位置/时间）采集。
  - 负责“活人感”的UI渲染：平滑的流式输出、打字机效果、Haptic震动、拟物动画。
  - 维持持久的WebSocket/SSE连接以接收服务端的推流。
- **云端服务（The Agent Core & MCP Hub）**：
  - 部署Node.js/Python环境，运行Agent Loop和Swarm系统。
  - 挂载MCP Client，安全连接用户的Notion/阅读软件授权。
  - **离线任务队列**：负责执行耗时几十秒甚至几分钟的“互联网冲浪收集”任务。

## 3. 核心功能设计

### 3.1 Coordinator Mode (多Agent协同系统)
借鉴Claude Code源码中的`coordinatorMode.ts`，我们要摆脱单体大模型的束缚。

- **Main Agent (The Coordinator / Chat Agent)**
  - **职责**：直接与用户在iOS上对话，维持活人感，做“面子”工程。
  - **特点**：响应极快，System Prompt主要设定人格和语调，自带短期记忆。
  - **能力**：当发现任务需要大量阅读、搜索或复杂处理时，它**不会自己去做**，而是调用内置的`AgentTool`来启动子Agent。
- **Explore Subagent (冲浪/阅读专用)**
  - **职责**：纯后台运行的“工具人”。
  - **触发**：当Coordinator发现用户丢来一篇长文，或者需要全网搜索“近期热门影视”时启动。
  - **特性**：**只读模式**。禁止写入任何文件或MCP，专注于调用`WebSearchTool`和`WebFetchTool`。参考CC源码，它使用廉价且快速的模型（如Gemini Flash），且`omitClaudeMd: true`（不注入主Agent的沉重人设规则），快速执行后返回报告给Coordinator。
- **Action Subagent (MCP执行专用)**
  - **职责**：高风险操作代理，专注于写入外部大脑（如Notion愿望清单）。

### 3.2 The Agentic Loop (ReAct 循环)
服务端的核心循环设计：
1. **Perceive (感知)**：接收iOS端传入的用户消息 + 当前上下文状态。
2. **Plan & Route (规划路由)**：Coordinator决定是闲聊，还是下发任务给Subagent。
3. **Execute (执行)**：
   - 走入循环：`Query -> Tool Use -> Tool Result -> Query...`
   - CC源码教训：必须设置防无限循环的机制（例如CC的`DENIAL_LIMITS`，连续拒绝或报错3次则触发熔断，返回人工确认）。
4. **Respond (流式返回)**：将子Agent传回的总结，经过Coordinator的“人格化修饰”，通过WebSocket推回给iOS客户端。

### 3.3 Harness (工具安检大脑)
参考CC的1486行权限决策大脑：
- **Level 1 (静默放行)**：WebSearch, WebFetch（冲浪工具），直接放行，无需iOS端确认。
- **Level 2 (事后通知)**：调用Notion_Append_Block记录灵感。允许执行，但Coordinator必须在对话中顺口提一句“已经帮你存好了”。
- **Level 3 (弹窗确认)**：删除外部记录、发起大额消费建议等。Agent Loop必须挂起（Suspend），向iOS下发`PermissionRequest`，iOS弹框，用户点击通过后，服务端恢复执行。

## 4. 接口与数据流 (MVP阶段)
1. `POST /api/chat/message`: iOS端发送消息，带上附件(URL/图)。
2. `WS /api/chat/stream`: 接收服务端的流式响应，包括“思考中(启动子Agent)”的状态信令。
3. `POST /api/agent/trigger_surf`: 触发计划任务（后台定时冲浪）。