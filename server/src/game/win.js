// 胡牌判定 + 听牌计算
// 川麻血战到底：必须缺一门（手牌 + 副露中至少一门完全不存在）
// 胡牌形态：4 副刻/顺 + 1 对将；或 七对（含龙七对）

import { tileSuit, tileCount } from './tiles.js';

// counts: 长度 27 的数组，手牌数量（不含副露）
// meldsCount: 已副露的组数（碰/杠各算 1 组）
// 返回能否分解为 (4 - meldsCount) 组顺/刻 + 1 对将
export function canFormWin(counts, meldsCount = 0) {
  const need = 4 - meldsCount;
  return tryDecompose([...counts], need) !== null;
}

// 递归分解；找到一种分解时返回面子列表（便于展示牌型）
export function tryDecompose(counts, setsNeeded) {
  // 先找对子
  for (let t = 0; t < tileCount; t++) {
    if (counts[t] >= 2) {
      counts[t] -= 2;
      const sets = extractSets(counts, setsNeeded);
      counts[t] += 2;
      if (sets !== null) return [{ type: 'pair', tile: t }, ...sets];
    }
  }
  return null;
}

// 从 counts 中取出 setsNeeded 组顺子/刻子
function extractSets(counts, remaining) {
  if (remaining === 0) {
    return counts.every((c) => c === 0) ? [] : null;
  }
  const first = counts.findIndex((c) => c > 0);
  if (first === -1) return null; // 还有组没凑但没牌了

  // 刻子
  if (counts[first] >= 3) {
    counts[first] -= 3;
    const rest = extractSets(counts, remaining - 1);
    counts[first] += 3;
    if (rest !== null) return [{ type: 'ke', tile: first }, ...rest];
  }
  // 顺子（只在同门内，且 rank ≤ 7）
  const suit = tileSuit(first);
  const rank = first % 9;
  if (rank <= 6 && counts[first + 1] > 0 && counts[first + 2] > 0) {
    counts[first]--; counts[first + 1]--; counts[first + 2]--;
    const rest = extractSets(counts, remaining - 1);
    counts[first]++; counts[first + 1]++; counts[first + 2]++;
    if (rest !== null) return [{ type: 'shun', tile: first }, ...rest];
  }
  return null;
}

// 七对：手牌 14 张全为对子（无副露），4 张算两对（龙七对）
export function isQiDui(counts) {
  let pairs = 0;
  for (let t = 0; t < tileCount; t++) {
    const c = counts[t];
    if (c === 0) continue;
    if (c === 2) { pairs++; continue; }
    if (c === 4) { pairs += 2; continue; }
    return false; // 1 张或 3 张都不行
  }
  return pairs === 7;
}

// 统一胡牌入口：标准牌型 或 七对（七对不允许有副露）
export function isWin(counts, meldsCount = 0) {
  if (meldsCount === 0 && isQiDui(counts)) return true;
  return canFormWin(counts, meldsCount);
}

// 听牌：打出/缺哪张后能胡。返回所有可胡的牌 index 数组
export function tingTiles(counts, meldsCount, mustVoidSuit) {
  const result = [];
  for (let t = 0; t < tileCount; t++) {
    if (counts[t] >= 4) continue; // 不可能有第 5 张
    if (mustVoidSuit !== null && tileSuit(t) === mustVoidSuit) continue;
    counts[t]++;
    const win = isWin(counts, meldsCount);
    counts[t]--;
    if (win) result.push(t);
  }
  return result;
}

// 检查是否缺一门（手牌+副露的牌型集合）
// suitMask: bit0=有万 bit1=有条 bit2=有筒
export function voidSuits(concealedCounts, meldTiles = []) {
  const suitsPresent = new Set();
  for (let t = 0; t < tileCount; t++) {
    if (concealedCounts[t] > 0) suitsPresent.add(tileSuit(t));
  }
  for (const t of meldTiles) suitsPresent.add(tileSuit(t));
  const missing = [];
  for (let s = 0; s < 3; s++) {
    if (!suitsPresent.has(s)) missing.push(s);
  }
  return missing; // 空数组 = 未定缺完成（三门都有）
}
