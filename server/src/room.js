// 房间管理：一个房间绑定一局 Table，4 个 WebSocket 玩家
// 消息协议（JSON）：
//   客户端 → 服务器：
//     {type:'create_room', name}
//     {type:'join_room', roomId, name}
//     {type:'quick_match', name}
//     {type:'dingque', suit}
//     {type:'discard', tile}
//     {type:'claim', action}          // hu | peng | minggang | pass
//     {type:'zimo'}                   // 自摸
//     {type:'gang', tile, gtype}      // angang | bugang
//   服务器 → 客户端：
//     {type:'room_created', roomId}
//     {type:'joined', roomId, seat, players:[names]}
//     {type:'player_joined', players}
//     {type:'game_start', dealer, hand, dealerHand?}
//     {type:'ask_dingque'}
//     {type:'ask_claim', tile, options}
//     {type:'your_turn', canSelfDraw, canGangTiles}
//     {type:'event', event}           // 牌桌事件（出牌/碰/杠/胡等）
//     {type:'state', view}            // 每次行动后的个人视角完整状态
//     {type:'error', msg}

import { randomInt } from 'node:crypto';
import { Table } from './game/table.js';
import { tileName } from './game/tiles.js';

const rooms = new Map();
let roomSeq = 100;

export class Room {
  constructor() {
    this.id = String(roomSeq++);
    this.players = [null, null, null, null]; // {socket, name, alive}
    this.table = null;
    this.claimTimer = null;
    this.autoPlayTimer = null;
    this.exchangeTimer = null;
    this.lastEventIdx = 0; // 已广播的事件下标
    rooms.set(this.id, this);
  }

  static get(id) {
    return rooms.get(id);
  }

  static findJoinable() {
    for (const r of rooms.values()) {
      if (r.players.every((p) => p !== null) === false && r.table === null) {
        if (r.players.some((p) => p === null)) return r;
      }
    }
    return null;
  }

  humanCount() {
    return this.players.filter((p) => p !== null).length;
  }

  emptySeats() {
    return this.players.map((p, i) => (p === null ? i : null)).filter((i) => i !== null);
  }

  /** 断线重连：按昵称找回掉线座位，恢复手牌与进度 */
  rejoin(socket, name) {
    for (let s = 0; s < 4; s++) {
      const p = this.players[s];
      if (p && p.connected === false && p.name === name) {
        this.players[s] = { socket, name: p.name, connected: true };
        socket.roomId = this.id;
        socket.seat = s;
        this.send(s, { type: 'joined', roomId: this.id, seat: s, players: this.names() });
        this.broadcastOthers(s, { type: 'player_reconnected', seat: s });
        this.pushState();
        return s;
      }
    }
    return null;
  }

  join(socket, name) {
    const seat = this.emptySeats()[0];
    if (seat === undefined) throw new Error('房间已满');
    this.players[seat] = { socket, name, alive: true };
    socket.roomId = this.id;
    socket.seat = seat;
    this.send(seat, { type: 'joined', roomId: this.id, seat, players: this.names() });
    this.broadcastOthers(seat, { type: 'player_joined', players: this.names() });
    // 满员自动开局
    if (this.humanCount() === 4) this.start();
    return seat;
  }

  leave(socket) {
    const seat = socket.seat;
    if (seat === undefined) return;
    const p = this.players[seat];
    if (p) {
      // 掉线托管：保留座位，标记掉线后由系统代打
      p.connected = false;
      p.socket = null;
      this.broadcast({ type: 'player_disconnected', seat, name: p.name });
    }
  }

  names() {
    return this.players.map((p) => (p ? p.name : null));
  }

  send(seat, msg) {
    const p = this.players[seat];
    if (p && p.socket.readyState === 1) {
      p.socket.send(JSON.stringify(msg));
    }
  }

  broadcast(msg) {
    for (let s = 0; s < 4; s++) this.send(s, msg);
  }

