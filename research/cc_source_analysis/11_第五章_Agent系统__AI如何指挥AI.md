description: 分析Agent之间的协同指挥机制，重点解析Explore Agent等6种内置Agent的设计差异、运行机制及其执行路径。

## 第五章：Agent系统——AI如何指挥AI ​

### 5.1 内置Agent完整档案 ​

**动手列出所有内置Agent：**

bash

```
ls tools/AgentTool/built-in/
```

6种内置Agent：

#### Explore Agent（84行，最值得学习的Agent定义） ​

bash

```
cat tools/AgentTool/built-in/exploreAgent.ts
```

**完整设计解析：**

typescript

```
export const EXPLORE_AGENT: BuiltInAgentDefinition = {
  agentType: 'Explore',

  // 什么时候用这个Agent
  whenToUse: 'Fast agent specialized for exploring codebases...',

  // 禁用的工具——保证完全只读
  disallowedTools: [
    AGENT_TOOL_NAME,         // 不能再启动子Agent（防止套娃）
    EXIT_PLAN_MODE_TOOL_NAME,
    FILE_EDIT_TOOL_NAME,     // 不能编辑文件
    FILE_WRITE_TOOL_NAME,    // 不能写文件
    NOTEBOOK_EDIT_TOOL_NAME, // 不能编辑Notebook
  ],

  // 模型选择——这是最有启发性的设计
  // Ant内部员工用继承模型（可能是Opus/Sonnet），外部用户用Haiku
  model: process.env.USER_TYPE === 'ant' ? 'inherit' : 'haiku',
  // Haiku速度是Opus的10倍，成本是1/10

  // 跳过CLAUDE.md——Explore是只读搜索Agent，不需要项目规范
  omitClaudeMd: true,
  // 这一个配置就能省几千Token

  getSystemPrompt: () => getExploreSystemPrompt(),
}
```

Explore的System Prompt（第24-56行）包含严格的只读约束：

```
=== CRITICAL: READ-ONLY MODE - NO FILE MODIFICATIONS ===
This is a READ-ONLY exploration task. You are STRICTLY PROHIBITED from:
- Creating new files (no Write, touch, or file creation of any kind)
- Modifying existing files (no Edit operations)
- Using redirect operators (>, >>, |) or heredocs to write to files
- Running ANY commands that change system state
```

以及效率要求：

```
NOTE: You are meant to be a fast agent that returns output as quickly as
possible. In order to achieve this you must:
- Make efficient use of the tools
- Wherever possible spawn multiple parallel tool calls
```

#### Plan Agent（93行） ​

bash

```
cat tools/AgentTool/built-in/planAgent.ts
```

与Explore的关键区别：

* 角色定位不同：`"You are a software architect and planning specialist"`
* 输出有严格格式要求——每个Plan必须以"Critical Files for Implementation"结尾，列3-5个关键文件
* 同样`omitClaudeMd: true`——Plan Agent可以自己Read CLAUDE.md，但不把它注入System Prompt，省Token

#### Verification Agent ​

**动手查看：**

bash

```
cat tools/AgentTool/built-in/verificationAgent.ts
```

这个Agent专门验证实现结果，输出PASS/FAIL/PARTIAL。关键设计：

* **独立运行**——不受原始Agent偏见影响
* 可以运行测试（有Bash权限）
* 触发条件：3+文件编辑、后端/API变更

### 5.2 Agent运行机制 ​

bash

```
head -60 tools/AgentTool/runAgent.ts
```

`runAgent()`是所有Agent执行的核心。它负责：

1. 构建Agent的消息历史
2. 调用API获取响应
3. 处理工具调用循环
4. 管理Token预算
5. 返回最终结果

### 5.3 Agent执行路径 ​

bash

```
head -60 tools/AgentTool/AgentTool.tsx
```

AgentTool的execute()会根据情况选择不同的执行路径：

* **本地执行** — LocalAgentTask（同机器）
* **远程执行** — RemoteAgentTask（通过Bridge发送到远端）
* **进程内执行** — InProcessTeammateTask（同进程的队友）
* **Fork执行** — 后台隔离运行

---