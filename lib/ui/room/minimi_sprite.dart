import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../room/registry.dart';
import 'iso_room_painter.dart';
import 'room_painter.dart';

/// 미니미 대기(idle) 애니메이션 시계: 4fps로 프레임 번호만 바꾼다 (01 §8.3).
/// TickerMode가 꺼지면(다른 탭) 멈추고, '동작 줄이기'면 0번 프레임에 머문다.
class IdleClock {
  IdleClock(TickerProvider vsync) {
    _ticker = vsync.createTicker((elapsed) {
      final f = (elapsed.inMilliseconds ~/ 250) % frames;
      if (f != frame.value) frame.value = f;
    })..start();
  }

  static const frames = 4;
  late final Ticker _ticker;
  final frame = ValueNotifier<int>(0);

  void dispose() {
    _ticker.dispose();
    frame.dispose();
  }
}

/// idle 프레임별 몸 오르내림(px): 2·3번 프레임에서 1px 내려감
const idleBob = [0, 1, 1, 0];

/// 방 그리기용 미니미 함수. 레이어 에셋이 모두 있으면 스프라이트로,
/// 하나라도 없으면 기존 미니미 그림으로 그린다(레이어를 섞지 않는다). 01 §8
MinimiDraw minimiDrawer(
  Profile p, {
  required int frame,
  AssetRegistry? registry,
  MinimiFacing facing = MinimiFacing.front,
}) {
  final layers = registry?.minimiLayers(
    outfitId: p.outfitId,
    accessoryId: p.accessoryId,
    skin: p.minimi.skin,
    hair: p.minimi.hair,
    facing: facing,
  );
  if (layers != null) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    return (canvas, frameRect) {
      final src = MinimiSheet.src(frame, facing);
      for (final l in layers) {
        if (l.mirror) {
          canvas.save();
          canvas.translate(frameRect.center.dx, 0);
          canvas.scale(-1, 1);
          canvas.translate(-frameRect.center.dx, 0);
          canvas.drawImageRect(l.sheet, src, frameRect, paint);
          canvas.restore();
        } else {
          canvas.drawImageRect(l.sheet, src, frameRect, paint);
        }
      }
    };
  }
  final outfit = itemById(p.outfitId)?.variant ?? 0;
  final acc = itemById(p.accessoryId)?.variant ?? 0;
  return (canvas, frameRect) {
    // 프레임 64×96, 발 앵커 (32, 88). 기존 그림은 가로:세로 = 1:1.2, 키 76px
    const h = 76.0, w = h / 1.2;
    final bob = idleBob[frame % idleBob.length].toDouble();
    final r = Rect.fromLTWH(frameRect.left + (frameRect.width - w) / 2, frameRect.top + 88 - h + bob, w, h);
    canvas.save();
    canvas.translate(r.left, r.top);
    if (facing == MinimiFacing.sideLeft) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    MinimiPainter(p.minimi, outfit: outfit, accessory: acc).paint(canvas, r.size);
    canvas.restore();
  };
}

/// 미니미 레이어 시트를 미리 읽는다 (없으면 아무 일도 없음)
void preloadMinimi(AssetRegistry? reg, Profile p) => reg?.preloadMinimi(
      outfitId: p.outfitId,
      accessoryId: p.accessoryId,
      skin: p.minimi.skin,
      hair: p.minimi.hair,
    );
