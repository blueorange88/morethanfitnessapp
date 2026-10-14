import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 바디 이미지에서 몸이 있는 곳(투명하지 않은 곳)을 알려 주는 마스크.
/// 구역이 없는 곳(머리·목·관절 등)을 눌러도 점을 찍을 수 있게 하되, 배경을
/// 눌러서는 찍히지 않게 한다.
class BodyMask {
  BodyMask._(this._width, this._height, this._alpha, this._viewBox);

  /// 항상 몸으로 보는 마스크(테스트용).
  BodyMask.open(ui.Size viewBox)
    : _width = 1,
      _height = 1,
      _alpha = Uint8List.fromList(const [255]),
      _viewBox = viewBox;

  final int _width;
  final int _height;
  final Uint8List _alpha;
  final ui.Size _viewBox;

  static const int _sampleWidth = 300;
  static const int _threshold = 40;

  /// 이미지 에셋을 읽어 마스크를 만든다. 테스트에서는 바꿔 끼울 수 있다.
  static Future<BodyMask?> Function(String asset, ui.Size viewBox) loader =
      defaultLoader;

  static final Map<String, Future<BodyMask?>> _cache =
      <String, Future<BodyMask?>>{};

  static Future<BodyMask?> load(String asset, ui.Size viewBox) =>
      _cache.putIfAbsent(asset, () => loader(asset, viewBox));

  static void resetCacheForTest() => _cache.clear();

  static Future<BodyMask?> defaultLoader(String asset, ui.Size viewBox) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: _sampleWidth,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return null;
      final width = image.width;
      final height = image.height;
      final alpha = Uint8List(width * height);
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = bytes.getUint8(i * 4 + 3);
      }
      image.dispose();
      return BodyMask._(width, height, alpha, viewBox);
    } catch (_) {
      return null;
    }
  }

  /// viewBox 좌표 [point] 가 몸 위인지. 가장자리는 이웃 한 칸까지 너그럽게 본다.
  bool contains(ui.Offset point) {
    final px = (point.dx / _viewBox.width * _width).floor();
    final py = (point.dy / _viewBox.height * _height).floor();
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final x = px + dx;
        final y = py + dy;
        if (x < 0 || y < 0 || x >= _width || y >= _height) continue;
        if (_alpha[y * _width + x] >= _threshold) return true;
      }
    }
    return false;
  }
}
