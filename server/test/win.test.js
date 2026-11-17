// 胡牌判定单元测试
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseHand, tileIndex } from '../src/game/tiles.js';
import { canFormWin, isWin, isQiDui, tingTiles, voidSuits } from '../src/game/win.js';

function counts(hand) {
  const c = new Array(27).fill(0);
  for (const t of hand) c[t]++;
  return c;
}

test('标准胡牌：清一色顺子', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万1万2万3万5万5万'));
  assert.equal(canFormWin(c, 0), true);
});

test('标准胡牌：刻子+顺子+将（14 张完整手牌）', () => {
  const c = counts(parseHand('1万2万3万3万3万3万4条5条6条7筒8筒9筒2万2万'));
  assert.equal(isWin(c, 0), true);
});

test('非胡牌：差一张的听牌形', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万1万2万3万5万'));
  assert.equal(canFormWin(c, 0), false);
});

test('七对', () => {
  const c = counts(parseHand('1万1万2万2万3万3万4条4条5条5条6筒6筒9筒9筒'));
  assert.equal(isQiDui(c), true);
  assert.equal(isWin(c, 0), true); // isWin 应涵盖七对
  assert.equal(canFormWin(c, 0), false); // canFormWin 只查标准牌型
});

test('非七对：有单张', () => {
  const c = counts(parseHand('1万1万2万2万3万3万4条4条5条5条6筒6筒9筒'));
  assert.equal(isQiDui(c), false);
});

test('龙七对：四张算两对', () => {
  const c = counts(parseHand('1万1万1万1万3万3万4条4条5条5条6筒6筒9筒9筒'));
  assert.equal(isQiDui(c), true);
});

test('有副露时：1 组副露 + 3 组面子 + 将', () => {
  // 胡牌时手牌 11 张 = 3 组面子 + 将；副露 1 组（碰 3万）
  const c = counts(parseHand('4万5万6万7万8万9万1条2条3条1条1条'));
  assert.equal(isWin(c, 1), true);
});

test('听牌计算：单钓将', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万2条3条4条5万'));
  const ting = tingTiles(c, 0, null);
  assert.ok(ting.includes(tileIndex(0, 5))); // 5万 对对碰
});

test('缺一门判定：三门都有 → 未完成缺门', () => {
  const c = counts(parseHand('1万2万3万4条5条6条7筒8筒9筒'));
  assert.deepEqual(voidSuits(c, []), []);
});

test('缺一门判定：缺条筒 → 剩余缺门为 条、筒', () => {
  const c = counts(parseHand('1万2万3万5万6万7万9万9万'));
  assert.deepEqual(voidSuits(c, []).sort(), [1, 2]);
});

test('副露计入缺一门判定', () => {
  const c = counts(parseHand('1万2万3万5万5万'));
  // 碰了 4条：手上有万+条，缺筒
  assert.deepEqual(voidSuits(c, [tileIndex(1, 4)]), [2]);
});
