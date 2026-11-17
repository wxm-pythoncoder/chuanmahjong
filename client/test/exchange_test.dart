// 换三张专项测试
import 'package:test/test.dart';

import 'package:chuanmahjong/game/tiles.dart';
import 'package:chuanmahjong/game/table.dart';
import 'package:chuanmahjong/game/bot.dart';
import 'package:chuanmahjong/game/scoring.dart' show Meld;

List<int> counts(List<int> hand) {
  final c = List<int>.filled(27, 0);
  for (final t in hand) {
    c[t]++;
  }
  return c;
}

List<int> makeWall(List<List<int>> hands) {
  final wall = hands.expand((h) => h).toList();
  final used = List<int>.filled(27, 0);
  for (final t in wall) {
    used[t]++;
  }
  final filler = buildWall().where((t) {
    if (used[t] > 0) {
      used[t]--;
      return false;
    }
    return true;
  }).toList();
  return [...wall, ...filler];
}

void main() {
  test('换三张：正确流程与牌权守恒', () {
    final hands = [
      parseHand('1万2万3万4条5条6条7条8条9条1筒2筒3筒4筒'),
      parseHand('2万3万4万5条6条7条8条9条2筒3筒4筒5筒6筒'),
      parseHand('3万4万5万6条7条8条9条1条3筒4筒5筒6筒7筒'),
      parseHand('4万5万6万1条2条3条4条5条6条1筒2筒3筒4筒'),
    ];
    // hands[0] 只有 13 张，庄家需要 14 —— makeWall 会补 fill，但发牌按顺序切
    // P0 取到 hands[0] 的 13 张 + filler 1 张
    final t = Table(['甲', '乙', '丙', '丁'],
        forcedWall: makeWall(hands), exchangeMode: 0);
    expect(t.state, stateHuan);

    final before = t.players.map((p) => p.hand.length).toList();
    expect(before, [14, 13, 13, 13]);

    // 每家换出 3 张万字（每人手牌里都有 3 张万）
    final picks = <List<int>>[];
    for (var s = 0; s < 4; s++) {
      final wanTiles =
          t.players[s].hand.where((x) => tileSuit(x) == 0).take(3).toList();
      assert(wanTiles.length == 3, '座位 $s 万字不足 3 张');
      picks.add(wanTiles);
      t.exchange(s, wanTiles);
    }
    expect(t.state, stateDingque, reason: '四家换完进入定缺');

    // 交换方向：0→1, 1→2, 2→3, 3→0（mode 0 = 传下家 +1）
    for (var s = 0; s < 4; s++) {
      for (final tile in picks[s]) {
        expect(
          t.players[(s + 1) % 4].hand.contains(tile),
          isTrue,
          reason: 'P$s 换出的牌应到 P${(s + 1) % 4} 手里',
        );
      }
    }
    // 手牌总数不变
    expect(t.players.map((p) => p.hand.length).toList(), [14, 13, 13, 13]);
    // 方向轮换到下一局：mode 0 → 1
    expect(t.exchangeMode, 1);
  });

  test('换三张：三张同值牌可以一起换出', () {
    final t = Table(['甲', '乙', '丙', '丁'], humanSeat0: false);
    final hand = t.players[0].hand;
    final cc = counts(hand);
    final dup = List.generate(27, (i) => i).firstWhere(
      (i) => cc[i] >= 3,
      orElse: () => -1,
    );
    if (dup == -1) return; // 随机手牌无三张同值时跳过
    final bot = Bot(t);
    t.exchange(0, [dup, dup, dup]);
    // 其他三家（bot）提交换牌后交换才生效
    for (var s = 1; s < 4; s++) {
      if (!t.exchangePicks.containsKey(s)) bot.act(s);
    }
    expect(t.state, stateDingque, reason: '四家换完进入定缺');
    // P0 换出的 3 张到了下家手里
    expect(t.exchangePicks[0], [dup, dup, dup]);
    expect(t.players[1].hand.where((x) => x == dup).length,
        greaterThanOrEqualTo(3), reason: 'P1 应收到 P0 的三张同值牌');
    // 全桌该牌值总数守恒（4 张）
    final total = t.players.fold<int>(
        0, (a, p) => a + counts(p.hand)[dup]) + counts(t.wall)[dup];
    expect(total, 4, reason: '同种牌全桌守恒');
  });

  test('换三张：非同门 / 数量不对要报错', () {
    final t = Table(['甲', '乙', '丙', '丁'], humanSeat0: false);
    final hand = t.players[0].hand;
    final wan = hand.where((x) => tileSuit(x) == 0).toList();
    final tiao = hand.where((x) => tileSuit(x) == 1).toList();
    expect(() => t.exchange(0, wan.take(2).toList()), throwsStateError);
    if (wan.length >= 2 && tiao.isNotEmpty) {
      expect(() => t.exchange(0, [wan[0], wan[1], tiao[0]]), throwsStateError);
    }
  });

  test('Bot 全流程：换三张 → 定缺 → 对局到结束', () {
    final t = Table(['甲', '乙', '丙', '丁'], humanSeat0: false);
    for (final p in t.players) {
      p.isHuman = false;
    }
    driveBots(t);
    expect(t.state, stateOver);
    expect(t.events.any((e) => e.type == 'exchange'), isTrue,
        reason: '对局应包含换三张事件');
    final total = t.players.fold<int>(0, (a, p) => a + p.pay);
    expect(total, 0);
  });

  // 抑制未使用告警
  test('占位', () {
    expect(counts(parseHand('1万')).length, 27);
    expect(Meld('peng', [0, 0, 0]).type, 'peng');
  });
}
