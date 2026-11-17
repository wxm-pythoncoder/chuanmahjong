// 血战到底牌桌状态机（Dart 版，与服务器 table.js 一致）
// 单机模式：玩家坐 0 号位，其余 3 家由 Bot 驱动

import 'dart:math';

import 'tiles.dart';
import 'win.dart';
import 'scoring.dart';

const stateHuan = 'huan'; // 换三张阶段
const stateDingque = 'dingque';
const statePlaying = 'playing';
const stateOver = 'over';

class GameEvent {
  final String type;
  final Map<String, dynamic> data;
  GameEvent(this.type, this.data);
  Map<String, dynamic> toJson() => {'type': type, ...data};
}

class PlayerState {
  final int seat;
  final String name;
  bool isHuman;
  List<int> hand = [];
  List<Meld> melds = [];
  List<int> discards = [];
  int? dingque;
  Map<String, dynamic>? hu; // {winType, tile, fans, base}
  bool isDealer = false;
  int pay = 0;
  bool isTing = false;
  int bestTingScore = 0; // 查大叫：最大听牌型自摸分
  bool isHuaZhu = false; // 花猪：未听且三门俱全
  final Set<int> passedHuTiles = {}; // 过手：过胡/过自摸的同种牌，出牌前不能胡
  List<int> tingDetail = []; // 流局查叫：听的牌（空=已构成胡形）

  // 回合内可用动作提示
  Map<String, dynamic>? canSelfDraw; // {tile, winType}
  List<int> canGangTiles = [];

  PlayerState(this.seat, this.name, {this.isHuman = false});

  bool get isHued => hu != null;
}

class Table {
  final List<PlayerState> players;
  List<int> wall;
  String state = stateDingque;
  String phase = 'idle'; // draw | discard | claim
  int turn = 0;
  int dealer = 0;
  bool firstRound = true;
  int? gangDiscarder; // 刚杠完摸牌的座位（用于杠上炮判定）
  bool discardAfterGang = false; // 本次出牌是否为杠后打牌
  Map<String, int>? lastDraw; // 最近一次摸牌 {seat, tile}
  Map<String, int>? lastDiscard; // {seat, tile}
  Map<String, dynamic>? pendingClaim; // {tile, from, options: Map<seat, List<String>>}
  Map<int, String> claims = {};
  int? pendingBugang;
  int? lastBugangTile;
  int exchangeMode = 0; // 0=传下家(+1) 1=传上家(+3) 2=传对家(+2)，逐局轮换
  int wallStartSide = 0; // 起牌墙位（骰子决定，0-3 哪面墙先摸）
  final bool _enableExchange;
  final Map<int, List<int>> exchangePicks = {};
  final List<GameEvent> events = [];
  final Random rng;

  Table(List<String> names,
      {Random? rng,
      List<int>? forcedWall,
      bool humanSeat0 = true,
      bool enableExchange = true,
      int exchangeMode = 0,
      int wallStartSide = 0})
      : players = List.generate(
            4,
            (i) => PlayerState(i, names[i], isHuman: i == 0 && humanSeat0)),
        wall = forcedWall ?? shuffleWall(buildWall(), rng ?? Random.secure()),
        rng = rng ?? Random.secure(),
        _enableExchange = enableExchange,
        exchangeMode = exchangeMode,
        wallStartSide = wallStartSide.clamp(0, 3) {
    deal();
  }

  void log(String type, Map<String, dynamic> data) {
    events.add(GameEvent(type, data));
  }

  void deal() {
    var idx = 0;
    for (final p in players) {
      final n = p.seat == dealer ? 14 : 13;
      p.hand = wall.sublist(idx, idx + n);
      idx += n;
      p.hand.sort();
      if (p.seat == dealer) p.isDealer = true;
    }
    wall = wall.sublist(idx);
    turn = dealer;
    // 先换三张，再定缺
    state = _enableExchange ? stateHuan : stateDingque;
    phase = _enableExchange ? 'exchange' : 'idle';
    log('deal', {'dealer': dealer});
  }

  /// 换三张方向提示
  String exchangeDirectionLabel() => const ['下家', '上家', '对家'][exchangeMode];

