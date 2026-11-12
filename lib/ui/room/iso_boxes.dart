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
final _white = [_cream[0], _cream[1], _cream[2], PixelPalette.floor[3]];
const _sage = PixelPalette.sage, _sky = PixelPalette.sky, _terra = PixelPalette.terracotta;
const _butter = PixelPalette.butter, _tan = PixelPalette.floor;
final _lav = [...PixelPalette.lavender, PixelPalette.hair[7][2]];
final _pink = [...PixelPalette.hair[4], PixelPalette.ink[0]];
final _navy = [...PixelPalette.hair[5], PixelPalette.ink[1]];
final _grey = [...PixelPalette.hair[3], PixelPalette.ink[0]];
final _walnut = [...PixelPalette.hair[1], PixelPalette.ink[1]];
final _black = [...PixelPalette.hair[0], PixelPalette.ink[1]];
final _bear = [...PixelPalette.hair[2], PixelPalette.ink[0]];
final _green = [_sage[1], _sage[2], _sage[3], PixelPalette.ink[0]];

/// 다리 넷: 모서리에서 [inset]만큼 들어온 자리에 굵기 [t], 높이 [h].
List<IsoBox> _legs(double w, double d, double inset, double t, double h, List<int> ramp) => [
  for (final x in [inset, w - inset - t])
    for (final y in [inset, d - inset - t]) IsoBox(x, y, x + t, y + t, 0, h, ramp),
];

List<IsoBox> _sofa(double w, List<int> c) => [
  IsoBox(0.04, 0.1, w - 0.04, 0.94, 0, 14, c),
  IsoBox(0.04, 0.1, w - 0.04, 0.3, 14, 40, c), // 등받이
  IsoBox(0.04, 0.3, 0.2, 0.94, 14, 26, c), // 팔걸이
  IsoBox(w - 0.2, 0.3, w - 0.04, 0.94, 14, 26, c),
  IsoBox(0.2, 0.3, w - 0.2, 0.92, 14, 19, c), // 방석
  if (w > 1) IsoBox(0.26, 0.3, 0.5, 0.4, 19, 30, _butter), // 쿠션
];

