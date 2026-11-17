// 牌桌状态机剧本测试：固定牌墙，验证完整对局流程
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseHand, buildWall, tileIndex } from '../src/game/tiles.js';
import { tingTiles } from '../src/game/win.js';
import { scoreHand } from '../src/game/scoring.js';
import { Table } from '../src/game/table.js';

function counts(hand) {
  const c = new Array(27).fill(0);
  for (const t of hand) c[t]++;
  return c;
}

const wan = (r) => tileIndex(0, r);
const tiao = (r) => tileIndex(1, r);
const tong = (r) => tileIndex(2, r);

// 用 4 手固定牌构造牌墙：前 53 张按发牌顺序，其余用剩余牌补满
function makeWall(hands) {
  const wall = hands.flat();
  const used = new Array(27).fill(0);
  for (const t of wall) used[t]++;
  const filler = buildWall().filter((t) => {
    if (used[t] > 0) { used[t]--; return false; }
    return true;
  });
  return [...wall, ...filler];
}

function newTable(wall) {
  const t = new Table(['东', '南', '西', '北'], Math.random, wall, { enableExchange: false });
  t.deal();
  return t;
}

test('定缺后未打缺时只能打缺门的牌', () => {
  // P0 手牌含 3万 与大量条筒，定缺万后必须先打 3万
  const t = newTable(makeWall([
    parseHand('3万4条5条6条7条8条9条1筒2筒3筒5条6条7条8条'),
    parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
    parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
    parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
  ]));
  for (let s = 0; s < 4; s++) t.dingque(s, 0); // 全部定缺万
  assert.equal(t.state, 'playing');
  assert.equal(t.canDiscard(0, tiao(4)), false, '未打缺不能出条子');
  assert.equal(t.canDiscard(0, wan(3)), true, '缺门的牌可以先出');
});

test('碰 → 打缺 → 点炮胡 → 血战继续', () => {
  const t = newTable(makeWall([
    parseHand('3万4条5条6条7条8条9条1筒2筒3筒5条6条7条8条'), // P0 庄家 14 张
    parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),     // P1 等 3万 碰
    parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),     // P2 定缺条，第一张出 7条
    parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),     // P3 定缺筒，听 7条
  ]));
  t.dingque(0, 0); // P0 定缺万
  t.dingque(1, 2); // P1 定缺筒（碰不受缺门限制）
  t.dingque(2, 1); // P2 定缺条（手里只有一张 7条）
  t.dingque(3, 2); // P3 定缺筒

  // P0 打 3万，P1 碰
  assert.equal(t.canDiscard(0, wan(3)), true);
  t.discard(0, wan(3));
  t.claim(1, 'peng');
  assert.equal(t.players[1].melds[0].type, 'peng');
  assert.equal(t.players[1].melds[0].tiles[0], wan(3));
  assert.equal(t.turn, 1, '碰后轮到碰家出牌');

  // P1 打缺（6筒是唯一缺门牌）
  assert.equal(t.canDiscard(1, tiao(4)), false);
  assert.equal(t.canDiscard(1, tong(6)), true);
  t.discard(1, tong(6));

  // P2 摸牌后打缺门 7条
  assert.equal(t.turn, 2);
  assert.equal(t.canDiscard(2, tiao(7)), true, 'P2 未打缺，只能出缺门的 7条');
  t.discard(2, tiao(7));

  // P3 点炮胡 7条（点炮平胡 0 番 1 分，自摸才有加成）
  t.claim(3, 'hu');
  assert.equal(t.players[3].hu.winType, 'dianpao');
  assert.equal(t.players[3].hu.base, 1);
  assert.equal(t.players[3].pay, 1, '胡家收 1 分');
  assert.equal(t.players[2].pay, -1, '炮家付 1 分');
  assert.equal(t.state, 'playing', '血战到底：有人胡了继续打');
  assert.equal(t.turn, 0, '继续轮到下一个未胡家');
  assert.equal(t.players[3].hand.length, 14, '胡家手牌定格');
});

test('未打缺时即使牌型成胡也不允许胡', () => {
  // P0 这手牌本身成胡，但定缺万且手里还有 9万 → 未打缺，不允许自摸
  const t = newTable(makeWall([
    parseHand('9万5条6条7条8条9条9条9条1筒2筒3筒4筒5筒6筒'),
    parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
    parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
    parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
  ]));
  t.dingque(0, 0);
  t.dingque(1, 2);
  t.dingque(2, 0);
  t.dingque(3, 2);
  assert.equal(t.voided(0), false);
  assert.equal(t.players[0].canSelfDraw ?? null, null, '未打缺不得自摸');
  // 打出唯一的 9万 后即完成打缺
  t.discard(0, wan(9));
  assert.equal(t.voided(0), true);
});

