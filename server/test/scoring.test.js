// 番数计分单元测试
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseHand, tileIndex } from '../src/game/tiles.js';
import { scoreHand, countGens, isDuiDuiHu, isQingYiSe } from '../src/game/scoring.js';

function counts(hand) {
  const c = new Array(27).fill(0);
  for (const t of hand) c[t]++;
  return c;
}
const wan = (r) => tileIndex(0, r);
const tiao = (r) => tileIndex(1, r);
const tong = (r) => tileIndex(2, r);

test('平胡自摸：只有自摸 1 番，2 分', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万1条2条3条4条4条'));
  const r = scoreHand(c, [], wan(4), { winType: 'zimo' });
  assert.ok(r.fans.some((f) => f.name === '自摸'));
  assert.equal(r.totalFan, 1);
  assert.equal(r.base, 2);
});

test('对对胡自摸：对对1+自摸1 = 2 番 4 分', () => {
  // 手牌 3 刻 + 将，副露碰 5条；无根
  const c = counts(parseHand('1万1万1万2万2万2万3万3万3万4条4条'));
  const r = scoreHand(c, [{ type: 'peng', tiles: [tiao(5), tiao(5), tiao(5)] }], wan(2), { winType: 'zimo' });
  assert.equal(r.totalFan, 2);
  assert.equal(r.base, 4);
});

test('清一色自摸：3 番 8 分', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万1万2万3万5万5万'));
  assert.equal(isQingYiSe(c, []), true);
  const r = scoreHand(c, [], wan(5), { winType: 'zimo' });
  assert.equal(r.totalFan, 3);
  assert.equal(r.base, 8);
});

test('七对自摸：3 番 8 分', () => {
  const c = counts(parseHand('1万1万2万2万3万3万4条4条5条5条6筒6筒9筒9筒'));
  const r = scoreHand(c, [], tong(9), { winType: 'zimo' });
  assert.ok(r.fans.some((f) => f.name === '七对'));
  assert.equal(r.totalFan, 3);
  assert.equal(r.base, 8);
});

test('龙七对自摸：七对2+自摸1+根1 = 4 番，16 分', () => {
  const c = counts(parseHand('1万1万1万1万3万3万4条4条5条5条6筒6筒9筒9筒'));
  const r = scoreHand(c, [], wan(1), { winType: 'zimo' });
  assert.ok(r.fans.some((f) => f.name === '七对'));
  assert.ok(r.fans.some((f) => f.name === '根×1'));
  assert.equal(r.totalFan, 4);
  assert.equal(r.base, 16);
});

test('杠上炮：点炮加一翻，2 分', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万1条2条3条4条4条'));
  const r = scoreHand(c, [], wan(4), { winType: 'gangshangpao' });
  assert.equal(r.totalFan, 1);
  assert.equal(r.base, 2);
});

test('杠上花自摸：2 番 4 分', () => {
  const c = counts(parseHand('1万2万3万4万5万6万7万8万9万1条2条3条4条4条'));
  const r = scoreHand(c, [], wan(4), { winType: 'gangshanghua' });
  assert.equal(r.totalFan, 2); // 杠上花1 + 自摸1
  assert.equal(r.base, 4);
});

test('四番封顶：超过 4 番按 4 番计', () => {
  const c = counts(parseHand('1万1万1万2万2万2万3万3万3万4万4万'));
  const melds = [{ type: 'angang', tiles: [wan(5), wan(5), wan(5), wan(5)] }];
  const r = scoreHand(c, melds, wan(2), { winType: 'zimo' });
  // 对对1+清一色2+根1+自摸1 = 5番 → 封顶 4
  assert.equal(r.totalFan, 5);
  assert.equal(r.capped, true);
  assert.equal(r.base, 16);
});

test('清一色对对胡带根自摸：4+1=5 番 → 封顶 16 分', () => {
  // 手牌 3 刻 + 将（11 张），副露暗杠 5万（4 张）→ 1 根
  const c = counts(parseHand('1万1万1万2万2万2万3万3万3万4万4万'));
  const melds = [{ type: 'angang', tiles: [wan(5), wan(5), wan(5), wan(5)] }];
  const r = scoreHand(c, melds, wan(2), { winType: 'zimo' });
  assert.ok(isQingYiSe(c, melds));
  assert.equal(r.totalFan, 5); // 对对1 + 清一色2 + 根1 + 自摸1
  assert.equal(r.capped, true);
  assert.equal(r.base, 16);
});

test('countGens：副露杠也计入根', () => {
  const c = counts(parseHand('1万2万3万5万5万'));
  const melds = [
    { type: 'minggang', tiles: [tiao(8), tiao(8), tiao(8), tiao(8)] },
    { type: 'peng', tiles: [tong(3), tong(3), tong(3)] },
    { type: 'peng', tiles: [tong(7), tong(7), tong(7)] },
  ];
  assert.equal(countGens(c, melds), 1);
});
