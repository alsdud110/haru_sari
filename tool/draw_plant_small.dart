// 작은 화분 스프라이트를 코드로 그린다 (docs/asset-system/01 §3.1: 1×1, h 36 → 64×72, 앵커 (32,40)).
//
// 사용: dart run tool/draw_plant_small.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:haru_sari/room/palette.dart';

const w = 64, h = 72, cx = 32;
final px = List<int?>.filled(w * h, null); // 0xRRGGBB, null = 투명

/// [part] 픽셀을 칠하고, 그 둘레 1px에 외곽선을 두른다 (먼저 그린 부분 위에도 덮는다).
void stamp(Map<(int, int), int> part, int outline) {
  for (final e in part.entries) {
    px[e.key.$2 * w + e.key.$1] = e.value;
  }
  for (final (x, y) in part.keys) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final p = (x + dx, y + dy);
      if (!part.containsKey(p)) px[p.$2 * w + p.$1] = outline;
    }
  }
}

/// 기울어진 타원 잎. 광원이 왼쪽 위라 왼쪽 위는 밝게, 오른쪽 아래는 그늘.
Map<(int, int), int> leaf(double lx, double ly, double rx, double ry, double deg) {
  const sage = PixelPalette.sage;
  final a = deg * math.pi / 180, c = math.cos(a), s = math.sin(a);
  final out = <(int, int), int>{};
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = x + 0.5 - lx, dy = y + 0.5 - ly;
      final u = dx * c + dy * s, v = -dx * s + dy * c;
      if (u * u / (rx * rx) + v * v / (ry * ry) > 1) continue;
      final t = (dx + dy) / (rx + ry);
      out[(x, y)] = u.abs() < 0.6 && v > -ry * 0.5
          ? sage[3] // 잎맥
          : t < -0.3
              ? sage[0]
              : t > 0.3
                  ? sage[2]
                  : sage[1];
    }
  }
  return out;
}

/// 아래로 좁아지는 화분. 테두리(림) 4줄 + 몸통.
Map<(int, int), int> pot() {
  const tc = PixelPalette.terracotta;
  final out = <(int, int), int>{};
  for (var y = 45; y <= 62; y++) {
    final rim = y <= 48;
    final hw = rim
        ? (y == 45 || y == 48 ? 9 : 10)
        : y == 62
            ? 5
            : (9 - (y - 49) * 3 / 13).round();
    for (var dx = -hw; dx < hw; dx++) {
      final t = (dx + 0.5) / hw;
      out[(cx + dx, y)] = y == 49
          ? tc[3] // 림 아래 그늘
          : t > 0.35
              ? tc[2]
              : dx == -hw + 2
                  ? tc[0] // 왼쪽 하이라이트 한 줄
                  : tc[1];
    }
  }
  return out;
}

void main() {
  const leafLine = 0x6F8F6B, potLine = 0x6A4630;
  stamp(leaf(25, 37, 4.5, 8.5, -35), leafLine);
  stamp(leaf(39, 37, 4.5, 8.5, 35), leafLine);
  stamp(leaf(32.5, 32, 5, 10.5, 0), leafLine);
  // 잎 밑동 사이 빈틈을 줄기 색으로 메운다
  for (var y = 41; y <= 45; y++) {
    for (var x = 27; x <= 36; x++) {
      px[y * w + x] ??= leafLine;
    }
  }
  stamp(pot(), potLine);

  final out = img.Image(width: w, height: h, numChannels: 4);
  for (var i = 0; i < px.length; i++) {
    final c = px[i];
    if (c == null) continue;
    assert(PixelPalette.all.contains(c));
    out.setPixelRgba(i % w, i ~/ w, c >> 16, (c >> 8) & 0xFF, c & 0xFF, 255);
  }
  final f = File('assets/pixel/furniture/decorations/plant_small_r0.png')..createSync(recursive: true);
  f.writeAsBytesSync(img.encodePng(out));
  stdout.writeln('wrote ${f.path}');
}
