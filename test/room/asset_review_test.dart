import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneul_sari/data/models.dart';
import 'package:oneul_sari/room/iso.dart';
import 'package:oneul_sari/room/layout.dart';
import 'package:oneul_sari/room/manifest.dart';
import 'package:oneul_sari/room/registry.dart';
import 'package:oneul_sari/room/scene.dart';
import 'package:oneul_sari/ui/room/iso_room_painter.dart';
import 'package:oneul_sari/ui/room/minimi_sprite.dart';

import 'manifest_test.dart' show loadManifest;
import 'scene_test.dart' show FakeBundle;

/// 후보 PNG를 앱 에셋에 넣지 않고 실제 방에 그려 검수 스크린샷을 만든다 (워크플로 6단계).
///
///   flutter test test/room/asset_review_test.dart \
///     --dart-define=REVIEW_ID=bed_single --dart-define=REVIEW_ROT=r0 \
///     --dart-define=REVIEW_PNG=art/work/bed_single_r0_gpt_v1_fit.png \
///     --dart-define=REVIEW_OUT=docs/asset-system/review/bed_single_r0_gpt_v1
///
/// 값이 없으면 건너뛴다(일반 테스트 실행에는 영향 없음).
const reviewId = String.fromEnvironment('REVIEW_ID');
const reviewRot = String.fromEnvironment('REVIEW_ROT', defaultValue: 'r0');
const reviewPng = String.fromEnvironment('REVIEW_PNG');
const reviewOut = String.fromEnvironment('REVIEW_OUT');

void main() {
  testWidgets('후보 에셋 방 안 검수 스크린샷', (tester) async {
    final m = loadManifest();
    final art = m[reviewId]!;
    final rot = Rot.values.byName(reviewRot);
    final path = '${PixelManifest.assetRoot}${art.rotations[rot]}';
    final reg = await tester.runAsync(() async {
      final r = AssetRegistry(m, bundle: FakeBundle({path: File(reviewPng).readAsBytesSync()}), showDraft: true);
      await r.preload([reviewId]);
      return r;
    });
    expect(reg!.sprite(reviewId, rot), isNotNull, reason: '크기가 규격과 다르면 레지스트리가 쓰지 않는다: ${reg.problems}');

    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final (w, d) = art.footprintFor(rot);
    final at = FloorPos(3, 2, rot);
    final neighbors = <String, FloorPos>{
      // 앞(x 또는 y가 큰 쪽)에 의자, 뒤에 화분, 옆에 러그 — 깊이 순서 확인용
      'chair_wood': FloorPos(3 + w, 2 + d - 1),
      'plant_small': const FloorPos(3, 1),
      'rug_round': FloorPos(0, 2 + d),
    };
    Future<void> shot(String suffix, {String? selected}) async {
      final l = RoomLayout(floor: {reviewId: at, ...neighbors}, minimi: (3 + w - 1, 2 + d + 1));
      final painter = IsoRoomPainter(
        layout: l,
        scene: RoomScene.build(l, m),
        manifest: m,
        registry: reg,
        drawMinimi: minimiDrawer(Profile(), frame: 0),
        editing: selected != null,
        selected: selected,
      );
      final key = GlobalKey();
      await tester.pumpWidget(Center(
        child: RepaintBoundary(key: key, child: CustomPaint(size: const Size(1024, 864), painter: painter)),
      ));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as dynamic;
        final ui.Image img = await boundary.toImage(pixelRatio: 1.0);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${reviewOut}_$suffix.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await shot('room');
    await shot('room_footprint', selected: reviewId);
    expect(IsoGrid.canvasW, 512);
  }, skip: reviewId.isEmpty || reviewPng.isEmpty || reviewOut.isEmpty);
}
