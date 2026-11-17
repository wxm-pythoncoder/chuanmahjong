// 联机房间流程测试：自起服务器，4 个客户端 quick_match → 开局 → 定缺
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { WebSocket } from 'ws';

const PORT = 8091;
const URL = `ws://127.0.0.1:${PORT}`;
let server;

before(async () => {
  server = spawn(process.execPath, ['src/index.js'], {
    env: { ...process.env, PORT: String(PORT) },
    stdio: 'ignore',
  });
  // 等服务器就绪
  for (let i = 0; i < 50; i++) {
    try {
      await new Promise((res, rej) => {
        const ws = new WebSocket(URL);
        ws.on('open', () => { ws.close(); res(); });
        ws.on('error', rej);
      });
      return;
    } catch {
      await new Promise((r) => setTimeout(r, 100));
    }
  }
  throw new Error('服务器启动失败');
});

after(() => {
  server?.kill();
});

function connect() {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(URL);
    const client = { ws, inbox: [], waiters: [] };
    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      const w = client.waiters.find((w) => w.type === msg.type);
      if (w) {
        client.waiters.splice(client.waiters.indexOf(w), 1);
        w.resolve(msg);
      } else {
        client.inbox.push(msg);
      }
    });
    ws.on('open', () => resolve(client));
    ws.on('error', reject);
  });
}

function wait(client, type, timeout = 3000) {
  const idx = client.inbox.findIndex((m) => m.type === type);
  if (idx >= 0) return Promise.resolve(client.inbox.splice(idx, 1)[0]);
  return new Promise((resolve, reject) => {
    const w = { type, resolve };
    client.waiters.push(w);
    setTimeout(() => {
      const i = client.waiters.indexOf(w);
      if (i >= 0) {
        client.waiters.splice(i, 1);
        reject(new Error(`等待 ${type} 超时`));
      }
    }, timeout);
  });
}

test('快速匹配：4 人满员开局 → 换三张 → 定缺', async () => {
  const clients = [];
  for (let i = 0; i < 4; i++) {
    const c = await connect();
    c.ws.send(JSON.stringify({ type: 'quick_match', name: `测试${i}` }));
    clients.push(c);
  }
  // 每个客户端都应收到 joined
  for (const c of clients) {
    const joined = await wait(c, 'joined');
    assert.ok(joined.seat >= 0 && joined.seat <= 3);
  }
  // 满员后开局：game_start + ask_exchange
  const startMsgs = [];
  for (const c of clients) {
    const gs = await wait(c, 'game_start');
    startMsgs.push(gs);
    assert.ok(Array.isArray(gs.hand) && (gs.hand.length === 13 || gs.hand.length === 14),
      `手牌应为 13 或 14（庄家）张，实际 ${gs.hand?.length}`);
    const ask = await wait(c, 'ask_exchange');
    assert.ok(['下家', '上家', '对家'].includes(ask.direction),
      `换三张方向应是 下家/上家/对家 之一，实际 ${ask.direction}`);
  }
  // 各家换出 3 张同门（从自己手牌里挑）
  for (let i = 0; i < clients.length; i++) {
    const c = clients[i];
    const hand = startMsgs[i].hand;
    // 找一个至少有 3 张的门
    const bySuit = [[], [], []];
    for (const t of hand) bySuit[Math.floor(t / 9)].push(t);
    const suit = bySuit.findIndex((a) => a.length >= 3);
    c.ws.send(JSON.stringify({ type: 'exchange', tiles: bySuit[suit].slice(0, 3) }));
  }
  // 换完进入定缺
  for (const c of clients) {
    await wait(c, 'ask_dingque');
  }
  // 定缺后进入 playing：丢弃旧状态，等到 playing 的 state
  for (const c of clients) {
    c.ws.send(JSON.stringify({ type: 'dingque', suit: 0 }));
  }
  for (const c of clients) {
    let st;
    do {
      st = await wait(c, 'state');
    } while (st.view.state !== 'playing');
    assert.ok(Array.isArray(st.view.players) && st.view.players.length === 4);
  }
  clients.forEach((c) => c.ws.close());
});
