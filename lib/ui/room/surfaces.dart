import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../room/iso.dart';
import '../../room/palette.dart';

/// 벽지·바닥·러그의 대체 그림 (PNG가 없을 때). 모양은 아이템 id로 정한다.

Color _c(int rgb) => Color(0xFF000000 | rgb);
Color _dark(int rgb, [double t = 0.08]) => Color.lerp(_c(rgb), _c(PixelPalette.ink[1]), t)!;

const _p = PixelPalette.cream, _terra = PixelPalette.terracotta, _floor = PixelPalette.floor;
const _pink = 0xFBDDD8, _pinkLight = 0xFFEAE6, _grey = 0xD6C8C4, _greyLight = 0xE4DAD6;

// ───────── 벽지 ─────────

enum WallPattern { plain, stripe, dot, panel, polka, gingham, wideStripe, diamond, heart, flower, hStripe }

/// 색을 고른 것('id~색')까지 받아 그 가구의 색 램프를 돌려준다 (원래 색이 정해진 것만).
List<int>? _rampOf(String id) {
  final item = itemById(id);
  final c = item?.color ?? item?.accent;
  return c == null ? null : PixelPalette.ramps[c.index];
}

class WallStyle {
  const WallStyle(this.base, [this.pattern = WallPattern.plain, this.accent = 0]);
  final int base;
  final WallPattern pattern;
  final int accent;
}

const wallStyles = <String, WallStyle>{
  'wall_sage': WallStyle(0xCFE0C8),
  'wall_sky': WallStyle(0xE3EEF7, WallPattern.dot, 0xFFF8EE),
  'wall_pink': WallStyle(_pink),
  'wall_butter': WallStyle(0xFBEFCB),
  'wall_lavender': WallStyle(0xE6D6E6, WallPattern.dot, 0xF3EDF2),
  'wall_grey': WallStyle(_greyLight),
  'wall_stripe': WallStyle(0xF6EBDD, WallPattern.stripe, 0xF8DCCB),
  'wall_night': WallStyle(0x4A6FA3, WallPattern.dot, 0xF2D27A),
  'wall_panel_wood': WallStyle(0xF6EBDD, WallPattern.panel, 0xD49E6E),
  'wall_panel_sage': WallStyle(0xFFF8EE, WallPattern.panel, 0xA9C4A3),
};

/// 색을 골라 살 수 있는 무늬 벽지. 무늬만 정하고, 색은 그 벽지의 램프(밝은 바탕 + 한 단계 짙은 무늬)로 칠한다.
const rampWalls = <String, WallPattern>{
  'wall_dot': WallPattern.polka,
  'wall_check': WallPattern.gingham,
  'wall_stripe_wide': WallPattern.wideStripe,
  'wall_diamond': WallPattern.diamond,
  'wall_heart': WallPattern.heart,
  'wall_floral': WallPattern.flower,
  'wall_hstripe': WallPattern.hStripe,
};

WallStyle wallStyleOf(String? id) {
  if (id == null) return WallStyle(_p[1]);
  final pattern = rampWalls[baseIdOf(id)], ramp = pattern == null ? null : _rampOf(id);
  if (ramp != null) return WallStyle(ramp[0], pattern!, ramp[1]);
  return wallStyles[baseIdOf(id)] ?? WallStyle(_p[1]);
}

/// 픽셀 그림을 뽑아 둘 벽지 id (색을 고른 것까지). tool/draw_furniture_test.dart 가 쓴다.
List<String> get wallSurfaceIds => [...wallStyles.keys, for (final id in rampWalls.keys) ...itemById(id)!.colorIds];

