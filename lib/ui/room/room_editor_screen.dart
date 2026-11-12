import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/catalog.dart';
import '../../data/store.dart';
import '../../room/iso.dart';
import '../../room/layout.dart';
import '../../room/manifest.dart';
import '../../room/registry.dart';
import '../../room/scene.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import 'iso_room_painter.dart';
import 'iso_room_view.dart';
import 'minimi_sprite.dart';
import 'room_painter.dart';

/// 방 꾸미기 (전체 화면 편집). docs/asset-system/02 §7
/// 가구를 눌러 고르고, 끌어서 칸에 맞춰 옮기고, 회전하거나 보관함에 넣는다.
class RoomEditorScreen extends StatefulWidget {
  const RoomEditorScreen({super.key});
  @override
  State<RoomEditorScreen> createState() => _RoomEditorScreenState();
}

class _RoomEditorScreenState extends State<RoomEditorScreen> with SingleTickerProviderStateMixin {
  String? _selected;

  // 끄는 중
  String? _dragId;
  Offset _grab = Offset.zero; // 손가락과 가구 기준 꼭짓점 사이 (캔버스 좌표)
  FloorPos? _ghostFloor;
  WallPos? _ghostWall;
  bool _ghostOk = true;

  late final _idle = IdleClock(this);

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  AppState get _s => AppScope.read(context);

  bool Function(SceneEntry, int, int)? _opaque(AssetRegistry? reg) => reg == null
      ? null
      : (e, lx, ly) {
          final sp = reg.sprite(e.id, e.rot);
          return sp == null || sp.opaqueAt(lx, ly); // PNG가 없으면 상자 전체를 인정
        };

  void _tap(Offset canvasPt, RoomScene scene, AssetRegistry? reg) {
    final id = scene.hitTest(canvasPt, opaque: _opaque(reg));
    setState(() => _selected = id);
    if (id != null) HapticFeedback.selectionClick();
  }

  void _panStart(Offset canvasPt, RoomScene scene, AssetRegistry? reg) {
    final l = _s.room;
    final hit = scene.hitTest(canvasPt, opaque: _opaque(reg));
    final id = hit ?? _selected;
    if (id == null) return;
    if (l.floor[id] case final p?) {
      _grab = canvasPt - IsoGrid.toCanvas(p.x, p.y);
      setState(() {
        _selected = id;
        _dragId = id;
        _ghostFloor = p;
        _ghostOk = true;
      });
    } else if (l.wall[id] case final p?) {
      setState(() {
        _selected = id;
        _dragId = id;
        _ghostWall = p;
        _ghostOk = true;
      });
    }
  }

  void _panUpdate(Offset canvasPt) {
    final id = _dragId;
    if (id == null) return;
    final s = _s;
    if (_ghostFloor case final cur?) {
      final (gx, gy) = IsoGrid.toGrid(canvasPt - _grab);
      final next = FloorPos(gx.round(), gy.round(), cur.r);
      if (next == cur) return;
      HapticFeedback.selectionClick();
      setState(() {
        _ghostFloor = next;
        _ghostOk = s.occupancy.canPlaceFloor(s.room, id, next).ok;
      });
    } else if (_ghostWall case final cur?) {
      final art = s.manifest[id]!;
      final left = canvasPt.dx < IsoGrid.originX;
      final along = left ? (IsoGrid.originX - canvasPt.dx) / 32 : (canvasPt.dx - IsoGrid.originX) / 32;
      final u = (along - art.span / 2).round().clamp(0, IsoGrid.size - art.span);
      final next = WallPos(left: left, u: u, z: cur.z);
      if (next == cur) return;
      HapticFeedback.selectionClick();
      setState(() {
        _ghostWall = next;
        _ghostOk = s.occupancy.canPlaceWall(s.room, id, next).ok;
      });
    }
  }

  void _panEnd() {
    final id = _dragId;
    if (id == null) return;
    final s = _s;
    var moved = false;
    if (_ghostFloor case final p? when _ghostOk) moved = s.moveFloor(id, p).ok;
    if (_ghostWall case final p? when _ghostOk) moved = s.moveWall(id, p).ok;
    if (moved) HapticFeedback.lightImpact();
    if (!moved && (_ghostFloor != s.room.floor[id] || _ghostWall != s.room.wall[id])) {
      showAppToast(context, '여기엔 놓을 수 없어요');
    }
    setState(() {
      _dragId = null;
      _ghostFloor = null;
      _ghostWall = null;
    });
  }

  void _rotate(String id) {
    final r = _s.rotateFloor(id);
    if (!r.ok) showAppToast(context, '회전하면 다른 가구와 겹치거나 방 밖으로 나가요');
    setState(() {});
  }

  void _putAway(String id) {
    final item = itemById(id);
    if (item == null) return;
    _s.putAway(item);
    setState(() => _selected = null);
    showAppToast(context, '${item.name}을(를) 보관함에 넣었어요');
  }