  /// 提交换三张：3 张同门；四家齐了统一交换，然后进入定缺
  void exchange(int seat, List<int> tiles) {
    if (state != stateHuan) throw StateError('不是换三张阶段');
    if (tiles.length != 3) throw StateError('必须选 3 张');
    final suit = tileSuit(tiles[0]);
    for (final t in tiles) {
      if (tileSuit(t) != suit) throw StateError('三张必须同门');
    }
    if (tiles.toSet().length > 4) throw StateError('同一牌值最多 4 张');
    final hand = players[seat].hand;
    final remaining = [...hand];
    for (final t in tiles) {
      final idx = remaining.indexOf(t);
      if (idx == -1) throw StateError('手牌里没有 ${tileName(t)}');
      remaining.removeAt(idx);
    }
    exchangePicks[seat] = [...tiles];
    log('exchange_pick', {'seat': seat, 'count': 3});

    if (exchangePicks.length == 4) {
      final offset = const [1, 3, 2][exchangeMode];
      for (var i = 0; i < 4; i++) {
        for (final t in exchangePicks[i]!) {
          players[i].hand.remove(t);
        }
      }
      for (var i = 0; i < 4; i++) {
        players[(i + offset) % 4].hand.addAll(exchangePicks[i]!);
        players[(i + offset) % 4].hand.sort();
      }
      exchangeMode = (exchangeMode + 1) % 3; // 下一局轮换方向
      state = stateDingque;
      phase = 'idle';
      log('exchange', {'done': true});
    }
  }

  List<int> countsOf(int seat) {
    final c = List<int>.filled(27, 0);
    for (final t in players[seat].hand) {
      c[t]++;
    }
    return c;
  }

  List<int> meldTilesOf(int seat) =>
      players[seat].melds.expand((m) => m.tiles).toList();

  /// 是否已打缺（手牌无缺门牌）
  bool voided(int seat) {
    final q = players[seat].dingque;
    if (q == null) return false;
    return !players[seat].hand.any((t) => tileSuit(t) == q);
  }

  /// 提交定缺；四家齐了进入打牌阶段
  void dingque(int seat, int suit) {
    if (state != stateDingque) throw StateError('当前不是定缺阶段');
    players[seat].dingque = suit;
    log('dingque', {'seat': seat, 'suit': suit});
    if (players.every((p) => p.dingque != null)) {
      state = statePlaying;
      phase = 'discard'; // 庄家 14 张直接出牌
      log('start', {'turn': turn});
    }
  }

  bool canDiscard(int seat, int tile) {
    final p = players[seat];
    if (state != statePlaying || phase != 'discard' || turn != seat) return false;
    if (p.isHued) return false;
    if (!p.hand.contains(tile)) return false;
    final q = p.dingque;
    if (q != null && !voided(seat)) {
      return tileSuit(tile) == q;
    }
    return true;
  }

  /// 出牌；返回是否有可claim动作
  bool discard(int seat, int tile) {
    if (!canDiscard(seat, tile)) {
      throw StateError('不能出这张牌 seat=$seat tile=$tile');
    }
    final p = players[seat];
    p.hand.remove(tile);
    p.discards.add(tile);
    p.passedHuTiles.clear(); // 自己出牌后过手限制解除
    lastDiscard = {'seat': seat, 'tile': tile};
    // 杠上炮标记：刚杠完摸牌的人打出的这张
    discardAfterGang = gangDiscarder == seat;
    gangDiscarder = null;
    firstRound = false;
    log('discard', {'seat': seat, 'tile': tile});

    final options = <int, List<String>>{};
    for (var s = 0; s < 4; s++) {
      if (s == seat || players[s].isHued) continue;
      final acts = availableClaimActions(s, tile);
      if (acts.isNotEmpty) options[s] = acts;
    }
    if (options.isEmpty) {
      nextTurn((seat + 1) % 4);
      return false;
    }
    pendingClaim = {'tile': tile, 'from': seat, 'options': options};
    claims = {};
    phase = 'claim';
    return true;
  }

