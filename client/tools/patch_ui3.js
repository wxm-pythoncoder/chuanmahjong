// 本轮 UI 优化补丁：发牌动画/摸牌高亮/牌河放大/打牌人名/节奏2s
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
let ok = 0;

// 1. 状态字段
const a1 = '  List<int> _preExchangeHand = []; // 换牌前手牌快照';
if (s.includes(a1)) {
  s = s.replace(a1, `  List<int> _preExchangeHand = []; // 换牌前手牌快照
  bool _dealing = false; // 发牌动画进行中
  int _dealtCount = 0; // 已发张数
  Timer? _dealTimer;
  int? _lastDrawnTile; // 刚摸的牌（蓝光高亮）`);
  ok++;
}

// 2. 骰子动画结束后 → 发牌动画 → 推进
const a2 = `              onDone: () {
                setState(() => _diceIntro = false);
                unawaited(_advance());
              },`;
if (s.includes(a2)) {
  s = s.replace(a2, `              onDone: () {
                setState(() => _diceIntro = false);
                _startDealing();
              },`);
  ok++;
}

// 3. _advance 推进后更新摸牌高亮
const a3 = '    if (!mounted) return;\n    setState(() {});\n    _announceHu();\n    if (table.state == stateOver) _showResult();\n  }';
if (s.includes(a3)) {
  s = s.replace(a3, `    if (!mounted) return;
    setState(() {});
    _announceHu();
    _updateDrawnTile();
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
    _dealTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
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
  }`);
  ok++;
}

// 4. 节奏 1.2~2.0s
const a4 = '    Duration(milliseconds: 1800 + _thinkRng.nextInt(2500));';
if (s.includes(a4)) {
  s = s.replace(a4, '    Duration(milliseconds: 1200 + _thinkRng.nextInt(800));');
  ok++;
}

// 5. 牌河放大 + 打牌人名
const a5 = "  Widget _lastDiscardMarker() {";
const a5b = "    return Column(\n      mainAxisSize: MainAxisSize.min,\n      children: [\n        Text('待应', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),";
if (s.includes(a5)) {
  s = s.replace(a5, `  Widget _lastDiscardMarker() {
    final ld = table.lastDiscard;
    final discarderName =
        ld != null ? table.players[ld['seat'] as int].name : null;`);
  s = s.replace(a5b, `    if (ld == null || table.phase != 'claim') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TileBack(width: 34, height: 46),
          const SizedBox(height: 2),
          Text(discarderName ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          discarderName! + ' 打',
          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        MahjongTileWidget(tile: ld['tile'] as int, width: 34, height: 46, glow: true),
      ],
    );
  }`);
  ok++;
}

// 5b. 牌河放大（旧 _lastDiscardMarker 主体替换后，_river 改大）
const a5c = "  Widget _river(List<int> discards) {\n    return Padding(\n      padding: const EdgeInsets.all(4),\n      child: Wrap(\n        spacing: 3,\n        runSpacing: 3,\n        children: discards.map((t) => MiniTile(tile: t)).toList(),\n      ),\n    );\n  }";
if (s.includes(a5c)) {
  s = s.replace(a5c, `  Widget _river(List<int> discards) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: discards
            .map((t) => MahjongTileWidget(tile: t, width: 24, height: 32))
            .toList(),
      ),
    );
  }`);
  ok++;
}

// 6. 人类动作后清除摸牌高亮
const a6 = '    table.discard(mySeat, tile);\n    unawaited(_advance());';
if (s.includes(a6)) {
  s = s.replace(a6, '    table.discard(mySeat, tile);\n    _lastDrawnTile = null;\n    unawaited(_advance());');
  ok++;
}
const a6b = '  void _selfHu() {\n    table.hu(mySeat);';
if (s.includes(a6b)) {
  s = s.replace(a6b, '  void _selfHu() {\n    _lastDrawnTile = null;\n    table.hu(mySeat);');
  ok++;
}

fs.writeFileSync(p, s);
console.log('成功应用修改数:', ok, '/ 8');
