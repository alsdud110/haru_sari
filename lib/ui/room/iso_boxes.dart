import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../room/iso.dart';
import '../../room/palette.dart';

/// PNG가 없는 방향 가구의 대체 그림: 상자를 쌓아 만든 입체.
/// 상자를 3D로 돌린 뒤 그리므로 네 방향이 모두 나오고, 명암도 광원(왼쪽 위)에 맞는다.
///
/// 좌표는 R0 기준 점유 칸 안의 위치 (x: 0~w, y: 0~d, 단위 타일)와 바닥에서의 높이 (z, px).
/// R0에서 앞면은 +y 쪽(왼쪽 아래)이다.
class IsoBox {
  const IsoBox(this.x0, this.y0, this.x1, this.y1, this.z0, this.z1, this.ramp);
  final double x0, y0, x1, y1, z0, z1;

  /// 윗면, 왼쪽 면, 오른쪽 면, 모서리선 색 (0xRRGGBB)
  final List<int> ramp;
}

const _wood = PixelPalette.wood;
const _cream = PixelPalette.cream;
final _paleFrame = [_cream[1], _cream[2], _cream[3], PixelPalette.floor[3]];

/// 그 아이템의 상자들 (R0 기준). 방향이 없는 가구(조명·화분 등)는 null.
List<IsoBox>? isoBoxesFor(ShopItem item, (int, int) footprint) {
  final w = footprint.$1.toDouble(), d = footprint.$2.toDouble();
  switch (item.slot) {
    case RoomSlot.bed:
      const m = 0.06;
      final frame = item.variant == 1 ? _paleFrame : _wood;
      final blanket = switch (item.variant) {
        1 => PixelPalette.sky,
        2 => PixelPalette.sage,
        _ => PixelPalette.terracotta,
      };
      return [
        IsoBox(m, m, w - m, d - m, 0, 10, frame),
        IsoBox(m, m, w - m, m + 0.1, 10, 48, frame), // 헤드보드
        IsoBox(m, d - m - 0.08, w - m, d - m, 10, 16, frame), // 발판
        IsoBox(m + 0.04, m + 0.1, w - m - 0.04, 0.8, 10, 22, _cream), // 매트리스
        for (var i = 0; i < footprint.$1; i++) IsoBox(i + 0.2, m + 0.16, i + 0.8, m + 0.5, 22, 27, _cream), // 베개
        IsoBox(m + 0.02, 0.8, w - m - 0.02, d - m - 0.08, 10, 24, blanket), // 이불
      ];
    case RoomSlot.desk:
      final ramp = item.variant == 1 ? [_cream[0], _cream[1], _cream[2], PixelPalette.floor[3]] : _wood;
      return [
        for (final (x0, x1) in [(0.08, 0.18), (w - 0.18, w - 0.08)])
          for (final (y0, y1) in [(0.12, 0.22), (0.78, 0.88)]) IsoBox(x0, y0, x1, y1, 0, 36, ramp), // 다리
        IsoBox(w - 0.75, 0.22, w - 0.18, 0.78, 16, 36, ramp), // 서랍
        IsoBox(0.03, 0.07, w - 0.03, 0.93, 36, 41, ramp), // 상판
        IsoBox(0.03, 0.07, w - 0.03, 0.15, 41, 52, ramp), // 뒤쪽 가림판
        IsoBox(0.4, 0.5, 0.52, 0.62, 41, 48, PixelPalette.terracotta), // 머그
      ];
    case RoomSlot.chair:
      return [
        for (final (x0, x1) in [(0.22, 0.3), (0.7, 0.78)])
          for (final (y0, y1) in [(0.22, 0.3), (0.7, 0.78)]) IsoBox(x0, y0, x1, y1, 0, 20, _wood), // 다리
        const IsoBox(0.2, 0.2, 0.8, 0.8, 20, 24, _wood), // 앉는 면
        const IsoBox(0.2, 0.2, 0.8, 0.28, 24, 46, _wood), // 등받이
      ];
    default:
      return null;
  }
}

/// R0 기준 상자를 [r] 방향으로 돌린다. 결과는 돌린 뒤 점유 칸 안의 좌표.
IsoBox rotateBox(IsoBox b, (int, int) footprint, Rot r) {
  final (w, d) = footprint;
  (double, double) turn(double x, double y) => switch (r) {
    Rot.r0 => (x, y),
    Rot.r1 => (y, w - x),
    Rot.r2 => (w - x, d - y),
    Rot.r3 => (d - y, x),
  };
  final (ax, ay) = turn(b.x0, b.y0);
  final (bx, by) = turn(b.x1, b.y1);
  return IsoBox(
    ax < bx ? ax : bx,
    ay < by ? ay : by,
    ax < bx ? bx : ax,
    ay < by ? by : ay,
    b.z0,
    b.z1,
    b.ramp,
  );
}

/// 뒤 → 앞 순서 (나중에 그릴수록 앞). 서로 겹치지 않는 상자들이라고 본다.
List<IsoBox> sortBackToFront(List<IsoBox> boxes) {
  const eps = 1e-6;
  bool behind(IsoBox a, IsoBox b) => a.x1 <= b.x0 + eps || a.y1 <= b.y0 + eps || a.z1 <= b.z0 + eps;
  final rest = [...boxes], out = <IsoBox>[];
  while (rest.isNotEmpty) {
    final next = rest.firstWhere(
      (a) => !rest.any((b) => b != a && behind(b, a) && !behind(a, b)),
      orElse: () => rest.first,
    );
    rest.remove(next);
    out.add(next);
  }
  return out;
}

/// (gx, gy)에 놓인 가구를 캔버스(네이티브 512×432 좌표)에 그린다.
void drawIsoBoxes(Canvas c, List<IsoBox> boxes, (int, int) footprint, Rot r, int gx, int gy) {
  Offset p(double x, double y, double z) => IsoGrid.toCanvas(gx + x, gy + y).translate(0, -z);
  for (final b in sortBackToFront([for (final b in boxes) rotateBox(b, footprint, r)])) {
    final faces = [
      ([p(b.x0, b.y1, b.z0), p(b.x1, b.y1, b.z0), p(b.x1, b.y1, b.z1), p(b.x0, b.y1, b.z1)], b.ramp[1]), // 왼쪽
      ([p(b.x1, b.y0, b.z0), p(b.x1, b.y1, b.z0), p(b.x1, b.y1, b.z1), p(b.x1, b.y0, b.z1)], b.ramp[2]), // 오른쪽
      ([p(b.x0, b.y0, b.z1), p(b.x1, b.y0, b.z1), p(b.x1, b.y1, b.z1), p(b.x0, b.y1, b.z1)], b.ramp[0]), // 위
    ];
    final line = Paint()
      ..color = Color(0xFF000000 | b.ramp[3])
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    for (final (pts, color) in faces) {
      final path = Path()..addPolygon(pts, true);
      c.drawPath(path, Paint()..color = Color(0xFF000000 | color));
      c.drawPath(path, line);
    }
  }
}
