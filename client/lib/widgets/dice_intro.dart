// 开局摇骰子动画：第一次决定换三张方向，第二次决定起牌墙位
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class DiceIntro extends StatefulWidget {
  final int d1, d2; // 第一次：换三张方向
  final int d3, d4; // 第二次：起牌墙位
  final String direction;
  final String startSide;
  final VoidCallback onDone;

  const DiceIntro({
    super.key,
    required this.d1,
    required this.d2,
    required this.d3,
    required this.d4,
    required this.direction,
    required this.startSide,
    required this.onDone,
  });

  @override
  State<DiceIntro> createState() => _DiceIntroState();
}

class _DiceIntroState extends State<DiceIntro> {
  int _f1 = 1, _f2 = 1, _f3 = 1, _f4 = 1;
  int _stage = 0; // 0=滚第一次 1=第一次定格滚第二次 2=全部定格
  Timer? _flicker;
  final _rng = Random.secure();

  @override
  void initState() {
    super.initState();
    _flicker = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted) return;
      setState(() {
        if (_stage == 0) {
          _f1 = _rng.nextInt(6) + 1;
          _f2 = _rng.nextInt(6) + 1;
        } else {
          _f3 = _rng.nextInt(6) + 1;
          _f4 = _rng.nextInt(6) + 1;
        }
      });
    });
    // 第一次滚 1.2 秒 → 定格并滚第二次 1.2 秒 → 全部定格 1.1 秒后收场
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _stage = 1);
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      _flicker?.cancel();
      setState(() => _stage = 2);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _flicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s1 = _stage >= 1 ? widget.d1 : _f1;
    final s2 = _stage >= 1 ? widget.d2 : _f2;
    final s3 = _stage >= 2 ? widget.d3 : _f3;
    final s4 = _stage >= 2 ? widget.d4 : _f4;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '摇 骰 子',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 20),
          // 第一次：换三张方向
          _rollRow(
            label: '换三张',
            dice: [_dieFace(s1), _dieFace(s2)],
            resultText: '${widget.d1} + ${widget.d2} · 与${widget.direction}换',
            settled: _stage >= 1,
          ),
          const SizedBox(height: 16),
          // 第二次：起牌墙位
          _rollRow(
            label: '起牌位',
            dice: [_dieFace(s3), _dieFace(s4)],
            resultText: '${widget.d3} + ${widget.d4} · 从${widget.startSide}起牌',
            settled: _stage >= 2,
          ),
        ],
      ),
    );
  }

  Widget _rollRow({
    required String label,
    required List<Widget> dice,
    required String resultText,
    required bool settled,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          dice[0],
          const SizedBox(width: 16),
          dice[1],
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 22,
          child: settled
              ? Text(resultText,
                  key: ValueKey(resultText),
                  style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold))
              : const Text('……',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _dieFace(int n) {
    const pipLayouts = {
      1: [Offset(0, 0)],
      2: [Offset(-1, -1), Offset(1, 1)],
      3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
      4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
      5: [Offset(-1, -1), Offset(1, -1), Offset(0, 0), Offset(-1, 1), Offset(1, 1)],
      6: [Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset(1, 0), Offset(-1, 1), Offset(1, 1)],
    };
    final pips = pipLayouts[n]!;
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final p in pips)
            Positioned(
              left: 31 + p.dx * 16 - 6,
              top: 31 + p.dy * 16 - 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFB3261E),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
