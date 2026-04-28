# 第九章：Skill 系统

Skill 让用户定制 AI 行为，无需写代码。

---

## 设计动机

Skill 是在工具（原子能力）和 Prompt（全局指令）之间的中间层：用 Markdown 描述工作流程，按需激活。

---

## Skill 的核心价值

- **按需激活**：只有任务匹配时才注入，不浪费上下文。
- **用户可修改**：无需编程，写 Markdown 即可。
- **自动优化**：对话结束后自动分析并提议改进。

---

## Skill 的格式与关键字段

Skill 是带有 YAML frontmatter 的 Markdown 文件：
- **when_to_use**：最重要的字段，决定触发时机。
- **allowed_tools**：工具白名单，实现最小权限。
- **disable_model_invocation**：控制是模型主动触发还是只能显式调用。

---

## 运行时机制

当 Skill 激活时：
1. 正文内容注入为一条 `system` 消息。
2. 工具列表限制为白名单。
3. AI 遵循 Skill 中的操作指南执行任务。

---

## 加载优先级

- `~/.alice/skills/`（全局）
- `{workdir}/.alice/skills/`（项目专属）
项目 Skill 优先级高于全局 Skill。

---

## Skill vs 工具

- **工具**：代码实现的原子能力，由开发者创建。
- **Skill**：给 AI 的操作手册（上层编排），由用户创建。
