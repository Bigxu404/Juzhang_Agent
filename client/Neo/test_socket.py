import asyncio
import websockets
import json

async def hello():
    uri = "ws://localhost:3000/socket.io/?EIO=4&transport=websocket"
    async with websockets.connect(uri) as websocket:
        print("Connected")
        res = await websocket.recv()
        print("Received:", res)
        # Try auth
        auth_msg = '40{"token":"123"}'
        await websocket.send(auth_msg)
        print("Sent Auth")
        res = await websocket.recv()
        print("Received:", res)

asyncio.get_event_loop().run_until_complete(hello())
