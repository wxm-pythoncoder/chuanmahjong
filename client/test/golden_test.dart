// 玉石麻将牌渲染 golden 测试：输出真实像素 PNG 供视觉检查
// 运行：flutter test --update-goldens test/golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuanmahjong/widgets/jade_tile.dart';

void main() {
  testWidgets('生成全套 27 张玉石麻将牌 golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1240, 640));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: const Color(0xFF1E5E24),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (var suit = 0; suit < 3; suit++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var rank = 1; rank <= 9; rank++)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: JadeTile(
                          tile: suit * 9 + rank - 1,
                          width: 90,
                          height: 124,
                          raised: true,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              // 牌背与发光态
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(4),
                    child: JadeTile(tile: 0, width: 70, height: 96, blank: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(4),
                    child: JadeTile(tile: 13, width: 70, height: 96, glow: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(4),
                    child: JadeTile(tile: 4, width: 70, height: 96, glow: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // 位图资产是异步加载的：预加载全部贴图后再截图
    final ctx = tester.element(find.byType(Container).first);
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/tiles/Front.png'), ctx);
      for (var t = 0; t < 27; t++) {
        await precacheImage(AssetImage(tileAssetName(t)), ctx);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/jade_tiles_full_set.png'),
    );
  });
}
