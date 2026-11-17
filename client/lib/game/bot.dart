// Bot AI v2：搭子效率 + 听牌评估
// 策略：
//  - 定缺：选「打掉后手牌搭子进度损失最小」的门
//  - 出牌：优先打缺门 → 否则对每张候选打牌评估：
//      · 打出后能听 → 得分 100 + 听牌张数 + 听牌剩余张数
//      · 打出后未听 → 搭子进度分（刻2 对1 两面1，取前 need 个）
//  - 碰：模拟「碰之后的最佳进度」与「不碰的最佳进度」对比，有提升才碰
//  - 杠：能杠就杠（川麻杠有根加分且多摸一张）
//  - 自摸即胡

import 'dart:math';

import 'tiles.dart';
import 'win.dart';
import 'scoring.dart' show Meld, scoreHand;
import 'table.dart';

class Bot {
  final Table table;
  final String difficulty; // easy | normal | hard

  Bot(this.table, {this.difficulty = 'normal'});

  void act(int seat) {
    final p = table.players[seat];
    if (table.state == stateHuan && !table.exchangePicks.containsKey(seat)) {
      table.exchange(seat, chooseExchange(seat));
      return;
    }
    if (table.state == stateDingque && p.dingque == null) {
      table.dingque(seat, chooseDingque(seat));
      return;
    }
    if (table.state != statePlaying) return;

    // claim 阶段
    if (table.phase == 'claim') {
      final who = table.nextClaimant();
      if (who != seat) return;
      final options = table.pendingClaim!['options'] as Map<int, List<String>>;
      final acts = options[seat]!;
      final tile = table.pendingClaim!['tile'] as int;
      if (acts.contains('hu')) {
        table.claim(seat, 'hu');
      } else if (acts.contains('minggang')) {
        table.claim(seat, 'minggang');
      } else if (acts.contains('peng') &&
          tileSuit(tile) != p.dingque &&
          _pengWorthwhile(seat, tile)) {
        table.claim(seat, 'peng');
      } else {
        table.claim(seat, 'pass');
      }
      return;
    }

    if (table.phase != 'discard' || table.turn != seat || p.isHued) return;

    if (p.canSelfDraw != null) {
      // 把牌做大：清一色雏形（单一门 ≥10 张、牌墙充足）且当前只是平胡时，过自摸继续做牌
      final cc = table.countsOf(seat);
      final drawTile = p.canSelfDraw!['tile'] as int;
      final winType = p.canSelfDraw!['winType'] as String;
      final r = scoreHand(
          cc, p.melds, drawTile, {'winType': winType, 'isFirstRound': false});
      final suitCounts = List.generate(3, (_) => 0);
      for (final x in table.players[seat].hand) {
        suitCounts[tileSuit(x)]++;
      }
      final maxSuit = suitCounts.reduce((a, b) => a > b ? a : b);
      // 大牌潜力门槛：困难 ≥8 张即赌；普通 ≥10 张；简单从不赌
      final minSuit = difficulty == 'hard'
          ? 8
          : difficulty == 'normal'
              ? 10
              : 99;
      final bigPotential =
          r.base <= 2 && maxSuit >= minSuit && table.wall.length >= 24;
      if (bigPotential) {
        table.passSelfDraw(seat); // 过自摸，把牌做大
        return;
      }
      table.hu(seat);
      return;
    }
    if (p.canGangTiles.isNotEmpty) {
      final t = p.canGangTiles.first;
      final isPeng = p.melds.any((m) => m.type == 'peng' && m.tiles[0] == t);
      table.gang(seat, t, isPeng ? 'bugang' : 'angang');
      return;
    }
    table.discard(seat, chooseDiscard(seat));
  }

  // ---------- 换三张 ----------

