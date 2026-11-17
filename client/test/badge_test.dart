// 缺门标记 + 记牌器渲染测试 + 换牌选牌逻辑测试
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_test/flutter_test.dart';

import 'package:chuanmahjong/main.dart';
import 'package:chuanmahjong/game/table.dart';
import 'package:chuanmahjong/game/tiles.dart';

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
  // ---- 换三张选牌逻辑（纯函数）----

  test('换三张选牌：同值两张可以各选一张（两张间循环增减）', () {
    // 手牌：两张 5条(14) + 其他
    final hand = [14, 14, 20, 0, 1, 2, 9, 10, 11, 18, 19, 21, 22];
    var sel = <int>[];
    sel = toggleExchangePick(sel, hand, 14);
    expect(sel, [14], reason: '第一次点 5条 → 选中一张');
    sel = toggleExchangePick(sel, hand, 14);
    expect(sel, [14, 14], reason: '第二次点 5条 → 两张同值都选中（核心：两张算两张）');
    sel = toggleExchangePick(sel, hand, 14);
    expect(sel, [14], reason: '第三下 → 退回一张');
    sel = toggleExchangePick(sel, hand, 14);
    expect(sel, [14, 14], reason: '第四下 → 再选一张（在两张间循环）');
  });

  test('换三张选牌：单张牌点两下 = 选中再退回；选满 3 张后不再增加', () {
    final hand = [0, 12, 13, 14, 9, 10, 11, 18, 19, 20, 21, 22];
    var sel = [0, 12, 13];
    sel = toggleExchangePick(sel, hand, 14);
    expect(sel, [0, 12, 13], reason: '已满 3 张不再增加');
    sel = toggleExchangePick(sel, hand, 0);
    expect(sel, [12, 13], reason: '手里只有一张 0 → 再点 = 退回');
  });

  // ---- 缺门标记 + 记牌器（真实渲染）----

  testWidgets('缺门手牌显示「缺」标记（3 张万 → 3 个标记）', (tester) async {
    final t = Table(['我', '南风', '西风', '北风'],
        enableExchange: false,
        forcedWall: makeWall([
          parseHand('9万9万9万4条5条6条7条8条9条1筒2筒3筒4筒5筒'), // 我：3 张万
          parseHand('3万3万4条5条6条7条8条1条2条3条9条9条6筒'),
          parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
          parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
        ]));
    t.dingque(0, 0); // 我定缺万 → 手里 3 张万都该有标记
    t.dingque(1, 2);
    t.dingque(2, 1);
    t.dingque(3, 2);

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: GamePage(injectedTable: t)));
    await tester.pump(const Duration(milliseconds: 300));

    final badges = find.text('缺');
    expect(badges.evaluate().length, 3,
        reason: '手牌里 3 张缺门的万应各有一个「缺」标记');

    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('记牌器'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('换三张：同值两张可各选一张（真实 UI 点击）', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final t = Table(['我', '南风', '西风', '北风'],
        forcedWall: makeWall([
          // 我（庄 14 张）：两张 5万 + 1万2万3万 + 条筒若干 → 万门足够换 3 张
          parseHand('5万5万1万2万3万4条5条6条7条8条9条1筒9筒'),
          parseHand('1万1万2万2万3万3万4条4条5条5条6条6条6条'),
          parseHand('7条1万2万3万4万5万6万7万8万9万1筒2筒3筒'),
          parseHand('1万1万2万2万3万3万1条2条3条4条5条6条7条'),
        ]));
    await tester.pumpWidget(MaterialApp(home: GamePage(injectedTable: t)));
    await tester.pump(const Duration(milliseconds: 300));

    // 换三张阶段等待我选牌
    expect(find.textContaining('已选 0/3'), findsOneWidget);

    // 点两张 5万（同值两张各选一张）
    final w5 = find.byWidgetPredicate(
        (w) => w is MahjongTileWidget && w.tile == tileIndex(0, 5) && w.width == 44);
    expect(w5.evaluate().length, 2, reason: '手牌里应有两张 5万');
    await tester.tap(w5.first);
    await tester.pump();
    expect(find.textContaining('已选 1/3'), findsOneWidget);
    await tester.tap(w5.last);
    await tester.pump();
    expect(find.textContaining('已选 2/3'), findsOneWidget,
        reason: '第二张同值 5万 也能选中');

    // 再点一张 1万 凑满 3 张
    final w1 = find
        .byWidgetPredicate(
            (w) => w is MahjongTileWidget && w.tile == tileIndex(0, 1) && w.width == 44)
        .first;
    await tester.tap(w1);
    await tester.pump();
    expect(find.textContaining('已选 3/3'), findsOneWidget);

    // 确认换三张 → bot 逐家换牌（带 1.2~2s 停顿）→ 四家换完 → 进入定缺
    await tester.tap(find.text('换三张 ✓'));
    await tester.pump();
    // 推进足够的假时钟让三家 bot 完成换牌
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('请定缺：'), findsOneWidget,
        reason: '换三张成功后应进入定缺阶段');
    // 「换出 → 换入」横幅应出现
    expect(find.text('换出'), findsOneWidget);
  });
}
