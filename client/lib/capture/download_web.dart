// Web 下载实现：Blob + Anchor 触发保存
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
