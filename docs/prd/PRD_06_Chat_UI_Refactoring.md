# PRD 06: 聊天流界面重构与多模态消息展示 (Chat UI & Multi-modal Message Display)

## 1. 背景与目标
在当前的 MVP 版本中，Agent 的思考过程（`<think>` 标签）、工具调用日志（Tool Calls）、子代理（Subagent）的执行结果以及最终回复，全部被揉捏在一个单一的文本气泡中。
这种展示方式不仅导致信息过载、排版混乱，也极大地削弱了 Agent 的“专业感”和“透明度”。

参考行业内顶尖的 Agent 产品（如 Manus、Cursor、Devin），我们需要对聊天流（Chat Stream）的 UI 进行彻底重构，将不同类型的消息解耦，实现**模块化、结构化、可折叠**的展示。

**核心目标：**
1. **信息分层**：将“过程（思考/工具）”与“结果（最终回复）”在视觉上严格区分。
2. **状态透明**：让用户清晰地看到 Agent 正在使用什么工具、派发了什么子任务。
3. **空间利用**：通过折叠面板（Accordion）隐藏冗长的思考和执行日志，保持主界面的清爽。

---

## 2. 核心组件设计 (UI Components)

一条完整的 Agent 回复（Agent Message）不再是一个单纯的文本框，而是由多个**消息块（Message Blocks）**按时间顺序组合而成的容器。

### 2.1 思考块 (Thinking Block)
*   **触发条件**：解析到大模型输出的 `<think>` 标签，或收到后端的 `THINK_START` 信令。
*   **视觉表现**：
    *   使用浅灰色背景或边框，字体略小，带有“大脑”或“思考”图标。
    *   **动态状态**：正在思考时，显示动态的呼吸灯或省略号动画；思考结束时，显示思考耗时（如 `思考了 4.2 秒`）。
*   **交互逻辑**：
    *   生成中：默认展开，文字流式打字输出。
    *   生成完毕：**自动折叠**，只保留标题行，用户点击可展开查看完整的思维链（CoT）。

### 2.2 工具调用块 (Tool Action Block)
*   **触发条件**：Agent 决定调用工具（如 `WebSearch`, `AppendNotionBlock`）。
*   **视觉表现**：
    *   **卡片式设计**：左侧为工具图标（如🌐代表搜索，📝代表Notion），右侧为工具名称和参数简述。
    *   **状态指示器**：
        *   `Running`：旋转的 Spinner，文案显示“正在搜索网页...”。
        *   `Success`：绿色的 Checkmark ✅，文案显示“搜索完成”。
        *   `Failed`：红色的 Cross ❌，文案显示“搜索失败”。
        *   `Suspended`：黄色的 ⚠️，文案显示“等待授权”（结合现有的 Permission 拦截卡片）。
*   **交互逻辑**：
    *   点击卡片可展开/弹窗查看具体的入参（JSON）和返回的原始结果（Raw Output）。

### 2.3 子代理任务块 (Subagent Delegation Block)
*   **触发条件**：调用 `DelegateToExploreAgent` 时。
*   **视觉表现**：
    *   类似于工具调用块，但视觉层级更高，带有“分身”或“机器人”图标。
    *   文案更加拟人化，如：“已指派探索助手去查阅《一级恐惧》相关资料...”。
*   **交互逻辑**：
    *   展开后，可以像看“画中画”一样，看到子代理内部的执行摘要。

### 2.4 最终回复块 (Final Response Block)
*   **触发条件**：不在 `<think>` 标签内，且非工具调用的纯文本输出。
*   **视觉表现**：
    *   标准的聊天气泡，支持完整的 Markdown 渲染（加粗、列表、代码块、表格）。
    *   字体清晰，对比度高，作为用户最终消费的核心内容。

---

## 3. 技术实现方案 (Frontend & Backend Alignment)

要实现上述 UI，前后端的数据协议需要进行升级，从“纯文本流”升级为“结构化事件流”。

### 3.1 后端协议升级方案
**方案 A：纯前端正则解析（轻量级，当前推荐）**
*   后端依然通过 `CHUNK` 发送文本。
*   iOS 客户端在接收到 `CHUNK` 时，实时进行正则匹配：
    *   遇到 `<think>` -> 创建一个 Thinking Block。
    *   遇到 `</think>` -> 结束 Thinking Block，折叠它。
*   工具调用的状态依然通过 `AGENT_STATE` 下发，前端根据 State 插入 Tool Action Block。

**方案 B：后端结构化流（更严谨，类似 OpenAI Server-Sent Events）**
*   废弃单一的 `CHUNK`，改为下发不同类型的帧：
    *   `{ type: 'think_chunk', text: '...' }`
    *   `{ type: 'tool_start', tool: 'WebSearch', input: {...} }`
    *   `{ type: 'tool_end', tool: 'WebSearch', result: '...' }`
    *   `{ type: 'message_chunk', text: '...' }`

### 3.2 iOS 客户端数据模型重构
原有的 `ChatMessage` 结构需要升级：
```swift
// 升级前的单薄结构
struct ChatMessage {
    let role: Role
    var content: String
}

// 升级后的复合结构
struct ChatMessage {
    let role: Role
    var components: [MessageComponent] // 一条消息包含多个组件
}

enum MessageComponent {
    case text(String)
    case thinking(content: String, isFinished: Bool)
    case toolCall(name: String, status: ToolStatus, input: String, result: String?)
}
```

---

## 4. 交互动效与用户体验 (UX Details)
1. **平滑过渡**：当从“思考块”过渡到“工具块”，再过渡到“最终回复”时，UI 列表应该平滑向上滚动，避免突兀的跳动。
2. **自动收起**：为了防止长对话占用过多屏幕空间，一旦 Agent 开始输出“最终回复”，之前的“思考块”和“工具块”必须自动折叠。
3. **Haptic 配合**：
    *   工具开始执行：轻微的 `impact(style: .light)`。
    *   工具执行成功：清脆的 `impact(style: .medium)`。
    *   最终回复输出完毕：`notification(type: .success)`。