  /// 换三张：挑「张数最少（≥3）的门」，从里选 3 张最没用的（孤张/边张优先）
  List<int> chooseExchange(int seat) {
    final counts = table.countsOf(seat);
    final perSuit = List.generate(3, (_) => <int>[]);
    for (var t = 0; t < tileCount; t++) {
      if (counts[t] > 0) perSuit[tileSuit(t)].add(t);
    }
    // 只有张数 ≥3 的门可选；取张数最少的门（换出去后最利于打缺）
    var suit = -1;
    var bestCount = 99;
    for (var s = 0; s < 3; s++) {
      if (perSuit[s].length >= 3 && perSuit[s].length < bestCount) {
        bestCount = perSuit[s].length;
        suit = s;
      }
    }
    if (suit == -1) suit = 0; // 理论上不会发生（13 张必有 ≥3 同门）
    // 门内选 3 张：孤立优先 → 边张优先
    final candidates = [...perSuit[suit]];
    candidates.sort((a, b) {
      final na = _tileIsolation(counts, a), nb = _tileIsolation(counts, b);
      if (na != nb) return nb.compareTo(na); // 孤立度高的先换
      final ea = a % 9 <= 1 || a % 9 >= 8 ? 1 : 0;
      final eb = b % 9 <= 1 || b % 9 >= 8 ? 1 : 0;
      return eb.compareTo(ea);
    });
    return candidates.take(3).toList();
  }

  /// 孤立度：同门内没有相邻牌 = 高
  int _tileIsolation(List<int> counts, int t) {
    final suit = tileSuit(t), rank = t % 9;
    for (var d = -2; d <= 2; d++) {
      if (d == 0) continue;
      final o = rank + d;
      if (o < 0 || o > 8) continue;
      if (counts[suit * 9 + o] > 0) return 0;
    }
    return 1;
  }

  // ---------- 定缺 ----------

