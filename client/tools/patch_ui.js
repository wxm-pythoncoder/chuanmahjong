// 一次性代码修改脚本：给 main.dart 加胡牌横幅与累计积分
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
let ok = 0;

// 1. 状态字段
const a1 = '  static const botThinkDelay = Duration(milliseconds: 650);';
if (s.includes(a1)) {
  s = s.replace(a1, a1 + `

  // 跨局累计积分（按座位）与局数
  final Map<int, int> totalScores = {0: 0, 1: 0, 2: 0, 3: 0};
  int roundNo = 0;
  bool _settled = false;
  final Set<int> _announcedHu = {};
  Map<String, dynamic>? huBanner; // 胡牌横幅数据`);
  ok++;
}

// 2. 推进循环中检测胡牌
const a2 = "if (r == 'waiting') break;\n        if (mounted) setState(() {});\n        await Future.delayed(botThinkDelay);";
if (s.includes(a2)) {
  s = s.replace(a2, "if (r == 'waiting') break;\n        if (mounted) setState(() {});\n        _announceHu();\n        await Future.delayed(botThinkDelay);");
  ok++;
}

// 3. 循环结束后再检测一次 + 新增 _announceHu
const a3 = '    if (!mounted) return;\n    setState(() {});\n    if (table.state == stateOver) _showResult();\n  }';
if (s.includes(a3)) {
  s = s.replace(a3, `    if (!mounted) return;
    setState(() {});
    _announceHu();
    if (table.state == stateOver) _showResult();
  }

  /// 检测新胡牌并显示牌型横幅
  void _announceHu() {
    for (final p in table.players) {
      if (p.hu != null && !_announcedHu.contains(p.seat)) {
        _announcedHu.add(p.seat);
        final hu = p.hu!;
        final fansText =
            (hu['fans'] as List).map((f) => (f as Map)['name']).join(' · ');
        setState(() {
          huBanner = {
            'name': p.name,
            'winType': hu['winType'],
            'fansText': fansText.isEmpty ? '平胡' : fansText,
            'base': hu['base'],
          };
        });
      }
    }
  }`);
  ok++;
}

// 4. 结算累计分
const a4 = '  void _showResult() {\n    final scores = table.players';
if (s.includes(a4)) {
  s = s.replace(a4, `  void _showResult() {
    if (!_settled) {
      _settled = true;
      roundNo++;
      for (final p in table.players) {
        totalScores[p.seat] = (totalScores[p.seat] ?? 0) + p.pay;
      }
    }
    final scores = table.players`);
  ok++;
}

// 4b. 结算文案带累计
const a4b = "        .map((p) => '\${p.name}  \${p.pay >= 0 ? \"+\" : \"\"}\${p.pay}')";
if (s.includes(a4b)) {
  s = s.replace(a4b, "        .map((p) => '\${p.name}  本局 \${p.pay >= 0 ? \"+\" : \"\"}\${p.pay}   累计 \${(totalScores[p.seat] ?? 0) >= 0 ? \"+\" : \"\"}\${totalScores[p.seat] ?? 0}')");
  ok++;
}

// 5. 再来一局重置局内状态
const a5 = "                table = Table(['我', '南风', '西风', '北风']);\n                bot = Bot(table);\n              });";
if (s.includes(a5)) {
  s = s.replace(a5, `                table = Table(['我', '南风', '西风', '北风']);
                bot = Bot(table);
                _announcedHu.clear();
                huBanner = null;
                _settled = false;
              });`);
  ok++;
}

fs.writeFileSync(p, s);
console.log('成功应用修改数:', ok, '/ 6');