/// 벽 한 면. [at]은 (벽을 따라 몇 칸째, 바닥에서 높이 px) → 캔버스 좌표.
/// [shaded]는 빛을 덜 받는 오른쪽 벽 (01 §5).
void drawWall(Canvas c, WallStyle s, Offset Function(double u, double z) at, {double span = 8, bool shaded = false}) {
  const h = 160.0;
  Color col(int rgb, [double t = 0]) => _dark(rgb, t + (shaded ? 0.08 : 0));
  void quad(double u0, double u1, double z0, double z1, Color color) =>
      c.drawPath(Path()..addPolygon([at(u0, z0), at(u1, z0), at(u1, z1), at(u0, z1)], true), Paint()..color = color);
  quad(0, span, 0, h, col(s.base));
  switch (s.pattern) {
    case WallPattern.plain:
      break;
    case WallPattern.stripe:
      for (var u = 0.25; u < span; u += 0.5) {
        quad(u, u + 0.125, 0, h, col(s.accent));
      }
    case WallPattern.dot:
      var row = 0;
      for (var z = 22.0; z < h - 8; z += 22, row++) {
        for (var u = row.isEven ? 0.25 : 0.5; u < span; u += 0.5) {
          quad(u, u + 0.07, z, z + 3, col(s.accent));
        }
      }
    case WallPattern.panel:
      quad(0, span, 0, 56, col(s.accent));
      quad(0, span, 56, 59, col(s.accent, 0.25));
      for (var u = 0.5; u < span; u += 1) {
        quad(u, u + 0.04, 8, 56, col(s.accent, 0.15));
      }
    case WallPattern.polka:
      var row = 0;
      for (var z = 14.0; z < h - 8; z += 16, row++) {
        for (var u = row.isEven ? 0.17 : 0.42; u < span; u += 0.5) {
          quad(u, u + 0.16, z, z + 5, col(s.accent));
        }
      }
    case WallPattern.gingham:
      // 세로 띠와 가로 띠를 겹치고, 만나는 곳은 한 단계 짙게
      for (var u = 0.25; u < span; u += 0.5) {
        quad(u, u + 0.25, 0, h, col(s.accent));
      }
      for (var z = 8.0; z < h; z += 16) {
        final top = math.min(z + 8, h);
        quad(0, span, z, top, col(s.accent));
        for (var u = 0.25; u < span; u += 0.5) {
          quad(u, u + 0.25, z, top, col(s.accent, 0.18));
        }
      }
    case WallPattern.wideStripe:
      for (var u = 0.25; u < span; u += 0.5) {
        quad(u, u + 0.25, 0, h, col(s.accent));
      }
    case WallPattern.diamond:
      var row = 0;
      for (var z = 12.0; z < h; z += 12, row++) {
        for (var u = row.isEven ? 0.25 : 0.5; u < span + 0.25; u += 0.5) {
          c.drawPath(
            Path()..addPolygon([
              at(u - 0.18, z),
              at(u, math.min(z + 9, h)),
              at(math.min(u + 0.18, span), z),
              at(u, z - 9),
            ], true),
            Paint()..color = col(s.accent),
          );
        }
      }
    case WallPattern.hStripe:
      for (var z = 12.0; z < h; z += 24) {
        quad(0, span, z, math.min(z + 12, h), col(s.accent));
      }
    case WallPattern.heart || WallPattern.flower:
      // 벽면 기울기를 따라 찍는다 (한 칸 = 벽 0.09칸 × 3px)
      final rows = s.pattern == WallPattern.heart ? _heartRows : _flowerRows;
      final paint = Paint()..color = col(s.accent);
      var row = 0;
      for (var z = 26.0; z < h - 4; z += 22, row++) {
        for (var u = row.isEven ? 0.12 : 0.37; u + 0.27 <= span; u += 0.5) {
          _motif(c, rows, at(u, z), at(u + 0.09, z) - at(u, z), const Offset(0, 3), paint);
        }
      }
  }
}

const _heartRows = [[0, 2], [0, 1, 2], [1]], _flowerRows = [[1], [0, 2], [1]];

/// 3×3 칸짜리 작은 그림(하트·꽃잎 넷)을 [o]를 왼쪽 위로 찍는다. 한 칸은 가로 [u], 세로 [v].
void _motif(Canvas c, List<List<int>> rows, Offset o, Offset u, Offset v, Paint paint) {
  for (final (r, cols) in rows.indexed) {
    for (final k in cols) {
      final p = o + u * k.toDouble() + v * r.toDouble();
      c.drawPath(Path()..addPolygon([p, p + u, p + u + v, p + v], true), paint);
    }
  }
}

/// 바닥에 놓인 그림: 격자 위의 점 [center]에 화면 방향 그대로(한 칸 2px) 찍는다.
void _floorMotif(Canvas c, List<List<int>> rows, Offset center, Paint paint) => _motif(
  c,
  rows,
  Offset(center.dx.roundToDouble() - 3, center.dy.roundToDouble() - 3),
  const Offset(2, 0),
  const Offset(0, 2),
  paint,
);