/// id로 정해지는 가구 (R0 기준).
List<IsoBox>? _boxesById(String id, double w, double d) => switch (id) {
  'sofa_single' => _sofa(w, _terra),
  'sofa_cream' => _sofa(w, _paleFrame),
  'sofa_sage' => _sofa(w, _sage),
  'sofa_pink' => _sofa(w, _pink),
  'chair_stool' => [..._legs(w, d, 0.27, 0.08, 18, _wood), IsoBox(0.25, 0.25, 0.75, 0.75, 18, 23, _terra)],
  'chair_bean' => [
    IsoBox(0.12, 0.12, 0.88, 0.88, 0, 14, _lav),
    IsoBox(0.2, 0.14, 0.8, 0.5, 14, 28, _lav),
    IsoBox(0.22, 0.5, 0.78, 0.84, 14, 18, _lav),
  ],
  'table_side' => [
    IsoBox(0.44, 0.44, 0.56, 0.56, 0, 26, _wood),
    IsoBox(0.2, 0.2, 0.8, 0.8, 26, 30, _wood),
    IsoBox(0.35, 0.35, 0.6, 0.55, 30, 33, _sky), // 책
  ],
  'table_coffee' => [
    ..._legs(w, d, 0.16, 0.08, 14, _wood),
    IsoBox(0.1, 0.15, w - 0.1, 0.85, 14, 18, _wood),
    IsoBox(0.5, 0.4, 0.62, 0.52, 18, 24, _terra), // 머그
    IsoBox(1.1, 0.35, 1.45, 0.6, 18, 21, _sage), // 책
  ],
  'table_dining' => [
    ..._legs(w, d, 0.16, 0.1, 30, _wood),
    IsoBox(0.1, 0.1, w - 0.1, d - 0.1, 30, 35, _wood),
    IsoBox(0.7, 0.1, 1.3, d - 0.1, 35, 36, _cream), // 러너
    IsoBox(0.9, 0.9, 1.1, 1.1, 36, 48, _sage), // 꽃병
  ],
  'nightstand' => [
    IsoBox(0.15, 0.1, 0.85, 0.8, 0, 30, _wood),
    IsoBox(0.12, 0.07, 0.88, 0.86, 30, 33, _wood),
    IsoBox(0.2, 0.8, 0.8, 0.83, 6, 26, _wood), // 서랍
    IsoBox(0.42, 0.36, 0.58, 0.52, 33, 38, _wood),
    IsoBox(0.34, 0.28, 0.66, 0.6, 38, 48, _butter), // 갓
  ],
  'shelf_cube' => [
    IsoBox(0.1, 0.15, 0.9, 0.75, 0, 50, _paleFrame),
    IsoBox(0.12, 0.75, 0.5, 0.85, 2, 24, _sage), // 수납함 넷
    IsoBox(0.5, 0.75, 0.88, 0.85, 2, 24, _terra),
    IsoBox(0.12, 0.75, 0.5, 0.85, 26, 48, _butter),
    IsoBox(0.5, 0.75, 0.88, 0.85, 26, 48, _sky),
  ],
  'drawer_wood' => [
    IsoBox(0.08, 0.1, w - 0.08, 0.8, 0, 44, _wood),
    IsoBox(0.05, 0.07, w - 0.05, 0.86, 44, 48, _wood),
    for (final z in [4.0, 17.0, 30.0]) IsoBox(0.14, 0.8, w - 0.14, 0.84, z, z + 11, _wood), // 서랍 셋
    IsoBox(0.3, 0.3, 0.45, 0.45, 48, 54, _terra), // 화분
    IsoBox(0.26, 0.26, 0.49, 0.49, 54, 62, _green),
  ],
  'bookcase_tall' => [
    IsoBox(0.08, 0.1, w - 0.08, 0.5, 0, 84, _wood),
    for (final z in [0.0, 26.0, 52.0, 78.0]) IsoBox(0.08, 0.5, w - 0.08, 0.66, z, z + 4, _wood), // 선반
    for (final (row, z) in [4.0, 30.0, 56.0].indexed)
      for (var i = 0; i < 6; i++)
        if ((i + row) % 4 != 3) // 군데군데 빈 칸
          IsoBox(0.14 + i * 0.28, 0.5, 0.4 + i * 0.28, 0.62, z, z + 16 + (i + row) % 3 * 3, [
            _sage,
            _terra,
            _sky,
            _butter,
            _lav,
          ][(i + row * 2) % 5]),
  ],
  'wardrobe_white' => [
    IsoBox(0.08, 0.1, w - 0.08, 0.85, 0, 90, _white),
    IsoBox(0.05, 0.07, w - 0.05, 0.9, 90, 94, _white),
    IsoBox(0.12, 0.85, w / 2 - 0.01, 0.88, 6, 86, _white), // 문 둘
    IsoBox(w / 2 + 0.01, 0.85, w - 0.12, 0.88, 6, 86, _white),
    IsoBox(w / 2 - 0.08, 0.88, w / 2 - 0.04, 0.9, 40, 52, _wood), // 손잡이
    IsoBox(w / 2 + 0.04, 0.88, w / 2 + 0.08, 0.9, 40, 52, _wood),
  ],
  'tv_stand' => [
    IsoBox(0.06, 0.2, w - 0.06, 0.85, 0, 20, _wood),
    IsoBox(0.12, 0.85, w / 2 - 0.02, 0.88, 4, 16, _wood), // 문 둘
    IsoBox(w / 2 + 0.02, 0.85, w - 0.12, 0.88, 4, 16, _wood),
    IsoBox(w / 2 - 0.1, 0.4, w / 2 + 0.1, 0.55, 20, 24, _black),
    IsoBox(0.35, 0.42, w - 0.35, 0.5, 24, 54, _black), // 화면
  ],
  'fridge_mint' => [
    IsoBox(0.15, 0.12, 0.85, 0.8, 0, 52, _sage),
    IsoBox(0.17, 0.8, 0.83, 0.83, 2, 30, _sage), // 문 둘
    IsoBox(0.17, 0.8, 0.83, 0.83, 32, 50, _sage),
    IsoBox(0.7, 0.83, 0.74, 0.85, 20, 28, _white), // 손잡이
    IsoBox(0.7, 0.83, 0.74, 0.85, 34, 42, _white),
  ],
  'plant_cactus' => [
    IsoBox(0.32, 0.32, 0.68, 0.68, 0, 12, _terra),
    IsoBox(0.4, 0.4, 0.6, 0.6, 12, 36, _green),
    IsoBox(0.6, 0.44, 0.72, 0.56, 20, 30, _green),
    IsoBox(0.28, 0.44, 0.4, 0.56, 16, 24, _green),
  ],
  'plant_flower' => [
    IsoBox(0.3, 0.3, 0.7, 0.7, 0, 12, _white),
    IsoBox(0.28, 0.28, 0.72, 0.72, 12, 24, _green),
    IsoBox(0.32, 0.32, 0.46, 0.46, 24, 30, _pink),
    IsoBox(0.54, 0.36, 0.68, 0.5, 24, 32, _butter),
    IsoBox(0.4, 0.54, 0.54, 0.68, 24, 29, _terra),
  ],
  'plant_tree' => [
    IsoBox(0.3, 0.3, 0.7, 0.7, 0, 16, _white),
    IsoBox(0.46, 0.46, 0.54, 0.54, 16, 44, _wood),
    IsoBox(0.22, 0.22, 0.78, 0.78, 44, 66, _green),
    IsoBox(0.32, 0.32, 0.68, 0.68, 66, 82, _green),
  ],
  'lamp_mood' => [IsoBox(0.36, 0.36, 0.64, 0.64, 0, 6, _wood), IsoBox(0.28, 0.28, 0.72, 0.72, 6, 28, _butter)],
  'lamp_floor' => [
    IsoBox(0.36, 0.36, 0.64, 0.64, 0, 4, _wood),
    IsoBox(0.47, 0.47, 0.53, 0.53, 4, 66, _wood),
    IsoBox(0.28, 0.28, 0.72, 0.72, 66, 90, _butter),
  ],
  'decor_books' => [
    IsoBox(0.25, 0.3, 0.7, 0.65, 0, 5, _sky),
    IsoBox(0.28, 0.32, 0.72, 0.68, 5, 10, _terra),
    IsoBox(0.3, 0.3, 0.66, 0.62, 10, 14, _sage),
  ],
  'decor_bear' => [
    IsoBox(0.3, 0.32, 0.7, 0.68, 0, 18, _bear),
    IsoBox(0.3, 0.68, 0.44, 0.8, 0, 8, _bear), // 다리
    IsoBox(0.56, 0.68, 0.7, 0.8, 0, 8, _bear),
    IsoBox(0.28, 0.3, 0.72, 0.7, 18, 34, _bear), // 머리
    IsoBox(0.28, 0.44, 0.38, 0.56, 34, 39, _bear), // 귀
    IsoBox(0.62, 0.44, 0.72, 0.56, 34, 39, _bear),
    IsoBox(0.42, 0.7, 0.58, 0.76, 20, 27, _white), // 주둥이
  ],
  'decor_fishbowl' => [
    IsoBox(0.2, 0.25, 0.8, 0.75, 0, 22, _wood),
    IsoBox(0.24, 0.29, 0.76, 0.71, 22, 42, _sky),
    IsoBox(0.24, 0.29, 0.76, 0.71, 42, 44, _wood),
  ],
  'decor_mirror' => [
    IsoBox(0.25, 0.4, 0.75, 0.6, 0, 4, _wood),
    IsoBox(0.25, 0.44, 0.75, 0.5, 4, 76, _wood),
    IsoBox(0.3, 0.5, 0.7, 0.52, 8, 72, _sky), // 거울 면
  ],
  'decor_cattower' => [
    IsoBox(0.15, 0.15, 0.85, 0.85, 0, 6, _paleFrame),
    IsoBox(0.25, 0.25, 0.4, 0.4, 6, 50, _tan), // 기둥
    IsoBox(0.45, 0.2, 0.85, 0.6, 6, 30, _sage), // 집
    IsoBox(0.15, 0.15, 0.6, 0.6, 50, 54, _paleFrame),
    IsoBox(0.25, 0.25, 0.4, 0.4, 54, 84, _tan),
    IsoBox(0.12, 0.12, 0.55, 0.55, 84, 88, _paleFrame),
    IsoBox(0.2, 0.2, 0.46, 0.46, 88, 96, _grey), // 고양이
  ],
  'decor_xmas' => [
    IsoBox(0.38, 0.38, 0.62, 0.62, 0, 10, _wood),
    IsoBox(0.15, 0.15, 0.85, 0.85, 10, 30, _green),
    IsoBox(0.24, 0.24, 0.76, 0.76, 30, 48, _green),
    IsoBox(0.33, 0.33, 0.67, 0.67, 48, 64, _green),
    IsoBox(0.45, 0.45, 0.55, 0.55, 64, 72, _butter), // 별
  ],
  _ => null,
};

