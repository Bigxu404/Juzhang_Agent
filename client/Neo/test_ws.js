const io = require('socket.io-client');
const token = '123'; // invalid token is fine, we just want to see if it connects
const socket = io('http://localhost:3000', {
  auth: { token }
});
socket.on('connect', () => { console.log('connected'); process.exit(0); });
socket.on('connect_error', (err) => { console.log('connect_error', err.message); process.exit(1); });
setTimeout(() => { console.log('timeout'); process.exit(1); }, 2000);