// ───────── 바닥 ─────────

enum FloorPattern { plank, tile, plain, dot, gingham, stripe, heart, flower, stripeX }

class FloorStyle {
  const FloorStyle(this.a, this.b, this.line, [this.pattern = FloorPattern.plank]);
  final int a, b, line;
  final FloorPattern pattern;
}

const floorStyles = <String, FloorStyle>{
  'floor_light': FloorStyle(0xEADBC7, 0xF6EBDD, 0xD6C2A8),
  'floor_walnut': FloorStyle(0x8E6240, 0xB98559, 0x6A4630),
  'floor_checker': FloorStyle(0xFFF8EE, _grey, 0xD6C2A8, FloorPattern.tile),
  'floor_tile_sky': FloorStyle(0xE3EEF7, 0xBCD3E8, 0x9DBBD8, FloorPattern.tile),
  'floor_tile_sage': FloorStyle(0xFFF8EE, 0xCFE0C8, 0xA9C4A3, FloorPattern.tile),
  'floor_tile_terra': FloorStyle(0xF8DCCB, 0xEDA77F, 0xE08A5B, FloorPattern.tile),
  'floor_carpet_pink': FloorStyle(_pink, _pinkLight, 0xE5B5AE, FloorPattern.plain),
  'floor_carpet_grey': FloorStyle(_grey, _greyLight, 0xB3A19D, FloorPattern.plain),
};

/// 색을 골라 살 수 있는 무늬 장판. 색은 그 장판의 램프 (밝은 바탕, 무늬, 짙은 무늬·판 두께)로 칠한다.
const rampFloors = <String, FloorPattern>{
  'floor_dot': FloorPattern.dot,
  'floor_stripe': FloorPattern.stripe,
  'floor_check': FloorPattern.gingham,
  'floor_heart': FloorPattern.heart,
  'floor_floral': FloorPattern.flower,
  'floor_hstripe': FloorPattern.stripeX,
};

FloorStyle floorStyleOf(String? id) {
  if (id == null) return FloorStyle(_floor[1], _floor[0], _floor[2]);
  final pattern = rampFloors[baseIdOf(id)], ramp = pattern == null ? null : _rampOf(id);
  if (ramp != null) return FloorStyle(ramp[0], ramp[1], ramp[2], pattern!);
  return floorStyles[baseIdOf(id)] ?? FloorStyle(_floor[1], _floor[0], _floor[2]);
}

/// 픽셀 그림을 뽑아 둘 바닥 id (색을 고른 것까지).
List<String> get floorSurfaceIds => [...floorStyles.keys, for (final id in rampFloors.keys) ...itemById(id)!.colorIds];

/// (0,0)부터 [n]×[n] 칸 바닥과 앞쪽 판 두께.
void drawFloor(Canvas c, FloorStyle s, [int n = IsoGrid.size]) {
  final a = Paint()..color = _c(s.a), b = Paint()..color = _c(s.b);
  final line = Paint()
    ..color = _c(s.line)
    ..strokeWidth = 1;
  // 타일·체크·줄무늬는 반 칸씩, 나머지는 한 칸씩 칠한다
  final half = const [
    FloorPattern.tile,
    FloorPattern.gingham,
    FloorPattern.stripe,
    FloorPattern.stripeX,
  ].contains(s.pattern);
  final step = half ? 0.5 : 1.0;
  for (var j = 0; j * step < n; j++) {
    for (var i = 0; i * step < n; i++) {
      final x = i * step, y = j * step;
      final paint = switch (s.pattern) {
        FloorPattern.dot || FloorPattern.heart || FloorPattern.flower => a,
        FloorPattern.stripe => j.isEven ? a : b,
        FloorPattern.stripeX => i.isEven ? a : b,
        // 띠 둘이 만나는 칸은 짙게, 하나만 지나는 칸은 무늬 색
        FloorPattern.gingham => i.isOdd && j.isOdd ? (Paint()..color = _c(s.line)) : (i.isOdd || j.isOdd ? b : a),
        _ => (i + j).isEven ? a : b,
      };
      c.drawPath(
        Path()..addPolygon([
          IsoGrid.toCanvas(x, y),
          IsoGrid.toCanvas(x + step, y),
          IsoGrid.toCanvas(x + step, y + step),
          IsoGrid.toCanvas(x, y + step),
        ], true),
        paint,
      );
      // 땡땡이: 칸 가운데와 모서리에 번갈아
      if (s.pattern == FloorPattern.dot) {
        for (final (u, v) in [(0.25, 0.25), (0.75, 0.75)]) {
          c.drawPath(_disc((p, q) => IsoGrid.toCanvas(x + p, y + q), u, v, 0.11), b);
        }
      }
      if (s.pattern == FloorPattern.heart || s.pattern == FloorPattern.flower) {
        final rows = s.pattern == FloorPattern.heart ? _heartRows : _flowerRows;
        for (final (u, v) in [(0.25, 0.25), (0.75, 0.75)]) {
          _floorMotif(c, rows, IsoGrid.toCanvas(x + u, y + v), b);
        }
      }
      // 마루 결: gx 방향으로 두 줄
      if (s.pattern == FloorPattern.plank) {
        for (final t in [1 / 3, 2 / 3]) {
          c.drawLine(IsoGrid.toCanvas(x, y + t), IsoGrid.toCanvas(x + 1, y + t), line);
        }
      }
    }
  }
  // 바닥 판 두께 (앞쪽 두 변)
  final l = IsoGrid.toCanvas(0, n), f = IsoGrid.toCanvas(n, n), r = IsoGrid.toCanvas(n, 0);
  Path slab(Offset p, Offset q) => Path()..addPolygon([p, q, q.translate(0, 8), p.translate(0, 8)], true);
  c.drawPath(slab(l, f), Paint()..color = _c(s.line));
  c.drawPath(slab(f, r), Paint()..color = _dark(s.line, 0.25));
}