  broadcastOthers(seat, msg) {
    for (let s = 0; s < 4; s++) {
      if (s !== seat) this.send(s, msg);
    }
  }

  start() {
    // 摇骰子（两次）：第一次定换三张方向，第二次定起牌墙位
    const d1 = randomInt(6) + 1;
    const d2 = randomInt(6) + 1;
    const d3 = randomInt(6) + 1;
    const d4 = randomInt(6) + 1;
    const sideLabels = ['东家墙', '南家墙', '西家墙', '北家墙'];
    const startSide = (d3 + d4) % 4;
    this.table = new Table(this.names(), Math.random, null, {
      exchangeMode: (d1 + d2) % 3,
      wallStartSide: startSide,
    });
    this.table.deal();
    this.table.log('dice_exchange', {
      d1, d2,
      direction: this.table.exchangeDirectionLabel(),
    });
    this.table.log('dice_draw', {
      d3, d4,
      startSide: sideLabels[startSide],
    });
    for (let s = 0; s < 4; s++) {
      this.send(s, { type: 'game_start', dealer: this.table.dealer, hand: this.table.players[s].hand });
    }
    // 开局后的状态推送（换三张阶段会附带 ask_exchange）
    this.pushState();
  }

  /** 给某家推送个人视角状态 */
  pushState() {
    // 广播自上次推送以来的新事件
    const evts = this.table.events;
    for (; this.lastEventIdx < evts.length; this.lastEventIdx++) {
      this.broadcast({ type: 'event', event: evts[this.lastEventIdx] });
    }
    for (let s = 0; s < 4; s++) {
      this.send(s, { type: 'state', view: this.table.view(s) });
    }
    // 待回应提示
    if (this.table.state === 'huan' && this.table.phase === 'exchange') {
      for (let s = 0; s < 4; s++) {
        if (!this.table.exchangePicks.has(s)) {
          this.send(s, { type: 'ask_exchange', direction: this.table.exchangeDirectionLabel() });
        }
      }
      this.armExchangeTimeout();
    } else if (this.table.state === 'dingque') {
      for (let s = 0; s < 4; s++) this.send(s, { type: 'ask_dingque' });
    } else if (this.table.phase === 'discard' && this.table.state === 'playing') {
      // 掉线托管：轮到掉线玩家出牌时，3 秒后代打
      const s = this.table.turn;
      const rp = this.players[s];
      if (rp && rp.connected === false) this.armAutoPlay(s);
    } else if (this.table.phase === 'claim') {
      const options = this.table.pendingClaim.options;
      for (const [seatStr, acts] of options) {
        const seat = Number(seatStr);
        this.send(seat, {
          type: 'ask_claim',
          tile: this.table.pendingClaim.tile,
          tileName: tileName(this.table.pendingClaim.tile),
          options: acts,
        });
      }
      this.armClaimTimeout();
    } else if (this.table.phase === 'discard' && this.table.state === 'playing') {
      const s = this.table.turn;
      const p = this.table.players[s];
      this.send(s, {
        type: 'your_turn',
        canSelfDraw: p.canSelfDraw,
        canGangTiles: p.canGangTiles,
      });
    }
  }

  /** claim 超时自动过（8 秒） */
  armClaimTimeout() {
    if (this.claimTimer) clearTimeout(this.claimTimer);
    this.claimTimer = setTimeout(() => {
      if (!this.table || this.table.phase !== 'claim') return;
      const options = this.table.pendingClaim?.options;
      if (!options) return;
      for (const seatStr of Object.keys(options)) {
        const seat = Number(seatStr);
        if (!(seat in this.table.claims)) {
          this.handleAction(seat, { type: 'claim', action: 'pass' });
        }
      }
    }, 8000);
  }

