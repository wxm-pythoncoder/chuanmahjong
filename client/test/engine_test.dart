// Dart 引擎单元测试（与服务器 JS 版测试对应）
import 'package:test/test.dart';

import 'package:chuanmahjong/game/tiles.dart';
import 'package:chuanmahjong/game/win.dart';
import 'package:chuanmahjong/game/scoring.dart';
import 'package:chuanmahjong/game/table.dart';
import 'package:chuanmahjong/game/bot.dart';

List<int> counts(List<int> hand) {
  final c = List<int>.filled(27, 0);
  for (final t in hand) {
    c[t]++;
  }
  return c;
}

/// 用 4 手固定牌构造牌墙
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
  group('胡牌判定', () {
    test('标准胡牌：清一色顺子', () {
      final c = counts(parseHand('1万2万3万4万5万6万7万8万9万1万2万3万5万5万'));
      expect(canFormWin(c, 0), isTrue);
    });

    test('标准胡牌：刻子+顺子+将（14 张）', () {
      final c = counts(parseHand('1万2万3万3万3万3万4条5条6条7筒8筒9筒2万2万'));
      expect(isWin(c, 0), isTrue);
    });

    test('非胡牌：差一张', () {
      final c = counts(parseHand('1万2万3万4万5万6万7万8万9万1万2万3万5万'));
      expect(canFormWin(c, 0), isFalse);
    });

    test('七对 / 龙七对', () {
      final c = counts(parseHand('1万1万2万2万3万3万4条4条5条5条6筒6筒9筒9筒'));
      expect(isQiDui(c), isTrue);
      expect(isWin(c, 0), isTrue);
      expect(canFormWin(c, 0), isFalse);

      final dragon = counts(parseHand('1万1万1万1万3万3万4条4条5条5条6筒6筒9筒9筒'));
      expect(isQiDui(dragon), isTrue);
    });

    test('有副露：1 组 + 3 面子 + 将', () {
      final c = counts(parseHand('4万5万6万7万8万9万1条2条3条1条1条'));
      expect(isWin(c, 1), isTrue);
    });

    test('听牌：单钓将', () {
      final c = counts(parseHand('1万2万3万4万5万6万7万8万9万2条3条4条5万'));
      final ting = tingTiles(c, 0, null);
      expect(ting, contains(tileIndex(0, 5)));
    });

    test('缺一门判定', () {
      final three = counts(parseHand('1万2万3万4条5条6条7筒8筒9筒'));
      expect(voidSuits(three, []), isEmpty);
      final wanOnly = counts(parseHand('1万2万3万5万6万7万9万9万'));
      expect(voidSuits(wanOnly, [])..sort(), [1, 2]);
      final withMeld = counts(parseHand('1万2万3万5万5万'));
      expect(voidSuits(withMeld, [tileIndex(1, 4)]), [2]);
    });
  });

  group('番数计分', () {
    test('平胡自摸：只有自摸 1 番 2 分', () {
      final c = counts(parseHand('1万2万3万4万5万6万7万8万9万1条2条3条4条4条'));
      final r = scoreHand(c, [], tileIndex(0, 4), {'winType': 'zimo'});
      expect(r.fans.any((f) => f.key == '自摸'), isTrue);
      expect(r.totalFan, 1);
      expect(r.base, 2);
    });

    test('对对胡自摸：2 番 4 分', () {
      final c = counts(parseHand('1万1万1万2万2万2万3万3万3万4条4条'));
      final r = scoreHand(c, [Meld('peng', List<int>.filled(3, tileIndex(1, 5)))],
          tileIndex(0, 2), {'winType': 'zimo'});
      expect(r.totalFan, 2);
      expect(r.base, 4);
    });

    test('清一色 4 分', () {
      final c = counts(parseHand('1万2万3万4万5万6万7万8万9万1万2万3万5万5万'));
      final r = scoreHand(c, [], tileIndex(0, 5), {'winType': 'zimo'});
      expect(r.totalFan, 3);
      expect(r.base, 8);
    });

    test('七对 4 分 / 龙七对 8 分', () {
      final c = counts(parseHand('1万1万2万2万3万3万4条4条5条5条6筒6筒9筒9筒'));
      final r = scoreHand(c, [], tileIndex(2, 9), {'winType': 'zimo'});
      expect(r.base, 8);

      final dragon = counts(parseHand('1万1万1万1万3万3万4条4条5条5条6筒6筒9筒9筒'));
      final r2 = scoreHand(dragon, [], tileIndex(0, 1), {'winType': 'zimo'});
      expect(r2.base, 16);
    });

    test('杠上花 2 分', () {
      final c = counts(parseHand('1万2万3万4万5万6万7万8万9万1条2条3条4条4条'));
      final r = scoreHand(c, [], tileIndex(0, 4), {'winType': 'gangshanghua'});
      expect(r.base, 4);
    });
  });

  group('牌桌状态机', () {
    test('定缺后未打缺只能打缺门', () {
      final t = Table(['东', '南', '西', '北'], enableExchange: false,
          forcedWall: makeWall([
            parseHand('3万4条5条6条7条8条9条1筒2筒3筒5条6条7条8条'),
            parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
            parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
            parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
          ]));
      t.dingque(0, 0);
      t.dingque(1, 2);
      t.dingque(2, 1);
      t.dingque(3, 2);
      expect(t.state, statePlaying);
      expect(t.canDiscard(0, tileIndex(1, 4)), isFalse);
      expect(t.canDiscard(0, tileIndex(0, 3)), isTrue);
    });

    test('碰 → 打缺 → 点炮胡 → 血战继续', () {
      final t = Table(['东', '南', '西', '北'], enableExchange: false,
          forcedWall: makeWall([
            parseHand('3万4条5条6条7条8条9条1筒2筒3筒5条6条7条8条'),
            parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
            parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
            parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
          ]));
      t.dingque(0, 0);
      t.dingque(1, 2);
      t.dingque(2, 1);
      t.dingque(3, 2);

      // P0 打 3万，P1 碰
      t.discard(0, tileIndex(0, 3));
      t.claim(1, 'peng');
      expect(t.players[1].melds[0].type, 'peng');
      expect(t.turn, 1);

      // P1 打缺
      t.discard(1, tileIndex(2, 6));

      // P2 打缺门 7条
      expect(t.turn, 2);
      t.discard(2, tileIndex(1, 7));

      // P3 点炮胡（平胡 1 分）
      t.claim(3, 'hu');
      expect(t.players[3].hu!['winType'], 'dianpao');
      expect(t.players[3].hu!['base'], 1);
      expect(t.players[3].pay, 1);
      expect(t.players[2].pay, -1);
      expect(t.state, statePlaying); // 血战继续
      expect(t.turn, 0);
    });

    test('未打缺成胡也不允许自摸', () {
      final t = Table(['东', '南', '西', '北'], enableExchange: false,
          forcedWall: makeWall([
            parseHand('9万5条6条7条8条9条9条9条1筒2筒3筒4筒5筒6筒'),
            parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
            parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
            parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
          ]));
      t.dingque(0, 0);
      t.dingque(1, 2);
      t.dingque(2, 1);
      t.dingque(3, 2);
      expect(t.voided(0), isFalse);
      expect(t.players[0].canSelfDraw, isNull);
      t.discard(0, tileIndex(0, 9));
      expect(t.voided(0), isTrue);
    });

    test('Bot 能完整驱动一局到结束', () {
      // 全 Bot 对局（4 个 bot），跑通不抛异常即算通过
      final t = Table(['甲', '乙', '丙', '丁'], enableExchange: false, humanSeat0: false);
      // 让所有人都是 bot：humanSeat0=false 时 seat0 也是 bot
      for (final p in t.players) {
        p.isHuman = false;
      }
      final done = driveBots(t);
      expect(t.state, stateOver);
      expect(done, isFalse);
      // 总收支守恒：所有玩家 pay 之和为 0
      final total = t.players.fold<int>(0, (a, p) => a + p.pay);
      expect(total, 0);
    });

    test('聪明 Bot：听牌时不会拆听', () => _botKeepsTing());

    test('聪明 Bot：能孤张先打', () => _botDiscardsIsolated());

    test('刮风下雨：暗杠收 2×3 分', () => _angangPay());

    test('查大叫：未听者按听牌者最大自摸分赔', () => _chadajiao());

    test('过自摸：放弃后本巡不能自摸，可继续出牌', () => _passSelfDrawBasic());

    test('Bot 把牌做大：清一色雏形平胡时过自摸', () => _botPassZimo());

    test('过手：过自摸/过点炮后同种牌不能再胡，自己出牌后解除', () => _guoShou());
  });
}

