// 川麻血战到底 —— 主入口与牌桌界面（v1：单机模式，纯自绘 UI）

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart' hide Table;

import 'game/tiles.dart';
import 'game/table.dart';
import 'game/win.dart' show tingTiles;
import 'game/scoring.dart' show Meld;
import 'game/bot.dart';
import 'online_page.dart';
import 'widgets/jade_tile.dart';
import 'widgets/dice_intro.dart';
import 'sound_manager.dart';
import 'capture/screenshot.dart';

void main() {
  runApp(const ChuanMahjongApp());
}

class ChuanMahjongApp extends StatelessWidget {
  const ChuanMahjongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '川麻血战到底',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _difficulty = 'normal'; // easy | normal | hard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.3,
            colors: [Color(0xFF33691E), Color(0xFF1B5E20), Color(0xFF0D3311)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 三张玉石牌装饰
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.12,
                    child: const MahjongTileWidget(tile: 8, width: 52, height: 72, raised: true),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: Transform.rotate(
                      angle: 0,
                      child: const MahjongTileWidget(tile: 23, width: 56, height: 78, raised: true),
                    ),
                  ),
                  Transform.rotate(
                    angle: 0.12,
                    child: const MahjongTileWidget(tile: 16, width: 52, height: 72, raised: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  '川麻血战到底',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                    fontFamily: 'serif',
                    shadows: [
                      Shadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 6),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('缺一门 · 定缺 · 血战到底',
                  style: TextStyle(color: Colors.white70, letterSpacing: 4)),
              const SizedBox(height: 44),
              // AI 难度选择
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final d in const [('简单', 'easy'), ('普通', 'normal'), ('困难', 'hard')])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        onTap: () => setState(() => _difficulty = d.$2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: _difficulty == d.$2
                                ? const Color(0xFFFFD54F)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _difficulty == d.$2
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            d.$1,
                            style: TextStyle(
                              color: _difficulty == d.$2
                                  ? Colors.brown
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _bigButton(
                context,
                icon: Icons.sports_esports,
                label: '单机模式 · 3 个机器人',
                gradient: const [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GamePage(difficulty: _difficulty)),
                  );
                },
              ),
              const SizedBox(height: 14),
              _bigButton(
                context,
                icon: Icons.wifi,
                label: '联机对战',
                gradient: const [Color(0xFF00695C), Color(0xFF004D40)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnlinePage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton(BuildContext context,
      {required IconData icon,
      required String label,
      required List<Color> gradient,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5)),
          boxShadow: const [
            BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFD54F)),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------------- 牌桌页 ----------------

/// 换三张选牌逻辑（纯函数，可测试）：按数量增减，同值两张可各选一张
/// 点已选满的同值牌 → 退回一张
List<int> toggleExchangePick(List<int> sel, List<int> hand, int tile) {
  final result = [...sel];
  final selCount = result.where((x) => x == tile).length;
  final handCount = hand.where((x) => x == tile).length;
  if (selCount > 0 && selCount >= handCount) {
    result.remove(tile); // 退回一张
    return result;
  }
  if (result.length >= 3) return sel; // 已满，不加
  result.add(tile);
  return result;
}

class GamePage extends StatefulWidget {
  final Table? injectedTable; // 测试用：注入固定牌局
  final String difficulty; // easy | normal | hard
  const GamePage({super.key, this.injectedTable, this.difficulty = 'normal'});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late Table table;
  late Bot bot;
  final mySeat = 0;
  bool _advancing = false;
  final Random _thinkRng = Random.secure();

  /// AI 思考停顿：模拟真人节奏（1.8~4.3 秒随机），一局约 3 分钟以上
  Duration botThinkDelay() =>
      Duration(milliseconds: 1200 + _thinkRng.nextInt(800));

  // 跨局累计积分（按座位）与局数
  final Map<int, int> totalScores = {0: 0, 1: 0, 2: 0, 3: 0};
  int roundNo = 0;
  bool _settled = false;
  final Set<int> _announcedHu = {};
  final List<int> _exchangeSel = []; // 可含同值牌（两张一样算两张）
  int _lastEventIdx = 0;
  List<int> _preExchangeHand = []; // 换牌前手牌快照
  bool _dealing = false; // 发牌动画进行中
  int _dealtCount = 0; // 已发张数
  Timer? _dealTimer;
  int? _lastDrawnTile;
  final List<Map<String, dynamic>> _floaters = [];
  final GlobalKey _resultKey = GlobalKey(); // 战报截图 // 碰杠飘字
  int _floaterSeq = 0;
  bool _huFlash = false; // 胡牌全屏特效
  Map<String, dynamic>? exchangeBanner; // 换三张「换出→换入」横幅
  Map<String, dynamic>? lastExchangeInfo; // 换三张回顾（进结算页）
  Map<String, dynamic>? huBanner; // 胡牌横幅数据
  int die1 = 1, die2 = 1; // 第一次骰子：换三张方向
  int die3 = 1, die4 = 1; // 第二次骰子：起牌墙位
  bool _diceIntro = false; // 开局摇骰子动画
  bool _counterOpen = false; // 记牌器开关
  int? _counterSuit; // 记牌器花色过滤：null=全部

  static const sideLabels = ['东家墙', '南家墙', '西家墙', '北家墙'];

  /// 掷骰子：第一次定换三张方向，第二次定起牌墙位
  void rollDice() {
    final r = Random.secure();
    die1 = r.nextInt(6) + 1;
    die2 = r.nextInt(6) + 1;
    die3 = r.nextInt(6) + 1;
    die4 = r.nextInt(6) + 1;
  }

  Table newTable() {
    rollDice();
    final t = Table(
      ['我', '南风', '西风', '北风'],
      exchangeMode: (die1 + die2) % 3,
      wallStartSide: (die3 + die4) % 4,
    );
    t.log('dice_exchange', {
      'd1': die1,
      'd2': die2,
      'direction': t.exchangeDirectionLabel(),
    });
    t.log('dice_draw', {
      'd3': die3,
      'd4': die4,
      'startSide': sideLabels[(die3 + die4) % 4],
    });
    return t;
  }

  /// 开局摇骰子 → 动画结束后开始推进
  void _startWithDice() {
    setState(() => _diceIntro = true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.injectedTable != null) {
      // 测试模式：跳过摇骰子动画，直接推进
      table = widget.injectedTable!;
      bot = Bot(table, difficulty: widget.difficulty);
      WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
    } else {
      table = newTable();
      bot = Bot(table, difficulty: widget.difficulty);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startWithDice());
    }
  }

  /// 带节奏地推进对局：每个 bot 动作之间留思考停顿
  Future<void> _advance() async {
    if (_advancing) return;
    _advancing = true;
    try {
      while (mounted) {
        var r = stepBot(table, bot);
        if (r == 'over') break;
        // 轮到人类时：缺门只剩一张 → 系统自动打掉
        if (r == 'waiting' && _autoDiscardLastDingque()) {
          r = 'acted';
        }
        if (r == 'waiting') break;
        if (mounted) setState(() {});
        _announceHu();
        // 出牌/胡牌用真人节奏；换牌、定缺等准备动作用快节奏
        await Future.delayed(
            table.state == statePlaying ? botThinkDelay() : const Duration(milliseconds: 350));
      }
    } finally {
      _advancing = false;
    }
    if (!mounted) return;
    setState(() {});
    _announceHu();
    _updateDrawnTile();
    // 摸牌音效（仅自己摸牌）
    final ld2 = table.lastDraw;
    if (ld2 != null && ld2['seat'] == mySeat) SoundManager.drawSound();
    if (table.state == stateOver) _showResult();
  }

  /// 记录/清除「刚摸的牌」高亮
  void _updateDrawnTile() {
    final ld = table.lastDraw;
    if (table.state == statePlaying &&
        table.phase == 'discard' &&
        table.turn == mySeat &&
        ld != null &&
        ld['seat'] == mySeat) {
      _lastDrawnTile = ld['tile'] as int?;
    } else {
      _lastDrawnTile = null;
    }
  }

  /// 发牌动画：手牌逐张亮出，发完自动推进
  void _startDealing() {
    setState(() {
      _dealing = true;
      _dealtCount = 0;
    });
    _dealTimer?.cancel();
    _dealTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _dealtCount++;
      setState(() {});
      if (_dealtCount >= table.players[mySeat].hand.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() => _dealing = false);
          unawaited(_advance());
        });
      }
    });
  }

  /// 缺门只剩一张时自动打掉；返回是否执行了
  bool _autoDiscardLastDingque() {
    if (table.state != statePlaying ||
        table.phase != 'discard' ||
        table.turn != mySeat) {
      return false;
    }
    final me = table.players[mySeat];
    final q = me.dingque;
    if (q == null || table.voided(mySeat)) return false;
    final dingqueTiles = me.hand.where((t) => tileSuit(t) == q).toList();
    if (dingqueTiles.length != 1) return false;
    table.discard(mySeat, dingqueTiles[0]);
    SoundManager.discard();
    setState(() {
      huBanner = {
        'kind': 'gang',
        'text': '🤖 自动打缺：最后一张${suitNames[q]}已打出',
      };
    });
    return true;
  }

  /// 在对应玩家位置弹飘字
  void _addFloater(int seat, String text) {
    final id = ++_floaterSeq;
    setState(() => _floaters.add({'id': id, 'seat': seat, 'text': text}));
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _floaters.removeWhere((f) => f['id'] == id));
    });
  }

  /// 检测新胡牌并显示牌型横幅
  void _announceHu() {
    // 刮风下雨提示
    final evts = table.events;
    for (; _lastEventIdx < evts.length; _lastEventIdx++) {
      final e = evts[_lastEventIdx];
      // 碰/杠飘字特效
      if (e.type == 'peng' || e.type == 'minggang' || e.type == 'angang' || e.type == 'bugang') {
        SoundManager.gang();
        if (e.type == 'peng') SoundManager.peng();
        final label = e.type == 'peng'
            ? '碰！'
            : e.type == 'bugang'
                ? '补杠！'
                : '杠！';
        _addFloater(e.data['seat'] as int, label);
      }
      if (e.type == 'gang_pay') {
        final gang = table.players[e.data['seat'] as int];
        setState(() {
          huBanner = {
            'kind': 'gang',
            'text': '💰 ${gang.name} ${e.data['label']}：${e.data['detail']}',
          };
        });
      }
      if (e.type == 'huazhu') {
        setState(() {
          huBanner = {
            'kind': 'gang',
            'text': '🐷 ${e.data['name']} 花猪（三门俱全）· 赔 16×家数',
          };
        });
      }
      if (e.type == 'huazhu' || e.type == 'chadajiao') {
        SoundManager.qiao();
      }
      if (e.type == 'chadajiao') {
        final p = table.players[e.data['seat'] as int];
        setState(() {
          huBanner = {
            'kind': 'gang',
            'text': '🔎 查大叫：${p.name} 未听 → 赔 ${e.data['amount']} 分',
          };
        });
      }
      if (e.type == 'exchange') {
        _announceExchange();
      }
    }
    for (final p in table.players) {
      if (p.hu != null && !_announcedHu.contains(p.seat)) {
        _announcedHu.add(p.seat);
        final hu = p.hu!;
        final fansText =
            (hu['fans'] as List).map((f) => (f as Map)['name']).join(' · ');
        setState(() {
          huBanner = {
            'kind': 'hu',
            'name': p.name,
            'winType': hu['winType'],
            'fansText': fansText.isEmpty ? '平胡' : fansText,
            'base': hu['base'],
          };
        });
        (hu['fans'] as List).any((f) => (f as Map)['name'] == '封顶')
            ? SoundManager.win()
            : SoundManager.hu();
        _huFlash = true;
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _huFlash = false);
        });
      }
    }
  }

  void _showResult() {
    if (!_settled) {
      _settled = true;
      roundNo++;
      for (final p in table.players) {
        totalScores[p.seat] = (totalScores[p.seat] ?? 0) + p.pay;
      }
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('对局结束 · 第 $roundNo 局'),
        content: RepaintBoundary(
          key: _resultKey,
          child: SizedBox(
            width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 换三张回顾
              if (lastExchangeInfo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('换三张',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      for (final t in (lastExchangeInfo!['gave'] as List))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: MiniTile(tile: t as int),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      for (final t in (lastExchangeInfo!['received'] as List))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: MiniTile(tile: t as int),
                        ),
                    ],
                  ),
                ),
              // 分数柱状图（按累计分归一化）
              if (totalScores.values.any((v) => v != 0))
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF388E3C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('战绩图',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      for (final p in table.players)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 40,
                                  child: Text(p.name,
                                      style: const TextStyle(fontSize: 11))),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.black12,
                                        borderRadius:
                                            BorderRadius.circular(5),
                                      ),
                                    ),
                                    LayoutBuilder(builder: (context, cons) {
                                      final v =
                                          totalScores[p.seat] ?? 0;
                                      final maxAbs = table.players
                                          .map((q) =>
                                              (totalScores[q.seat] ?? 0)
                                                  .abs())
                                          .reduce((a, b) =>
                                              a > b ? a : b);
                                      final w = maxAbs == 0
                                          ? 0.0
                                          : v.abs() / maxAbs * 0.5;
                                      return Align(
                                        alignment: v >= 0
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                        child: Container(
                                          height: 10,
                                          width: cons.maxWidth * w,
                                          decoration: BoxDecoration(
                                            color: v >= 0
                                                ? Colors.lightGreen
                                                : Colors.redAccent,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              SizedBox(
                                  width: 36,
                                  child: Text(
                                      '${(totalScores[p.seat] ?? 0) >= 0 ? "+" : ""}${totalScores[p.seat] ?? 0}',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: (totalScores[p.seat] ?? 0) >= 0
                                              ? Colors.green
                                              : Colors.red))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              // 查叫 / 花猪明细
              if (table.events.any((e) => e.type == 'chadajiao' || e.type == 'huazhu'))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in table.events)
                        if (e.type == 'chadajiao')
                          Text(
                            '🔎 查大叫：${table.players[e.data['seat'] as int].name} 未听 → 赔 ${e.data['amount']} 分',
                            style: const TextStyle(fontSize: 12),
                          )
                        else if (e.type == 'huazhu')
                          Text(
                            '🐷 查花猪：${table.players[e.data['seat'] as int].name} 三门俱全 → 赔 16×家数',
                            style: const TextStyle(fontSize: 12),
                          ),
                    ],
                  ),
                ),
              for (final p in table.players)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${p.name}${p.hu != null ? " 🀄胡" : (p.isTing ? " · 听牌" : " · 未听")}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '本局 ${p.pay >= 0 ? "+" : ""}${p.pay} · 累计 ${(totalScores[p.seat] ?? 0) >= 0 ? "+" : ""}${totalScores[p.seat] ?? 0}',
                            style: TextStyle(
                              color: (totalScores[p.seat] ?? 0) >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (p.hu != null)
                        Text(
                          '牌型：${(p.hu!['fans'] as List).map((f) => (f as Map)['name']).join(' · ')}（${p.hu!['base']} 分）',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade800),
                        ),
                      const SizedBox(height: 4),
                      // 摊牌：手牌
                      Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          for (final t in sortHand(p.hand))
                            MiniTile(tile: t),
                          for (final m in p.melds)
                            for (var i = 0; i < m.tiles.length; i++)
                              Opacity(
                                opacity: m.type == 'angang' && i > 2 ? 0.5 : 1,
                                child: MiniTile(tile: m.tiles[i]),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回大厅'),
          ),
          TextButton(
            onPressed: () async {
              final bytes = await captureWidget(_resultKey);
              if (bytes != null) {
                await downloadBytes(bytes, '川麻战报_第$roundNo局.png');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('战报图已保存到下载')),
                  );
                }
              }
            },
            child: const Text('保存战报图'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                table = newTable();
                bot = Bot(table, difficulty: widget.difficulty);
                _announcedHu.clear();
                huBanner = null;
                exchangeBanner = null;
                lastExchangeInfo = null;
                _preExchangeHand = [];
                _settled = false;
                _lastEventIdx = 0;
                _exchangeSel.clear();
              });
              _startWithDice(); // 新一局先摇骰子，动画结束后再推进
            },
            child: const Text('再来一局'),
          ),
        ],
      ),
    );
  }

  // ---- 人类操作 ----

  bool get needExchange =>
      table.state == stateHuan && table.waitingForHuman();

  void _tapHandTile(int tile) {
    // 换三张阶段：按数量增减选择（同值两张可以各选一张）
    if (needExchange) {
      final hand = table.players[mySeat].hand;
      final selCount = _exchangeSel.where((x) => x == tile).length;
      final handCount = hand.where((x) => x == tile).length;
      final removing = selCount > 0 && selCount >= handCount;
      if (!removing) {
        if (_exchangeSel.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('已经选满 3 张了'), duration: Duration(seconds: 1)),
          );
          return;
        }
        if (_exchangeSel.isNotEmpty &&
            tileSuit(_exchangeSel.first) != tileSuit(tile)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('换三张必须是同门的牌！'), duration: Duration(seconds: 1)),
          );
          return;
        }
      }
      setState(() {
        // 先在旧选择上计算新列表，再整体替换（顺序不能反！）
        final next = toggleExchangePick(_exchangeSel, hand, tile);
        _exchangeSel
          ..clear()
          ..addAll(next);
      });
      return;
    }
    if (!table.waitingForHuman() || table.phase != 'discard') return;
    if (!table.canDiscard(mySeat, tile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没打缺，必须先打缺门的牌！'), duration: Duration(seconds: 1)),
      );
      return;
    }
    table.discard(mySeat, tile);
    SoundManager.discard();
    _lastDrawnTile = null;
    unawaited(_advance());
  }

  void _confirmExchange() {
    if (_exchangeSel.length != 3) return;
    // 记录换牌前手牌快照，用于换牌完成后显示「换出 → 换入」
    _preExchangeHand = [...table.players[mySeat].hand];
    table.exchange(mySeat, _exchangeSel.toList());
    _exchangeSel.clear();
    unawaited(_advance());
  }

  /// 换三张完成后计算「换出 / 换入」并弹横幅
  void _announceExchange() {
    if (_preExchangeHand.isEmpty) return;
    final gave = [...table.exchangePicks[mySeat] ?? <int>[]];
    if (gave.isEmpty) return;
    // 换入 = 当前手牌 - 换牌前手牌（多重集差）
    final remaining = [..._preExchangeHand];
    final received = <int>[];
    for (final t in sortHand(table.players[mySeat].hand)) {
      final idx = remaining.indexOf(t);
      if (idx >= 0) {
        remaining.removeAt(idx);
      } else {
        received.add(t);
      }
    }
    setState(() {
      exchangeBanner = {
        'gave': gave,
        'received': received,
        'direction': table.exchangeDirectionLabel(),
      };
      lastExchangeInfo = {
        'gave': gave,
        'received': received,
        'direction': table.exchangeDirectionLabel(),
      };
    });
    _preExchangeHand = [];
  }

  void _claim(String action) {
    table.claim(mySeat, action);
    unawaited(_advance());
  }

  void _selfHu() {
    _lastDrawnTile = null;
    table.hu(mySeat);
    unawaited(_advance());
  }

  /// 过自摸：放弃本次自摸，继续出牌把牌做大
  void _passSelfDraw() {
    table.passSelfDraw(mySeat);
    SoundManager.pass();
    setState(() {
      huBanner = {
        'kind': 'gang',
        'text': '🎯 已过自摸 · 继续把牌做大',
      };
    });
  }

  void _gang(int tile) {
    final p = table.players[mySeat];
    final isPeng = p.melds.any((m) => m.type == 'peng' && m.tiles[0] == tile);
    table.gang(mySeat, tile, isPeng ? 'bugang' : 'angang');
    unawaited(_advance());
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final needDingque = table.state == stateDingque &&
        table.players[mySeat].dingque == null;
    final needClaim = table.phase == 'claim' && table.waitingForHuman();
    final myTurn = table.phase == 'discard' &&
        table.turn == mySeat &&
        !table.players[mySeat].isHued;
    final me = table.players[mySeat];

    return Scaffold(
      backgroundColor: const Color(0xFF0D3311),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text('血战到底 · 余牌 ${table.wall.length}'),
            const SizedBox(width: 12),
            // 缺门醒目提示：缺什么、还剩几张
            Builder(builder: (context) {
              final q = table.players[mySeat].dingque;
              if (q == null) {
                return const Text('待定缺',
                    style: TextStyle(color: Colors.white38, fontSize: 13));
              }
              final left = table
                  .players[mySeat].hand
                  .where((t) => tileSuit(t) == q)
                  .length;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: left > 0
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  left > 0 ? '缺${suitNames[q]} · 还剩 $left 张' : '已打缺 ✓',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
        actions: [
          // 记牌器开关
          IconButton(
            icon: Icon(
              Icons.calculate_outlined,
              color: _counterOpen ? const Color(0xFFFFD54F) : Colors.white,
            ),
            tooltip: '记牌器',
            onPressed: () => setState(() => _counterOpen = !_counterOpen),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => _showScoreboard(context),
          ),
          // 音效开关
          IconButton(
            icon: Icon(
              SoundManager.enabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              color: SoundManager.enabled ? Colors.white : Colors.white38,
            ),
            tooltip: '音效',
            onPressed: () => setState(() {
              SoundManager.enabled = !SoundManager.enabled;
              if (!SoundManager.enabled) {
                for (final p in SoundManager.pool.values) {
                  p.stop();
                }
              }
            }),
          ),
          // 规则速查
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: '规则速查',
            onPressed: () => _showRules(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: [Color(0xFF388E3C), Color(0xFF1E5E24), Color(0xFF0D3311)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // 上方：对家（seat 2）
                  _opponentRow(2),
                  // 中间：左右两家 + 牌池
                  Expanded(
                    child: Row(
                      children: [
                    _sideOpponent(1),
                    Expanded(child: _centerArea()),
                    _sideOpponent(3),
                  ],
                ),
              ),
              // 换三张「换出 → 换入」横幅（点击关闭）
              if (exchangeBanner != null)
                GestureDetector(
                  onTap: () => setState(() => exchangeBanner = null),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade700,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('换出',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                        for (final t in (exchangeBanner!['gave'] as List))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: MiniTile(tile: t as int),
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward,
                              color: Color(0xFF90CAF9), size: 18),
                        ),
                        const Text('换入',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                        for (final t in (exchangeBanner!['received'] as List))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: MiniTile(tile: t as int),
                          ),
                        Text(
                          ' · 传给${exchangeBanner!['direction']}',
                          style: const TextStyle(
                              color: Color(0xFF90CAF9),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              // 胡牌横幅（点击关闭）
              if (huBanner != null)
                GestureDetector(
                  onTap: () => setState(() => huBanner = null),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB8860B), Color(0xFF8B6508)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      huBanner!['kind'] == 'gang'
                          ? huBanner!['text'] as String
                          : '🎉 ${huBanner!['name']}'
                              '${huBanner!['winType'] == 'zimo' || huBanner!['winType'] == 'gangshanghua' ? ' 自摸' : huBanner!['winType'] == 'qianggang' ? ' 抢杠胡' : ' 点炮胡'}'
                              '：${huBanner!['fansText']} = ${huBanner!['base']} 分',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              // 动作条
              _actionBar(needDingque, needClaim, myTurn, me),
              // 我的手牌
              _myHand(me),
              // 记牌器面板
              if (_counterOpen) _counterPanel(),
            ],
          ),
        ),
      ),
          // 开局摇骰子动画（第一次换三张方向，第二次起牌墙位）
          if (_diceIntro)
            DiceIntro(
              d1: die1,
              d2: die2,
              d3: die3,
              d4: die4,
              direction: table.exchangeDirectionLabel(),
              startSide: sideLabels[table.wallStartSide],
              onDone: () {
                setState(() => _diceIntro = false);
                _startDealing();
              },
            ),
          // 胡牌全屏特效
          if (_huFlash)
            Container(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.4),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: const Text(
                  '🀄 胡！',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFC62828),
                    shadows: [
                      Shadow(color: Colors.white, blurRadius: 20),
                      Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          // 碰杠飘字特效
          for (final f in _floaters)
            Positioned.fill(
              child: Align(
                alignment: f['seat'] == 2
                    ? Alignment.topCenter
                    : f['seat'] == 0
                        ? Alignment.bottomCenter
                        : f['seat'] == 1
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: f['seat'] == 2 ? 56 : 0,
                    bottom: f['seat'] == 0 ? 180 : 0,
                    left: f['seat'] == 1 ? 32 : 0,
                    right: f['seat'] == 3 ? 32 : 0,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) => Opacity(
                      opacity: v.clamp(0, 1),
                      child: Transform.scale(scale: v, child: child),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFFFD54F), width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black45, blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        f['text'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 是否缺门的牌（需要先打掉）
  bool _isDingqueTile(int tile, PlayerState me) =>
      me.dingque != null && tileSuit(tile) == me.dingque;

  /// 记牌器：按公开信息（所有人的牌河 + 副露 + 自己手牌）计算每张牌剩余张数
  List<int> _visibleCounts() {
    final visible = List<int>.filled(27, 0);
    for (final p in table.players) {
      for (final t in p.discards) {
        visible[t]++;
      }
      for (final m in p.melds) {
        for (final t in m.tiles) {
          visible[t]++;
        }
      }
    }
    for (final t in table.players[mySeat].hand) {
      visible[t]++;
    }
    return visible;
  }

  Widget _counterPanel() {
    final visible = _visibleCounts();
    final suits = _counterSuit == null ? [0, 1, 2] : [_counterSuit!];
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 花色过滤
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('记牌器',
                  style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(width: 8),
              for (final label in ['全部', '万', '条', '筒'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _counterSuit =
                          label == '全部' ? null : ['万', '条', '筒'].indexOf(label);
                    }),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_counterSuit == null && label == '全部') ||
                                (_counterSuit != null &&
                                    label != '全部' &&
                                    ['万', '条', '筒'].indexOf(label) == _counterSuit)
                            ? const Color(0xFF2E7D32)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(label,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ),
            ],
          ),
          // 剩余张数
          for (final s in suits)
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var rank = 1; rank <= 9; rank++)
                    SizedBox(
                      width: 42,
                      child: Column(
                        children: [
                          MiniTile(tile: s * 9 + rank - 1),
                          Text(
                            '${4 - visible[s * 9 + rank - 1]}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: 4 - visible[s * 9 + rank - 1] == 0
                                  ? Colors.redAccent
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 规则速查
  void _showRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('规则速查（成都血战）'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('· 108 张牌（万条筒），无风花', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 摇骰子定换三张方向与起牌墙位', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 换三张：3 张同门，传给骰子指定的方向', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 定缺后必须先打完缺门的牌（红「缺」标记）', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 无吃；碰 / 明杠 / 暗杠 / 补杠', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 自摸 +1 番；过自摸可把牌做大（过手限制）', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 番型：对对胡/金钩钓 +1，清一色/七对 +2，根每根 +1，杠上花/杠上炮/抢杠 +1，天胡/地胡 +6',
                    style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 四番封顶：总番超 4 按 4 计（最高 16 分）', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 刮风下雨：点杠 2 分、暗杠 2×3、补杠 1×3（即时结算）',
                    style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 血战到底：一家胡后继续打，自摸各家付、点炮独付', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 流局查大叫：未听者按听牌者最大自摸分赔', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('· 查花猪：三门俱全未听者赔其他未胡家各 16 分', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
        ],
      ),
    );
  }

  void _showScoreboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('当前战况'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: table.players
              .map((p) => ListTile(
                    dense: true,
                    title: Text('${p.name}${p.isDealer ? "（庄）" : ""}'),
                    subtitle: Text(
                        '累计 ${totalScores[p.seat] ?? 0} · 已打 $roundNo 局',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                      '${p.pay >= 0 ? "+" : ""}${p.pay}',
                      style: TextStyle(
                        color: p.pay >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _opponentRow(int seat) {
    final p = table.players[seat];
    return Padding(
      padding: const EdgeInsets.all(6),
      child: _playerBadge(p, wide: true),
    );
  }

  Widget _sideOpponent(int seat) {
    final p = table.players[seat];
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 84,
        child: _playerBadge(p),
      ),
    );
  }

  Widget _playerBadge(PlayerState p, {bool wide = false}) {
    final active = table.turn == p.seat && table.state == statePlaying;
    final hued = p.isHued;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB8860B), Color(0xFF8B6508)],
              )
            : const LinearGradient(
                colors: [Color(0x42000000), Color(0x26000000)],
              ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? const Color(0xFFFFD54F)
              : hued
                  ? const Color(0xFFFFAB40)
                  : Colors.white24,
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: const Color(0xFFFFD54F).withValues(alpha: 0.35), blurRadius: 10)]
            : null,
      ),
      child: wide
          // 顶部对家：横排（宽度充足，名字可伸缩省略）
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _badgeAvatar(p),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _badgeName(p),
                      _badgeTotal(p),
                      _badgeStatus(p, hued),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!hued) _badgeFan(p, compact: false),
                if (hued)
                  const Icon(Icons.emoji_events, color: Color(0xFFFFAB40), size: 22),
              ],
            )
          // 左右侧家：竖排紧凑（宽度仅 84，避免横向溢出）
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _badgeAvatar(p),
                const SizedBox(height: 3),
                _badgeName(p),
                _badgeTotal(p),
                _badgeStatus(p, hued),
                const SizedBox(height: 3),
                if (!hued) _badgeFan(p, compact: true),
                if (hued)
                  const Icon(Icons.emoji_events, color: Color(0xFFFFAB40), size: 18),
              ],
            ),
    );
  }

  Widget _badgeAvatar(PlayerState p) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [
          Colors.amber.shade300,
          Colors.orange.shade700,
        ]),
      ),
      child: Text(
        p.name.characters.first,
        style: const TextStyle(
            color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _badgeName(PlayerState p) {
    return Text(
      '${p.name}${p.isDealer ? " · 庄" : ""}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _badgeTotal(PlayerState p) {
    final v = totalScores[p.seat] ?? 0;
    return Text(
      '累计 ${v >= 0 ? "+" : ""}$v',
      style: TextStyle(
        color: v >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _badgeStatus(PlayerState p, bool hued) {
    final dq = p.dingque;
    final dqText = dq == null
        ? '待定缺'
        : '缺${suitNames[dq]}${table.voided(p.seat) ? "✓" : "…"}';
    const suitColor = [Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF1565C0)];
    return Text(
      hued ? '胡牌 +${p.hu!['base']}分' : dqText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: hued
            ? const Color(0xFFFFAB40)
            : dq != null
                ? suitColor[dq]
                : Colors.white70,
        fontSize: 10,
        fontWeight: dq != null ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  /// 对手手牌：扇形玉背牌（compact = 侧边窄版）
  Widget _badgeFan(PlayerState p, {required bool compact}) {
    final w = compact ? 10.0 : 17.0;
    final h = compact ? 15.0 : 26.0;
    final step = compact ? 2.6 : 4.4;
    final n = p.hand.length > 13 ? 13 : p.hand.length;
    return SizedBox(
      width: compact ? 42 : 64,
      height: compact ? 17 : 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            Positioned(
              left: i * step,
              top: 0,
              child: JadeTile(tile: 0, width: w, height: h, blank: true),
            ),
        ],
      ),
    );
  }

  Widget _miniMeld(Meld m) {
    final concealed = m.type == 'angang';
    return Container(
      padding: const EdgeInsets.all(2),
      color: Colors.black38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < m.tiles.length; i++)
            if (concealed && i > 0)
              const Text('▒', style: TextStyle(color: Colors.white30, fontSize: 9))
            else
              MiniTile(tile: m.tiles[i]),
        ],
      ),
    );
  }

  /// 副露展示：碰/杠亮在各家面前（暗杠只亮一张）
  /// 副露展示：碰/杠亮在各家面前（暗杠只亮一张），新增时脉冲动画
  Widget _meldDisplay(PlayerState p, {bool vertical = false}) {
    if (p.melds.isEmpty) return const SizedBox.shrink();
    // 每组副露独立滑入动画（新增的副露从右侧滑入）
    Widget meldSlide(int index, Widget group) {
      return TweenAnimationBuilder<double>(
        key: ValueKey('meld-slide-undefined-$index'),
        tween: Tween(begin: 36.0, end: 0.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, dx, child) =>
            Transform.translate(offset: Offset(dx, 0), child: child),
        child: group,
      );
    }

    final melds = vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < p.melds.length; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: meldSlide(i, _meldGroup(p.melds[i]))),
            ],
          )
        : Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < p.melds.length; i++)
                meldSlide(i, _meldGroup(p.melds[i])),
            ],
          );
    return TweenAnimationBuilder<double>(
      key: ValueKey('meld-${p.seat}-${p.melds.length}'),
      tween: Tween(begin: 1.25, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: melds,
      ),
    );
  }

  Widget _meldGroup(Meld m) {
    final concealed = m.type == 'angang';
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < m.tiles.length; i++)
            concealed && i > 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: TileBack(width: 16, height: 22),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: MahjongTileWidget(tile: m.tiles[i], width: 22, height: 30),
                  ),
        ],
      ),
    );
  }

  /// 牌墙：四面各 27 张，摸牌从「起牌墙位」那面开始依次消耗
  List<int> _wallSideCounts() {
    final consumed = 108 - table.wall.length;
    final start = table.wallStartSide;
    return List.generate(4, (phys) {
      // off: 该面是第几个被消耗的（0 = 最先摸的那面）
      final off = (phys - start + 4) % 4;
      final segStart = off * 27;
      if (consumed >= segStart + 27) return 0;
      if (consumed <= segStart) return 27;
      return 27 - (consumed - segStart);
    });
  }

  /// 牌墙：玉背牌堆（vertical=true 为竖放），当前消耗面金色高亮
  Widget _wallStrip(int side, {bool vertical = false}) {
    final counts = _wallSideCounts();
    final n = counts[side];
    final isActive = n > 0 && counts.take(side).every((c) => c == 0);
    final tiles = [
      for (var i = 0; i < n; i++)
        Padding(
          padding: const EdgeInsets.all(0.5),
          child: TileBack(width: 13, height: 18),
        ),
    ];
    final box = Container(
      decoration: isActive
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
                width: 1.5,
              ),
            )
          : null,
      padding: isActive ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: vertical
          ? (tiles.isEmpty
              ? const SizedBox(width: 16)
              // FittedBox：27 张牌墙自动缩放到可用高度，避免溢出挤掉牌河
              : SizedBox(
                  width: 18,
                  child: FittedBox(fit: BoxFit.contain, child: Column(children: tiles)),
                ))
          : (tiles.isEmpty
              ? const SizedBox(height: 20)
              : SizedBox(
                  height: 20,
                  child: FittedBox(fit: BoxFit.contain, child: Row(children: tiles)),
                )),
    );
    return box;
  }

  Widget _centerArea() {
    // 展示各家的弃牌河（木框 + 绿呢台面 + 四面牌墙）
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D6E63), Color(0xFF5D4037), Color(0xFF4E342E)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF43A047), Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ),
        ),
        child: Column(
          children: [
            // 上方牌墙 + 对家（牌河 + 副露）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Center(child: _wallStrip(0)),
            ),
            Expanded(
              child: Column(
                children: [
                  _meldDisplay(table.players[2]),
                  Expanded(child: _river(2)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  // 左侧牌墙 + 上家（牌河 + 副露）
                  _wallStrip(3, vertical: true),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _river(1)),
                        _meldDisplay(table.players[1]),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _lastDiscardMarker(),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _river(3)),
                        _meldDisplay(table.players[3]),
                      ],
                    ),
                  ),
                  // 右侧牌墙 + 下家副露
                  _wallStrip(2, vertical: true),
                ],
              ),
            ),
            Expanded(child: _river(mySeat)),
            // 下方牌墙
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Center(child: _wallStrip(1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lastDiscardMarker() {
    final ld = table.lastDiscard;
    final discarderName =
        ld != null ? table.players[ld['seat'] as int].name : null;
    if (ld == null || table.phase != 'claim') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TileBack(width: 34, height: 46),
          const SizedBox(height: 2),
          if (discarderName != null)
            Text(discarderName,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          discarderName! + ' 打',
          style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        MahjongTileWidget(tile: ld['tile'] as int, width: 34, height: 46, glow: true),
      ],
    );
  }

  /// 牌河：最后打出的一张高亮显示
  Widget _river(int seat) {
    final discards = table.players[seat].discards;
    final ld = table.lastDiscard;
    final isLastRiver = ld != null && ld['seat'] == seat;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (var i = 0; i < discards.length; i++)
            // 最新打出的牌：弹入动画
            if (isLastRiver && i == discards.length - 1)
              TweenAnimationBuilder<double>(
                key: ValueKey('river-$seat-${discards.length}'),
                tween: Tween(begin: 1.5, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: MahjongTileWidget(
                    tile: discards[i],
                    width: 24,
                    height: 32,
                    glow: true,
                    glowColor: const Color(0xFFFFD54F),
                  ),
                ),
              )
            else
              MahjongTileWidget(
                tile: discards[i],
                width: 24,
                height: 32,
              ),
        ],
      ),
    );
  }

  Widget _actionBar(bool needDingque, bool needClaim, bool myTurn, PlayerState me) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: needExchange
          ? _exchangeButtons()
          : needDingque
          ? _dingqueButtons()
          : needClaim
              ? _claimButtons()
              : myTurn
                  ? _turnButtons(me)
                  : Text(
                      _statusText(),
                      style: const TextStyle(color: Colors.white70),
                    ),
    );
  }

  String _statusText() {
    if (table.state == stateOver) return '对局结束';
    if (table.state == stateHuan) return '换三张：选 3 张同门的牌，传给${table.exchangeDirectionLabel()}';
    if (table.phase == 'claim') return '等待其他玩家回应…';
    final p = table.players[table.turn];
    return '等待 ${p.name} 行动…';
  }

  Widget _exchangeButtons() {
    final ready = _exchangeSel.length == 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '🎲 $die1 + $die2 = ${die1 + die2} · 传给${table.exchangeDirectionLabel()} · 已选 ${_exchangeSel.length}/3',
          style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1))]),
        ),
        const SizedBox(width: 10),
        // 重播摇骰子动画
        GestureDetector(
          onTap: _startWithDice,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text('🎲',
                style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 10),
        _actionBtn(
          ready ? '换三张 ✓' : '换三张（选 3 张同门）',
          ready ? const Color(0xFF2E7D32) : Colors.blueGrey,
          ready ? _confirmExchange : () {},
        ),
      ],
    );
  }

  Widget _dingqueButtons() {    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('请定缺：', style: TextStyle(color: Colors.white)),
        const SizedBox(width: 12),
        for (var s = 0; s < 3; s++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FilledButton(
              onPressed: () {
                table.dingque(mySeat, s);
                unawaited(_advance());
              },
              child: Text('缺${suitNames[s]}'),
            ),
          ),
      ],
    );
  }

  Widget _claimButtons() {
    final options = table.pendingClaim!['options'] as Map<int, List<String>>;
    final acts = options[mySeat] ?? [];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (acts.contains('hu'))
          _actionBtn('胡', const Color(0xFFC62828), () => _claim('hu'), primary: true),
        if (acts.contains('minggang'))
          _actionBtn('杠', const Color(0xFFE65100), () => _claim('minggang')),
        if (acts.contains('peng'))
          _actionBtn('碰', const Color(0xFFEF6C00), () => _claim('peng')),
        _actionBtn('过', const Color(0xFF455A64), () => _claim('pass')),
      ],
    );
  }

  Widget _turnButtons(PlayerState me) {
    // 听牌提示：已打缺且听牌时显示听哪些牌
    final ting = table.voided(mySeat)
        ? tingTiles(table.countsOf(mySeat), me.melds.length, me.dingque)
        : <int>[];
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (me.canSelfDraw != null) ...[
          _actionBtn('自摸胡！', const Color(0xFFC62828), _selfHu, primary: true),
          _actionBtn('过（把牌做大）', const Color(0xFF455A64), _passSelfDraw),
        ],
        for (final t in me.canGangTiles)
          _actionBtn('杠 ${tileName(t)}', const Color(0xFFE65100), () => _gang(t)),
        const SizedBox(width: 8),
        if (ting.isNotEmpty)
          Text(
            '听: ${ting.map((t) => tileName(t)).join(' ')}',
            style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        const SizedBox(width: 8),
        const Text('轮到你了 · 点手牌打出',
            style: TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1))])),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap,
      {bool primary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.85), color],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primary ? const Color(0xFFFFD54F) : Colors.white38,
              width: primary ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              shadows: [Shadow(color: Colors.black38, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _myHand(PlayerState me) {
    final hand = sortHand(me.hand);
    // 发牌动画：逐张亮出
    final shown = _dealing ? hand.take(_dealtCount).toList() : hand;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5D4037), Color(0xFF4E342E), Color(0xFF3E2723)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF8D6E63), width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in shown)
                  GestureDetector(
                    onTap: () => _tapHandTile(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: _isDingqueTile(t, me)
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFE53935),
                                      width: 2,
                                    ),
                                  )
                                : null,
                            padding: _isDingqueTile(t, me)
                                ? const EdgeInsets.all(2)
                                : EdgeInsets.zero,
                            child: MahjongTileWidget(
                              tile: t,
                              width: 44,
                              height: 60,
                              raised: true,
                              glow: _exchangeSel.contains(t) || t == _lastDrawnTile,
                              glowColor: t == _lastDrawnTile && !_exchangeSel.contains(t)
                                  ? const Color(0xFF90CAF9)
                                  : const Color(0xFFFFD54F),
                            ),
                          ),
                          // 换三张选中数量（同值多张）
                          if (_exchangeSel.where((x) => x == t).length > 1)
                            Positioned(
                              top: -5,
                              left: -5,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1976D2),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '×' + _exchangeSel.where((x) => x == t).length.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (_isDingqueTile(t, me))
                            Positioned(
                              top: -5,
                              right: -5,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '缺',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (me.melds.isNotEmpty)
            Wrap(
              spacing: 4,
              children: me.melds.map(_miniMeld).toList(),
            ),
        ],
      ),
    );
  }
}

