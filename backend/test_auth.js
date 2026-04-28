const axios = require('axios');
const io = require('socket.io-client');

async function test() {
  try {
    console.log("1. Registering user...");
    const regRes = await axios.post('http://localhost:3000/api/auth/register', {
      username: 'testuser_' + Date.now(),
      password: 'password123'
    });
    console.log("Registered:", regRes.data);
    const token = regRes.data.token;

    console.log("\n2. Connecting via WS...");
    const socket = io("http://localhost:3000", {
      auth: { token }
    });

    socket.on("connect", () => {
      console.log("WS Connected!");
      socket.emit("MESSAGE", { content: "你好，帮我查一下今天的新闻" });
    });

    socket.on("CHUNK", (chunk) => {
      process.stdout.write(chunk.text);
    });

    socket.on("AGENT_STATE", (state) => {
      console.log(`\n[State] ${state.status}: ${state.description}`);
    });

    setTimeout(() => {
      console.log("\nDisconnecting...");
      socket.disconnect();
      process.exit(0);
    }, 10000);

  } catch (e) {
    console.error(e.response ? e.response.data : e.message);
  }
}
test();
