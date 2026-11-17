// 川麻血战到底 —— 牌定义
// 只有 万/条/筒 三门，各 1-9，每种 4 张，共 108 张

export const SUITS = ['万', '条', '筒'];
export const SUIT_WAN = 0, SUIT_TIAO = 1, SUIT_TONG = 2;

// 牌用 0-26 整数表示：suit * 9 + (rank - 1)
export const tileCount = 27;
export const totalTiles = 108;

export function tileIndex(suit, rank) {
  return suit * 9 + (rank - 1);
}

export function tileSuit(t) {
  return Math.floor(t / 9);
}

export function tileRank(t) {
  return (t % 9) + 1;
}

export function tileName(t) {
  return SUITS[tileSuit(t)] + tileRank(t);
}

export function handNames(tiles) {
  return tiles.map(tileName).sort((a, b) => a.localeCompare(b, 'zh'));
}

// 生成完整牌墙（108 张）
export function buildWall() {
  const wall = [];
  for (let t = 0; t < tileCount; t++) {
    for (let i = 0; i < 4; i++) wall.push(t);
  }
  return wall;
}

// Fisher-Yates 洗牌（默认使用 crypto 级随机数，保证发牌公平）
import { randomInt } from 'node:crypto';
export function shuffle(wall, rng) {
  for (let i = wall.length - 1; i > 0; i--) {
    const j = rng ? Math.floor(rng() * (i + 1)) : randomInt(i + 1);
    [wall[i], wall[j]] = [wall[j], wall[i]];
  }
  return wall;
}

// 把手牌字符串 "1万2万3万 4条5条6条" 转成 index 数组（便于测试）
export function parseHand(s) {
  const out = [];
  for (const suitChar of ['万', '条', '筒']) {
    const suit = SUITS.indexOf(suitChar);
    const re = new RegExp(`(\\d)${suitChar}`, 'g');
    let m;
    while ((m = re.exec(s)) !== null) {
      const n = parseInt(m[1], 10);
      if (n < 1 || n > 9) throw new Error(`非法牌: ${m[0]}`);
      out.push(tileIndex(suit, n));
    }
  }
  const unknown = s.replace(/[\d万条筒\s]/g, '');
  if (unknown) throw new Error(`无法解析: ${unknown}`);
  return out;
}