/// 过手规则完整流程
void _guoShou() {
  final t = Table(['我', '南风', '西风', '北风'],
      enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万2万3万4万5万6万7万8万9万4条5条6条7条'), // 我：缺筒，单钓 7条
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'),
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'),
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
      ]));
  t.dingque(0, 2);
  t.dingque(1, 2);
  t.dingque(2, 1);
  t.dingque(3, 1);
  final tiao7 = tileIndex(1, 7); // 7条
  // 固定我的手牌：单钓 7条
  t.players[0].hand = parseHand('1万2万3万4万5万6万7万8万9万4条5条6条7条');

  // 摸 7条 → 自摸
  t.wall.insert(0, tiao7);
  t.drawFor(0, afterGang: false);
  expect(t.players[0].canSelfDraw, isNotNull, reason: '摸 7条 形成自摸');
  t.passSelfDraw(0);
  expect(t.players[0].passedHuTiles, contains(tiao7), reason: '过自摸入过手集');

  // 再摸 7条 → 过手：不能自摸
  t.wall.insert(0, tiao7);
  t.drawFor(0, afterGang: false);
  expect(t.players[0].canSelfDraw, isNull, reason: '过手：同种牌不能再自摸');

  // 自己出牌后解除（打 7万，无人能碰/胡）
  t.wall.insert(0, tiao7); // 南风自动摸 7条
  t.discard(0, tileIndex(0, 7));
  expect(t.players[0].passedHuTiles, isEmpty, reason: '出牌后过手解除');

}


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
  t.players[0].hand = parseHand('1万2万3万4万5万6万7万8万9万4条5条6条7条');

  t.discard(0, tileIndex(0, 7));
  t.discard(1, t.players[1].hand.first);

  t.players[2].hand.add(tileIndex(1, 7));
  t.discard(2, tileIndex(1, 7));
  final acts = t.availableClaimActions(0, tileIndex(1, 7));
  expect(acts, contains('hu'), reason: '点炮可胡');
  t.claim(0, 'pass');
  expect(t.players[0].passedHuTiles, contains(tileIndex(1, 7)), reason: '过点炮入过手集');

  t.players[3].hand.add(tileIndex(1, 7));
  t.discard(3, tileIndex(1, 7));
  final acts2 = t.availableClaimActions(0, tileIndex(1, 7));
  expect(acts2, isNot(contains('hu')), reason: '过手：同种牌不能再点炮胡');
}

