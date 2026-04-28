// 这是一个可以在浏览器控制台运行的测试脚本，用于连接和验证后端逻辑。
// 你可以先启动你的 Node.js 后端服务 (npm run dev)，然后打开任意网页的控制台，
// 粘贴并运行以下代码。

const socketScript = document.createElement('script');
socketScript.src = "https://cdn.socket.io/4.7.4/socket.io.min.js";
document.head.appendChild(socketScript);

socketScript.onload = () => {
    console.log("[Client] Socket.IO Loaded");
    
    // 连接到你的本地后端
    const socket = io("http://localhost:3000");

    socket.on("connect", () => {
        console.log("[Client] Connected to Server:", socket.id);
        
        // 测试 1: 发送普通的电影查询 (触发 Explore Agent 冲浪)
        setTimeout(() => {
            console.log("\n--- Test 1: Explore Agent ---");
            console.log("[Client] User says: 查一下最新电影沙丘");
            socket.emit("MESSAGE", { content: "查一下最新电影沙丘" });
        }, 1000);
        
        // 测试 2: 发送模糊指令 (触发 AskClarification 主动澄清)
        setTimeout(() => {
            console.log("\n--- Test 2: Clarification ---");
            console.log("[Client] User says: 帮我买个包");
            socket.emit("MESSAGE", { content: "帮我买个包" });
        }, 4000);

        // 测试 3: 发送敏感操作 (触发 Permission Interceptor 挂起和恢复)
        setTimeout(() => {
            console.log("\n--- Test 3: Permission Harness ---");
            console.log("[Client] User says: 存到Notion愿望单");
            socket.emit("MESSAGE", { content: "存到Notion愿望单" });
        }, 8000);
    });

    // 监听状态变化
    socket.on("AGENT_STATE", (state) => {
        console.log(`[Status Indicator]: ${state.status} - ${state.description}`);
    });

    // 监听流式打字输出
    let buffer = "";
    socket.on("CHUNK", (chunk) => {
        buffer += chunk.text;
        process.stdout?.write(chunk.text); // If in Node
    });

    // 监听高危操作拦截请求
    socket.on("PERMISSION_REQ", (req) => {
        console.warn(`\n[ALERT] 收到高危权限请求！`);
        console.warn(`工具名称: ${req.tool}`);
        console.warn(`操作描述: ${req.desc}`);
        
        // 模拟用户在 iOS 界面上思考了 1 秒钟，然后点击了“允许”
        setTimeout(() => {
            console.log("[Client] 用户点击了【允许】");
            socket.emit("PERMISSION_RES", { action: "ALLOW" });
        }, 1000);
    });
};
