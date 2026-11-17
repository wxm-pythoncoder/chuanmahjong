// 下载空实现（非 Web 平台）
import 'dart:typed_data';

Future<void> downloadBytes(Uint8List bytes, String filename) async {
  // 非 Web 平台暂不支持文件下载（iOS 打包后可接入分享）
}
