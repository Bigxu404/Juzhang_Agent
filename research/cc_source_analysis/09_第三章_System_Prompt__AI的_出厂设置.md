description: 深度解析Claude Code的五层系统提示词设计，包含其为了降低成本而进行的动静分区，以及缓存失效检测与具体安全指令的约束规范。

## 第三章：System Prompt——AI的"出厂设置" ​

这是最值得细读的文件。每一行都是真金白银的提示词工程经验。

### 3.1 文件概览 ​

bash

```
wc -l constants/prompts.ts
# → 914行
```

### 3.2 五层优先级模型 ​

打开`utils/systemPrompt.ts`，找到`buildEffectiveSystemPrompt()`函数：

```
优先级（高→低）：
第0层：Override System Prompt（loop模式等覆盖一切）
第1层：Coordinator System Prompt（多Agent协调）
第2层：Agent System Prompt（子Agent专属指令）
第3层：Custom System Prompt（用户通过--system-prompt传入）
第4层：Default System Prompt（标准prompt + Append追加）
```

**动手验证：**

bash

```
grep -n "override\|coordinator\|agent.*system\|custom.*system\|default.*system" utils/systemPrompt.ts
```

### 3.3 静态/动态分区——省90%成本的关键一刀 ​

bash

```
grep -n "SYSTEM_PROMPT_DYNAMIC_BOUNDARY" constants/prompts.ts
```

这个常量把914行prompt切成两半：

**静态部分（标记之前）——被API缓存：**

* Claude Code身份介绍
* 工具使用规范（"用Read不用cat，用Edit不用sed"）
* 代码修改准则（"不要添加超出要求的功能"）
* 安全操作准则（"仔细考虑操作的可逆性"）
* 语调和风格（"简洁、无冒号、用绝对路径"）
* 输出效率要求（"直奔主题，先说答案不说过程"）

**动态部分（标记之后）——每次会话不同：**

* 当前工作目录和Git状态
* CLAUDE.md内容注入
* 模型信息和知识截止日期
* MCP服务器列表
* Scratchpad目录路径

**为什么这很重要：** Anthropic API的Prompt Cache机制——静态部分被缓存后，后续请求的输入Token只收10%。一个重度Vibe Coding会话可能100次API调用，这一刀切出来的是数十美元的成本差距。

### 3.4 缓存失效检测 ​

bash

```
head -40 services/api/promptCacheBreakDetection.ts
```

这个文件对系统提示词做哈希比对，追踪每次缓存是否命中：

typescript

```
type PreviousState = {
  systemHash: number         // 系统提示词哈希
  toolsHash: number          // 工具定义哈希
  cacheControlHash: number   // 缓存控制哈希
  toolNames: string[]        // 工具名称列表
  perToolHashes: Record<string, number>  // 每个工具的schema哈希
  systemCharCount: number    // 字符计数
  model: string              // 模型名称
}
```

如果某个工具的描述变化导致缓存全线失效，这个模块会记录diff帮助诊断。注释中提到（原文）：

> "Per-tool schema hash. Diffed to name which tool's description changed when toolSchemasChanged but added=removed=0 (77% of tool breaks per BQ 2026-03-22)"

翻译：77%的缓存失效是因为工具描述变化，而不是工具增删。

### 3.5 提示词中的具体指令 ​

**动手提取所有"禁止"指令：**

bash

```
grep -n "NEVER\|MUST NOT\|Don't\|CRITICAL\|IMPORTANT" constants/prompts.ts
```

你会找到这些生产级规则：

**关于代码修改：**

> "Don't add features, refactor code, or make 'improvements' beyond what was asked. A bug fix doesn't need surrounding code cleaned up. A simple feature doesn't need extra configurability."

**关于工具使用优先级：**

> "To read files use Read instead of cat, head, tail, or sed. To edit files use Edit instead of sed or awk. To search for files use Glob instead of find or ls."

**关于安全操作：**

> "Carefully consider the reversibility and blast radius of actions. Generally you can freely take local, reversible actions like editing files or running tests."

**关于Git安全：**

> "NEVER update the git config. NEVER run destructive git commands unless the user explicitly requests. NEVER skip hooks (--no-verify) unless the user explicitly requests."

**关于输出效率：**

> "Go straight to the point. Try the simplest approach first without going in circles. Do not overdo it. Be extra concise."

**启发：** 如果你在写自己的AI Agent，这些指令就是最佳模板。每一条背后都是真实的生产事故——有人让AI"改进"代码结果弄崩了项目，有人让AI push --force丢了分支。

---