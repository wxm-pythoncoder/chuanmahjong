// 番数计分（Dart 版，与服务器 scoring.js 一致）

import 'tiles.dart';
import 'win.dart';

class Meld {
  String type; // peng | minggang | angang | bugang（补杠会升级，不能 final）
  final List<int> tiles;
  final int from;
  Meld(this.type, this.tiles, {this.from = -1});

  Map<String, dynamic> toJson() => {'type': type, 'tiles': tiles, 'from': from};
  static Meld fromJson(Map<String, dynamic> j) =>
      Meld(j['type'] as String, List<int>.from(j['tiles']), from: j['from'] as int? ?? -1);
}

const Map<String, int> fanRules = {
  'duiduihu': 1,   // 对对胡
  'qingyise': 2,   // 清一色
  'qidui': 2,      // 七对
  'jingoudiao': 1, // 金钩钓
  'gen': 1,        // 每根
  'gangshanghua': 1,
  'gangshangpao': 1, // 杠上炮（杠后打牌点炮，点炮分加一翻）
  'qianggang': 1,
  'tianhu': 6,
  'dihu': 6,
};

const Map<String, String> fanNames = {
  '对对胡': 'duiduihu',
  '清一色': 'qingyise',
  '七对': 'qidui',
  '金钩钓': 'jingoudiao',
  '根': 'gen',
  '杠上花': 'gangshanghua',
  '抢杠胡': 'qianggang',
  '天胡': 'tianhu',
  '地胡': 'dihu',
};

class ScoreResult {
  final List<MapEntry<String, int>> fans; // 名称 → 番
  final int totalFan;
  final int effectiveFan; // 封顶后的有效番
  final bool capped; // 是否触顶
  final int base;
  final int winTile;
  ScoreResult(this.fans, this.totalFan, this.effectiveFan, this.capped, this.base, this.winTile);
}

/// 根：任一牌种凑满 4 张（手牌 + 副露）
int countGens(List<int> concealedCounts, List<Meld> melds) {
  final total = [...concealedCounts];
  for (final m in melds) {
    for (final t in m.tiles) {
      total[t]++;
    }
  }
  var gens = 0;
  for (final c in total) {
    if (c == 4) gens++;
  }
  return gens;
}

/// 对对胡：手牌全为刻/将，无顺子（4 张无法分解为刻+将）
bool isDuiDuiHu(List<int> counts, int meldsCount) {
  final need = 4 - meldsCount;
  var pairs = 0, ke = 0;
  for (var t = 0; t < tileCount; t++) {
    final c = counts[t];
    if (c == 0) continue;
    if (c == 2) { pairs++; continue; }
    if (c == 3) { ke++; continue; }
    return false; // 1 张或 4 张都不行
  }
  return pairs == 1 && ke == need;
}

/// 清一色：所有牌同一门
bool isQingYiSe(List<int> concealedCounts, List<Meld> melds) {
  var suit = -1;
  for (var t = 0; t < tileCount; t++) {
    if (concealedCounts[t] > 0) {
      final s = tileSuit(t);
      if (suit == -1) { suit = s; } else if (suit != s) { return false; }
    }
  }
  for (final m in melds) {
    final s = tileSuit(m.tiles[0]);
    if (suit == -1) { suit = s; } else if (suit != s) { return false; }
  }
  return true;
}

/// 计算番数与基础分
ScoreResult scoreHand(List<int> concealedCounts, List<Meld> melds, int winTile, Map<String, dynamic> ctx) {
  final meldsCount = melds.length;
  final fans = <MapEntry<String, int>>[];

  final qidui = meldsCount == 0 && isQiDui(concealedCounts);
  if (qidui) {
    fans.add(MapEntry('七对', fanRules['qidui']!));
  } else if (isDuiDuiHu(concealedCounts, meldsCount)) {
    fans.add(MapEntry('对对胡', fanRules['duiduihu']!));
  }

  if (isQingYiSe(concealedCounts, melds)) {
    fans.add(MapEntry('清一色', fanRules['qingyise']!));
  }

  // 金钩钓：4 组副露 + 手牌单钓（手牌剩 2 张：1 胡 + 1 将）
  final handTiles = concealedCounts.fold<int>(0, (a, b) => a + b);
  if (meldsCount == 4 && handTiles == 2) {
    fans.add(MapEntry('金钩钓', fanRules['jingoudiao']!));
  }

  final gens = countGens(concealedCounts, melds);
  if (gens > 0) {
    fans.add(MapEntry('根×$gens', fanRules['gen']! * gens));
  }

  final winType = ctx['winType'] as String?;
  // 自摸加一翻（自摸/杠上花都算自摸）
  if (winType == 'zimo' || winType == 'gangshanghua') {
    fans.add(const MapEntry('自摸', 1));
  }
  if (winType == 'gangshanghua') {
    fans.add(MapEntry('杠上花', fanRules['gangshanghua']!));
  }
  if (winType == 'gangshangpao') {
    fans.add(MapEntry('杠上炮', fanRules['gangshangpao']!));
  }
  if (winType == 'qianggang') {
    fans.add(MapEntry('抢杠胡', fanRules['qianggang']!));
  }
  if (ctx['isFirstRound'] == true) {
    if (winType == 'zimo') fans.add(MapEntry('天胡', fanRules['tianhu']!));
    if (winType == 'dianpao') fans.add(MapEntry('地胡', fanRules['dihu']!));
  }

  final totalFan = fans.fold<int>(0, (a, f) => a + f.value);
  // 四番封顶
  const fanCap = 4;
  final capped = totalFan > fanCap;
  final effectiveFan = totalFan > fanCap ? fanCap : totalFan;
  final base = 1 << effectiveFan;
  if (capped) fans.add(MapEntry('封顶($totalFan番)', 0));
  return ScoreResult(fans, totalFan, effectiveFan, capped, base, winTile);
}
