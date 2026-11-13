import 'dart:ui';

import 'depth.dart';
import 'iso.dart';
import 'layout.dart';
import 'manifest.dart';

enum EntryKind { floorDecor, wall, object, minimi }

/// 그릴 것 하나 (위치·크기 확정)
class SceneEntry {
  const SceneEntry({required this.id, required this.kind, required this.box, this.rot = Rot.r0, this.footprint});
  final String id;
  final EntryKind kind;
  final SpriteBox box;
  final Rot rot;

  /// 바닥 점유 (x, y, w, d). 벽 장식은 null
  final (int, int, int, int)? footprint;
}

/// 방 장면 계산 (그리기와 분리해 테스트할 수 있게). 순서는 그리는 순서(뒤 → 앞).
class RoomScene {
  RoomScene._(this.entries);

  final List<SceneEntry> entries;

  static const minimiFrame = (w: 64, h: 96, ax: 32, ay: 88);

  /// 미니미 프레임 상자: 발(앵커)이 타일 중심에 놓인다
  static SpriteBox minimiBox(int x, int y) {
    final c = IsoGrid.tileCenter(x, y);
    return SpriteBox(
      left: c.dx.round() - minimiFrame.ax,
      top: c.dy.round() - minimiFrame.ay,
      width: minimiFrame.w,
      height: minimiFrame.h,
    );
  }

  static SpriteBox wallBoxFor(ItemArt art, WallPos p) =>
      IsoGrid.wallBox(left: p.left, u: p.u, span: art.span, z: p.z, h: art.height);

  factory RoomScene.build(RoomLayout l, PixelManifest m, {Map<String, FloorPos>? override}) {
    final floor = {...l.floor, ...?override};
    final out = <SceneEntry>[];

    // 1) 러그 (바닥 장식): (x+y) 순
    final decor = floor.entries.where((e) => m[e.key]?.layer == ArtLayer.floorDecor).toList()
      ..sort((a, b) => (a.value.x + a.value.y).compareTo(b.value.x + b.value.y));
    for (final e in decor) {
      out.add(_floorEntry(e.key, e.value, m[e.key]!, EntryKind.floorDecor));
    }

    // 2) 벽 장식
    final walls = l.wall.entries.where((e) => m[e.key] != null).toList()
      ..sort((a, b) => a.value.u.compareTo(b.value.u));
    for (final e in walls) {
      out.add(SceneEntry(id: e.key, kind: EntryKind.wall, box: wallBoxFor(m[e.key]!, e.value)));
    }

    // 3) 물체 + 미니미 깊이 정렬
    final objs = floor.entries.where((e) => m[e.key]?.layer == ArtLayer.object).toList();
    final items = <DepthItem>[
      for (final e in objs)
        () {
          final (w, d) = m[e.key]!.footprintFor(e.value.r);
          return DepthItem(e.key, e.value.x, e.value.y, w, d);
        }(),
      DepthItem(minimiId, l.minimi.$1, l.minimi.$2, 1, 1),
    ];
    for (final di in depthSort(items)) {
      if (di.id == minimiId) {
        out.add(SceneEntry(
          id: minimiId,
          kind: EntryKind.minimi,
          box: minimiBox(di.x, di.y),
          footprint: (di.x, di.y, 1, 1),
        ));
      } else {
        out.add(_floorEntry(di.id, floor[di.id]!, m[di.id]!, EntryKind.object));
      }
    }
    return RoomScene._(out);
  }

  static const minimiId = '__minimi__';

  static SceneEntry _floorEntry(String id, FloorPos p, ItemArt art, EntryKind kind) {
    final (w, d) = art.footprintFor(p.r);
    return SceneEntry(
      id: id,
      kind: kind,
      rot: p.r,
      box: IsoGrid.spriteBox(p.x, p.y, w, d, art.height),
      footprint: (p.x, p.y, w, d),
    );
  }

  /// 터치한 아이템 (앞 → 뒤 순서로 찾는다). 미니미는 [minimi]를 켰을 때만 고른다 (방 꾸미기).
  /// [opaque]가 주어지면 그 픽셀이 실제로 칠해진 곳만 인정한다(PNG 알파 마스크).
  String? hitTest(Offset p, {bool Function(SceneEntry e, int lx, int ly)? opaque, bool minimi = false}) {
    for (final e in entries.reversed) {
      if (e.kind == EntryKind.minimi && !minimi) continue;
      if (!e.box.contains(p)) continue;
      if (opaque != null && !opaque(e, (p.dx - e.box.left).floor(), (p.dy - e.box.top).floor())) continue;
      return e.id;
    }
    return null;
  }

  /// 바닥 마름모 꼭짓점 (뒤, 오른쪽, 앞, 왼쪽)
  static List<Offset> footprintDiamond((int, int, int, int) f) {
    final (x, y, w, d) = f;
    return [
      IsoGrid.toCanvas(x, y),
      IsoGrid.toCanvas(x + w, y),
      IsoGrid.toCanvas(x + w, y + d),
      IsoGrid.toCanvas(x, y + d),
    ];
  }
}
