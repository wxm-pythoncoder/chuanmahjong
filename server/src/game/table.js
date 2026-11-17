// 血战到底牌桌状态机
// 流程：发牌(庄家14张) → 定缺 → 打牌循环 → 血战(胡一家继续) → 3家胡或流局
// 规则要点：
//  - 无吃，只有 碰/明杠/暗杠/补杠
//  - 定缺后必须先打缺门的牌
//  - 胡 > 碰/杠 的优先级
//  - 流局查大叫：未听牌者赔已听牌者
//  - 自摸：其余未胡家各付；点炮：炮家独付

import { buildWall, shuffle, tileSuit, tileName } from './tiles.js';
import { isWin, tingTiles, voidSuits } from './win.js';
import { scoreHand, FAN_RULES } from './scoring.js';

export const HUAN = 'huan';           // 换三张阶段
export const DINGQUE = 'dingque';   // 定缺阶段
export const PLAYING = 'playing';   // 对局中
export const OVER = 'over';         // 结束

export class Table {
  /**
   * @param {Array<string>} names 4 个玩家名
   * @param {Function} rng 随机源
   * @param {number[]} forcedWall 测试用固定牌墙（可选）
   */
  constructor(names, rng = Math.random, forcedWall = null, opts = {}) {
    if (names.length !== 4) throw new Error('需要 4 名玩家');
    this.players = names.map((name, seat) => ({
      seat, name,
      hand: [],            // 手牌 index 数组
      melds: [],           // [{type:'peng'|'minggang'|'angang'|'bugang', tiles:[], from}]
      discards: [],        // 打出的牌
      dingque: null,       // 定缺的门
      hu: null,            // 胡牌信息 {winType, tile, score} 或 null
      isDealer: false,
      passedHuTiles: [],   // 过手：过胡/过自摸的同种牌
      pay: 0,              // 本局累计收支（含刮风下雨）
    }));
    this.rng = rng;
    this.wall = forcedWall ?? shuffle(buildWall(), rng);
    this.enableExchange = opts.enableExchange ?? true;
    this.exchangeMode = opts.exchangeMode ?? 0; // 0下家 1上家 2对家
    this.wallStartSide = Math.min(3, Math.max(0, opts.wallStartSide ?? 0)); // 起牌墙位
    this.exchangePicks = new Map();
    this.state = this.enableExchange ? HUAN : DINGQUE;
    this.turn = 0;              // 当前行动玩家
    this.phase = 'idle';        // idle | draw | discard | claim(等回应)
    this.lastDiscard = null;    // {seat, tile}
    this.claims = {};           // 座位→动作，收集中的回应
    this.pendingClaim = null;   // {tile, from, options:Map<seat, action>}
    this.firstRound = true;     // 首巡（天胡/地胡用）
    this.round = 0;
    this.events = [];
    this.dealer = 0;
  }

  log(type, data) {
    this.events.push({ type, ...data });
  }

  deal() {
    // 庄家 14 张，其余 13 张
    let idx = 0;
    for (const p of this.players) {
      const n = p.seat === this.dealer ? 14 : 13;
      p.hand = this.wall.slice(idx, idx + n);
      idx += n;
      p.hand.sort((a, b) => a - b);
    }
    this.wall = this.wall.slice(idx);
    this.turn = this.dealer;
    this.players[this.dealer].isDealer = true;
    this.state = this.enableExchange ? HUAN : DINGQUE;
    this.phase = this.enableExchange ? 'exchange' : 'idle';
    this.log('deal', { dealer: this.dealer });
  }

  /** 换三张方向提示 */
  exchangeDirectionLabel() {
    return ['下家', '上家', '对家'][this.exchangeMode];
  }

