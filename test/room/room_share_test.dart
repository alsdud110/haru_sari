import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/ui/room/room_share.dart';

import 'manifest_test.dart' show loadManifest;

void main() {
  testWidgets('방 공유 이미지는 원본 방 크기의 배수인 PNG 다', (tester) async {
    final s = AppState(MemoryKeyValue(), clock: () => DateTime(2026, 11, 15), manifest: loadManifest());
    await tester.runAsync(() async {
      final png = await renderRoomPng(s, null, scale: 2);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final image = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
      expect((image.width, image.height), (IsoGrid.canvas.width * 2, IsoGrid.canvas.height * 2));
    });
  });
}