/// 그 아이템의 상자들 (R0 기준). 방향이 없는 가구(조명·화분 등)는 null.
List<IsoBox>? isoBoxesFor(ShopItem item, (int, int) footprint) {
  final w = footprint.$1.toDouble(), d = footprint.$2.toDouble();
  final byId = _boxesById(item.id, w, d);
  if (byId != null) return byId;
  switch (item.slot) {
    case RoomSlot.bed:
      const m = 0.06;
      final frame = const [1, 3, 5].contains(item.variant) ? _paleFrame : _wood;
      final blanket = switch (item.variant) {
        1 => PixelPalette.sky,
        2 => PixelPalette.sage,
        3 => _pink,
        4 => _navy,
        5 => _lav,
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
      final vanity = item.id == 'desk_vanity';
      final ramp = item.variant == 1 || vanity ? _white : (item.variant == 2 ? _walnut : _wood);
      return [
        for (final (x0, x1) in [(0.08, 0.18), (w - 0.18, w - 0.08)])
          for (final (y0, y1) in [(0.12, 0.22), (0.78, 0.88)]) IsoBox(x0, y0, x1, y1, 0, 36, ramp), // 다리
        IsoBox(w - 0.75, 0.22, w - 0.18, 0.78, 16, 36, ramp), // 서랍
        IsoBox(0.03, 0.07, w - 0.03, 0.93, 36, 41, ramp), // 상판
        IsoBox(0.03, 0.07, w - 0.03, 0.15, 41, 52, ramp), // 뒤쪽 가림판
        IsoBox(0.4, 0.5, 0.52, 0.62, 41, 48, vanity ? _pink : PixelPalette.terracotta), // 머그
        if (vanity) IsoBox(0.45, 0.07, w - 0.45, 0.15, 52, 72, _sky), // 거울
      ];
    case RoomSlot.chair:
      final ramp = item.variant == 1 ? _white : _wood;
      return [
        for (final (x0, x1) in [(0.22, 0.3), (0.7, 0.78)])
          for (final (y0, y1) in [(0.22, 0.3), (0.7, 0.78)]) IsoBox(x0, y0, x1, y1, 0, 20, ramp), // 다리
        IsoBox(0.2, 0.2, 0.8, 0.8, 20, 24, ramp), // 앉는 면
        IsoBox(0.2, 0.2, 0.8, 0.28, 24, 46, ramp), // 등받이
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
