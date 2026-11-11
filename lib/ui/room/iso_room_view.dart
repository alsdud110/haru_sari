import 'package:flutter/material.dart';

import '../../app.dart';
import '../../room/iso.dart';
import '../../room/registry.dart';
import '../../room/scene.dart';
import 'iso_room_painter.dart';
import 'minimi_sprite.dart';

/// 방 표시 크기 (docs/asset-system/01 §1.4): 물리 픽셀 기준 정수배.
class RoomFit {
  const RoomFit({required this.scale, required this.size, required this.scrolls});
  final int scale;
  final Size size;
  final bool scrolls;

  static RoomFit of(double availableWidth, double dpr) {
    final s = IsoGrid.pixelScale(availableWidth * dpr);
    final size = Size(IsoGrid.canvasW * s / dpr, IsoGrid.canvasH * s / dpr);
    return RoomFit(scale: s, size: size, scrolls: size.width > availableWidth + 0.5);
  }

  /// 위젯 안 좌표 → 캔버스(512×432) 좌표
  Offset toCanvas(Offset local) => local * (IsoGrid.canvasW / size.width);
}

/// 방을 정수배로 키워 보여주고, 화면보다 넓으면 가로로 스크롤한다.
class RoomViewport extends StatefulWidget {
  const RoomViewport({super.key, required this.builder, this.lockScroll = false});

  /// (fit) → 방 위젯. 방 위젯은 fit.size 크기로 그린다.
  final Widget Function(BuildContext context, RoomFit fit) builder;

  /// 편집 중 끄는 동안 가로 스크롤을 막는다
  final bool lockScroll;

  @override
  State<RoomViewport> createState() => _RoomViewportState();
}

class _RoomViewportState extends State<RoomViewport> {
  final _scroll = ScrollController();
  bool _centered = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final fit = RoomFit.of(c.maxWidth, MediaQuery.of(context).devicePixelRatio);
      final room = SizedBox.fromSize(size: fit.size, child: widget.builder(context, fit));
      if (!fit.scrolls) return Center(child: room);
      if (!_centered) {
        // 처음엔 방 가운데를 보여준다
        _centered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo((fit.size.width - c.maxWidth) / 2);
        });
      }
      return SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: widget.lockScroll ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        child: room,
      );
    });
  }
}

/// 좌우 여백이 있는 목록 안에서도 방은 화면 폭 전체를 쓴다.
class FullBleed extends StatelessWidget {
  const FullBleed({super.key, required this.child, required this.height});
  final Widget child;
  final double height;

  static double heightFor(BuildContext context) {
    final mq = MediaQuery.of(context);
    return RoomFit.of(mq.size.width, mq.devicePixelRatio).size.height;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return SizedBox(
      height: height,
      child: OverflowBox(minWidth: w, maxWidth: w, child: child),
    );
  }
}

/// 보기 전용 아이소메트릭 방 (내 방 탭). 편집은 '방 꾸미기' 화면에서.
class IsoRoomView extends StatefulWidget {
  const IsoRoomView({super.key, required this.fit});
  final RoomFit fit;
  @override
  State<IsoRoomView> createState() => _IsoRoomViewState();
}

class _IsoRoomViewState extends State<IsoRoomView> with SingleTickerProviderStateMixin {
  late final _idle = IdleClock(this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    RegistryScope.of(context)?.preload(s.room.floor.keys);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final reg = RegistryScope.of(context);
    final l = s.room;
    return Semantics(
      label: '내 방. 가구 ${l.floor.length + l.wall.length}개',
      child: ValueListenableBuilder<int>(
        valueListenable: _idle.frame,
        builder: (context, tick, _) {
          final frame = MediaQuery.of(context).disableAnimations ? 0 : tick;
          return CustomPaint(
          size: widget.fit.size,
          painter: IsoRoomPainter(
            layout: l,
            scene: RoomScene.build(l, s.manifest),
            manifest: s.manifest,
            registry: reg,
            drawMinimi: minimiDrawer(s.profile, frame: frame, registry: reg),
            repaintKey: frame,
          ),
        );
        },
      ),
    );
  }
}
