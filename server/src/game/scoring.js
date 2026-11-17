// 番数计分（成都血战到底常见规则，番型可后续调整）
//
// 基础分 1，总番数 = 2^(各番型之和)
//   对对胡 +1      （全部为刻子/杠 + 将）
//   清一色 +2      （只有一门）
//   七对   +2      （龙七对自动含 1 根）
//   金钩钓 +1      （副露 4 组，手牌只剩 1 张单钓）
//   根     每根 +1 （同一种牌凑齐 4 张，含杠）
//   杠上花 +1      （杠后摸牌自摸）
//   抢杠   +1      （别人补杠时胡）
//   天胡   +6      地胡 +6（首巡，较少见，先占位）
//
// 付费：自摸 → 其余未胡家各付；点炮 → 炮家独付
// 血战：胡牌后其他家继续打，直到 3 家胡或流局

import { tileSuit } from './tiles.js';

export const FAN_RULES = {
  duiduihu: 1,    // 对对胡
  qingyise: 2,    // 清一色
  qidui: 2,       // 七对
  jingoudiao: 1,  // 金钩钓
  gen: 1,         // 每根
  gangshanghua: 1,// 杠上花
  gangshangpao: 1,// 杠上炮（杠后打牌点炮，点炮分加一翻）
  qianggang: 1,   // 抢杠
  tianhu: 6,      // 天胡
  dihu: 6,        // 地胡
};

// 根：任一牌种凑满 4 张（手牌 + 副露合并计）
export function countGens(concealedCounts, melds) {
  const total = [...concealedCounts];
  for (const m of melds) {
    // m.tiles: 组成该副露的 3-4 张牌
    for (const t of m.tiles) total[t]++;
  }
  let gens = 0;
  for (const c of total) {
    if (c === 4) gens++;
  }
  return gens;
}

// 判定对对胡：手牌全为刻子/将（副露必为碰/杠），无顺子
// 注意：4 张同牌在手牌中无法分解为刻+将（需 5 张），视为非对对胡
export function isDuiDuiHu(counts, meldsCount) {
  const need = 4 - meldsCount;
  let pairs = 0;
  let ke = 0;
  for (let t = 0; t < 27; t++) {
    const c = counts[t];
    if (c === 0) continue;
    if (c === 2) pairs++;
    else if (c === 3) ke++;
    else return false; // 1 张（必有顺子）或 4 张（无法分解）都不行
  }
  return pairs === 1 && ke === need;
}

// 判定清一色：所有牌同一门
export function isQingYiSe(concealedCounts, melds) {
  let suit = -1;
  for (let t = 0; t < 27; t++) {
    if (concealedCounts[t] > 0) {
      const s = tileSuit(t);
      if (suit === -1) suit = s;
      else if (suit !== s) return false;
    }
  }
  for (const m of melds) {
    const s = tileSuit(m.tiles[0]);
    if (suit === -1) suit = s;
    else if (suit !== s) return false;
  }
  return true;
}

/**
 * 计算番数与得分
 * @param {number[]} concealedCounts 手牌（胡牌时含胡的那张）
 * @param {Array} melds 副露 [{type:'peng'|'minggang'|'angang', tiles:[...]}]
 * @param {number} winTile 胡的那张牌
 * @param {object} ctx { winType: 'zimo'|'dianpao'|'qianggang'|'gangshanghua',
 *                        isFirstRound: bool, dealerIsWinner: bool }
 * @returns {{ fans: {name,fan}[], totalFan, base, score }}
 */
export function scoreHand(concealedCounts, melds, winTile, ctx) {
  const meldsCount = melds.length;
  const fans = [];

  // 七对（无副露）
  const qidui = meldsCount === 0 && isQiDuiPure(concealedCounts);
  if (qidui) fans.push({ name: '七对', fan: FAN_RULES.qidui });
  else if (isDuiDuiHu(concealedCounts, meldsCount)) fans.push({ name: '对对胡', fan: FAN_RULES.duiduihu });

  if (isQingYiSe(concealedCounts, melds)) fans.push({ name: '清一色', fan: FAN_RULES.qingyise });

  // 金钩钓：4 组副露 + 手牌单钓 1 张
  if (meldsCount === 4 && concealedCounts.reduce((a, b) => a + b, 0) === 2) {
    fans.push({ name: '金钩钓', fan: FAN_RULES.jingoudiao });
  }

  // 根
  const gens = countGens(concealedCounts, melds);
  if (gens > 0) fans.push({ name: `根×${gens}`, fan: FAN_RULES.gen * gens });

  // 胡法番（自摸加一翻：自摸/杠上花都算自摸）
  if (ctx.winType === 'zimo' || ctx.winType === 'gangshanghua') {
    fans.push({ name: '自摸', fan: 1 });
  }
  if (ctx.winType === 'gangshanghua') fans.push({ name: '杠上花', fan: FAN_RULES.gangshanghua });
  if (ctx.winType === 'gangshangpao') fans.push({ name: '杠上炮', fan: FAN_RULES.gangshangpao });
  if (ctx.winType === 'qianggang') fans.push({ name: '抢杠胡', fan: FAN_RULES.qianggang });
  if (ctx.winType === 'zimo' && ctx.isFirstRound) fans.push({ name: '天胡', fan: FAN_RULES.tianhu });
  if (ctx.winType === 'dianpao' && ctx.isFirstRound) fans.push({ name: '地胡', fan: FAN_RULES.dihu });

  const totalFan = fans.reduce((a, f) => a + f.fan, 0);
  // 自摸加翻、四番封顶（成都血战常见规则）
  const FAN_CAP = 4;
  const capped = totalFan > FAN_CAP;
  const effectiveFan = Math.min(totalFan, FAN_CAP);
  const base = Math.pow(2, effectiveFan);
  if (capped) fans.push({ name: `封顶(${totalFan}番)`, fan: 0 });
  return { fans, totalFan, effectiveFan, capped, base, winTile };
}

// 纯七对判定（不含龙七对也在内的手牌对数检查）
function isQiDuiPure(counts) {
  let pairs = 0;
  for (let t = 0; t < 27; t++) {
    const c = counts[t];
    if (c === 0) continue;
    if (c === 2) { pairs++; continue; }
    if (c === 4) { pairs += 2; continue; }
    return false;
  }
  return pairs === 7;
}
