// 全局错误兜底：异常显示在屏幕上（不再白屏）
const fs = require('fs');
const p = 'C:/Users/xiaomingwang/.zcode/workspace/60268042-4997-4a13-b6e7-65360b48a60a/chuanmahjong/client/lib/main.dart';
let s = fs.readFileSync(p, 'utf8');
let ok = 0;

const a1 = `void main() {
  runApp(const ChuanMahjongApp());
}`;
if (s.includes(a1)) {
  s = s.replace(a1, `// 全局错误兜底：异常直接显示在屏幕上（不再白屏）
final ValueNotifier<String?> lastUiError = ValueNotifier<String?>(null);

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    lastUiError.value = 'Build错误: ' + details.exception.toString();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    lastUiError.value = '运行错误: ' + error.toString();
    return true;
  };
  runApp(const ChuanMahjongApp());
}`);
  ok++;
}

const a2 = '      home: const HomePage(),';
if (s.includes(a2)) {
  s = s.replace(a2, `      home: const HomePage(),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [
              Positioned.fill(child: child ?? const SizedBox()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<String?>(
                  valueListenable: lastUiError,
                  builder: (context, err, _) => err == null
                      ? const SizedBox(height: 0)
                      : Material(
                          color: const Color(0xFFB3261E),
                          child: InkWell(
                            onTap: () => lastUiError.value = null,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(err,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),`);
  ok++;
}

// imports
if (!s.includes('PlatformDispatcher')) {
  s = s.replace("import 'dart:async';", "import 'dart:async';\nimport 'dart:ui' show PlatformDispatcher;");
  ok++;
}

fs.writeFileSync(p, s);
console.log('ok:', ok, '/3');
