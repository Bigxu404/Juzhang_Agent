description: 剖析贯穿全栈的1486行安全大脑和五种权限模式，以及如何通过YOLO分类器、拒绝熔断器、文件系统沙箱等手段控制大模型的破坏风险。

## 第六章：Harness——AI的缰绳（核心重点） ​

Harness是贯穿全栈的控制哲学，散布在多个模块中。

### 6.1 权限决策引擎——1486行的安全大脑 ​

bash

```
wc -l utils/permissions/permissions.ts
# → 1486行
```

核心函数`hasPermissionsToUseTool()`实现了6层安检。每次AI调用任何工具，都经过这个函数。

**动手看函数签名：**

bash

```
grep -n "hasPermissionsToUseTool" utils/permissions/permissions.ts | head -5
```

**六层安检详解：**

```
AI提交工具调用
     ↓
【第1层】工具级规则（5个子步骤）
  1a. getDenyRuleForTool() — 工具被整体禁止？
  1b. getAskRuleForTool() — 工具有ask规则？
  1c. tool.checkPermissions() — 工具自身安全检查
  1d. 工具deny？ → 直接拒绝
  1e. 需要用户交互？
  1f. 内容特定ask规则？（如"Bash(npm publish:*)"）
  1g. 安全检查失败？
     ↓
  ⚠️ 1d-1g对所有模式免疫，包括bypassPermissions
     ↓
【第2层】权限模式过滤
  2a. bypassPermissions → 放行（但1d-1g不可跳过）
  2b. always-allow规则匹配 → 放行
     ↓
【第3层】模式转换
  如果 mode === 'dontAsk' 且 result === 'ask'
    → 自动拒绝（后台Agent不弹对话框）
     ↓
【第4层】Auto模式分类器
  4a. acceptEdits快路径 — 编辑工作目录？直接放行
  4b. 安全工具白名单 — FileRead/Grep/Glob直接放行
  4c. 运行YOLO分类器 — AI评估风险
     ↓
【第5层】用户钩子
  执行PermissionRequest钩子
  钩子可以allow/deny/无操作
     ↓
【第6层】用户交互
  弹出权限对话框
  等待用户点击
     ↓
  返回 allow / deny
```

### 6.2 五种权限模式 ​

**动手查看模式定义：**

bash

```
grep -A 5 "PermissionMode\|PERMISSION_MODE" utils/permissions/PermissionMode.ts | head -30
```

| 模式                | 行为         | 适用场景    | 风险等级 |
| ----------------- | ---------- | ------- | ---- |
| default           | 每次操作都问     | 日常开发    | 最安全  |
| plan              | 只能看不能改     | 方案讨论    | 最安全  |
| acceptEdits       | 文件操作自动通过   | 快速编码    | 中等   |
| auto              | AI分类器自动判断  | 熟悉的项目   | 中高   |
| bypassPermissions | 几乎全部放行     | 完全信任    | 高    |
| dontAsk           | 需确认的操作直接拒绝 | 后台Agent | 特殊   |

### 6.3 YOLO分类器——52KB的AI安全大脑 ​

bash

```
wc -l utils/permissions/yoloClassifier.ts
# → 1495行
```

**动手搜索安全白名单：**

bash

```
grep -A 15 "SAFE_YOLO_ALLOWLISTED\|allowlisted" utils/permissions/yoloClassifier.ts | head -25
```

白名单中的工具直接放行，不消耗API调用：

* FileReadTool（只读）
* GrepTool（搜索内容）
* GlobTool（搜索文件名）
* TaskCreateTool/TaskUpdateTool（元数据操作）
* SendMessageTool（给队友发消息）

对于非白名单工具（尤其是Bash），分类器的处理流程：

1. 先检查acceptEdits快路径
2. 对Bash命令进行AST解析
3. 检测危险模式（rm -rf、force push、权限变更等）
4. 可能调用API进行深度评估
5. 返回allow或deny

### 6.4 拒绝熔断器 ​

