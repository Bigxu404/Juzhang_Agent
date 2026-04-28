description: 分析Coordinator领导者模式和四种底层Swarm后端机制。

## 第十一章：多Agent协调 ​

### 11.1 Coordinator模式 ​

bash

```
head -60 coordinator/coordinatorMode.ts
```

当`COORDINATOR_MODE`启用时，一个"领导者"AI可以：

* 用`TeamCreateTool`创建团队
* 用`SendMessageTool`给队友下达任务
* 每个队友在独立环境中运行

### 11.2 Swarm系统 ​

bash

```
ls utils/swarm/
```

Swarm目录包含20+个模块，实现了4种队友后端：

| 后端        | 执行方式     | 适用场景     |
| --------- | -------- | -------- |
| InProcess | 同进程共享内存  | 快速小任务    |
| Tmux      | Tmux会话   | 需要终端的任务  |
| iTerm     | iTerm2窗口 | macOS可视化 |
| Pane      | 面板模式     | IDE集成    |

### 11.3 Buddy系统 ​

bash

```
ls buddy/
```

虚拟伙伴系统——通过`/buddy`命令交互。这是一个隐藏的彩蛋功能。

---