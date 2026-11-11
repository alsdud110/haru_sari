import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/room/asset_check.dart';
import 'package:haru_sari/room/iso.dart';

import 'manifest_test.dart' show loadManifest;

/// 작은 화분 (tool/draw_plant_small.dart로 그린 draft)
void main() {
  testWidgets('작은 화분 R0: 크기·알파·팔레트·허용 영역 모두 통과', (tester) async {
    await tester.runAsync(() async {
      final png = File('assets/pixel/furniture/decorations/plant_small_r0.png').readAsBytesSync();
      expect(await AssetCheck.objectSprite(loadManifest()['plant_small']!, Rot.r0, png), isEmpty);
    });
  });
}
