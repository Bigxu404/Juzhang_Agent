const io = require('socket.io-client');
const jwt = require('jsonwebtoken');

// 从之前数据库里获取到的 zhangxu 用户的 ID
const userId = '0a2472cc-a266-47a3-984d-1844cd882999';
const token = jwt.sign({ userId }, process.env.JWT_SECRET || 'super-secret-key-for-dev');

console.log("Token:", token);

const socket = io('http://localhost:3000', {
  auth: { token }
});

socket.on('connect', () => {
  console.log('Connected to server!');
  socket.emit('MESSAGE', { content: '你好，橘长！' });
});

socket.on('connect_error', (err) => {
  console.log('Connect error:', err.message);
});

socket.on('AGENT_STATE', (data) => {
  console.log('AGENT_STATE:', data);
});

socket.on('CHUNK', (data) => {
  console.log('CHUNK:', data);
});

setTimeout(() => {
  console.log('Timeout. Exiting.');
  process.exit(0);
}, 5000);
