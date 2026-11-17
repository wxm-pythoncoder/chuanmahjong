// 修复 main.dart 柱状图作用域 + online_page 类成员重建
const fs = require('fs');

// ---- 1. main.dart：柱状图尾部 Text 改用直接取值（v 只在 builder 作用域）----
{
  const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
  let s = fs.readFileSync(p, 'utf8');
  const broken = `                                      child: Text(
                                      '\${v >= 0 ? "+" : ""}\${totalScores[p.seat] ?? 0}',
`;
  if (s.includes(broken)) {
    s = s.replace(broken, `                                      child: Text(
                                      '\${(totalScores[p.seat] ?? 0) >= 0 ? "+" : ""}\${totalScores[p.seat] ?? 0}',
`);
    fs.writeFileSync(p, s);
    console.log('main.dart 柱状图作用域已修');
  } else {
    console.log('main.dart 柱状图：锚点未找到（可能已修）');
  }
}

// ---- 2. online_page.dart：重建类成员（needExchange + _autoDiscard）----
{
  const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/online_page.dart';
  const lines = fs.readFileSync(p, 'utf8').split('\n');
  // 校验损坏区域（index 200..234）
  const seg = lines.slice(200, 235).join('\n');
  if (!seg.includes('widget.net.views.listen((v) {') || !seg.includes('_autoDiscardLastDingque')) {
    console.log('online_page：结构与预期不符，跳过（可能已修）');
  } else {
    // 删除 201..235 行（index 200..234）
    let out = [...lines.slice(0, 200), ...lines.slice(235)];
    // system 监听插入 super.initState(); 之后
    const si = out.findIndex((l, i) => i > 190 && l.trim() === 'super.initState();');
    if (si === -1) throw new Error('super.initState not found');
    const sys = [
      "    // 掉线重连状态（全屏覆盖层）",
      "    widget.net.system.listen((msg) {",
      "      if (!mounted) return;",
      "      if (msg['type'] == 'disconnected') {",
      "        setState(() {",
      "          reconnecting = true;",
      "          banner = '连接断开，自动重连中…';",
      "        });",
      "      }",
      "      if (msg['type'] == 'player_reconnected' || msg['type'] == 'joined') {",
      "        setState(() {",
      "          reconnecting = false;",
      "          banner = '已重连';",
      "        });",
      "      }",
      "    });",
    ];
    out = [...out.slice(0, si + 1), ...sys, ...out.slice(si + 1)];
    // 在 build 前插入 needExchange + _autoDiscardLastDingque
    const bi = out.findIndex((l, i) => i > 210 && l.trim() === '@override' &&
        out[i + 1] !== undefined && out[i + 1].includes('Widget build'));
    if (bi === -1) throw new Error('build not found');
    const members = [
      "  bool needExchange(OnlineView v) =>",
      "      v.state == 'huan' && !v.exchangeDone;",
      "",
      "  /// 缺门只剩一张时自动打掉",
      "  void _autoDiscardLastDingque(OnlineView v) {",
      "    if (v.state != 'playing' || v.phase != 'discard' || v.turn != v.mySeat) {",
      "      return;",
      "    }",
      "    final q = v.me.dingque;",
      "    if (q == null) return;",
      "    final dingqueTiles = v.myHand.where((t) => tileSuit(t) == q).toList();",
      "    if (dingqueTiles.length != 1) return;",
      "    widget.net.discard(dingqueTiles[0]);",
      "    setState(() {",
      "      banner = '🤖 自动打缺：最后一张' + suitNames[q] + '已打出';",
      "    });",
      "  }",
      "",
    ];
    out = [...out.slice(0, bi), ...members, ...out.slice(bi)];
    fs.writeFileSync(p, out.join('\n'));
    console.log('online_page 类成员已重建');
  }
}
