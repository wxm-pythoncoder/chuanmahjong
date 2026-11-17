// 胡牌判定 + 听牌计算（Dart 版，与服务器 win.js 一致）

import 'tiles.dart';

/// counts: 长度 27 的手牌计数；meldsCount: 副露组数
/// 能否分解为 (4 - meldsCount) 组顺/刻 + 1 对将
bool canFormWin(List<int> counts, int meldsCount) {
  final need = 4 - meldsCount;
  return tryDecompose([...counts], need) != null;
}

/// 递归分解，返回面子列表（pair/shun/ke），无法分解返回 null
List<Map<String, int>>? tryDecompose(List<int> counts, int setsNeeded) {
  for (var t = 0; t < tileCount; t++) {
    if (counts[t] >= 2) {
      counts[t] -= 2;
      final sets = _extractSets(counts, setsNeeded);
      counts[t] += 2;
      if (sets != null) return [const {'type': -1, 'tile': -1}, ...sets]; // 占位 pair 标记
    }
  }
  return null;
}

List<Map<String, int>>? _extractSets(List<int> counts, int remaining) {
  if (remaining == 0) {
    return counts.every((c) => c == 0) ? [] : null;
  }
  var first = -1;
  for (var t = 0; t < tileCount; t++) {
    if (counts[t] > 0) { first = t; break; }
  }
  if (first == -1) return null;

  // 刻子
  if (counts[first] >= 3) {
    counts[first] -= 3;
    final rest = _extractSets(counts, remaining - 1);
    counts[first] += 3;
    if (rest != null) return [ {'type': 2, 'tile': first}, ...rest ];
  }
  // 顺子
  final rank = first % 9;
  if (rank <= 6 && counts[first + 1] > 0 && counts[first + 2] > 0) {
    counts[first]--;
    counts[first + 1]--;
    counts[first + 2]--;
    final rest = _extractSets(counts, remaining - 1);
    counts[first]++;
    counts[first + 1]++;
    counts[first + 2]++;
    if (rest != null) return [ {'type': 1, 'tile': first}, ...rest ];
  }
  return null;
}

/// 七对（无副露），4 张算两对（龙七对）
bool isQiDui(List<int> counts) {
  var pairs = 0;
  for (var t = 0; t < tileCount; t++) {
    final c = counts[t];
    if (c == 0) continue;
    if (c == 2) { pairs++; continue; }
    if (c == 4) { pairs += 2; continue; }
    return false;
  }
  return pairs == 7;
}

/// 统一胡牌入口
bool isWin(List<int> counts, int meldsCount) {
  if (meldsCount == 0 && isQiDui(counts)) return true;
  return canFormWin(counts, meldsCount);
}

/// 听牌：可以胡哪些牌（mustVoidSuit 排除定缺门）
List<int> tingTiles(List<int> counts, int meldsCount, int? mustVoidSuit) {
  final result = <int>[];
  for (var t = 0; t < tileCount; t++) {
    if (counts[t] >= 4) continue;
    if (mustVoidSuit != null && tileSuit(t) == mustVoidSuit) continue;
    counts[t]++;
    final win = isWin(counts, meldsCount);
    counts[t]--;
    if (win) result.add(t);
  }
  return result;
}

/// 缺一门判定：手牌 + 副露中缺失的花色
List<int> voidSuits(List<int> concealedCounts, List<int> meldTiles) {
  final present = <int>{};
  for (var t = 0; t < tileCount; t++) {
    if (concealedCounts[t] > 0) present.add(tileSuit(t));
  }
  for (final t in meldTiles) {
    present.add(tileSuit(t));
  }
  final missing = <int>[];
  for (var s = 0; s < 3; s++) {
    if (!present.contains(s)) missing.add(s);
  }
  return missing;
}