  /** 掉线托管：3 秒后代掉线玩家出牌/自摸 */
  armAutoPlay(seat) {
    if (this.autoPlayTimer) clearTimeout(this.autoPlayTimer);
    this.autoPlayTimer = setTimeout(() => {
      if (!this.table || this.table.state !== 'playing') return;
      if (this.table.turn !== seat || this.table.phase !== 'discard') return;
      if (this.players[seat]?.connected) return; // 已重连则不代打
      const p = this.table.players[seat];
      if (p.canSelfDraw) {
        this.table.hu(seat);
      } else {
        // 托管出牌：优先打缺门，否则打第一张能打的
        let tile = null;
        const q = p.dingque;
        if (q !== null && !this.table.voided(seat)) {
          tile = p.hand.find((t) => tileSuit(t) === q);
        }
        tile = tile ?? p.hand.find((t) => this.table.canDiscard(seat, t));
        if (tile !== undefined && tile !== null) this.table.discard(seat, tile);
        else if (p.hand.length > 0) this.table.discard(seat, p.hand[0]);
      }
      this.pushState();
    }, 3000);
  }

  /** 换三张超时：10 秒后给未交的座位自动选 3 张同门（缺最少的门） */
  armExchangeTimeout() {
    if (this.exchangeTimer) clearTimeout(this.exchangeTimer);
    this.exchangeTimer = setTimeout(() => {
      if (!this.table || this.table.state !== 'huan') return;
      for (const p of this.table.players) {
        if (!this.table.exchangePicks.has(p.seat)) {
          const counts = this.table.countsOf(p.seat);
          const perSuit = [[], [], []];
          for (let x = 0; x < 27; x++) {
            if (counts[x] > 0) perSuit[Math.floor(x / 9)].push(x);
          }
          let suit = 0;
          let bestN = 99;
          for (let s = 0; s < 3; s++) {
            if (perSuit[s].length >= 3 && perSuit[s].length < bestN) {
              bestN = perSuit[s].length;
              suit = s;
            }
          }
          const tiles = perSuit[suit].slice(0, 3);
          this.handleAction(p.seat, { type: 'exchange', tiles });
        }
      }
    }, 10000);
  }

  /** 处理玩家动作消息 */
  handleAction(seat, msg) {
    const t = this.table;
    const rp = this.players[seat];
    if (rp && rp.connected === false) return; // 掉线玩家由托管代打，忽略其消息
    if (!t || t.state === 'over') return;
    try {
      switch (msg.type) {
        case 'exchange':
          if (t.state === 'huan') {
            t.exchange(seat, msg.tiles);
            this.pushState();
          }
          break;
        case 'dingque':
          if (t.state === 'dingque') {
            t.dingque(seat, msg.suit);
            if (t.state === 'playing') this.pushState();
          }
          break;
        case 'discard':
          if (t.phase === 'discard' && t.turn === seat) {
            const r = t.discard(seat, msg.tile);
            this.pushState();
          }
          break;
        case 'claim':
          if (t.phase === 'claim') {
            t.claim(seat, msg.action);
            if (t.claimTimer) clearTimeout(t.claimTimer);
            this.pushState();
          }
          break;
        case 'zimo':
          if (t.turn === seat && t.players[seat].canSelfDraw) {
            t.hu(seat);
            this.pushState();
          }
          break;
        case 'pass_zimo':
          if (t.turn === seat && t.players[seat].canSelfDraw) {
            t.passSelfDraw(seat);
            this.pushState();
          }
          break;
        case 'gang':
          if (t.turn === seat && t.phase === 'discard') {
            t.gang(seat, msg.tile, msg.gtype);
            this.pushState();
          }
          break;
        default:
          this.send(seat, { type: 'error', msg: `未知消息 ${msg.type}` });
      }
    } catch (e) {
      this.send(seat, { type: 'error', msg: e.message });
    }
  }

  dispose() {
    if (this.claimTimer) clearTimeout(this.claimTimer);
    if (this.autoPlayTimer) clearTimeout(this.autoPlayTimer);
    if (this.exchangeTimer) clearTimeout(this.exchangeTimer);
    rooms.delete(this.id);
  }
}
