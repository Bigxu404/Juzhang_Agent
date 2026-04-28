# Phase 2 执行计划 (PHASE_2_EXECUTION_PLAN.md)

基于 `PHASE_2_TASKS.md` 的功能模块，我们将二阶段的开发工作拆解为以下 5 个可执行的 Sprint（冲刺）。每个 Sprint 都有明确的代码修改目标和验收标准，确保我们可以一步步稳扎稳打地实现。

## Sprint 1: 状态机与微表情信令底座 (优先打通全链路状态)
*目标：让前端能感知到后端在干什么，为后续的耗时任务（搜索、总结）提供 UI 渲染基础。*
- [ ] **1.1 扩展 WS 协议**：在 `backend/src/websocket/` 中定义完整的 `AgentState` 枚举（如 `THINKING`, `SEARCHING`, `WAITING_PERMISSION`, `IDLE`）。
- [ ] **1.2 状态下发钩子**：在 `runAgent` 的关键节点（调用 LLM 前、调用工具前）插入 `ws.send(AGENT_STATE)`。
- [ ] **1.3 打字机延迟模拟**：在 `CHUNK` 发送逻辑中，识别标点符号并注入微小的延迟，模拟真人思考和打字的停顿。
- **验收**：运行测试客户端，能看到服务端依次打印出状态变更，且文本流输出有拟真停顿。

## Sprint 2: 多 Agent 协同 (Coordinator & Explore Subagent)
*目标：实现主 Agent 异步派发任务给子代办，不阻塞主流程。*
- [ ] **2.1 创建 Explore Subagent**：新增 `backend/src/agent/subagents/exploreAgent.ts`，配置纯粹的信息提取 Prompt 和搜索工具。
- [ ] **2.2 实现 DelegateTool**：新增 `backend/src/tools/delegateTaskTool.ts`，主 Agent 可通过此工具唤起 Explore Subagent。
- [ ] **2.3 异步非阻塞改造**：优化 `runAgent`，当触发 DelegateTool 时，下发 `SEARCHING` 状态，后台 Promise 执行，主 Agent 挂起等待，期间前端显示呼吸灯状态。
- **验收**：用户输入“帮我查一下今天的新闻”，主 Agent 触发 DelegateTool，控制台显示 Explore Agent 启动并返回摘要，主 Agent 最终整合输出结果。

## Sprint 3: 记忆压缩与岁月痕迹 (Memory System)
*目标：解决上下文过载，赋予 Agent 长期记忆。*
- [ ] **3.1 Token 监控与滑动窗口**：在 `backend/src/memory/` 中实现 Token 估算，当 History 超过阈值时截断。
- [ ] **3.2 Working Memory 压缩**：集成小模型（如 Haiku/Flash），对截断的历史进行摘要，存入 `DYNAMIC_CONTEXT`。
- [ ] **3.3 Episodic Memory 向量化**：接入 Pinecone 或本地 Vector DB 模拟器，将会话事件 Embedding 存储，并在每次对话前进行 RAG 召回。
- **验收**：进行超过 10 轮的长对话，系统自动触发压缩日志，且能准确回答早期对话中的细节。

## Sprint 4: Harness 安全拦截与熔断 (Safety Shield)
*目标：实现高危操作的“事中拦截”与“事后熔断”。*
- [ ] **4.1 拦截器挂起逻辑**：在 `ToolDispatcher` 中，遇到 Level 3 工具（如 `AppendNotionBlock`），暂停执行，下发 `PERMISSION_REQ`。
- [ ] **4.2 授权回调恢复**：WebSocket 监听 `PERMISSION_RES`，收到 `ALLOW` 后恢复 Promise 执行，收到 `DENY` 则阻断。
- [ ] **4.3 拒绝熔断器**：在 Session 中记录拒绝次数，连续 3 次拒绝后，抛出特定 Error，主 Agent 切换安抚话术（“好的，那我们先不操作这个了”）。
- **验收**：测试客户端触发 Notion 写入，服务端暂停，客户端输入 `ALLOW` 后服务端继续写入；连续输入 3 次 `DENY`，服务端主动放弃。

## Sprint 5: 离线捕获与系统级入口 (Share Extension API)
*目标：支持 iOS Share Extension 的静默灵感收集。*
- [ ] **5.1 新增 Ingest API**：在 `backend/src/api/` 下新增 `POST /api/share/ingest` 路由，接收 URL/文本。
- [ ] **5.2 离线任务队列**：将接收到的数据推入后台队列，静默唤醒 Explore Subagent 进行处理。
- [ ] **5.3 模拟 APNs 推送**：处理完成后，调用模拟的 Push 服务（打印日志），通知客户端“处理完成”。
- **验收**：通过 Postman 向 API 发送一篇文章链接，后端静默处理 10 秒后，控制台打印出“推送通知：摘要已生成”。