  List<String> availableClaimActions(int seat, int tile) {
    final acts = <String>[];
    final c = countsOf(seat);
    final p = players[seat];
    // 过手规则：被自己过掉的同种牌，出牌前不能再胡
    if (voided(seat) && !p.passedHuTiles.contains(tile)) {
      final cc = List<int>.filled(27, 0);
      for (final t in [...p.hand, tile]) {
        cc[t]++;
      }
      if (isWin(cc, p.melds.length)) acts.add('hu');
    }
    if (c[tile] >= 2) acts.add('peng');
    if (c[tile] == 3) acts.add('minggang');
    return acts;
  }

  /// 回应碰/杠/胡；pass 跳过。返回 true 表示还有待回应
  void claim(int seat, String action) {
    if (phase != 'claim') throw StateError('当前没有待回应的牌');
    final options = pendingClaim!['options'] as Map<int, List<String>>;
    if (!options.containsKey(seat)) {
      if (action == 'pass') return evaluateClaims();
      throw StateError('座位 $seat 无权对该牌行动');
    }
    claims[seat] = action;
    // 过手：有胡却选择过 → 该牌在自己出牌前不能再胡
    if (action == 'pass' && (options[seat] ?? []).contains('hu')) {
      players[seat].passedHuTiles.add(pendingClaim!['tile'] as int);
    }
    evaluateClaims();
  }

  /// 该谁回应了（UI 提示用）：按顺序第一个有权且未回应的
  int? nextClaimant() {
    if (phase != 'claim') return null;
    final options = pendingClaim!['options'] as Map<int, List<String>>;
    for (final s in options.keys) {
      if (!claims.containsKey(s)) return s;
    }
    return null;
  }

  void evaluateClaims() {
    final claim0 = pendingClaim;
    if (claim0 == null) return;
    final tile = claim0['tile'] as int;
    final from = claim0['from'] as int;
    final claimants = claims.entries.where((e) => e.value != 'pass').toList();

    final hus = claimants.where((e) => e.value == 'hu').toList();
    if (hus.isNotEmpty) {
      for (final e in hus) {
        doDianpaoHu(e.key, from, tile);
      }
      pendingClaim = null;
      phase = 'draw';
      continueBloodbattle(from);
      return;
    }
    final pengs = claimants
        .where((e) => e.value == 'peng' || e.value == 'minggang')
        .toList();
    if (pengs.isNotEmpty) {
      final e = pengs.first;
      pendingClaim = null;
      phase = 'draw';
      if (e.value == 'peng') {
        doPeng(e.key, from, tile);
      } else {
        doMingGang(e.key, from, tile);
      }
      return;
    }
    // 全部过
    final bugangSeat = pendingBugang;
    pendingClaim = null;
    phase = 'draw';
    if (bugangSeat != null && lastBugangTile != null) {
      final t2 = lastBugangTile!;
      pendingBugang = null;
      lastBugangTile = null;
      doBugang(bugangSeat, t2);
      return;
    }
    nextTurn((from + 1) % 4);
  }

  void doPeng(int seat, int from, int tile) {
    final p = players[seat];
    p.hand.remove(tile);
    p.hand.remove(tile);
    p.melds.add(Meld('peng', [tile, tile, tile], from: from));
    turn = seat;
    phase = 'discard';
    log('peng', {'seat': seat, 'tile': tile, 'from': from});
  }

  /// 刮风下雨：杠的即时收费（明杠=刮风，暗杠=下雨）
  void gangPay(int seat, String type, int from) {
    final gang = players[seat];
    if (type == 'minggang') {
      players[from].pay -= 2;
      gang.pay += 2;
      log('gang_pay', {
        'seat': seat,
        'type': type,
        'label': '明杠（刮风）',
        'detail': '${players[from].name} 付 2 分',
        'amount': 2,
      });
    } else if (type == 'angang') {
      for (final o in activePlayers()) {
        if (o.seat == seat) continue;
        o.pay -= 2;
        gang.pay += 2;
      }
      log('gang_pay', {
        'seat': seat,
        'type': type,
        'label': '暗杠（下雨）',
        'detail': '其余各家付 2 分',
        'amount': 2,
      });
    } else {
      for (final o in activePlayers()) {
        if (o.seat == seat) continue;
        o.pay -= 1;
        gang.pay += 1;
      }
      log('gang_pay', {
        'seat': seat,
        'type': type,
        'label': '补杠',
        'detail': '其余各家付 1 分',
        'amount': 1,
      });
    }
  }

