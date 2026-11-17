// 截图与下载：Web 用 dart:html 下载，其他平台空实现
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'download_stub.dart' if (dart.library.html) 'download_web.dart' as impl;

/// 截取 RepaintBoundary 为 PNG 字节
Future<Uint8List?> captureWidget(GlobalKey key, {double pixelRatio = 3}) async {
  final ctx = key.currentContext;
  final ro = ctx?.findRenderObject();
  if (ro is! RenderRepaintBoundary) return null;
  final image = await ro.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// 下载字节（按平台分发）
Future<void> downloadBytes(Uint8List bytes, String filename) =>
    impl.downloadBytes(bytes, filename);
