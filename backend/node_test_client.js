const io = require("socket.io-client");

console.log("[Client] Starting Node.js test client");

const socket = io("http://localhost:3000");

socket.on("connect", () => {
    console.log("[Client] Connected to Server:", socket.id);
    
    // Test 1: Explore Agent
    setTimeout(() => {
        console.log("\n--- Test 1: Explore Agent ---");
        console.log("[Client] User says: 查一下最新电影沙丘");
        socket.emit("MESSAGE", { content: "查一下最新电影沙丘" });
    }, 1000);
    
    // Test 2: Clarification
    setTimeout(() => {
        console.log("\n--- Test 2: Clarification ---");
        console.log("[Client] User says: 帮我买个包");
        socket.emit("MESSAGE", { content: "帮我买个包" });
    }, 4000);

    // Test 3: Permission Harness
    setTimeout(() => {
        console.log("\n--- Test 3: Permission Harness ---");
        console.log("[Client] User says: 存到Notion愿望单");
        socket.emit("MESSAGE", { content: "存到Notion愿望单" });
    }, 8000);
});

socket.on("AGENT_STATE", (state) => {
    console.log(`[Status Indicator]: ${state.status} - ${state.description}`);
});

let buffer = "";
socket.on("CHUNK", (chunk) => {
    buffer += chunk.text;
    process.stdout.write(chunk.text);
});

socket.on("PERMISSION_REQ", (req) => {
    console.warn(`\n[ALERT] 收到高危权限请求！`);
    console.warn(`工具名称: ${req.tool}`);
    console.warn(`操作描述: ${req.desc}`);
    
    // Simulate user clicking ALLOW after 1 second
    setTimeout(() => {
        console.log("[Client] 用户点击了【允许】");
        socket.emit("PERMISSION_RES", { action: "ALLOW" });
    }, 1000);
});

socket.on("disconnect", () => {
    console.log("[Client] Disconnected");
});