  void doMingGang(int seat, int from, int tile) {
    final p = players[seat];
    for (var i = 0; i < 3; i++) {
      p.hand.remove(tile);
    }
    p.melds.add(Meld('minggang', [tile, tile, tile, tile], from: from));
    gangPay(seat, 'minggang', from);
    drawFor(seat, afterGang: true);
    log('minggang', {'seat': seat, 'tile': tile, 'from': from});
  }

  /// 自己回合内杠（暗杠/补杠）
  Map<String, dynamic> gang(int seat, int tile, String type) {
    final p = players[seat];
    if (state != statePlaying || turn != seat || phase != 'discard') {
      throw StateError('当前不能杠');
    }
    final c = countsOf(seat);
    if (type == 'angang') {
      if (c[tile] != 4) throw StateError('暗杠需要 4 张');
      for (var i = 0; i < 4; i++) {
        p.hand.remove(tile);
      }
      p.melds.add(Meld('angang', [tile, tile, tile, tile], from: seat));
      gangPay(seat, 'angang', seat);
      drawFor(seat, afterGang: true);
    } else if (type == 'bugang') {
      final peng = p.melds.any((m) => m.type == 'peng' && m.tiles[0] == tile);
      if (!peng || c[tile] != 1) throw StateError('补杠不合法');
      // 抢杠窗口
      final qiang = <int>[];
      for (var s = 0; s < 4; s++) {
        if (s == seat || players[s].isHued) continue;
        final cc = List<int>.filled(27, 0);
        for (final t in [...players[s].hand, tile]) {
          cc[t]++;
        }
        if (isWin(cc, players[s].melds.length)) qiang.add(s);
      }
      if (qiang.isNotEmpty) {
        pendingClaim = {'tile': tile, 'from': seat, 'options': {for (final s in qiang) s: ['hu']}};
        claims = {};
        phase = 'claim';
        pendingBugang = seat;
        lastBugangTile = tile;
        return {'qianggangPossible': qiang};
      }
      doBugang(seat, tile);
    } else {
      throw ArgumentError('未知杠类型: $type');
    }
    log(type, {'seat': seat, 'tile': tile});
    return {'ok': true};
  }

  void doBugang(int seat, int tile) {
    final p = players[seat];
    p.hand.remove(tile);
    final peng = p.melds.firstWhere((m) => m.type == 'peng' && m.tiles[0] == tile);
    peng.type = 'bugang';
    peng.tiles.add(tile);
    gangPay(seat, 'bugang', seat);
    drawFor(seat, afterGang: true);
    log('bugang', {'seat': seat, 'tile': tile});
  }

  int? nextActiveSeat(int from) {
    for (var i = 1; i <= 4; i++) {
      final s = (from + i) % 4;
      if (!players[s].isHued) return s;
    }
    return null;
  }

  void nextTurn(int seat) {
    if (players[seat].isHued) {
      final s = nextActiveSeat(seat);
      if (s == null) return settleDraw();
      seat = s;
    }
    if (wall.isEmpty || activePlayers().length <= 1) {
      settleDraw();
      return;
    }
    drawFor(seat, afterGang: false);
  }

  List<PlayerState> activePlayers() =>
      players.where((p) => !p.isHued).toList();

