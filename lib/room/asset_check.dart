import 'dart:typed_data';
import 'dart:ui' as ui;

import 'iso.dart';
import 'manifest.dart';
import 'palette.dart';

/// 에셋 PNG 자동 검증 (docs/asset-system/02 §10). 문제 목록을 돌려준다. 비어 있으면 통과.
class AssetCheck {
  /// 바닥 물체 스프라이트: 크기, 알파 0/255, 팔레트, 허용 영역(점유 마름모를 높이만큼 올린 기둥).
  static Future<List<String>> objectSprite(ItemArt art, Rot rot, Uint8List png) async {
    final img = await _decode(png);
    final spec = art.spriteSpec(rot);
    final problems = <String>[];
    if (img.width != spec.width || img.height != spec.height) {
      problems.add('크기 ${img.width}×${img.height} ≠ ${spec.width}×${spec.height}');
      return problems;
    }
    final (w, d) = art.footprintFor(rot);
    final poly = allowedRegion(w, d, art.height, spec.ax, spec.ay);
    final px = await _rgba(img);
    var semi = 0, offPalette = 0, outside = 0;
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        final i = (y * img.width + x) * 4;
        final a = px[i + 3];
        if (a == 0) continue;
        if (a != 255) semi++;
        final rgb = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
        if (!PixelPalette.all.contains(rgb)) offPalette++;
        if (!_inside(poly, x + 0.5, y + 0.5)) outside++;
      }
    }
    if (semi > 0) problems.add('반투명 픽셀 $semi개 (알파는 0 또는 255만)');
    if (offPalette > 0) problems.add('팔레트 밖 색 $offPalette픽셀');
    if (outside > 0) problems.add('허용 영역 밖 픽셀 $outside개');
    return problems;
  }

  /// 허용 영역 육각형 (스프라이트 좌표). 1px 여유를 둔다.
  static List<(double, double)> allowedRegion(int w, int d, int h, int ax, int ay) {
    final b = (ax.toDouble(), ay.toDouble());
    final r = (ax + w * 32.0, ay + w * 16.0);
    final f = (ax + (w - d) * 32.0, ay + (w + d) * 16.0);
    final l = (ax - d * 32.0, ay + d * 16.0);
    final up = h.toDouble();
    return [
      (b.$1, b.$2 - up - 1),
      (r.$1 + 1, r.$2 - up),
      (r.$1 + 1, r.$2),
      (f.$1, f.$2 + 1),
      (l.$1 - 1, l.$2),
      (l.$1 - 1, l.$2 - up),
    ];
  }

  static bool _inside(List<(double, double)> poly, double x, double y) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final (xi, yi) = poly[i];
      final (xj, yj) = poly[j];
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }

  static Future<ui.Image> _decode(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    return (await codec.getNextFrame()).image;
  }

  static Future<Uint8List> _rgba(ui.Image img) async =>
      (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();

  /// 그리드 상수와 캔버스 크기가 서로 맞는지 (설정 실수 방지)
  static bool gridConsistent() =>
      IsoGrid.size * IsoGrid.tileW == IsoGrid.canvasW &&
      IsoGrid.originY + IsoGrid.size * IsoGrid.tileH + 8 == IsoGrid.canvasH;
}