test('查花猪：三门俱全未听赔 16×家数', () => {
  const t = newTable(makeWall([
    parseHand('1万9万1条9条1筒9筒2万8万2条8条2筒8筒3万'), // P0 庄：三门俱全未听 → 花猪
    parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // P1 听（缺筒）
    parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'), // P2：三门俱全 → 也是花猪
    parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // P3 听（缺筒）
  ]));
  t.dingque(0, 0); t.dingque(1, 2); t.dingque(2, 0); t.dingque(3, 2);
  t.settleDraw();
  assert.equal(t.players[0].isHuaZhu, true);
  assert.equal(t.players[2].isHuaZhu, true);
  assert.equal(t.players[1].isTing, true);
  assert.equal(t.players[3].isTing, true);
  // P0/P2 花猪各赔其他三家 16：各自 -48，但从对方花猪收 16
  assert.equal(t.players[0].pay, -48 + 16, 'P0 花猪付 48、从 P2 花猪收 16');
  assert.equal(t.players[2].pay, -48 + 16, 'P2 花猪付 48、从 P0 花猪收 16');
  assert.equal(t.players[1].pay, 16 + 16, '听牌者从两个花猪各收 16');
  assert.equal(t.players[3].pay, 16 + 16);
  assert.equal(t.players.reduce((a, p) => a + p.pay, 0), 0, '零和守恒');
});

test('查大叫：未听者按听牌者最大自摸分赔', () => {
  const t = newTable(makeWall([
    // P0 庄家 14 张：二门俱全未听（不花猪），牌全孤立必未听
    parseHand('1万4万7万2万5万8万1条4条7条2条5条8条3万3万'),
    parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // P1 听（龙七对最大 16）
    parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'), // P2 三门俱全 → 花猪
    parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // P3 听（龙七对最大 16）
  ]));
  t.dingque(0, 0); t.dingque(1, 2); t.dingque(2, 0); t.dingque(3, 2);
  t.settleDraw();
  assert.equal(t.players[0].isTing, false, 'P0 应未听');
  assert.equal(t.players[0].isHuaZhu, false, 'P0 只有万条两门，不花猪');
  assert.equal(t.players[2].isHuaZhu, true, 'P2 三门俱全 → 花猪');
  assert.equal(t.players[1].isTing, true);
  assert.equal(t.players[3].isTing, true);
  // 每个听牌者的最大自摸分（引擎同口径计算）
  const expected = t.players
    .slice(1)
    .filter((p) => p.isTing)
    .map((p) => {
      const cc = counts(p.hand);
      let best = 0;
      for (const tile of tingTiles(cc, p.melds.length, p.dingque)) {
        const cc2 = [...cc];
        cc2[tile]++;
        best = Math.max(
          best,
          scoreHand(cc2, p.melds, tile, { winType: 'zimo', isFirstRound: false })
            .base,
        );
      }
      return best;
    });
  assert.equal(expected.length, 2);
  for (const b of expected) {
    assert.ok(b >= 2, `听牌最大自摸分应 ≥2，实际 ${b}`);
  }
  // P2 花猪赔 P0/P1/P3 各 16；P0 查叫赔 P1/P3 各 16（P2 花猪不再叠加查叫）
  assert.equal(t.players[0].pay, 16 - 16 - 16, 'P0 从 P2 花猪收 16、查叫赔 P1/P3 各 16');
  assert.equal(t.players[1].pay, 16 + 16, 'P1 从 P2 花猪收 16、从 P0 查叫收 16');
  assert.equal(t.players[2].pay, -16 * 3, 'P2 花猪赔其他三家各 16');
  assert.equal(t.players[3].pay, 16 + 16, 'P3 从 P2 花猪收 16、从 P0 查叫收 16');
  assert.equal(t.players.reduce((a, p) => a + p.pay, 0), 0, '零和守恒');
});

test('刮风下雨：暗杠收 2×3 分', () => {
  const t = newTable(makeWall([
    parseHand('9万9万9万9万4条5条6条7条8条9条1筒2筒3筒4筒'),
    parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
    parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
    parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
  ]));
  t.dingque(0, 0); t.dingque(1, 2); t.dingque(2, 1); t.dingque(3, 2);
  t.gang(0, wan(9), 'angang');
  assert.equal(t.players[0].pay, 6, '杠家收 3 家各 2 分');
  assert.equal(t.players[1].pay, -2);
  assert.equal(t.players[2].pay, -2);
  assert.equal(t.players[3].pay, -2);
  assert.equal(t.players[0].melds[0].type, 'angang');
});