  void _placeFromStorage(ShopItem item) {
    if (_s.use(item)) {
      HapticFeedback.lightImpact();
      setState(() => _selected = item.id);
    } else {
      showAppToast(context, '방에 빈 자리가 없어요. 다른 가구를 보관함에 넣어 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final reg = RegistryScope.of(context);
    final t = Theme.of(context).textTheme;
    final l = s.room;
    if (_selected != null && !l.contains(_selected!)) _selected = null;

    final override = <String, FloorPos>{if (_dragId != null && _ghostFloor != null) _dragId!: _ghostFloor!};
    final shownLayout = _ghostWall == null
        ? l
        : (RoomLayout.fromJson(l.toJson())..wall[_dragId!] = _ghostWall!);
    final scene = RoomScene.build(shownLayout, s.manifest, override: override);
    reg?.preload([...l.floor.keys, ...l.wall.keys]);
    reg?.preloadSurfaces(floor: l.floorSurface, wall: l.wallSurface);
    preloadMinimi(reg, s.profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('방 꾸미기'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('완료')),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: RoomViewport(
                lockScroll: _selected != null || _dragId != null,
                builder: (context, fit) => GestureDetector(
                  key: const Key('room-editor-canvas'),
                  behavior: HitTestBehavior.opaque,
                  // 손가락이 처음 닿은 곳에서 집는다 (기본값은 드래그로 인정된 지점)
                  dragStartBehavior: DragStartBehavior.down,
                  onTapUp: (d) => _tap(fit.toCanvas(d.localPosition), scene, reg),
                  // 작은 화면(가로 스크롤)에서 아무것도 고르지 않았으면 드래그는 스크롤에 양보한다.
                  // 가구를 탭해 고르면 스크롤이 잠기고 드래그로 옮길 수 있다.
                  onPanStart: fit.scrolls && _selected == null
                      ? null
                      : (d) => _panStart(fit.toCanvas(d.localPosition), scene, reg),
                  onPanUpdate: fit.scrolls && _selected == null ? null : (d) => _panUpdate(fit.toCanvas(d.localPosition)),
                  onPanEnd: fit.scrolls && _selected == null ? null : (_) => _panEnd(),
                  onPanCancel: fit.scrolls && _selected == null ? null : _panEnd,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _idle.frame,
                    builder: (context, tick, _) {
                      final frame = MediaQuery.of(context).disableAnimations ? 0 : tick;
                      return CustomPaint(
                        size: fit.size,
                        painter: IsoRoomPainter(
                          layout: shownLayout,
                          scene: scene,
                          manifest: s.manifest,
                          registry: reg,
                          drawMinimi: minimiDrawer(s.profile, frame: frame, registry: reg),
                          editing: true,
                          selected: _selected,
                          ghost: _dragId == null ? null : DragGhost(id: _dragId!, ok: _ghostOk),
                          repaintKey: frame,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: Motion.fast,
            child: _selected == null
                ? _StoragePanel(key: const ValueKey('storage'), onPick: _placeFromStorage)
                : _SelectedPanel(
                    key: ValueKey(_selected),
                    id: _selected!,
                    canRotate: (s.manifest[_selected!]?.rotatable ?? false) && l.floor.containsKey(_selected),
                    onRotate: () => _rotate(_selected!),
                    onPutAway: () => _putAway(_selected!),
                    onDone: () => setState(() => _selected = null),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
            child: Text(
              _selected == null ? '가구를 눌러 고르고, 끌어서 옮겨요' : '끌어서 옮기면 칸에 맞춰 놓여요',
              style: t.bodySmall,
            ),
          ),
        ]),
      ),
    );
  }
}

class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({
    super.key,
    required this.id,
    required this.canRotate,
    required this.onRotate,
    required this.onPutAway,
    required this.onDone,
  });
  final String id;
  final bool canRotate;
  final VoidCallback onRotate;
  final VoidCallback onPutAway;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final item = itemById(id);
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.sm),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(children: [
        Expanded(child: Text(item?.name ?? id, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (canRotate)
          IconButton(tooltip: '회전', onPressed: onRotate, icon: const Icon(Icons.rotate_90_degrees_ccw_rounded)),
        IconButton(tooltip: '보관함으로', onPressed: onPutAway, icon: const Icon(Icons.inventory_2_outlined)),
        IconButton(tooltip: '선택 해제', onPressed: onDone, icon: const Icon(Icons.check_rounded)),
      ]),
    );
  }
}

class _StoragePanel extends StatelessWidget {
  const _StoragePanel({super.key, required this.onPick});
  final ValueChanged<ShopItem> onPick;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final items = s.storedItems.where((i) => i.isFurniture && s.manifest[i.id]?.layer != ArtLayer.surface).toList();
    return Container(
      height: 112,
      margin: const EdgeInsets.symmetric(vertical: Space.sm),
      child: items.isEmpty
          ? Center(child: Text('보관함이 비어 있어요', style: t.bodySmall))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (context, i) {
                final item = items[i];
                return Semantics(
                  button: true,
                  label: '${item.name} 방에 놓기',
                  excludeSemantics: true,
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.md),
                      onTap: () => onPick(item),
                      child: SizedBox(
                        width: 88,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          ItemThumb(item, size: 56, minimi: s.profile.minimi),
                          const SizedBox(height: Space.xs),
                          Text(item.name, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