/// 过自摸基础行为
void _passSelfDrawBasic() {
  final t = Table(['我', '南风', '西风', '北风'],
      enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // 我：缺筒，听 6条
        parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
        parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
      ]));
  t.dingque(0, 2);
  t.dingque(1, 2);
  t.dingque(2, 1);
  t.dingque(3, 2);
  t.players[0].canSelfDraw = {'tile': tileIndex(0, 6), 'winType': 'zimo'};
  t.passSelfDraw(0);
  expect(t.players[0].canSelfDraw, isNull, reason: '过自摸后标记清除');
  expect(() => t.hu(0), throwsStateError, reason: '已过自摸不能再自摸');
  // 仍可正常出牌
  final tile = t.players[0].hand.first;
  expect(t.canDiscard(0, tile), isTrue);
}

/// Bot：清一色雏形 + 平胡自摸 → 过自摸把牌做大
void _botPassZimo() {
  final t = Table(['甲', '乙', '丙', '丁'],
      enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万4万7万2万5万8万1条4条7条2条5条8条3万3万'),
        parseHand('1万2万3万4万5万6万7万8万9万1万2万3万4条'), // 乙：清一色雏形（12 张万）+ 平胡口
        parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
      ]));
  t.dingque(0, 0);
  t.dingque(1, 2);
  t.dingque(2, 1);
  t.dingque(3, 2);
  t.players[1].canSelfDraw = {'tile': tileIndex(0, 2), 'winType': 'zimo'};
  // 手动切到乙的出牌回合（庄家是甲）
  t.turn = 1;
  t.phase = 'discard';
  final bot = Bot(t);
  bot.act(1);
  expect(t.players[1].hu, isNull, reason: '清一色雏形 + 平胡 → 应过自摸');
  expect(t.players[1].canSelfDraw, isNull);
  bot.act(1); // 继续出牌
  expect(t.players[1].hand.length, 12, reason: '过自摸后正常出牌');
}