// ---------------- 麻将牌组件（玉石质感，见 widgets/jade_tile.dart） ----------------

/// 大牌：点击交互用手牌
class MahjongTileWidget extends StatelessWidget {
  final int tile;
  final double width;
  final double height;
  final bool raised;
  final bool glow;
  final Color glowColor;
  const MahjongTileWidget({
    super.key,
    required this.tile,
    this.width = 40,
    this.height = 56,
    this.raised = false,
    this.glow = false,
    this.glowColor = const Color(0xFFFFD54F),
  });

  @override
  Widget build(BuildContext context) {
    return JadeTile(
      tile: tile,
      width: width,
      height: height,
      raised: raised,
      glow: glow,
      glowColor: glowColor,
    );
  }
}

/// 小牌：牌河 / 副露
class MiniTile extends StatelessWidget {
  final int tile;
  const MiniTile({super.key, required this.tile});

  @override
  Widget build(BuildContext context) {
    return JadeTile(tile: tile, width: 20, height: 26);
  }
}

/// 牌背（等待提示用）
class TileBack extends StatelessWidget {
  final double width;
  final double height;
  const TileBack({super.key, this.width = 34, this.height = 46});

  @override
  Widget build(BuildContext context) {
    return JadeTile(tile: 0, width: width, height: height, blank: true);
  }
}