  /** 提交换三张：3 张同门；四家齐了统一交换，然后进入定缺 */
  exchange(seat, tiles) {
    if (this.state !== HUAN) throw new Error('不是换三张阶段');
    if (!Array.isArray(tiles) || tiles.length !== 3) throw new Error('必须选 3 张');
    const suit = tileSuit(tiles[0]);
    for (const t of tiles) {
      if (tileSuit(t) !== suit) throw new Error('三张必须同门');
      if (t < 0 || t > 26) throw new Error('非法牌');
    }
    const hand = this.players[seat].hand;
    const remaining = [...hand];
    for (const t of tiles) {
      const idx = remaining.indexOf(t);
      if (idx === -1) throw new Error(`手牌里没有 ${tileName(t)}`);
      remaining.splice(idx, 1);
    }
    this.exchangePicks.set(seat, [...tiles]);
    this.log('exchange_pick', { seat, count: 3 });

    if (this.exchangePicks.size === 4) {
      const offset = [1, 3, 2][this.exchangeMode];
      for (let i = 0; i < 4; i++) {
        for (const t of this.exchangePicks.get(i)) {
          const p = this.players[i];
          const at = p.hand.indexOf(t);
          p.hand.splice(at, 1);
        }
      }
      for (let i = 0; i < 4; i++) {
        this.players[(i + offset) % 4].hand.push(...this.exchangePicks.get(i));
        this.players[(i + offset) % 4].hand.sort((a, b) => a - b);
      }
      this.exchangeMode = (this.exchangeMode + 1) % 3;
      this.state = DINGQUE;
      this.phase = 'idle';
      this.log('exchange', { done: true });
    }
  }

  countsOf(seat) {
    const c = new Array(27).fill(0);
    for (const t of this.players[seat].hand) c[t]++;
    return c;
  }

  meldTilesOf(seat) {
    return this.players[seat].melds.flatMap((m) => m.tiles);
  }

  // 是否已打缺（手牌中不再有缺门的牌）
  voided(seat) {
    const q = this.players[seat].dingque;
    if (q === null) return false;
    return !this.players[seat].hand.some((t) => tileSuit(t) === q);
  }

  /** 每个玩家提交定缺（0万 1条 2筒）；全部提交后进入打牌阶段 */
  dingque(seat, suit) {
    if (this.state !== DINGQUE) throw new Error('当前不是定缺阶段');
    if (suit < 0 || suit > 2) throw new Error('定缺非法');
    this.players[seat].dingque = suit;
    this.log('dingque', { seat, suit });
    if (this.players.every((p) => p.dingque !== null)) {
      this.state = PLAYING;
      this.phase = 'draw';
      // 庄家已有 14 张，直接视为已摸牌
      this.phase = 'discard';
      this.log('start', { turn: this.turn });
    }
  }

  canDiscard(seat, tile) {
    const p = this.players[seat];
    if (this.state !== PLAYING || this.phase !== 'discard' || this.turn !== seat) return false;
    if (p.hu) return false;
    if (!p.hand.includes(tile)) return false;
    // 未打缺前只能打缺门
    const q = p.dingque;
    if (q !== null && !this.voided(seat)) {
      return tileSuit(tile) === q;
    }
    return true;
  }

  /** 出牌；出牌后进入 claim 阶段等其他家回应 */
  discard(seat, tile) {
    if (!this.canDiscard(seat, tile)) throw new Error(`不能出这张牌 seat=${seat} tile=${tile}`);
    const p = this.players[seat];
    p.hand.splice(p.hand.indexOf(tile), 1);
    p.discards.push(tile);
    p.passedHuTiles.length = 0; // 自己出牌后过手限制解除
    this.lastDiscard = { seat, tile };
    // 杠上炮标记：刚杠完摸牌的人打出的这张
    this.discardAfterGang = this.gangDiscarder === seat;
    this.gangDiscarder = null;
    this.firstRound = false; // 有人出牌即过首巡
    this.log('discard', { seat, tile });

    // 收集其他家的可执行动作
    const options = new Map();
    for (let s = 0; s < 4; s++) {
      if (s === seat || this.players[s].hu) continue;
      const acts = this.availableClaimActions(s, tile);
      if (acts.length) options.set(s, acts);
    }
    if (options.size === 0) {
      this.nextTurn((seat + 1) % 4);
      return { claimable: false };
    }
    this.pendingClaim = { tile, from: seat, options };
    this.claims = {};
    this.phase = 'claim';
    return { claimable: true };
  }

