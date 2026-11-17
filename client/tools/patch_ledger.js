// 结算页全流水明细
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
let ok = 0;

// 1. 明细区改为全量结算流水
const a1 = "              // 查叫 / 花猪明细\n              if (table.events.any((e) => e.type == 'chadajiao' || e.type == 'huazhu'))";
if (s.includes(a1)) {
  s = s.replace(a1, "              // 结算明细（自摸/点炮/杠钱/查叫/花猪全流水）\n              if (table.events.any((e) =>\n                  ['zimo', 'dianpao', 'gang_pay', 'chadajiao', 'huazhu']\n                      .contains(e.type)))");
  ok++;
}

// 2. 条目渲染扩展：zimo + dianpao
const a2 = "                      for (final e in table.events)\n                        if (e.type == 'chadajiao')";
if (s.includes(a2)) {
  s = s.replace(a2, `                      for (final e in table.events)
                        if (e.type == 'zimo')
                          Text(
                            '🀄 \${table.players[e.data['seat'] as int].name} 自摸 \${tileName(e.data['tile'] as int)}（\${(e.data['fans'] as List).map((f) => (f as Map)['name']).join(' · ')}）\${e.data['base']} 分 ← \${(e.data['payers'] as List).join('、')} 各付',
                            style: const TextStyle(fontSize: 12),
                          )
                        else if (e.type == 'dianpao')
                          Text(
                            '💣 \${table.players[e.data['from'] as int].name} 点炮 \${tileName(e.data['tile'] as int)} → \${table.players[e.data['seat'] as int].name} 胡 \${e.data['base']} 分',
                            style: const TextStyle(fontSize: 12),
                          )
                        else if (e.type == 'gang_pay')
                          Text(
                            '💰 \${table.players[e.data['seat'] as int].name} \${e.data['label']}：\${e.data['detail']}',
                            style: const TextStyle(fontSize: 12),
                          )
                        else if (e.type == 'chadajiao')`);
  ok++;
}

// 3. chadajiao 行加听牌者名
const a3 = "                            '🔎 查大叫：\${table.players[e.data['seat'] as int].name} 未听 → 赔 \${e.data['amount']} 分',";
if (s.includes(a3)) {
  s = s.replace(a3, "                            '🔎 查大叫：\${table.players[e.data['seat'] as int].name} 未听 → 赔 \${e.data['toNames'] ?? ''} \${e.data['amount']} 分',");
  ok++;
}

fs.writeFileSync(p, s);
console.log('ok:', ok, '/3');
