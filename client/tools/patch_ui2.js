// 第二批 UI 修改（字符串拼接版，避免模板字面量转义问题）
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
let ok = 0;
const Q = "'";
const D = '"';

// 1. 胡牌横幅插在动作条前
const a1 = '              // 动作条\n              _actionBar(needDingque, needClaim, myTurn, me),';
if (s.includes(a1)) {
  const banner = [
    '              // 胡牌横幅（点击关闭）',
    '              if (huBanner != null)',
    '                GestureDetector(',
    '                  onTap: () => setState(() => huBanner = null),',
    '                  child: Container(',
    '                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),',
    '                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),',
    '                    decoration: BoxDecoration(',
    '                      gradient: const LinearGradient(',
    '                        colors: [Color(0xFFB8860B), Color(0xFF8B6508)],',
    '                      ),',
    '                      borderRadius: BorderRadius.circular(12),',
    '                      border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),',
    '                      boxShadow: [',
    '                        BoxShadow(',
    '                          color: const Color(0xFFFFC107).withValues(alpha: 0.4),',
    '                          blurRadius: 12,',
    '                        ),',
    '                      ],',
    '                    ),',
    '                    child: Text(',
    '                      ' + Q + '🎉 ' + Q + ' +',
    '                      huBanner![D + Q + 'name' + Q + D] +',
    '                      (huBanner![D + Q + 'winType' + Q + D] == ' + Q + 'zimo' + Q + ' ||',
    '                          huBanner![D + Q + 'winType' + Q + D] == ' + Q + 'gangshanghua' + Q + ')',
    '                          ? ' + Q + ' 自摸' + Q,
    '                          : huBanner![D + Q + 'winType' + Q + D] == ' + Q + 'qianggang' + Q + '',
    '                              ? ' + Q + ' 抢杠胡' + Q,
    '                              : ' + Q + ' 点炮胡' + Q + ') +',
    '                      ' + Q + '：' + Q + ' + huBanner![D + Q + 'fansText' + Q + D] +',
    '                      ' + Q + ' = ' + Q + ' + huBanner![D + Q + 'base' + Q + D].toString() + ' + Q + ' 分' + Q + ',',
    '                      style: const TextStyle(',
    '                        color: Colors.white,',
    '                        fontWeight: FontWeight.bold,',
    '                        fontSize: 14,',
    '                      ),',
    '                    ),',
    '                  ),',
    '                ),',
    '              // 动作条',
    '              _actionBar(needDingque, needClaim, myTurn, me),',
  ].join('\n');
  s = s.replace(a1, banner);
  ok++;
}

// 2. 名牌里显示累计分
const a2 = "                  color: hued ? const Color(0xFFFFAB40) : Colors.white70,";
if (s.includes(a2)) {
  const before = s;
  const insert = [
    "              Text(",
    "                '累计 ' + ((totalScores[p.seat] ?? 0) >= 0 ? '+' : '') + (totalScores[p.seat] ?? 0).toString(),",
    "                style: TextStyle(",
    "                  color: (totalScores[p.seat] ?? 0) >= 0 ? Colors.lightGreenAccent : Colors.redAccent,",
    "                  fontSize: 11,",
    "                  fontWeight: FontWeight.bold,",
    "                ),",
    "              ),",
  ].join('\n');
  // 在 hued 那段 Text 前插入
  s = s.replace("              Text(\n                hued\n", insert + "\n              Text(\n                hued\n");
  if (s !== before) ok++;
}

// 3. 记分板显示累计与局数
const a3 = "                    title: Text('" + '${p.name}' + "${p.isDealer ? " + D + '（庄）' + D + " : " + D + D + "}),";
if (s.includes(a3)) {
  const sub = "                    subtitle: Text('累计 " + '${totalScores[p.seat] ?? 0}' + " · 已打 " + '$roundNo' + " 局',\n                        style: const TextStyle(fontSize: 12)),";
  s = s.replace(a3, a3 + '\n' + sub);
  ok++;
}

fs.writeFileSync(p, s);
console.log('成功应用修改数:', ok, '/ 3');
