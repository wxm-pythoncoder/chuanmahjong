// 移除 _turnButtons 内的听牌块（改由常驻听牌条显示）
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
const start = s.indexOf('          if (ting.isNotEmpty)');
const endMarker = "            ),\n";
const end = s.indexOf(endMarker, start);
if (start === -1 || end === -1) throw new Error('anchor not found ' + start + ' ' + end);
s = s.slice(0, start) + s.slice(end + endMarker.length);
fs.writeFileSync(p, s);
console.log('已移除');
