// 麻将牌渲染 v3：专业位图素材（riichi-mahjong-tiles，CC0 公有领域）
// 素材: https://github.com/FluffyStuff/riichi-mahjong-tiles
// 叠加立体投影 + 选中光圈，保留统一的组件 API

import 'package:flutter/material.dart';

/// 牌 index(0-26) → 素材文件名
String tileAssetName(int tile) {
  final suit = tile ~/ 9; // 0万 1条 2筒
  final rank = tile % 9 + 1;
  final prefix = ['Man', 'Sou', 'Pin'][suit];
  return 'assets/tiles/$prefix$rank.png';
}

class JadeTile extends StatelessWidget {
  final int tile;
  final double width;
  final double height;
  final bool raised;
  final bool glow;
  final Color glowColor; // 光圈颜色（选中=金、刚摸=蓝）
  final bool blank;

  const JadeTile({
    super.key,
    required this.tile,
    required this.width,
    required this.height,
    this.raised = false,
    this.glow = false,
    this.glowColor = const Color(0xFFFFD54F),
    this.blank = false,
  });

  @override
  Widget build(BuildContext context) {
    // 符号层是透明 PNG，必须叠在 Front.png（米白牌面）上
    Widget face = Stack(
      children: [
        Image.asset(
          'assets/tiles/Front.png',
          width: width,
          height: height,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        ),
        // 玉色透染：米白底 → 温润玉色
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF7FD8A8).withValues(alpha: 0.16),
                  const Color(0xFF3FA878).withValues(alpha: 0.26),
                ],
              ),
            ),
          ),
        ),
        if (!blank)
          Positioned.fill(
            child: Image.asset(
              tileAssetName(tile),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        if (blank)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9CCFB0).withValues(alpha: 0.92),
                    const Color(0xFF5EA986).withValues(alpha: 0.92),
                    const Color(0xFF3F7D5F).withValues(alpha: 0.95),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFEAF7EF).withValues(alpha: 0.7),
                  width: width * 0.03,
                ),
              ),
            ),
          ),
      ],
    );

    Widget inner = ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.09),
      child: face,
    );

    if (glow) {
      inner = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.09),
          border: Border.all(
            color: glowColor,
            width: width * 0.06,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.8),
              blurRadius: width * 0.22,
              spreadRadius: width * 0.04,
            ),
          ],
        ),
        child: inner,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.09),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: raised ? 0.5 : 0.35),
            offset: Offset(0, raised ? height * 0.045 : height * 0.02),
            blurRadius: raised ? width * 0.14 : width * 0.07,
          ),
        ],
      ),
      child: inner,
    );
  }
}