bash

```
cat utils/permissions/denialTracking.ts
```

完整源码只有46行——这是教科书级的小模块设计：

typescript

```
export const DENIAL_LIMITS = {
  maxConsecutive: 3,    // 连续3次被拒 → 降级为人工确认
  maxTotal: 20,         // 累计20次被拒 → 整个auto模式熔断
} as const

export function recordDenial(state) {
  return { ...state,
    consecutiveDenials: state.consecutiveDenials + 1,
    totalDenials: state.totalDenials + 1,
  }
}

export function recordSuccess(state) {
  if (state.consecutiveDenials === 0) return state // 无变化
  return { ...state, consecutiveDenials: 0 }       // 重置连续计数
}

export function shouldFallbackToPrompting(state) {
  return (
    state.consecutiveDenials >= DENIAL_LIMITS.maxConsecutive ||
    state.totalDenials >= DENIAL_LIMITS.maxTotal
  )
}
```

**设计启发：**

* 一次成功就重置连续拒绝计数（`recordSuccess`只重置`consecutiveDenials`）
* 总拒绝数不重置——这是永久记录
* 46行4个函数，不多不少

### 6.5 文件系统沙箱 ​

bash

```
wc -l utils/permissions/filesystem.ts
# → 1777行
```

**动手搜索危险文件列表：**

bash

```
grep -A 10 "DANGEROUS_FILE\|DANGEROUS_DIR" utils/permissions/filesystem.ts | head -25
```

不可修改的文件/目录（对所有模式免疫）：

* `.gitconfig` — 可被利用执行任意代码
* `.bashrc` / `.zshrc` — Shell初始化
* `.mcp.json` — MCP服务器列表
* `.git/` — 版本控制核心
* `.vscode/` / `.idea/` — IDE设置
* `.claude/` — Claude配置目录

**三重路径验证：**

1. 原始路径检查
2. 符号链接解析（防止软链接逃逸）
3. 工作目录归属检查

### 6.6 Hint侧通道 ​

bash

```
head -70 utils/claudeCodeHints.ts
```

**原始注释（这是最精确的设计说明）：**

typescript

```
/**
 * CLIs and SDKs running under Claude Code can emit a self-closing
 * `<claude-code-hint />` tag to stderr (merged into stdout by the shell
 * tools). The harness scans tool output for these tags, strips them before
 * the output reaches the model, and surfaces an install prompt to the
 * user — no inference, no proactive execution.
 *
 * This file provides both the parser and a small module-level store for
 * the pending hint. The store is a single slot (not a queue) — we surface
 * at most one prompt per session, so there's no reason to accumulate.
 */
```

关键实现：

typescript

```
// 标签匹配正则——只匹配独占一行的标签
const HINT_TAG_RE = /^[ \t]*<claude-code-hint\s+([^>]*?)\s*\/>[ \t]*$/gm

// 属性解析
const ATTR_RE = /(\w+)=(?:"([^"]*)"|([^\s/>]+))/g

// 支持的版本和类型
const SUPPORTED_VERSIONS = new Set([1])
const SUPPORTED_TYPES = new Set<string>(['plugin'])
```

**设计精髓：**

* 标签必须独占一行（防止嵌入在日志语句中被误匹配）
* 单槽存储——每会话最多一个提示（防止AI轰炸用户）
* 不支持的版本/类型静默丢弃（向前兼容）
* AI看到的是剥离后的输出，完全不知道标签的存在

### 6.7 Bash权限系统 ​

bash

```
wc -l tools/BashTool/bashPermissions.ts
# → 500+行
```

这个文件实现了Bash命令的精细权限控制：

bash

```
head -60 tools/BashTool/bashPermissions.ts
```

包括：

* 命令前缀匹配（`npm *`匹配所有npm命令）
* 通配符模式（`Bash(git push:*)`）
* 环境变量白名单（`HARNESS_QUIET`等）
* 输出重定向检测
* 管道命令分析

---