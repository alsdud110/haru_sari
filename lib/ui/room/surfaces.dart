import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../room/iso.dart';
import '../../room/palette.dart';

/// 벽지·바닥·러그의 대체 그림 (PNG가 없을 때). 모양은 아이템 id로 정한다.

Color _c(int rgb) => Color(0xFF000000 | rgb);
Color _dark(int rgb, [double t = 0.08]) => Color.lerp(_c(rgb), _c(PixelPalette.ink[1]), t)!;

const _p = PixelPalette.cream, _terra = PixelPalette.terracotta, _floor = PixelPalette.floor;
const _pink = 0xFBDDD8, _pinkLight = 0xFFEAE6, _grey = 0xD6C8C4, _greyLight = 0xE4DAD6;

// ───────── 벽지 ─────────

enum WallPattern { plain, stripe, dot, panel }

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

WallStyle wallStyleOf(String? id) => wallStyles[id] ?? WallStyle(_p[1]);

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
  }
}

// ───────── 바닥 ─────────

enum FloorPattern { plank, tile, plain }

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

FloorStyle floorStyleOf(String? id) => floorStyles[id] ?? FloorStyle(_floor[1], _floor[0], _floor[2]);

/// (0,0)부터 [n]×[n] 칸 바닥과 앞쪽 판 두께.
void drawFloor(Canvas c, FloorStyle s, [int n = IsoGrid.size]) {
  final a = Paint()..color = _c(s.a), b = Paint()..color = _c(s.b);
  final line = Paint()
    ..color = _c(s.line)
    ..strokeWidth = 1;
  // 타일은 반 칸짜리 체크, 나머지는 한 칸씩 번갈아 칠한다
  final step = s.pattern == FloorPattern.tile ? 0.5 : 1.0;
  for (var j = 0; j * step < n; j++) {
    for (var i = 0; i * step < n; i++) {
      final x = i * step, y = j * step;
      c.drawPath(
        Path()..addPolygon([
          IsoGrid.toCanvas(x, y),
          IsoGrid.toCanvas(x + step, y),
          IsoGrid.toCanvas(x + step, y + step),
          IsoGrid.toCanvas(x, y + step),
        ], true),
        (i + j).isEven ? a : b,
      );
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

enum RugPattern { border, stripe, checker }

class RugStyle {
  const RugStyle(this.a, this.b, {this.round = false, this.pattern = RugPattern.border});
  final int a, b;
  final bool round;
  final RugPattern pattern;
}

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
};

RugStyle rugStyleOf(String id) => rugStyles[id] ?? RugStyle(_terra[0], _terra[1]);

/// 점유 칸 (x, y, w, d)에 깔린 러그.
// shortcut: 줄무늬는 돌려도 항상 gx 방향이다. 방향이 중요해지면 Rot을 받아 축을 바꿀 것.
void drawRug(Canvas c, RugStyle s, (int, int, int, int) f) {
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
  final outer = shape(0.08), b = Paint()..color = _c(s.b);
  c.drawPath(outer, Paint()..color = _c(s.a));
  void cell(double u0, double v0, double u1, double v1) =>
      c.drawPath(Path()..addPolygon([at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)], true), b);
  switch (s.pattern) {
    case RugPattern.border:
      c.drawPath(shape(0.3), b);
    case RugPattern.stripe:
      c.save();
      c.clipPath(outer);
      for (var v = 0.25; v < d; v += 0.5) {
        cell(0, v, w.toDouble(), v + 0.25);
      }
      c.restore();
    case RugPattern.checker:
      c.save();
      c.clipPath(outer);
      for (var j = 0; j < d * 2; j++) {
        for (var i = 0; i < w * 2; i++) {
          if ((i + j).isOdd) cell(i / 2, j / 2, i / 2 + 0.5, j / 2 + 0.5);
        }
      }
      c.restore();
  }
}
