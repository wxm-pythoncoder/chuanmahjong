// 川麻血战到底 —— 牌定义（与服务器 JS 版逻辑一致）
// 牌用 0-26 整数表示：suit * 9 + (rank - 1)

import 'dart:math';

const List<String> suitNames = ['万', '条', '筒'];

const int tileCount = 27;
const int totalTiles = 108;

int tileIndex(int suit, int rank) => suit * 9 + (rank - 1);
int tileSuit(int t) => t ~/ 9;
int tileRank(int t) => t % 9 + 1;
String tileName(int t) => '${suitNames[tileSuit(t)]}${tileRank(t)}';

/// 生成完整牌墙（108 张）
List<int> buildWall() {
  final wall = <int>[];
  for (var t = 0; t < tileCount; t++) {
    for (var i = 0; i < 4; i++) {
      wall.add(t);
    }
  }
  return wall;
}

/// Fisher-Yates 洗牌（默认加密级随机数，保证发牌公平）
List<int> shuffleWall(List<int> wall, [Random? rng]) {
  final r = rng ?? Random.secure();
  for (var i = wall.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = wall[i];
    wall[i] = wall[j];
    wall[j] = tmp;
  }
  return wall;
}

/// 把手牌字符串 "1万2万3万 4条5条6条" 转成 index 数组（便于测试）
List<int> parseHand(String s) {
  final out = <int>[];
  for (var suit = 0; suit < 3; suit++) {
    final re = RegExp('(\\d)${suitNames[suit]}');
    for (final m in re.allMatches(s)) {
      final n = int.parse(m.group(1)!);
      if (n < 1 || n > 9) throw ArgumentError('非法牌: ${m.group(0)}');
      out.add(tileIndex(suit, n));
    }
  }
  return out;
}

/// 手牌排序（花色 → 点数）
List<int> sortHand(List<int> hand) {
  final sorted = [...hand]..sort();
  return sorted;
}