  availableClaimActions(seat, tile) {
    const acts = [];
    const c = this.countsOf(seat);
    const p = this.players[seat];
    // 胡（点炮）：必须已打缺，且牌型成胡
    // 过手规则：被自己过掉的同种牌，出牌前不能再胡
    if (this.voided(seat) && !p.passedHuTiles.includes(tile)) {
      const hand = [...p.hand, tile];
      const cc = new Array(27).fill(0);
      for (const t of hand) cc[t]++;
      if (isWin(cc, p.melds.length)) {
        acts.push('hu');
      }
    }
    // 碰
    if (c[tile] >= 2) acts.push('peng');
    // 明杠
    if (c[tile] === 3) acts.push('minggang');
    return acts;
  }

  /** 玩家回应碰/杠/胡；pass 则跳过 */
  claim(seat, action) {
    if (this.phase !== 'claim') throw new Error('当前没有待回应的牌');
    if (!this.pendingClaim.options.has(seat)) {
      if (action === 'pass') return this.evaluateClaims();
      throw new Error(`座位 ${seat} 无权对该牌行动`);
    }
    // 过手：有胡却选择过 → 该牌在自己出牌前不能再胡
    if (action === 'pass' && this.pendingClaim.options.get(seat).includes('hu')) {
      this.players[seat].passedHuTiles.push(this.pendingClaim.tile);
    }
    this.claims[seat] = action;
    return this.evaluateClaims();
  }

  // 按 胡 > 碰/杠 优先结算
  evaluateClaims() {
    if (!this.pendingClaim) return;
    const { tile, from } = this.pendingClaim;
    const claimants = Object.entries(this.claims).filter(([s, a]) => a !== 'pass');
    const hus = claimants.filter(([s, a]) => a === 'hu');
    if (hus.length > 0) {
      for (const [s] of hus) this.doDianpaoHu(Number(s), from, tile);
      this.pendingClaim = null;
      this.phase = 'draw';
      this.firstRound = false;
      this.continueBloodbattle(from);
      return;
    }    const pengs = claimants.filter(([s, a]) => a === 'peng' || a === 'minggang');
    if (pengs.length > 0) {
      const [s, a] = pengs[0];
      this.pendingClaim = null;
      this.phase = 'draw';
      if (a === 'peng') this.doPeng(Number(s), from, tile);
      else this.doMingGang(Number(s), from, tile);
      return;
    }
    // 全部过：正常出牌 → 下家摸牌；补杠被抢杠窗口 → 完成补杠
    const from2 = this.pendingClaim.from;
    const bugangSeat = this.pendingBugang;
    this.pendingClaim = null;
    this.phase = 'draw';
    if (bugangSeat !== undefined) {
      this.pendingBugang = undefined;
      this.doBugang(bugangSeat, this.lastBugangTile);
      return;
    }
    this.nextTurn((from2 + 1) % 4);
  }

  /** 找 from 之后下一个未胡的座位 */
  nextActiveSeat(from) {
    for (let i = 1; i <= 4; i++) {
      const s = (from + i) % 4;
      if (!this.players[s].hu) return s;
    }
    return null;
  }

  doPeng(seat, from, tile) {
    const p = this.players[seat];
    p.hand.splice(p.hand.indexOf(tile), 1);
    p.hand.splice(p.hand.indexOf(tile), 1);
    p.melds.push({ type: 'peng', tiles: [tile, tile, tile], from });
    this.turn = seat;
    this.phase = 'discard';
    this.log('peng', { seat, tile, from });
  }