  /// 摸牌并检查自摸/杠
  void drawFor(int seat, {required bool afterGang}) {
    if (wall.isEmpty) {
      settleDraw();
      return;
    }
    final tile = wall.removeAt(0);
    final p = players[seat];
    p.hand.add(tile);
    p.hand.sort();
    turn = seat;
    // 杠上炮跟踪：杠后摸牌的人打出即触发
    gangDiscarder = afterGang ? seat : null;
    lastDraw = {'seat': seat, 'tile': tile};
    log('draw', {'seat': seat, 'tile': afterGang ? tile : null, 'hidden': !afterGang});

    // 自摸检查（必须已打缺；过手的同种牌不能再自摸）
    final cc = countsOf(seat);
    if (voided(seat) &&
        !p.passedHuTiles.contains(tile) &&
        isWin(cc, p.melds.length)) {
      p.canSelfDraw = {'tile': tile, 'winType': afterGang ? 'gangshanghua' : 'zimo'};
    } else {
      p.canSelfDraw = null;
    }
    p.canGangTiles = [];
    for (var t = 0; t < 27; t++) {
      if (cc[t] == 4) {
        p.canGangTiles.add(t); // 暗杠
      } else if (cc[t] == 1 && p.melds.any((m) => m.type == 'peng' && m.tiles[0] == t)) {
        p.canGangTiles.add(t); // 补杠
      }
    }
    phase = 'discard';
  }

  /// 自摸胡
  void hu(int seat) {
    final p = players[seat];
    if (p.canSelfDraw == null) throw StateError('无自摸');
    doZimoHu(seat, p.canSelfDraw!['tile'] as int, p.canSelfDraw!['winType'] as String);
  }

  /// 过自摸：放弃本次自摸，继续出牌把牌做大
  /// 过手规则：被过的这张牌在玩家自己出牌前，不能再胡同种牌
  void passSelfDraw(int seat) {
    final p = players[seat];
    if (p.canSelfDraw == null) throw StateError('当前没有可过的自摸');
    final tile = p.canSelfDraw!['tile'] as int;
    log('pass_zimo', {'seat': seat, 'tile': tile});
    p.canSelfDraw = null;
    p.passedHuTiles.add(tile);
  }

  void doZimoHu(int seat, int tile, String winType) {
    final p = players[seat];
    final cc = countsOf(seat);
    final result = scoreHand(cc, p.melds, tile,
        {'winType': winType, 'isFirstRound': firstRound});
    p.hu = {
      'winType': winType,
      'tile': tile,
      'fans': result.fans.map((f) => {'name': f.key, 'fan': f.value}).toList(),
      'base': result.base,
    };
    p.canSelfDraw = null;
    final payers = activePlayers().where((o) => o.seat != seat).map((o) => o.name).toList();
    log('zimo', {'seat': seat, 'tile': tile, 'base': result.base, 'payers': payers});
    for (final other in activePlayers()) {
      if (other.seat == seat) continue;
      other.pay -= result.base;
      p.pay += result.base;
    }
    firstRound = false;
    continueBloodbattle(seat);
  }

  void doDianpaoHu(int seat, int from, int tile) {
    final p = players[seat];
    p.hand.add(tile);
    final cc = countsOf(seat);
    // 杠上炮：点炮者刚杠完摸牌打出 → 点炮加一翻
    final winType = discardAfterGang ? 'gangshangpao' : 'dianpao';
    final result = scoreHand(cc, p.melds, tile,
        {'winType': winType, 'isFirstRound': firstRound});
    p.hu = {
      'winType': winType,
      'tile': tile,
      'fans': result.fans.map((f) => {'name': f.key, 'fan': f.value}).toList(),
      'base': result.base,
    };
    final shooter = players[from];
    shooter.pay -= result.base;
    p.pay += result.base;
    log('dianpao', {'seat': seat, 'from': from, 'tile': tile, 'base': result.base});
  }

  void continueBloodbattle(int afterSeat) {
    final active = activePlayers();
    if (active.isEmpty || wall.isEmpty) {
      settleDraw();
      return;
    }
    final next = nextActiveSeat(afterSeat);
    if (next == null) {
      settleDraw();
      return;
    }
    nextTurn(next);
  }