// ───────── 러그 ─────────

enum RugPattern { border, stripe, checker, dot, gingham, diamond, heart, flower, stripeU }

class RugStyle {
  const RugStyle(this.a, this.b, {this.round = false, this.pattern = RugPattern.border, this.c});
  final int a, b;
  final bool round;
  final RugPattern pattern;

  /// 깅엄 체크에서 띠 둘이 만나는 칸의 색
  final int? c;
}

/// 격자 위의 작은 원 (팔각형). [at]은 격자 좌표 → 캔버스 좌표.
Path _disc(Offset Function(double u, double v) at, double u, double v, double r) => Path()
  ..addPolygon([
    for (var i = 0; i < 8; i++) at(u + math.cos(i * math.pi / 4) * r, v + math.sin(i * math.pi / 4) * r),
  ], true);

const rugStyles = <String, RugStyle>{
  'rug_round': RugStyle(0xF8DCCB, 0xEDA77F, round: true),
  'rug_stripe': RugStyle(0xFFF8EE, 0xBCD3E8, pattern: RugPattern.stripe),
  'rug_sage': RugStyle(0xCFE0C8, 0xA9C4A3, round: true),
  'rug_checker': RugStyle(0xFFF8EE, 0xEDA77F, pattern: RugPattern.checker),
  'rug_runner': RugStyle(0xE6D6E6, 0xC9A3C9, pattern: RugPattern.stripe),
  'rug_pink': RugStyle(_pinkLight, 0xF4B8C8, round: true),
  'rug_navy': RugStyle(0x6A93C9, 0xE3EEF7),
  'rug_picnic': RugStyle(0xFFF8EE, 0xA9C4A3, pattern: RugPattern.checker),
  'rug_big': RugStyle(0xF6EBDD, 0xF2D27A, round: true),
  // 무늬 러그 3차. 색을 바꿔 칠할 수 있게 한 램프의 색과 크림색만 쓴다.
  'rug_dot': RugStyle(0xA9C4A3, 0xFFF8EE, pattern: RugPattern.dot),
  'rug_diamond': RugStyle(0xFBEFCB, 0xF2D27A, pattern: RugPattern.diamond),
  'rug_gingham': RugStyle(0xFFF8EE, 0xBCD3E8, pattern: RugPattern.gingham, c: 0x9DBBD8),
  'rug_dot_round': RugStyle(0xEDA77F, 0xFFF8EE, round: true, pattern: RugPattern.dot),
  'rug_heart': RugStyle(0xEDA77F, 0xFFF8EE, pattern: RugPattern.heart),
  'rug_floral': RugStyle(0xC9A3C9, 0xFFF8EE, round: true, pattern: RugPattern.flower),
  'rug_hstripe': RugStyle(0xFFF8EE, 0xBCD3E8, pattern: RugPattern.stripeU),
};