  /** 刮风下雨：杠的即时收费（明杠=刮风，暗杠=下雨） */
  gangPay(seat, type, from) {
    const gang = this.players[seat];
    if (type === 'minggang') {
      // 刮风：点杠者付 2 分
      this.players[from].pay -= 2;
      gang.pay += 2;
      this.log('gang_pay', { seat, type, label: '明杠（刮风）', detail: `${this.players[from].name} 付 2 分`, amount: 2 });
    } else if (type === 'angang') {
      // 下雨：其余未胡家各付 2 分
      for (const o of this.activePlayers()) {
        if (o.seat === seat) continue;
        o.pay -= 2;
        gang.pay += 2;
      }
      this.log('gang_pay', { seat, type, label: '暗杠（下雨）', detail: '其余各家付 2 分', amount: 2 });
    } else {
      // 补杠：其余未胡家各付 1 分
      for (const o of this.activePlayers()) {
        if (o.seat === seat) continue;
        o.pay -= 1;
        gang.pay += 1;
      }
      this.log('gang_pay', { seat, type, label: '补杠', detail: '其余各家付 1 分', amount: 1 });
    }
  }

  doMingGang(seat, from, tile) {
    const p = this.players[seat];
    for (let i = 0; i < 3; i++) p.hand.splice(p.hand.indexOf(tile), 1);
    p.melds.push({ type: 'minggang', tiles: [tile, tile, tile, tile], from });
    this.gangPay(seat, 'minggang', from);
    this.drawFor(seat, { afterGang: true });
    this.log('minggang', { seat, tile, from });
  }

  /** 自己回合内杠（暗杠/补杠） */
  gang(seat, tile, type) {
    const p = this.players[seat];
    if (this.state !== PLAYING || this.turn !== seat || this.phase !== 'discard') {
      throw new Error('当前不能杠');
    }
    const c = this.countsOf(seat);
    if (type === 'angang' && c[tile] !== 4) throw new Error('暗杠需要 4 张');
    if (type === 'bugang') {
      // 补杠：已有碰该牌
      const peng = p.melds.find((m) => m.type === 'peng' && m.tiles[0] === tile);
      if (!peng || c[tile] !== 1) throw new Error('补杠不合法');
      // 检查抢杠：其他家可胡
      const qiang = [];
      for (let s = 0; s < 4; s++) {
        if (s === seat || this.players[s].hu) continue;
        const hand = [...this.players[s].hand, tile];
        const cc = new Array(27).fill(0);
        for (const t of hand) cc[t]++;
        if (isWin(cc, this.players[s].melds.length)) qiang.push(s);
      }
      if (qiang.length) {
        this.pendingClaim = { tile, from: seat, options: new Map(qiang.map((s) => [s, ['hu']])) };
        this.claims = {};
        this.phase = 'claim';
        this.pendingBugang = seat;
        this.lastBugangTile = tile;
        return { qianggangPossible: qiang };
      }
    }
    if (type === 'angang') {
      for (let i = 0; i < 4; i++) p.hand.splice(p.hand.indexOf(tile), 1);
      p.melds.push({ type: 'angang', tiles: [tile, tile, tile, tile], from: seat });
      this.gangPay(seat, 'angang', seat);
      this.drawFor(seat, { afterGang: true });
    } else {
      this.doBugang(seat, tile);
    }
    this.log(type, { seat, tile });
    return { ok: true };
  }

  /** 补杠：碰升级为杠，随后杠后摸牌 */
  doBugang(seat, tile) {
    const p = this.players[seat];
    p.hand.splice(p.hand.indexOf(tile), 1);
    const peng = p.melds.find((m) => m.type === 'peng' && m.tiles[0] === tile);
    peng.type = 'bugang';
    peng.tiles.push(tile);
    this.gangPay(seat, 'bugang', seat);
    this.drawFor(seat, { afterGang: true });
  }

