const io = require('socket.io-client');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'super-secret-key-for-dev';
const userId = '0a2472cc-a266-47a3-984d-1844cd882999';
const token = jwt.sign({ userId }, JWT_SECRET);

const socket = io('http://localhost:3000', {
  auth: { token },
  transports: ['websocket']
});

socket.on('connect', () => {
  console.log('Connected! ID:', socket.id);
  socket.emit('MESSAGE', { content: 'test message' });
});

socket.on('AGENT_STATE', (data) => {
  console.log('AGENT_STATE:', data);
});

socket.on('CHUNK', (data) => {
  console.log('CHUNK:', data);
});

socket.on('connect_error', (err) => {
  console.log('Error:', err);
});

setTimeout(() => process.exit(0), 3000);
