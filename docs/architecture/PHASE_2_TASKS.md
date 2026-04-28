# 移动端 Agent 产品二阶段开发任务清单 (Phase 2 Tasks)

> **文档说明**：本清单结合了《第一章：Agent的大脑与思维》与《第四章：Agent的躯壳与微表情》的最新产品思考，以及前期的架构蓝图。在第一阶段（核心大脑与基础通讯）跑通的基础上，第二阶段的核心目标是**赋予 Agent 真正的“活人感”、“协同思考”能力以及“岁月痕迹”**。

---

## 模块一：多 Agent 协同与异步调度 (The Coordinator)
*对应：Subagent 并发与主 Agent 异步非阻塞机制，解决复杂任务的耗时痛点。*

### 1.1 Coordinator 主路由升级
- **任务描述**：将现有的单体 Agent 升级为 Coordinator（协调者），使其具备任务拆解和派发能力。
- **子任务**：
  - [ ] **Task 1.1.1**: 注册 `DelegateTaskTool`，允许主 Agent 将耗时/繁琐任务（如广度搜索、长文阅读）外包给子代办。
  - [ ] **Task 1.1.2**: 实现主 Agent 的异步非阻塞机制：在 Subagent 执行期间，主 Agent 仍能挂起主线任务，并响应用户的闲聊或状态查询。

### 1.2 Explore Subagent (探索子代办) 实例化
- **任务描述**：配置一个专用于信息检索和处理的轻量级只读 Subagent，充当主 Agent 的“手眼”。
- **子任务**：
  - [ ] **Task 1.2.1**: 为 Explore Subagent 编写极简的 System Prompt（剥离复杂人设，专注信息提取，提升处理速度）。
  - [ ] **Task 1.2.2**: 挂载 `WebSearch` 和 `WebFetch` 工具，确保其在沙箱内运行，无任何外部写入权限。
  - [ ] **Task 1.2.3**: 实现 Subagent 结果的汇总与回调机制，将提炼后的精华上下文（剔除垃圾信息）返回给主 Agent。

---

## 模块二：记忆系统与岁月痕迹 (Memory & Temporal Evolution)
*对应：Working Memory 压缩、Episodic Memory 检索，以及 Agent 随时间推移的共同成长与人物弧光。*

### 2.1 记忆压缩与提炼 (Working Memory)
- **任务描述**：防止上下文过载（Context Overflow），实现对话历史的动态滑动窗口与摘要压缩。
- **子任务**：
  - [ ] **Task 2.1.1**: 编写后台摘要小模型（如 Haiku/Flash）触发逻辑，当 History Token 超过安全阈值时自动触发后台总结。
  - [ ] **Task 2.1.2**: 将冗长对话替换为“浓缩工作记忆”，并无缝注入到下一次请求的 `DYNAMIC_CONTEXT` 中，保持对全局任务的清晰认知。

### 2.2 长期记忆与价值观反思 (Episodic Memory & Reflection)
- **任务描述**：让 Agent 拥有“岁月痕迹”，能够根据用户的长期交互演变自身的三观和说话风格。
- **子任务**：
  - [ ] **Task 2.2.1**: 接入向量数据库（如 Pinecone），实现会话事件的 Embedding 写入与语义检索 (Tool RAG)。
  - [ ] **Task 2.2.2**: 编写夜间定时任务 (Cron Job)，扫描近期记忆，提取用户新产生的兴趣点或习惯。
  - [ ] **Task 2.2.3**: 自动更新 `Persona.md`（静态人设区），实现 Agent 认知、语气和社交图谱的渐进式进化。

---

## 模块三：微表情信令与系统级捕获 (Backend for Frontend)
*对应：为 iOS 客户端的活人感 UI（打字机、呼吸灯、Haptic 震动）提供底层数据与接口支撑。*

### 3.1 细粒度状态机与微表情信令 (Agent State)
- **任务描述**：丰富 WebSocket 的下发帧，让前端能渲染出真实的呼吸感和工作状态。
- **子任务**：
  - [ ] **Task 3.1.1**: 定义并下发多维度的 `AGENT_STATE`（如 `THINKING`, `SEARCHING_WEB`, `READING_DOC`, `WAITING_PERMISSION`）。
  - [ ] **Task 3.1.2**: 在 Subagent 并发执行时，主 Agent 持续下发进度信令，驱动前端的动态文案和 Haptic 震动。
  - [ ] **Task 3.1.3**: 优化流式打字机 (Chunking) 的输出节奏，在标点符号或思考节点注入自然延迟标记，模拟真人敲击键盘。

### 3.2 灵感捕获与离线处理接口 (Share Extension Support)
- **任务描述**：打破 App 边界，支持 iOS Share Extension 的系统级内容注入，实现“无感知助理”。
- **子任务**：
  - [ ] **Task 3.2.1**: 开发 `POST /api/share/ingest` 接口，接收来自 iOS 系统的 URL、文本及用户附言。
  - [ ] **Task 3.2.2**: 实现离线任务队列：接收到分享后，后台静默唤醒 Subagent 进行阅读、总结或比价。
  - [ ] **Task 3.2.3**: 集成 APNs (Apple Push Notification service)，任务完成后向 iOS 设备推送交互式通知（如：“阅读摘要已生成，存入Notion了”）。

---

## 模块四：Harness 安全拦截深化 (The Shield)
*延续：第一阶段的 MCP 基础，强化操作前的阻断与熔断机制，确保越权操作绝对安全。*

### 4.1 交互式授权与熔断器
- **任务描述**：确保高危操作（如写入 Notion、发送邮件）必须经过用户的显式确认。
- **子任务**：
  - [ ] **Task 4.1.1**: 完善 Level 3 工具的挂起 (Suspend) 逻辑，通过 WS 下发 `PERMISSION_REQ` 并等待前端回传 `ALLOW/DENY`。
  - [ ] **Task 4.1.2**: 实现“拒绝熔断器”：单会话连续被拒绝 3 次后，自动终止当前工具链调用，主 Agent 切换为安抚话术（“好的，那我们先不操作这个了”）。

---

## 🏁 阶段验收标准 (Phase 2 MVP)
1. **多线程体感**：用户要求“查一下最近的 AI 新闻”，前端立刻显示“正在派出探索助手...”，主 Agent 不阻塞，几秒后结合搜索结果给出带有人设的回复。
2. **记忆压缩与检索**：连续进行超长对话后，系统不崩溃且响应速度不减；随口问之前的细节，Agent 能准确依靠记忆提取回答。
3. **离线冲浪闭环**：通过 API 模拟 iOS 系统的 Share Extension 抛入一篇长文链接，后端能静默处理并在完成后触发 APNs 推送逻辑。
4. **安全拦截闭环**：触发 Notion 写入时，后端准确暂停输出，等待外部的 `ALLOW` 信号后才真正执行写入，并在前端配合 Haptic 震动反馈。