/// 查大叫：流局时未听者按各听牌者的最大自摸分赔
void _chadajiao() {
  final t = Table(['甲', '乙', '丙', '丁'],
      enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万4万7万2万5万8万1条4条7条2条5条8条3万3万'), // 甲 庄 14：二门未听（不花猪）
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // 乙 听（龙七对最大 16）
        parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'), // 丙 三门俱全 → 花猪
        parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'), // 丁 听（16）
      ]));
  t.dingque(0, 0);
  t.dingque(1, 2);
  t.dingque(2, 0);
  t.dingque(3, 2);
  t.settleDraw();
  expect(t.players[0].isTing, false, reason: '甲应未听');
  expect(t.players[0].isHuaZhu, false, reason: '甲只有万条两门，不花猪');
  expect(t.players[2].isHuaZhu, true, reason: '丙三门俱全 → 花猪');
  final tings = t.players.where((p) => p.isTing).toList();
  expect(tings.length, 2, reason: '乙丁听牌');
  final expected = <int>[];
  for (final p in tings) {
    final cc = counts(p.hand);
    var best = 0;
    for (final tile in tingTiles(cc, p.melds.length, p.dingque)) {
      final cc2 = [...cc];
      cc2[tile]++;
      final r = scoreHand(cc2, p.melds, tile,
          {'winType': 'zimo', 'isFirstRound': false});
      if (r.base > best) best = r.base;
    }
    expect(best >= 2, isTrue, reason: '听牌最大自摸分应 ≥2');
    expected.add(best);
  }
  // 丙花猪赔甲乙丁各 16；甲查叫赔乙丁各 16
  expect(t.players[0].pay, 16 - 16 - 16, reason: '甲从丙花猪收 16、查叫赔乙丁各 16');
  expect(t.players[1].pay, 16 + 16, reason: '乙从丙花猪收 16、从甲查叫收 16');
  expect(t.players[2].pay, -16 * 3, reason: '丙花猪赔其他三家各 16');
  expect(t.players[3].pay, 16 + 16, reason: '丁从丙花猪收 16、从甲查叫收 16');
  expect(t.players.fold<int>(0, (a, p) => a + p.pay), 0, reason: '零和守恒');
}

/// 暗杠即时收费：杠家 +6，其余各家 -2
void _angangPay() {
  final t = Table(['甲', '乙', '丙', '丁'],
      enableExchange: false,
      forcedWall: makeWall([
        parseHand('9万9万9万9万4条5条6条7条8条9条1筒2筒3筒4筒'),
        parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
        parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
      ]));
  t.dingque(0, 0);
  t.dingque(1, 2);
  t.dingque(2, 1);
  t.dingque(3, 2);
  t.gang(0, tileIndex(0, 9), 'angang');
  expect(t.players[0].pay, 6, reason: '杠家收 3 家各 2 分');
  expect(t.players[1].pay, -2);
  expect(t.players[2].pay, -2);
  expect(t.players[3].pay, -2);
  expect(t.players[0].melds[0].type, 'angang');
}

/// 听牌手牌 + 一张多余孤张，Bot 必须打出孤张外的牌保听
void _botKeepsTing() {
  // 14 张：三组万顺 + 1条2条3条顺 + 5条刻 + 已成听（打 1条2条3条任意一张都听）
  final t = Table(['甲', '乙', '丙', '丁'], enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万2万3万4万5万6万7万8万9万1条2条3条5条5条5条'),
        parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
        parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
      ]));
  final bot = Bot(t);
  t.dingque(0, 2); // 定缺筒（手里没筒）
  t.dingque(1, 2);
  t.dingque(2, 0);
  t.dingque(3, 2);
  final choice = bot.chooseDiscard(0);
  expect(tileSuit(choice), 0, reason: '打出后必须仍能听牌，应从万子里选');
  final c2 = counts(t.players[0].hand);
  c2[choice]--;
  expect(tingTiles(c2, 0, 2), isNotEmpty, reason: '打出 ${tileName(choice)} 后不能丢听');
}

/// 有孤张和搭子时优先打孤张
void _botDiscardsIsolated() {
  final t = Table(['甲', '乙', '丙', '丁'], enableExchange: false,
      forcedWall: makeWall([
        parseHand('1万2万3万4条5条6条7条8条9条1筒2筒3筒9万'),
        parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
        parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
        parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
      ]));
  final bot = Bot(t);
  t.dingque(0, 0);
  t.dingque(1, 2);
  t.dingque(2, 1);
  t.dingque(3, 2);
  // 定缺万，先打缺门（9万 或 1万2万3万 中之一），打缺后不应再动万
  final first = bot.chooseDiscard(0);
  expect(tileSuit(first), 0, reason: '未打缺必须先打万');
}