  nextTurn(seat) {
    if (this.players[seat].hu) {
      seat = this.nextActiveSeat(seat);
      if (seat === null) {
        this.settleDraw();
        return;
      }
    }
    if (this.wall.length === 0 || this.activePlayers().length <= 1) {
      this.settleDraw();
      return;
    }
    this.drawFor(seat, {});
  }

  activePlayers() {
    return this.players.filter((p) => !p.hu);
  }

  /** 摸牌并检查自摸；杠后摸牌可杠上花 */
  drawFor(seat, { afterGang }) {
    if (this.wall.length === 0) {
      this.settleDraw();
      return;
    }
    const tile = this.wall.shift();
    const p = this.players[seat];
    p.hand.push(tile);
    this.turn = seat;
    // 杠上炮跟踪：杠后摸牌的人打出即触发
    this.gangDiscarder = afterGang ? seat : null;
    this.lastDraw = { seat, tile, afterGang };
    this.log('draw', { seat, tile: afterGang ? tile : undefined, hidden: !afterGang });

    // 自摸检查（必须已打缺）
    const cc = new Array(27).fill(0);
    for (const t of p.hand) cc[t]++;
    if (this.voided(seat) && !p.passedHuTiles.includes(tile) && isWin(cc, p.melds.length)) {
      p.canSelfDraw = { tile, winType: afterGang ? 'gangshanghua' : 'zimo' };
    } else {
      p.canSelfDraw = null;
    }
    // 杠检查
    const c = this.countsOf(seat);
    p.canGangTiles = [];
    for (let t = 0; t < 27; t++) {
      if (c[t] === 4) p.canGangTiles.push(t); // 暗杠
      else if (c[t] === 1 && p.melds.some((m) => m.type === 'peng' && m.tiles[0] === t)) p.canGangTiles.push(t); // 补杠
    }
    this.phase = 'discard';
  }

  /** 自摸胡 */
  hu(seat) {
    const p = this.players[seat];
    if (!p.canSelfDraw) throw new Error('无自摸');
    this.doZimoHu(seat, p.canSelfDraw.tile, p.canSelfDraw.winType);
  }

  /** 过自摸：放弃本次自摸，继续出牌把牌做大 */
  passSelfDraw(seat) {
    const p = this.players[seat];
    if (!p.canSelfDraw) throw new Error('当前没有可过的自摸');
    const tile = p.canSelfDraw.tile;
    this.log('pass_zimo', { seat, tile });
    p.canSelfDraw = null;
    // 过手规则：被过的这张牌，在自己出牌前不能再胡同种
    p.passedHuTiles.push(tile);
  }

  doZimoHu(seat, tile, winType) {
    const p = this.players[seat];
    const cc = this.countsOf(seat);
    const ctx = { winType, isFirstRound: this.firstRound };
    const result = scoreHand(cc, p.melds, tile, ctx);
    p.hu = { winType, tile, ...result, pays: null };
    this.log('zimo', { seat, tile, fans: result.fans, base: result.base });
    // 自摸：其余未胡家各付 base
    for (const other of this.activePlayers()) {
      if (other.seat === seat) continue;
      other.pay = (other.pay ?? 0) - result.base;
      p.pay = (p.pay ?? 0) + result.base;
    }
    this.afterHu(seat);
  }

  doDianpaoHu(seat, from, tile) {
    const p = this.players[seat];
    p.hand.push(tile);
    const cc = this.countsOf(seat);
    // 杠上炮：点炮者刚杠完摸牌打出 → 点炮加一翻
    const winType = this.discardAfterGang ? 'gangshangpao' : 'dianpao';
    const ctx = { winType, isFirstRound: this.firstRound };
    const result = scoreHand(cc, p.melds, tile, ctx);
    p.hu = { winType, tile, ...result };
    const shooter = this.players[from];
    shooter.pay = (shooter.pay ?? 0) - result.base;
    p.pay = (p.pay ?? 0) + result.base;
    this.log('dianpao', { seat, from, tile, fans: result.fans, base: result.base });
    this.afterHu(seat);
  }

