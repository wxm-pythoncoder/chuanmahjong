// 拆分过点炮测试为独立函数（锚点与实际文件一致）
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/test/engine_test.dart';
let s = fs.readFileSync(p, 'utf8');

const startMarker = '  // 过点炮：南风打 7条 → 我可胡但过 → 同种牌不能再点炮胡';
const endMarker = "  expect(acts2, isNot(contains('hu')), reason: '过手：同种牌不能再点炮胡');\n}";
const start = s.indexOf(startMarker);
const end = s.indexOf(endMarker);
if (start === -1 || end === -1) throw new Error('anchor not found');

// _guoShou 只保留过自摸部分（去掉过点炮块）
s = s.slice(0, start) + '}\n' + s.slice(end + endMarker.length);

// 在 _guoShou 结束后插入独立的过点炮测试
const anchor = '}\n\n/// 过自摸基础行为';
if (!s.includes(anchor)) throw new Error('insert anchor not found');
const testFn = `}

/// 过点炮过手：过胡后同种牌不能再胡
void _guoPaoDianHu() {
  final t = Table(['我', '南风', '西风', '北风'],
      enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万2万3万4万5万6万7万8万9万4条5条6条7条'), // 我：缺筒，单钓 7条
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // 南风
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // 西家
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'), // 北家（有 7条）
      ]));
  t.dingque(0, 2);
  t.dingque(1, 2);
  t.dingque(2, 1);
  t.dingque(3, 2);
  // 固定我的手牌：单钓 7条
  t.players[0].hand = parseHand('1万2万3万4万5万6万7万8万9万4条5条6条7条');

  // 我出 7万（无人能碰/胡）→ 南风自动摸牌后出牌
  t.discard(0, tileIndex(0, 7));
  t.discard(1, t.players[1].hand.first);

  // 西家打 7条 → 我可点炮胡
  t.players[2].hand.add(tileIndex(1, 7));
  t.discard(2, tileIndex(1, 7));
  final acts = t.availableClaimActions(0, tileIndex(1, 7));
  expect(acts, contains('hu'), reason: '点炮可胡');
  t.claim(0, 'pass');
  expect(t.players[0].passedHuTiles, contains(tileIndex(1, 7)), reason: '过点炮入过手集');

  // 北家再打 7条 → 过手限制：不能胡
  t.players[3].hand.add(tileIndex(1, 7));
  t.discard(3, tileIndex(1, 7));
  final acts2 = t.availableClaimActions(0, tileIndex(1, 7));
  expect(acts2, isNot(contains('hu')), reason: '过手：同种牌不能再点炮胡');
}
`;
s = s.replace(anchor, testFn);

fs.writeFileSync(p, s);
console.log('拆分完成');