  int chooseDingque(int seat) {
    final p = table.players[seat];
    final counts = table.countsOf(seat);
    var best = 0;
    var bestScore = double.infinity;
    for (var s = 0; s < 3; s++) {
      // 打掉这门之后的搭子进度（越低越该缺这门）
      final c2 = [...counts];
      var n = 0;
      for (var t = s * 9; t < s * 9 + 9; t++) {
        n += c2[t];
        c2[t] = 0;
      }
      // 原本就没这门 → 直接缺它最划算
      var score = _blockScore(c2, 4 - p.melds.length).toDouble();
      if (n == 0) score -= 10;
      score += n * 0.05; // 同分时缺张数少的
      if (score < bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  // ---------- 出牌 ----------

  int chooseDiscard(int seat) {
    final p = table.players[seat];
    final hand = p.hand;
    final q = p.dingque;
    // 1. 先打缺门
    if (q != null && !table.voided(seat)) {
      return hand.firstWhere((t) => tileSuit(t) == q);
    }
    final counts = table.countsOf(seat);
    final meldsCount = p.melds.length;
    final need = 4 - meldsCount;
    // 防守强度：简单 = 不防守；普通 = 对手有威胁才防守；困难 = 有副露就防
    final risky = difficulty != 'easy' &&
        (difficulty == 'hard'
            ? table.activePlayers().any((o) => o.seat != seat && o.melds.length >= 1)
            : table.activePlayers().any((o) =>
                o.seat != seat &&
                (o.melds.length >= 2 ||
                    (table.wall.length < 24 && o.melds.length >= 1))));

    int? bestTile;
    var bestScore = -1.0;
    var bestTiebreak = -1.0;
    final seen = <int>{};
    for (final t in hand) {
      if (!seen.add(t)) continue;
      final c2 = [...counts];
      c2[t]--;
      final tings = tingTiles(c2, meldsCount, q);
      double sc;
      if (tings.isNotEmpty) {
        sc = 100 + tings.length + _waitQuality(tings, c2, p.melds);
      } else if (difficulty == 'easy') {
        // 简单：只看搭子进度，不做两步搜索
        sc = _blockScore(c2, need).toDouble();
      } else {
        // 两步搜索：这张打出去之后，进一张最好的牌能形成几面听
        sc = _twoStepProgress(c2, meldsCount, q) * 4;
        sc += _blockScore(c2, need);
        sc += _suitFocus(c2) * 0.5;
      }
      // 防守：对手可能已听牌时，避免喂牌（简单档不防守）
      if (risky) sc -= _dangerScore(t, seat) * 0.6;
      // 次级排序：打出后手牌更整齐（散张少优先打散张）
      final tiebreak = -_isolatedCount(c2).toDouble();
      if (sc > bestScore || (sc == bestScore && tiebreak > bestTiebreak)) {
        bestScore = sc;
        bestTiebreak = tiebreak;
        bestTile = t;
      }
    }
    return bestTile ?? hand.first;
  }

  /// 两步搜索：手牌 13 张（c2 已扣掉候选打牌），枚举「进张 → 再打牌」后能听的口数
  /// 进张范围限制在手牌各牌 ±2 以内（有效进张），控制计算量
  double _twoStepProgress(List<int> c2, int meldsCount, int? dingque) {
    // 收集有用的进张候选
    final phantoms = <int>{};
    for (var t = 0; t < tileCount; t++) {
      if (c2[t] > 0) {
        final suit = tileSuit(t), rank = t % 9;
        for (var d = -2; d <= 2; d++) {
          final o = suit * 9 + rank + d;
          if (rank + d >= 0 && rank + d <= 8) phantoms.add(o);
        }
      }
    }
    var best = 0.0;
    for (final ph in phantoms) {
      if (dingque != null && tileSuit(ph) == dingque) continue;
      if (c2[ph] >= 4) continue;
      c2[ph]++;
      // 进张后 14 张：枚举再打一张后的听牌数
      final seen = <int>{};
      for (var t = 0; t < tileCount; t++) {
        if (c2[t] == 0 || !seen.add(t)) continue;
        c2[t]--;
        final tings = tingTiles(c2, meldsCount, dingque);
        c2[t]++;
        if (tings.length > best) best = tings.length.toDouble();
      }
      c2[ph]--;
    }
    return best;
  }

  /// 危险度：这张牌打出去喂给已副露对手的可能性
  double _dangerScore(int tile, int fromSeat) {
    var danger = 0.0;
    for (final o in table.activePlayers()) {
      if (o.seat == fromSeat) continue;
      final hot = o.melds.length >= 2 || (table.wall.length < 24 && o.melds.length >= 1);
      if (!hot) continue;
      // 对手自己打过的牌 → 对他安全
      if (o.discards.contains(tile)) continue;
      // 与对手副露同门的牌更危险
      final oMeldSuits = o.melds.map((m) => tileSuit(m.tiles[0])).toSet();
      danger += 2 + o.melds.length * 0.5 + (oMeldSuits.contains(tileSuit(tile)) ? 2 : 0);
    }
    return danger;
  }

  /// 听牌质量：每个听牌张在场上还剩几张（自己视角可见）
  double _waitQuality(List<int> tings, List<int> counts, List<Meld> melds) {
    var q = 0.0;
    for (final t in tings) {
      var left = 4 - counts[t];
      for (final m in melds) {
        for (final mt in m.tiles) {
          if (mt == t) left--;
        }
      }
      // 其他家副露里的也算死
      for (final o in table.players) {
        for (final m in o.melds) {
          for (final mt in m.tiles) {
            if (mt == t) left--;
          }
        }
        for (final d in o.discards) {
          if (d == t) left--;
        }
      }
      if (left < 0) left = 0;
      q += left;
    }
    return q * 0.1;
  }

  /// 只剩一门时 +1（清一色潜力）
  int _suitFocus(List<int> counts) {
    final suits = <int>{};
    for (var t = 0; t < tileCount; t++) {
      if (counts[t] > 0) suits.add(tileSuit(t));
    }
    return suits.length == 1 ? 1 : 0;
  }

  int _isolatedCount(List<int> counts) {
    var n = 0;
    for (var t = 0; t < tileCount; t++) {
      if (counts[t] == 0) continue;
      final suit = tileSuit(t);
      var near = false;
      for (var d = -2; d <= 2; d++) {
        final o = t + d;
        if (o < suit * 9 || o >= suit * 9 + 9) continue;
        if (counts[o] > 0) near = true;
      }
      if (!near && counts[t] == 1) n++;
    }
    return n;
  }

  // ---------- 搭子进度分 ----------

  /// 刻=2 分，对=1 分，两面/嵌张=1 分；只取前 need 个最高块
  double _blockScore(List<int> counts, int need) {
    final values = <double>[];
    final c = [...counts];
    for (var t = 0; t < tileCount; t++) {
      while (c[t] >= 3) {
        values.add(2);
        c[t] -= 3;
      }
    }
    for (var t = 0; t < tileCount; t++) {
      if (c[t] >= 2) {
        values.add(1);
        c[t] -= 2;
      }
    }
    for (var t = 0; t < tileCount; t++) {
      final rank = t % 9;
      if (rank <= 7 && c[t] >= 1 && c[t + 1] >= 1) {
        values.add(1);
        c[t]--;
        c[t + 1]--;
        if (rank <= 6 && c[t + 2] >= 1) {
          // 嵌张也算半搭
        }
      } else if (rank <= 6 && c[t] >= 1 && c[t + 2] >= 1) {
        values.add(0.5);
        c[t]--;
        c[t + 2]--;
      }
    }
    values.sort((a, b) => b.compareTo(a));
    var score = 0.0;
    for (var i = 0; i < need && i < values.length; i++) {
      score += values[i];
    }
    return score;
  }

  /// 13 张手牌的最佳进度：能听 → 100+；否则搭子分
  double _bestProgress(int seat) {
    final p = table.players[seat];
    final counts = table.countsOf(seat);
    final meldsCount = p.melds.length;
    final need = 4 - meldsCount;
    var best = 0.0;
    final seen = <int>{};
    for (final t in p.hand) {
      if (!seen.add(t)) continue;
      final c2 = [...counts];
      c2[t]--;
      final tings = tingTiles(c2, meldsCount, p.dingque);
      best = max(
        best,
        tings.isNotEmpty
            ? 100.0 + tings.length + _waitQuality(tings, c2, p.melds)
            : _blockScore(c2, need),
      );
    }
    return best;
  }

  // ---------- 碰的决策 ----------

  bool _pengWorthwhile(int seat, int tile) {
    final p = table.players[seat];
    if (table.voided(seat) == false && tileSuit(tile) == p.dingque) return false;

    // 模拟碰：手牌 -2，副露 +1
    final handAfter = [...p.hand]..remove(tile)..remove(tile);
    final meldsAfter = [...p.melds, Meld('peng', [tile, tile, tile])];

    // 碰后最佳进度（从 11 张里挑一张打出）
    final after = _bestProgressOfHand(handAfter, meldsAfter, p.dingque);
    final before = _bestProgress(seat);
    // 碰后需要打出一张 → 有效进度取碰后
    return after >= before + 1 || (after >= 100 && before < 100);
  }

  double _bestProgressOfHand(
      List<int> hand, List<Meld> melds, int? dingque) {
    final counts = List<int>.filled(27, 0);
    for (final t in hand) {
      counts[t]++;
    }
    final meldsCount = melds.length;
    final need = 4 - meldsCount;
    var best = 0.0;
    final seen = <int>{};
    for (final t in hand) {
      if (!seen.add(t)) continue;
      final c2 = [...counts];
      c2[t]--;
      final tings = tingTiles(c2, meldsCount, dingque);
      best = max(
        best,
        tings.isNotEmpty
            ? 100.0 + tings.length + _waitQuality(tings, c2, melds)
            : _blockScore(c2, need),
      );
    }
    return best;
  }
}

/// 执行一步 bot 行动（一次定缺 / 一次回应 / 一次出牌）
/// 返回 'acted'（执行了动作）| 'waiting'（轮到人类）| 'over'（对局结束）
  String stepBot(Table table, [Bot? b0]) {
    final b = b0 ?? Bot(table);
    if (table.state == stateOver) return 'over';

    if (table.state == stateHuan) {
      final pending =
          table.players.where((p) => !table.exchangePicks.containsKey(p.seat)).toList();
      if (pending.isEmpty) return 'acted';
      final p = pending.first;
      if (p.isHuman) return 'waiting';
      b.act(p.seat);
      return 'acted';
    }

    if (table.state == stateDingque) {
    final pending = table.players.where((p) => p.dingque == null).toList();
    if (pending.isEmpty) return 'acted'; // 全部定缺完成（状态切换在 act 里发生）
    final p = pending.first;
    if (p.isHuman) return 'waiting';
    b.act(p.seat);
    return 'acted';
  }

  if (table.phase == 'claim') {
    final who = table.nextClaimant();
    if (who == null) {
      table.evaluateClaims();
      return 'acted';
    }
    if (table.players[who].isHuman) return 'waiting';
    b.act(who);
    return 'acted';
  }

  if (table.phase == 'discard') {
    final p = table.players[table.turn];
    if (p.isHuman) return 'waiting';
    b.act(table.turn);
    return 'acted';
  }
  return 'waiting';
}

/// 驱动整局：循环让 bot 行动，直到轮到人类或对局结束
/// 返回 true 表示轮到人类需要 UI 输入
bool driveBots(Table table, [Bot? bot]) {
  final b = bot ?? Bot(table);
  var guard = 0;
  while (true) {
    if (++guard > 10000) throw StateError('Bot 循环超限，疑似死锁');
    final r = stepBot(table, b);
    if (r == 'over') return false;
    if (r == 'waiting') return true;
  }
}
