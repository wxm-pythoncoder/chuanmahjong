// 重写 _myHand：待出牌标记 + 牌名显示
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');

const startMarker = '  Widget _myHand(PlayerState me) {';
const tailMarker = `            Wrap(
              spacing: 4,
              children: me.melds.map(_miniMeld).toList(),
            ),
        ],
      ),
    );
  }
}`;
const start = s.indexOf(startMarker);
const tailStart = s.indexOf(tailMarker);
if (start === -1 || tailStart === -1) throw new Error('anchor not found');

const newMethod = `  Widget _myHand(PlayerState me) {
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
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in shown)
                  GestureDetector(
                    onTap: () => _tapHandTile(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: _isDingqueTile(t, me)
                                    ? BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(6),
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
                                  glow: _exchangeSel.contains(t) ||
                                      t == _pendingDiscard ||
                                      t == _lastDrawnTile,
                                  glowColor: t == _pendingDiscard
                                      ? const Color(0xFF1976D2)
                                      : t == _lastDrawnTile &&
                                              !_exchangeSel.contains(t)
                                          ? const Color(0xFF90CAF9)
                                          : const Color(0xFFFFD54F),
                                ),
                              ),
                              // 待出牌角标
                              if (t == _pendingDiscard)
                                Positioned(
                                  top: -5,
                                  left: -5,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1976D2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      '出',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                          const SizedBox(height: 2),
                          // 牌名（看清是什么牌）
                          Text(
                            tileName(t),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (me.melds.isNotEmpty)
            Wrap(
              spacing: 4,
              children: me.melds.map(_miniMeld).toList(),
            ),
        ],
      ),
    );
  }
}`;

s = s.slice(0, start) + newMethod + s.slice(tailStart + tailMarker.length);
fs.writeFileSync(p, s);
console.log('_myHand 已重写（待出标记 + 牌名）');
