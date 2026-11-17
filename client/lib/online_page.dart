// 联机模式页面：连接服务器 → 大厅（匹配/建房/加入） → 对局
// 对局界面复用 main.dart 里的麻将牌组件

import 'package:flutter/material.dart';

import 'main.dart' show MahjongTileWidget, MiniTile, TileBack;
import 'net_client.dart';
import 'widgets/dice_intro.dart';
import 'game/win.dart' show tingTiles;
import 'game/scoring.dart' show Meld;
import 'game/tiles.dart' show suitNames, tileSuit;

class OnlinePage extends StatefulWidget {
  const OnlinePage({super.key});

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  final urlCtrl = TextEditingController(text: 'ws://127.0.0.1:8080');
  final nameCtrl = TextEditingController(text: randomName());
  final roomCtrl = TextEditingController();
  final NetClient net = NetClient();
  String status = '未连接';
  String? roomId;
  bool inGame = false;
  final List<String> toast = [];

  @override
  void initState() {
    super.initState();
    net.system.listen((msg) {
      if (!mounted) return;
      setState(() {
        switch (msg['type']) {
          case 'joined':
            roomId = msg['roomId'];
            status = '已加入房间 $roomId（座位 ${msg['seat']}）';
            break;
          case 'player_joined':
            status = '有玩家加入：${(msg['players'] as List).whereType<String>().join('、')}';
            break;
          case 'game_start':
            inGame = true;
            break;
          case 'error':
            status = '错误：${msg['msg']}';
            break;
          case 'disconnected':
            status = '连接已断开，自动重连中…';
            // 自动重连：找回原座位（最多 5 次，每次间隔 2 秒）
            if (roomId != null) {
              final savedRoom = roomId;
              final savedName = nameCtrl.text.trim();
              Future(() async {
                for (var i = 0; i < 5; i++) {
                  await Future.delayed(const Duration(seconds: 2));
                  final ok = await net.rejoinRoom(savedRoom!, savedName);
                  if (ok && mounted) {
                    setState(() => status = '已重连回房间 $savedRoom');
                    return;
                  }
                }
                if (mounted) {
                  setState(() => status = '重连失败，请手动重新加入');
                }
              });
            }
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    net.dispose();
    urlCtrl.dispose();
    nameCtrl.dispose();
    roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      setState(() => status = '连接中…');
      await net.connect(urlCtrl.text.trim());
      setState(() => status = '已连接到服务器');
    } catch (e) {
      setState(() => status = '连接失败：$e');
    }
  }



  @override
  Widget build(BuildContext context) {
    if (inGame) {
      return OnlineGamePage(net: net, onExit: () => setState(() => inGame = false));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('联机对战')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'ws://127.0.0.1:8080',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('连接'),
              onPressed: _connect,
            ),
            const Divider(height: 32),
            Text(status, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.bolt),
              label: const Text('快速匹配（4 人满员开局）'),
              onPressed: net.connected
                  ? () => net.quickMatch(nameCtrl.text.trim())
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: '房间号',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: net.connected
                      ? () => net.joinRoom(roomCtrl.text.trim(), nameCtrl.text.trim())
                      : null,
                  child: const Text('加入房间'),
                ),
              ],
            ),
            if (roomId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('当前房间：$roomId（等朋友输入房号加入，满 4 人自动开局）'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 联机对局页 ----------------

class OnlineGamePage extends StatefulWidget {
  final NetClient net;
  final VoidCallback onExit;
  const OnlineGamePage({super.key, required this.net, required this.onExit});

  @override
  State<OnlineGamePage> createState() => _OnlineGamePageState();
}

class _OnlineGamePageState extends State<OnlineGamePage> {
  OnlineView? view;
  AskClaim? ask;
  String banner = '';
  final List<String> feed = [];
  final List<int> exchangeSel = []; // 可含同值牌
  bool counterOpen = false;
  int? counterSuit;
  int dice1 = 1, dice2 = 1;
  int dice3 = 1, dice4 = 1;
  bool diceIntro = false;
  static const sideLabels = ['东家墙', '南家墙', '西家墙', '北家墙'];
  List<int> preExchangeHand = []; // 换牌前手牌快照
  List<int> gaveList = []; // 我换出的牌
  Map<String, dynamic>? exchangeBanner; // 换出→换入 横幅
  String? lastViewState;
  bool reconnecting = false; // 掉线重连中


  @override
  void initState() {
    super.initState();
    // 掉线重连状态（全屏覆盖层）
    widget.net.system.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'disconnected') {
        setState(() {
          reconnecting = true;
          banner = '连接断开，自动重连中…';
        });
      }
      if (msg['type'] == 'player_reconnected' || msg['type'] == 'joined') {
        setState(() {
          reconnecting = false;
          banner = '已重连';
        });
      }
    });
    widget.net.views.listen((v) {
      if (!mounted) return;
      setState(() {
        view = v;
        if (v.state == 'over') banner = '对局结束';
        // 新一局进入换三张阶段：清空上一局的换牌横幅
        if (v.state == 'huan' && lastViewState != 'huan') {
          exchangeBanner = null;
          preExchangeHand = [];
          gaveList = [];
        }
        lastViewState = v.state;
      });
      _autoDiscardLastDingque(v);
      // 换三张完成（进入定缺）→ 计算换出/换入并弹横幅
      if (v.state == 'dingque' && preExchangeHand.isNotEmpty) {
        final remaining = [...preExchangeHand];
        final received = <int>[];
        for (final t in v.myHand) {
          final idx = remaining.indexOf(t);
          if (idx >= 0) {
            remaining.removeAt(idx);
          } else {
            received.add(t);
          }
        }
        setState(() {
          exchangeBanner = {
            'gave': gaveList,
            'received': received,
            'direction': v.exchangeDirection,
          };
          preExchangeHand = [];
          gaveList = [];
        });
      }
    });
    widget.net.asks.listen((a) {
      if (!mounted) return;
      setState(() => ask = a);
    });
    widget.net.events.listen((e) {
      if (!mounted) return;
      setState(() {
        feed.insert(0, e.describe());
        if (feed.length > 5) feed.removeLast();
        if (e.type == 'dice_exchange') {
          dice1 = e.data['d1'] as int;
          dice2 = e.data['d2'] as int;
        }
        if (e.type == 'dice_draw') {
          dice3 = e.data['d3'] as int;
          dice4 = e.data['d4'] as int;
        }
      });
    });
  }

  bool needExchange(OnlineView v) =>
      v.state == 'huan' && !v.exchangeDone;
  /// 缺门只剩一张时自动打掉
  void _autoDiscardLastDingque(OnlineView v) {
    if (v.state != 'playing' || v.phase != 'discard' || v.turn != v.mySeat) {
      return;
    }
    final q = v.me.dingque;
    if (q == null) return;
    final dingqueTiles = v.myHand.where((t) => tileSuit(t) == q).toList();
    if (dingqueTiles.length != 1) return;
    widget.net.discard(dingqueTiles[0]);
    setState(() {
      banner = '🤖 自动打缺：最后一张${suitNames[q]}已打出';
    });
  }
  @override
  Widget build(BuildContext context) {
    final v = view;
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('联机 · 余牌 ${v?.wallLeft ?? 0} · 房间 ${widget.net.mySeat}号位'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calculate_outlined,
              color: counterOpen ? const Color(0xFFFFD54F) : Colors.white,
            ),
            tooltip: '记牌器',
            onPressed: () => setState(() => counterOpen = !counterOpen),
          ),
          TextButton(
            onPressed: widget.onExit,
            child: const Text('离开', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: v == null
          ? const Center(child: Text('等待开局…', style: TextStyle(color: Colors.white)))
          : Stack(
              children: [
                _table(v),
                // 换三张摇骰子动画（重播：两次骰子）
                if (diceIntro)
                  DiceIntro(
                    d1: dice1,
                    d2: dice2,
                    d3: dice3,
                    d4: dice4,
                    direction: v.exchangeDirection,
                    startSide: sideLabels[v.wallStartSide],
                    onDone: () => setState(() => diceIntro = false),
                  ),
                // 断线重连覆盖层
                if (reconnecting)
                  Container(
                    color: Colors.black.withValues(alpha: 0.72),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Color(0xFFFFD54F)),
                        SizedBox(height: 16),
                        Text('连接断开 · 自动重连中…',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('已重连将自动恢复手牌与进度',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// 记牌器（联机）：按公开信息计算剩余张数
  List<int> _visibleCounts(OnlineView v) {
    final visible = List<int>.filled(27, 0);
    for (final p in v.players) {
      for (final t in p.discards) {
        visible[t]++;
      }
      for (final m in p.melds) {
        for (final t in m.tiles) {
          visible[t]++;
        }
      }
    }
    for (final t in v.myHand) {
      visible[t]++;
    }
    return visible;
  }

  Widget _counterPanel(OnlineView v) {
    final visible = _visibleCounts(v);
    final suits = counterSuit == null ? [0, 1, 2] : [counterSuit!];
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                      counterSuit =
                          label == '全部' ? null : ['万', '条', '筒'].indexOf(label);
                    }),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (counterSuit == null && label == '全部') ||
                                (counterSuit != null &&
                                    label != '全部' &&
                                    ['万', '条', '筒'].indexOf(label) == counterSuit)
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

  Widget _table(OnlineView v) {
    final needDingque = v.state == 'dingque' && v.me.dingque == null;
    final myTurn = v.phase == 'discard' && v.turn == v.mySeat && !v.me.isHued;

    return SafeArea(
      child: Column(
        children: [
          _badge(v.players[(v.mySeat + 2) % 4]),
          Expanded(child: _center(v)),
          if (banner.isNotEmpty) Text(banner, style: const TextStyle(color: Colors.amberAccent, fontSize: 18)),
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
          if (counterOpen) _counterPanel(v),
          _actionBar(v, needDingque, myTurn),
          _hand(v, myTurn),
        ],
      ),
    );
  }
  Widget _badge(OnlinePlayer p) {
    final v = view!;
    final active = v.turn == p.seat && v.state == 'playing';
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active ? Colors.amber.shade700 : Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${p.name}  ${p.dingque == null ? "待定缺" : "缺${suitNames[p.dingque!]}"}  手牌${p.handCount}',
            style: TextStyle(
              color: p.dingque == null
                  ? Colors.white
                  : const [Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF1565C0)][p.dingque!],
            ),
          ),
        ],
      ),
    );
  }

  /// 副露展示：碰/杠亮在各家面前（暗杠只亮一张）
  Widget _meldDisplay(List<Meld> melds, {bool vertical = false}) {
    if (melds.isEmpty) return const SizedBox.shrink();
    Widget group(Meld m) {
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
              m.type == 'angang' && i > 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: TileBack(width: 16, height: 22),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child:
                          MahjongTileWidget(tile: m.tiles[i], width: 22, height: 30),
                    ),
          ],
        ),
      );
    }

    final inner = vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in melds)
                Padding(padding: const EdgeInsets.only(bottom: 3), child: group(m)),
            ],
          )
        : Wrap(spacing: 6, runSpacing: 4, children: [for (final m in melds) group(m)]);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: inner,
    );
  }

  /// 牌墙每面张数（从起牌墙位开始依次消耗）
  int _wallPerSide(OnlineView v, int side) {
    final consumed = 108 - v.wallLeft;
    final start = v.wallStartSide;
    final off = (side - start + 4) % 4;
    final segStart = off * 27;
    if (consumed >= segStart + 27) return 0;
    if (consumed <= segStart) return 27;
    return 27 - (consumed - segStart);
  }

  Widget _wallStrip(OnlineView v, int side, {bool vertical = false}) {
    final n = _wallPerSide(v, side).clamp(0, 27);
    final tiles = [
      for (var i = 0; i < n; i++)
        const Padding(
          padding: EdgeInsets.all(0.5),
          child: TileBack(width: 13, height: 18),
        ),
    ];
    return vertical
        ? SizedBox(
            width: 18,
            child: FittedBox(fit: BoxFit.contain, child: Column(children: tiles)),
          )
        : SizedBox(
            height: 20,
            child: FittedBox(fit: BoxFit.contain, child: Row(children: tiles)),
          );
  }

  Widget _center(OnlineView v) {
    final me = v.me;
    final right = v.players[(v.mySeat + 1) % 4];
    final left = v.players[(v.mySeat + 3) % 4];
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF388E3C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Center(child: _wallStrip(v, 0)),
          ),
          Expanded(
            child: Column(
              children: [
                _meldDisplay(v.players[(v.mySeat + 2) % 4].melds),
                Expanded(child: _river(me.discards)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _wallStrip(v, 3, vertical: true),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _river(left.discards)),
                      _meldDisplay(left.melds),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: feed.isEmpty
                        ? const SizedBox()
                        : Text(
                            feed.first,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _river(right.discards)),
                      _meldDisplay(right.melds),
                    ],
                  ),
                ),
                _wallStrip(v, 2, vertical: true),
              ],
            ),
          ),
          Expanded(child: _river(v.players[(v.mySeat + 2) % 4].discards)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Center(child: _wallStrip(v, 1)),
          ),
        ],
      ),
    );
  }
  Widget _river(List<int> discards) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: discards.map((t) => MiniTile(tile: t)).toList(),
      ),
    );
  }

  Widget _actionBar(OnlineView v, bool needDingque, bool myTurn) {
    // 听牌提示（轮到自己且已打缺时显示听哪些牌）
    List<int> ting = <int>[];
    if (v.state == 'playing' &&
        v.phase == 'discard' &&
        v.turn == v.mySeat &&
        v.me.dingque != null &&
        !v.myHand.any((t) => tileSuit(t) == v.me.dingque)) {
      final cc = List<int>.filled(27, 0);
      for (final t in v.myHand) {
        cc[t]++;
      }
      ting = tingTiles(cc, v.me.melds.length, v.me.dingque);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: needExchange(v)
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '🎲 $dice1 + $dice2 · 传给${v.exchangeDirection} · 已选 ${exchangeSel.length}/3',
                  style: const TextStyle(
                      color: Color(0xFFFFD54F), fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => diceIntro = true),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text('🎲', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: exchangeSel.length == 3
                        ? const Color(0xFF2E7D32)
                        : Colors.blueGrey,
                  ),
                  onPressed: exchangeSel.length == 3
                      ? () {
                          // 快照换牌前手牌与换出牌，用于「换出→换入」横幅
                          preExchangeHand = [...v.myHand];
                          gaveList = [...exchangeSel];
                          widget.net.exchange(exchangeSel.toList());
                          exchangeSel.clear();
                          setState(() {});
                        }
                      : null,
                  child: const Text('换三张'),
                ),
              ],
            )
          : needDingque
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('请定缺：', style: TextStyle(color: Colors.white)),
                for (var s = 0; s < 3; s++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FilledButton(
                      onPressed: () {
                        widget.net.dingque(s);
                        setState(() {});
                      },
                      child: Text('缺${suitNames[s]}'),
                    ),
                  ),
              ],
            )
          : ask != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (ask!.options.contains('hu'))
                      _btn('胡', Colors.red, () => widget.net.claim('hu')),
                    if (ask!.options.contains('minggang'))
                      _btn('杠', Colors.deepOrange, () => widget.net.claim('minggang')),
                    if (ask!.options.contains('peng'))
                      _btn('碰', Colors.orange, () => widget.net.claim('peng')),
                    _btn('过', Colors.blueGrey, () => widget.net.claim('pass')),
                  ],
                )
              : myTurn
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (v.canSelfDraw != null) ...[
                          _btn('自摸胡！', Colors.red, () => widget.net.zimo()),
                          _btn('过（做大）', Colors.blueGrey,
                              () => widget.net.passZimo()),
                        ],
                        for (final t in v.canGangTiles)
                          _btn(
                              '杠${v.me.melds.any((m) => m.type == 'peng' && m.tiles[0] == t) ? "补" : ""} ${t % 9 + 1}',
                              Colors.deepOrange,
                              () => widget.net.gang(
                                  t,
                                  v.me.melds.any((m) => m.type == 'peng' && m.tiles[0] == t)
                                      ? 'bugang'
                                      : 'angang')),
                        if (ting.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '听: ${ting.map((t) => '${t % 9 + 1}${suitNames[tileSuit(t)]}').join(' ')}',
                              style: const TextStyle(
                                  color: Color(0xFF90CAF9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                        const Text(' 点手牌打出', style: TextStyle(color: Colors.amberAccent)),
                      ],
                    )
                  : Center(
                      child: Text('等待玩家行动…',
                          style: TextStyle(color: Colors.white70)),
                    ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _hand(OnlineView v, bool myTurn) {
    final exchanging = needExchange(v);
    return Container(
      color: Colors.black26,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in v.myHand)
              GestureDetector(
                onTap: exchanging || myTurn
                    ? () {
                        if (exchanging) {
                          setState(() {
                            final selCount =
                                exchangeSel.where((x) => x == t).length;
                            final handCount =
                                v.myHand.where((x) => x == t).length;
                            if (selCount > 0 && selCount >= handCount) {
                              exchangeSel.remove(t); // 退回一张
                            } else if (exchangeSel.length < 3) {
                              if (exchangeSel.isEmpty ||
                                  tileSuit(exchangeSel.first) ==
                                      tileSuit(t)) {
                                exchangeSel.add(t);
                              }
                            }
                          });
                        } else {
                          widget.net.discard(t);
                          setState(() {});
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: v.me.dingque != null && tileSuit(t) == v.me.dingque
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE53935),
                                  width: 2,
                                ),
                              )
                            : null,
                        padding: v.me.dingque != null && tileSuit(t) == v.me.dingque
                            ? const EdgeInsets.all(2)
                            : EdgeInsets.zero,
                        child: MahjongTileWidget(
                          tile: t,
                          width: 44,
                          height: 60,
                          glow: exchangeSel.contains(t),
                        ),
                      ),
                      if (v.me.dingque != null && tileSuit(t) == v.me.dingque)
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
    );
  }
}
