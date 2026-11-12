import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../room/iso.dart';
import '../../room/layout.dart';
import '../../room/manifest.dart';
import '../../room/palette.dart';
import '../../room/registry.dart';
import '../../room/scene.dart';
import 'iso_boxes.dart';
import 'room_painter.dart';
import 'surfaces.dart';

Color px(int rgb) => Color(0xFF000000 | rgb);

/// 미니미를 프레임 상자(64×96, 캔버스 좌표)에 그리는 함수
typedef MinimiDraw = void Function(Canvas canvas, Rect frame);

/// 편집 중 끌고 있는 가구
class DragGhost {
  const DragGhost({required this.id, required this.ok});
  final String id;
  final bool ok;
}

/// 아이소메트릭 방 그리기 (docs/asset-system/03 §3).
/// 캔버스 좌표는 네이티브 512×432이며, 위젯 크기에 맞춰 한 번에 확대한다.
/// PNG가 없거나 쓸 수 없으면 기존 벡터 그림(drawFurniture)으로 대체한다.
class IsoRoomPainter extends CustomPainter {
  IsoRoomPainter({
    required this.layout,
    required this.scene,
    required this.manifest,
    required this.registry,
    required this.drawMinimi,
    this.editing = false,
    this.selected,
    this.ghost,
    this.repaintKey = 0,
  });

  final RoomLayout layout;
  final RoomScene scene;
  final PixelManifest manifest;
  final AssetRegistry? registry;
  final MinimiDraw drawMinimi;
  final bool editing;
  final String? selected;
  final DragGhost? ghost;

  /// 애니메이션 프레임 등 바뀔 때 다시 그리기 위한 값
  final int repaintKey;