RugStyle rugStyleOf(String id) => rugStyles[baseIdOf(id)] ?? RugStyle(_terra[0], _terra[1]);

/// 점유 칸 (x, y, w, d)에 깔린 러그.
/// [antiAlias]를 끄면 가장자리가 번지지 않는다 (픽셀 그림을 뽑을 때. 번진 색은 색 바꾸기에서 빠진다).
// shortcut: 줄무늬는 돌려도 항상 gx 방향이다. 방향이 중요해지면 Rot을 받아 축을 바꿀 것.
void drawRug(Canvas c, RugStyle s, (int, int, int, int) f, {bool antiAlias = true}) {
  final (x, y, w, d) = f;
  Offset at(double u, double v) => IsoGrid.toCanvas(x + u, y + v);
  Path shape(double inset) => Path()
    ..addPolygon(
      s.round
          ? [
              for (var i = 0; i < 32; i++)
                at(
                  w / 2 + math.cos(i * math.pi / 16) * (w / 2 - inset),
                  d / 2 + math.sin(i * math.pi / 16) * (d / 2 - inset),
                ),
            ]
          : [at(inset, inset), at(w - inset, inset), at(w - inset, d - inset), at(inset, d - inset)],
      true,
    );
  Paint fill(int rgb) => Paint()
    ..color = _c(rgb)
    ..isAntiAlias = antiAlias;
  final outer = shape(0.08), b = fill(s.b);
  c.drawPath(outer, fill(s.a));
  void cell(double u0, double v0, double u1, double v1) =>
      c.drawPath(Path()..addPolygon([at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)], true), b);
  switch (s.pattern) {
    case RugPattern.border:
      c.drawPath(shape(0.3), b);
    case RugPattern.dot:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      var row = 0;
      for (var v = 0.3; v < d - 0.2; v += 0.35, row++) {
        for (var u = row.isEven ? 0.3 : 0.475; u < w - 0.2; u += 0.35) {
          c.drawPath(_disc(at, u, v, 0.09), b);
        }
      }
      c.restore();
    case RugPattern.heart || RugPattern.flower:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      final rows = s.pattern == RugPattern.heart ? _heartRows : _flowerRows;
      var row = 0;
      for (var v = 0.35; v < d - 0.25; v += 0.45, row++) {
        for (var u = row.isEven ? 0.35 : 0.575; u < w - 0.25; u += 0.45) {
          _floorMotif(c, rows, at(u, v), b);
        }
      }
      c.restore();
    case RugPattern.stripeU:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      for (var u = 0.25; u < w; u += 0.5) {
        cell(u, 0, u + 0.25, d.toDouble());
      }
      c.restore();
    case RugPattern.gingham:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      final cross = fill(s.c ?? s.b);
      for (var j = 0; j < d * 4; j++) {
        for (var i = 0; i < w * 4; i++) {
          if (i.isEven && j.isEven) continue;
          c.drawPath(
            Path()..addPolygon([at(i / 4, j / 4), at(i / 4 + 0.25, j / 4), at(i / 4 + 0.25, j / 4 + 0.25), at(i / 4, j / 4 + 0.25)], true),
            i.isOdd && j.isOdd ? cross : b,
          );
        }
      }
      c.restore();
    case RugPattern.diamond:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      var row = 0;
      for (var v = 0.25; v < d; v += 0.25, row++) {
        for (var u = row.isEven ? 0.25 : 0.5; u < w; u += 0.5) {
          c.drawPath(Path()..addPolygon([at(u - 0.2, v), at(u, v - 0.2), at(u + 0.2, v), at(u, v + 0.2)], true), b);
        }
      }
      c.restore();
    case RugPattern.stripe:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      for (var v = 0.25; v < d; v += 0.5) {
        cell(0, v, w.toDouble(), v + 0.25);
      }
      c.restore();
    case RugPattern.checker:
      c.save();
      c.clipPath(outer, doAntiAlias: antiAlias);
      for (var j = 0; j < d * 2; j++) {
        for (var i = 0; i < w * 2; i++) {
          if ((i + j).isOdd) cell(i / 2, j / 2, i / 2 + 0.5, j / 2 + 0.5);
        }
      }
      c.restore();
  }
}
