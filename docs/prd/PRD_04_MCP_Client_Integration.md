description: 讨论了如何在Agent产品中安全集成MCP（Model Context Protocol）以实现强大的外部数据访问与写入能力。重点解决Token管理、工具原子化设计以及权限拦截机制。

# PRD 04: MCP Client Integration (工具与外部沙箱)

## 1. 产品定位与目标
本模块是Agent在数字世界的“手脚”与“记忆外脑”。
用户希望Agent能连接他们的Notion、Obsidian等知识库进行深度的阅读整理和消费灵感归档。通过集成MCP，让Agent具备标准化地调用各种外部数据库和接口的能力。

## 2. 核心功能设计

### 2.1 MCP 客户端架构选型 (Server-side Hub)
基于 **PRD 01** 中的端云切割建议，MCP客户端应部署在我们的云端服务器上，而非iOS端内。

- **优势**：
  - Node.js 环境完美支持官方或社区成熟的MCP SDK库（包括stdio或SSE）。
  - 可以通过服务器的长连接直接操作MCP Server，规避移动端网络中断导致的写库失败。
- **机制**：
  - iOS 端只负责 OAuth 授权或者用户输入 Token。
  - 服务器接收到 Token 后，在安全的沙箱内挂载 MCP Server (例如，启动一个 `notion-mcp-server` 进程连接用户的 Notion)。
  - 当Agent Loop运行时，它向这个已连接的 MCP Client 发起标准化调用。

### 2.2 Token与凭证安全 (Security Guard)
Agent需要访问高度私密的用户笔记，因此安全是重中之重。
- **Token 隔离与加密**：在服务端，用户的 Notion 访问凭证等敏感 Token 必须通过KMS或强加密机制存储。
- **OAuth集成优先**：尽量优先开发标准的 OAuth 授权流，减少用户直接向我们输入原始 API 密钥的需求。

### 2.3 工具的原子化设计 (Atomized Tools)
参考 Claude Code 中 `BashTool` 的设计哲学（第四章：工具系统），我们不能给大模型设计诸如 `ParseArticleAndSaveToNotion` 这种过度集成的宏大工具，这容易让Agent在执行失败时无从下手。

我们要求所有通过MCP暴露给大模型的工具必须是**原子化且健壮的**。例如集成Notion：
1. `QueryNotionDatabase`：只负责查询并列出某个愿望清单的结构。
2. `FetchWebpageContent`（非Notion MCP，是自有工具）：只负责抓取正文。
3. `AppendNotionBlock`：只负责将解析后的摘要写入特定的块中。
- 大模型自己（或通过Coordinator指挥Action Subagent）去编排这些原子动作。

### 2.4 Harness: 权限拦截器 (Permission Interceptor)
这是借鉴CC源码最核心的部分（第六章Harness）。

- **拦截策略定义**：
  - 对于所有读操作的 MCP 工具（如 `SearchNotion`），配置为 **Auto Allow (自动放行)**。
  - 对于写入或修改的 MCP 工具（如 `UpdateNotionPage` 或发送推文），必须强制配置为 **Requires Approval (需审批)**。
- **拦截流程**：
  1. Action Subagent 决定调用 `AppendNotionBlock`，由于权限属于 Level 3，服务器拦截该动作。
  2. 服务器将此 `PermissionRequest` 通过 WebSocket 发送给 iOS 客户端。
  3. 客户端弹出交互式卡片（例如：“Agent打算将这篇文章保存到Notion，是否允许？”）。
  4. 用户点击【同意】，iOS 将结果返回给服务器，服务器解除拦截并执行真正的 MCP 调用。

## 3. MVP 阶段的取舍
- **排除**：第一阶段不支持需要复杂本地文件系统权限的 MCP（例如运行在用户自己电脑上的 Obsidian 本地 MCP）。这涉及穿透内网，过于复杂。
- **保留**：首期**只深度打通 1-2 款云端优先**的知识管理工具，比如 **Notion (用于记录灵感和清单)** 或者 **Readwise (用于稍后读摘要)**，把整个 OAuth、Token 存储和读写链路做透。