  /// 流局结算（查大叫）
  /// 查叫听牌判定：支持 13 张与 14 张（最后摸牌者）手牌
  /// 返回 [是否听牌, 最大自摸分]
  List<dynamic> _tingHandCheck(PlayerState p) {
    final cc = countsOf(p.seat);
    final total = cc.fold<int>(0, (a, b) => a + b);
    if (total == 14) {
      // 最后摸牌者：胡形 即听；或弃任意一张后仍听
      if (isWin(cc, p.melds.length)) {
        var best = 0;
        for (var t = 0; t < 27; t++) {
          if (cc[t] == 0) continue;
          final r = scoreHand(cc, p.melds, t,
              {'winType': 'zimo', 'isFirstRound': false});
          if (r.base > best) best = r.base;
        }
        return [true, best];
      }
      for (var d = 0; d < 27; d++) {
        if (cc[d] == 0) continue;
        cc[d]--;
        final ting = tingTiles(cc, p.melds.length, p.dingque);
        cc[d]++;
        if (ting.isNotEmpty) {
          final waits = <int>{};
          // 最大自摸分：枚举 弃 d 进 p 的组合
          var best = 0;
          for (var t = 0; t < 27; t++) {
            if (cc[t] == 0) continue;
            cc[d]--;
            cc[t]++;
            if (isWin(cc, p.melds.length)) {
              final r = scoreHand(cc, p.melds, t,
                  {'winType': 'zimo', 'isFirstRound': false});
              if (r.base > best) best = r.base;
            }
            cc[t]--;
            cc[d]++;
          }
          // 明细：胡牌形（听牌张即手中牌）
          return [true, best, <int>[]];
        }
      }
      return [false, 0, <int>[]];
    }
    // 13 张：标准听牌
    final ting = tingTiles(cc, p.melds.length, p.dingque);
    if (ting.isEmpty) return [false, 0];
    var best = 0;
    for (final tile in ting) {
      final cc2 = [...cc];
      cc2[tile]++;
      final r = scoreHand(cc2, p.melds, tile,
          {'winType': 'zimo', 'isFirstRound': false});
      if (r.base > best) best = r.base;
    }
    return [true, best, ting];
  }

  void settleDraw() {
    state = stateOver;
    // 查大叫 + 查花猪：花猪（未听且三门俱全）大赔
    const huazhuFan = 16;
    final tings = <PlayerState>[];
    final huazhus = <PlayerState>[];
    for (final p in activePlayers()) {
      final suits = p.hand.map((t) => tileSuit(t)).toSet();
      p.isHuaZhu = suits.length == 3;
      // 听牌判定（支持 13/14 张，按自摸最大方式计赔）
      final check = _tingHandCheck(p);
      p.isTing = !p.isHuaZhu && (check[0] as bool);
      if (p.isTing) {
        p.bestTingScore = check[1] as int;
        p.tingDetail = List<int>.from(check[2] as List);
        tings.add(p);
      } else if (p.isHuaZhu) {
        huazhus.add(p);
      }
    }
    // 花猪先赔：赔给其他每个未胡玩家 16 分
    for (final h in huazhus) {
      for (final o in activePlayers()) {
        if (o == h) continue;
        h.pay -= huazhuFan;
        o.pay += huazhuFan;
      }
      log('huazhu', {'seat': h.seat, 'name': h.name, 'amount': huazhuFan});
    }
    // 查大叫：未听（非花猪）→ 赔每个听牌者
    for (final p in activePlayers()) {
      if (!p.isTing && !p.isHuaZhu) {
        for (final t in tings) {
          if (t == p) continue;
          p.pay -= t.bestTingScore;
          t.pay += t.bestTingScore;
        }
        if (tings.isNotEmpty) {
          log('chadajiao', {
            'seat': p.seat,
            'count': tings.length,
            'amount': tings.fold<int>(0, (a, t) => a + t.bestTingScore),
            'toNames': tings.map((t) => t.name).join('、'),
          });
        }
      }
    }
    log('liuju', {});
  }

  /// 当前是否等待玩家(人类)操作
  bool waitingForHuman() {
    if (state == stateHuan) {
      return players[0].isHuman && !exchangePicks.containsKey(0);
    }
    if (state != statePlaying) return false;
    if (phase == 'claim') {
      final who = nextClaimant();
      return who != null && players[who].isHuman;
    }
    return phase == 'discard' && players[turn].isHuman;
  }
}