  afterHu(seat) {
    const p = this.players[seat];
    p.canSelfDraw = null;
    this.firstRound = false;
    // 从手上移除胡牌张已在 doDianpaoHu 加入；自摸时保留在手
  }

  /** 血战继续：从 afterSeat 起找下一个未胡家摸牌；只剩 1 家或墙空则结算 */
  continueBloodbattle(afterSeat) {
    const active = this.activePlayers();
    if (active.length === 0 || this.wall.length === 0) {
      this.settleDraw();
      return;
    }
    const next = this.nextActiveSeat(afterSeat);
    if (next === null) {
      this.settleDraw();
      return;
    }
    this.nextTurn(next);
  }

  /** 流局结算（含查大叫） */
  settleDraw() {
    this.state = OVER;
    // 查大叫 + 查花猪：未听牌者向每个已听牌者赔其「最大听牌型自摸分」
    // 花猪（未听且手里三门俱全）大赔：赔给其他每个未胡玩家 16 分
    const HUAZHU_FAN = 16;
    const tings = [];
    const huazhus = [];
    for (const p of this.activePlayers()) {
      const suits = new Set(p.hand.map((t) => tileSuit(t)));
      const cc = this.countsOf(p.seat);
      const ting = suits.size < 3 && tingTiles(cc, p.melds.length, p.dingque);
      p.isHuaZhu = suits.size === 3;
      p.isTing = !p.isHuaZhu && ting.length > 0;
      if (p.isTing) {
        // 以最大的方式算牌：听牌者按最大可胡番的自摸分计赔
        let best = 0;
        for (const tile of ting) {
          const cc2 = [...cc];
          cc2[tile]++;
          const r = scoreHand(cc2, p.melds, tile, {
            winType: 'zimo',
            isFirstRound: false,
          });
          if (r.base > best) best = r.base;
        }
        p.bestTingScore = best;
        tings.push(p);
      } else if (p.isHuaZhu) {
        huazhus.push(p);
      }
    }
    // 花猪先赔：赔给其他每个未胡玩家 16 分
    for (const h of huazhus) {
      for (const o of this.activePlayers()) {
        if (o === h) continue;
        h.pay -= HUAZHU_FAN;
        o.pay += HUAZHU_FAN;
      }
      this.log('huazhu', { seat: h.seat, name: h.name, amount: HUAZHU_FAN });
    }
    // 查大叫：未听（非花猪）→ 赔每个听牌者
    for (const p of this.activePlayers()) {
      if (!p.isTing && !p.isHuaZhu) {
        for (const t of tings) {
          if (t === p) continue;
          p.pay -= t.bestTingScore;
          t.pay += t.bestTingScore;
        }
        if (tings.length > 0) {
          this.log('chadajiao', {
            seat: p.seat,
            count: tings.length,
            amount: tings.reduce((a, t) => a + t.bestTingScore, 0),
          });
        }
      }
    }
    this.log('liuju', {});
  }

  /** 便捷视图（发给客户端的脱敏状态） */
  view(seat) {
    return {
      state: this.state,
      phase: this.phase,
      turn: this.turn,
      wallLeft: this.wall.length,
      lastDiscard: this.lastDiscard,
      canSelfDraw: this.players[seat].canSelfDraw,
      canGangTiles: this.players[seat].canGangTiles,
      exchangeDone: this.exchangePicks.has(seat),
      exchangeMode: this.exchangeMode,
      exchangeDirection: this.exchangeDirectionLabel(),
      wallStartSide: this.wallStartSide,
      players: this.players.map((p) => ({
        seat: p.seat,
        name: p.name,
        dingque: p.dingque,
        melds: p.melds,
        discards: p.discards,
        hu: p.hu ? { winType: p.hu.winType, fans: p.hu.fans, base: p.hu.base } : null,
        handCount: p.hand.length,
        hand: p.seat === seat ? p.hand : undefined,
      })),
    };
  }
}