  static final _sprite = Paint()..filterQuality = FilterQuality.none;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / IsoGrid.canvasW, size.height / IsoGrid.canvasH);
    canvas.clipRect(Offset.zero & IsoGrid.canvas);
    _walls(canvas);
    _floor(canvas);
    for (final e in scene.entries) {
      final isGhost = ghost?.id == e.id;
      if (e.kind == EntryKind.object || e.kind == EntryKind.minimi) _shadow(canvas, e);
      if (editing && (e.id == selected || isGhost) && e.footprint != null) {
        _footprintFill(canvas, e.footprint!, isGhost ? ghost!.ok : true);
      }
      if (isGhost) canvas.saveLayer(null, Paint()..color = const Color(0xB3FFFFFF));
      switch (e.kind) {
        case EntryKind.minimi:
          drawMinimi(canvas, e.box.rect);
        case EntryKind.floorDecor || EntryKind.object:
          _item(canvas, e);
        case EntryKind.wall:
          _wallItem(canvas, e);
      }
      if (isGhost) canvas.restore();
    }
    canvas.restore();
  }

  // ───────── 벽 ─────────

  /// 픽셀 그림(방 전체 크기 한 장)이 있으면 그걸 깔고, 없으면 화면에서 바로 그린다.
  bool _surface(Canvas c, String kind, String? id) {
    final img = registry?.surface(kind, id);
    if (img == null) return false;
    c.drawImage(img, Offset.zero, _sprite);
    return true;
  }

  void _walls(Canvas c) {
    if (!_surface(c, 'walls', layout.wallSurface)) drawRoomWalls(c, wallStyleOf(layout.wallSurface));
  }

  /// 두 벽면 + 걸레받이 + 모서리선 (tool/draw_furniture_test.dart 도 이 그림을 픽셀로 뽑는다).
  static void drawRoomWalls(Canvas c, WallStyle style) {
    const h = IsoGrid.wallH;
    final o = IsoGrid.toCanvas(0, 0), l = IsoGrid.toCanvas(0, 8), r = IsoGrid.toCanvas(8, 0);
    drawWall(c, style, (u, z) => IsoGrid.toCanvas(0, u).translate(0, -z));
    drawWall(c, style, (u, z) => IsoGrid.toCanvas(u, 0).translate(0, -z), shaded: true);
    // 걸레받이 8px + 모서리선
    final base = Paint()..color = px(PixelPalette.wood[1]);
    final baseDark = Paint()..color = px(PixelPalette.wood[2]);
    Path band(Offset a, Offset b, double t) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx, b.dy - t)
      ..lineTo(a.dx, a.dy - t)
      ..close();
    c.drawPath(band(o, l, 8), base);
    c.drawPath(band(o, r, 8), baseDark);
    final edge = Paint()
      ..color = px(PixelPalette.cream[3])
      ..strokeWidth = 1;
    c.drawLine(Offset(o.dx, o.dy), Offset(o.dx, o.dy - h), edge);
    // 벽 윗변
    final top = Paint()
      ..color = px(PixelPalette.wood[2])
      ..strokeWidth = 2;
    c.drawLine(Offset(o.dx, o.dy - h), Offset(l.dx, l.dy - h), top);
    c.drawLine(Offset(o.dx, o.dy - h), Offset(r.dx, r.dy - h), top);
  }

  // ───────── 바닥 ─────────

  void _floor(Canvas c) {
    if (!_surface(c, 'floors', layout.floorSurface)) drawFloor(c, floorStyleOf(layout.floorSurface));
  }

  // ───────── 아이템 ─────────

  void _shadow(Canvas c, SceneEntry e) {
    final f = e.footprint;
    if (f == null) return;
    final art = manifest[e.id];
    if (e.kind == EntryKind.object && art != null && !art.blocking) return; // 매달린 조명은 그림자 없음
    final d = RoomScene.footprintDiamond(f);
    final center = d.reduce((a, b) => a + b) / 4;
    final inset = [for (final p in d) center + (p - center) * 0.86];
    c.drawPath(
      Path()..addPolygon(inset, true),
      Paint()..color = px(PixelPalette.shadow).withValues(alpha: PixelPalette.shadowAlpha),
    );
  }

  void _footprintFill(Canvas c, (int, int, int, int) f, bool ok) {
    final d = RoomScene.footprintDiamond(f);
    final color = ok ? px(PixelPalette.sage[2]) : px(PixelPalette.terracotta[2]);
    c.drawPath(Path()..addPolygon(d, true), Paint()..color = color.withValues(alpha: 0.35));
    c.drawPath(
      Path()..addPolygon(d, true),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _item(Canvas c, SceneEntry e) {
    final s = registry?.sprite(e.id, e.rot);
    final dst = e.box.rect;
    if (s != null) {
      final src = Rect.fromLTWH(0, 0, s.image.width.toDouble(), s.image.height.toDouble());
      if (s.mirror) {
        c.save();
        c.translate(dst.center.dx, 0);
        c.scale(-1, 1);
        c.translate(-dst.center.dx, 0);
        c.drawImageRect(s.image, src, dst, _sprite);
        c.restore();
      } else {
        c.drawImageRect(s.image, src, dst, _sprite);
      }
      return;
    }
    _fallback(c, e);
  }

  /// PNG가 없을 때: 기존 벡터 그림을 계산된 상자 안에 그린다 (02 §9.2).
  void _fallback(Canvas c, SceneEntry e) {
    final item = itemById(baseIdOf(e.id));
    if (item == null) return;
    if (e.kind == EntryKind.floorDecor) {
      drawRug(c, rugStyleOf(item.id), e.footprint!);
      return;
    }
    // 방향이 있는 가구(침대·책상·의자): 상자를 쌓아 네 방향 입체로 그린다
    final boxes = isoBoxesFor(item, manifest[e.id]?.footprint ?? (1, 1));
    if (boxes != null) {
      final (x, y, _, _) = e.footprint!;
      drawIsoBoxes(c, boxes, manifest[e.id]!.footprint, e.rot, x, y);
      return;
    }
    // 대칭 가구(조명·화분): 점유 칸 위쪽 상자에 기존 그림 (가로세로 비율 유지, 바닥에 붙임)
    final box = e.box.rect;
    final ref = slotRect(item.slot!, const Size(300, 300));
    final ratio = ref.width / ref.height;
    var w = box.width * 0.9, h = w / ratio;
    if (h > box.height * 0.95) {
      h = box.height * 0.95;
      w = h * ratio;
    }
    final bottom = box.bottom - (e.footprint == null ? 0 : (e.footprint!.$3 + e.footprint!.$4) * 16 * 0.35);
    drawFurniture(c, item, Rect.fromLTWH(box.center.dx - w / 2, bottom - h, w, h));
  }

  void _wallItem(Canvas c, SceneEntry e) {
    final item = itemById(e.id);
    if (item == null) return;
    final box = e.box.rect;
    final art = manifest[e.id];
    final onLeft = layout.wall[e.id]?.left ?? true;
    // 픽셀 그림이 있으면 그걸 쓴다. 왼쪽 벽 기울기로 그린 한 장이라 오른쪽 벽에서는 좌우로 뒤집는다.
    final s = registry?.wallSprite(e.id);
    if (s != null) {
      final src = Rect.fromLTWH(0, 0, s.image.width.toDouble(), s.image.height.toDouble());
      if (onLeft) {
        c.drawImageRect(s.image, src, box, _sprite);
      } else {
        c.save();
        c.translate(box.center.dx, 0);
        c.scale(-1, 1);
        c.translate(-box.center.dx, 0);
        c.drawImageRect(s.image, src, box, _sprite);
        c.restore();
      }
      return;
    }
    // 그림이 없으면 기존 그림을 벽 기울기만큼 비스듬히 그린다.
    final h = (art?.height ?? 40).toDouble();
    // 벽면 기울기: 왼쪽 벽은 x가 1 늘면 y가 0.5 줄고, 오른쪽 벽은 0.5 는다.
    final k = onLeft ? -0.5 : 0.5;
    // 장식 왼쪽 위 모서리의 y (왼쪽 벽은 왼쪽 끝이 가장 낮고, 오른쪽 벽은 오른쪽 끝이 가장 낮다)
    final topLeftY = onLeft ? box.bottom - h : box.bottom - box.width * 0.5 - h;
    c.save();
    c.translate(box.left, topLeftY);
    c.transform((Matrix4.identity()..setEntry(1, 0, k)).storage);
    drawFurniture(c, item, Rect.fromLTWH(0, 0, box.width, h));
    c.restore();
  }

  @override
  bool shouldRepaint(IsoRoomPainter old) =>
      old.layout != layout ||
      old.scene != scene ||
      old.selected != selected ||
      old.ghost?.id != ghost?.id ||
      old.ghost?.ok != ghost?.ok ||
      old.editing != editing ||
      old.repaintKey != repaintKey ||
      old.registry != registry;
}
