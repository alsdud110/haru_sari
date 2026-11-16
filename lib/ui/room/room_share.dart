import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../data/store.dart';
import '../../room/iso.dart';
import '../../room/registry.dart';
import '../../room/scene.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import '../widgets.dart';
import 'iso_room_painter.dart';
import 'minimi_sprite.dart';

/// 방과 미니미만 담은 PNG. 닉네임·기록·달성률·경험치·코인은 넣지 않는다.
/// 화면에 보이는 크기와 상관없이 원본(512×432)의 [scale]배로 그린다.
Future<Uint8List> renderRoomPng(AppState s, AssetRegistry? reg, {int scale = 3}) async {
  final size = IsoGrid.canvas * scale.toDouble();
  final rec = ui.PictureRecorder();
  // 투명한 배경은 메신저에서 검게 보이므로 앱 바탕색을 깐다
  final canvas = Canvas(rec)..drawRect(Offset.zero & size, Paint()..color = AppColors.background);
  IsoRoomPainter(
    layout: s.room,
    scene: RoomScene.build(s.room, s.manifest),
    manifest: s.manifest,
    registry: reg,
    drawMinimi: minimiDrawer(s.profile, frame: 0, registry: reg),
  ).paint(canvas, size);
  final picture = rec.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// 방 이미지를 만들어 기기의 공유 화면을 연다. [context]는 누른 버튼의 것 (iPad 는 그 자리에서 창이 뜬다).
Future<void> shareRoomImage(BuildContext context) async {
  final s = AppScope.read(context);
  final reg = RegistryScope.of(context);
  final box = context.findRenderObject() as RenderBox?;
  try {
    final png = await renderRoomPng(s, reg);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: const ['harusari-room.png'],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (e) {
    debugPrint('room share failed: $e');
    if (context.mounted) showAppToast(context, '방 이미지를 만들지 못했어요. 잠시 뒤 다시 해 주세요');
  }
}

/// 방 방문 공개 스위치. 서버에 바로 저장하고, 저장하지 못하면 이전 상태 그대로 둔다.
/// 서버가 없는 빌드(테스트)에서는 아무것도 그리지 않는다.
class RoomVisitSwitch extends StatefulWidget {
  const RoomVisitSwitch({super.key});

  @override
  State<RoomVisitSwitch> createState() => _RoomVisitSwitchState();
}

class _RoomVisitSwitchState extends State<RoomVisitSwitch> {
  /// 서버에서 확인한 공개 상태. 아직 모르면 null (스위치를 잠근다).
  bool? _public;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool? v;
    try {
      v = await AppScope.read(context).sync?.remote.roomPublic();
    } catch (e) {
      debugPrint('room public load failed: $e');
    }
    if (mounted) {
      setState(() {
        _public = v;
        _busy = false;
      });
    }
  }

  Future<void> _set(bool on) async {
    final remote = AppScope.read(context).sync!.remote;
    if (on) {
      final ok = await showAppDialog<bool>(
        context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('방을 방문할 수 있게 열까요?'),
          content: const Text(
            '방문한 사람은 꾸민 방과 미니미의 모습만 볼 수 있어요.\n'
            '루틴, 기록, 메모, 달성률, 코인은 보이지 않고 방을 바꿀 수도 없어요.\n'
            '이 스위치를 끄면 언제든 공개를 멈출 수 있어요.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그대로 둘게요')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('공개하기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    var saved = false;
    try {
      await remote.setRoomPublic(on);
      saved = true;
    } catch (e) {
      debugPrint('room public save failed: $e');
    }
    if (!mounted) return;
    setState(() {
      if (saved) _public = on;
      _busy = false;
    });
    if (saved) HapticFeedback.selectionClick();
    showAppToast(
      context,
      !saved
          ? '공개 상태를 바꾸지 못했어요. 잠시 뒤 다시 해 주세요'
          : on
          ? '이제 방을 방문할 수 있어요'
          : '방 공개를 멈췄어요',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppScope.of(context).sync == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final v = _public;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('방 방문 공개', style: t.titleMedium),
                const SizedBox(height: 2),
                Text(
                  _busy
                      ? '확인하고 있어요'
                      : v == null
                      ? '지금은 공개 상태를 확인할 수 없어요'
                      : v
                      ? '공개 중이에요. 방의 모습만 보여요'
                      : '나만 볼 수 있어요',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          // 상태를 모를 때 누르면 다시 확인한다
          if (!_busy && v == null)
            TextButton(
              onPressed: () {
                setState(() => _busy = true);
                _load();
              },
              child: const Text('다시 확인'),
            )
          else
            Semantics(
              label: '방 방문 공개',
              child: Switch.adaptive(value: v ?? false, onChanged: _busy ? null : _set),
            ),
        ],
      ),
    );
  }
}
