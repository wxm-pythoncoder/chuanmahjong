// 川麻服务器入口：WebSocket 接入 + 房间调度
import { WebSocketServer } from 'ws';
import { Room } from './room.js';

const PORT = process.env.PORT || 8080;
const wss = new WebSocketServer({ port: PORT });

wss.on('connection', (socket) => {
  socket.on('message', (data) => {
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      socket.send(JSON.stringify({ type: 'error', msg: '非法 JSON' }));
      return;
    }
    try {
      handle(socket, msg);
    } catch (e) {
      socket.send(JSON.stringify({ type: 'error', msg: e.message }));
    }
  });

  socket.on('close', () => {
    const room = Room.get(socket.roomId);
    if (room) room.leave(socket);
  });
});

function handle(socket, msg) {
  switch (msg.type) {
    case 'create_room': {
      const room = new Room();
      room.join(socket, msg.name || '玩家');
      break;
    }
    case 'rejoin_room': {
      const room = Room.get(String(msg.roomId));
      if (!room) throw new Error('房间不存在或已结束');
      const seat = room.rejoin(socket, msg.name || '玩家');
      if (seat === null) throw new Error('没有可重连的座位，请重新加入房间');
      break;
    }
    case 'join_room': {
      const room = Room.get(String(msg.roomId));
      if (!room) throw new Error('房间不存在');
      room.join(socket, msg.name || '玩家');
      break;
    }
    case 'quick_match': {
      let room = Room.findJoinable();
      if (!room) room = new Room();
      room.join(socket, msg.name || '玩家');
      break;
    }
    case 'exchange':
    case 'dingque':
    case 'discard':
    case 'claim':
    case 'zimo':
    case 'pass_zimo':
    case 'gang': {
      const room = Room.get(socket.roomId);
      if (!room) throw new Error('你不在房间里');
      room.handleAction(socket.seat, msg);
      break;
    }
    case 'ping':
      socket.send(JSON.stringify({ type: 'pong' }));
      break;
    default:
      socket.send(JSON.stringify({ type: 'error', msg: `未知消息 ${msg.type}` }));
  }
}

console.log(`川麻服务器启动，监听端口 ${PORT}`);
console.log('协议：create_room / join_room / quick_match / dingque / discard / claim / zimo / gang');
