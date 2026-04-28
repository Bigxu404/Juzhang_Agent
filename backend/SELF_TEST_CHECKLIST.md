# 移动端Agent MVP 自测清单 (Phase 1 & Phase 2 Mock)

## 模块 1: WebSocket 服务通信
- [ ] 能否通过客户端/Postman连上 WebSocket Server (ws://localhost:3000)？
- [ ] 连上后，是否自动收到欢迎文本 (事件: `CHUNK`) 和待机状态 (事件: `AGENT_STATE`, status: `IDLE`)？
- [ ] 用户发送 `MESSAGE` 后，服务端状态是否变更为 `WORKING`，结束后是否恢复 `IDLE`？

## 模块 2: Harness 安全拦截器 (MVP Mock测试)
- [ ] 当用户发送包含触发工具的指令（例如：“把我刚才发你的淘宝鞋链接存到Notion愿望单”）时，服务端是否挂起循环？
- [ ] 服务端是否会向客户端发射 `PERMISSION_REQ` 事件，并携带描述（“将内容追加到用户的Notion文档”）？
- [ ] 客户端回复 `PERMISSION_RES` 为 `DENY` 时，后端终端是否捕获到并放弃工具执行？
- [ ] 如果客户端连续回复 3 次 `DENY`，系统是否触发 `DENIAL_LIMIT_REACHED`（拒绝熔断）并正常退出 Agent Loop？

## 模块 3: 多Agent派发 (Coordinator Mode)
- [ ] 当用户发送查询指令（如：“查一下最新《沙丘》电影评分”）时，系统是否会调度 `DelegateToExploreAgent` 工具？
- [ ] 界面状态是否变更为 `WORKING`（“派发代理冲浪...”）？
- [ ] 在等待一定时间后，是否能获取到 Explore Agent 的总结并发送 `CHUNK` 给用户？
