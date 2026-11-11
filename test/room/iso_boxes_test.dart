import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/ui/room/iso_boxes.dart';

/// 검수 그림: `flutter test test/room/iso_boxes_test.dart --dart-define=REVIEW_PNG=<파일>`
const reviewPng = String.fromEnvironment('REVIEW_PNG');

void main() {
  const ids = ['bed_single', 'bed_double', 'bed_quilt', 'desk_wood', 'desk_white', 'chair_wood'];
  const fps = {'bed_single': (1, 2), 'bed_double': (2, 2), 'bed_quilt': (1, 2), 'desk_wood': (2, 1), 'desk_white': (2, 1), 'chair_wood': (1, 1)};

  test('네 방향 모두: 돌린 상자가 그 방향의 점유 칸 안에 있다', () {
    for (final id in ids) {
      final fp = fps[id]!;
      final boxes = isoBoxesFor(itemById(id)!, fp)!;
      for (final r in Rot.values) {
        final (w, d) = r.index.isEven ? fp : (fp.$2, fp.$1);
        for (final b in boxes.map((b) => rotateBox(b, fp, r))) {
          expect(b.x0 >= 0 && b.y0 >= 0 && b.x1 <= w && b.y1 <= d && b.x0 < b.x1 && b.y0 < b.y1, isTrue, reason: '$id $r');
        }
        expect(sortBackToFront(boxes).length, boxes.length);
      }
    }
  });

  test('침대 헤드보드: R0 뒤쪽(y=0) → R1 x=0 쪽 → R2 앞쪽 → R3 x 끝 쪽', () {
    const fp = (1, 2);
    final head = isoBoxesFor(itemById('bed_single')!, fp)![1];
    expect(rotateBox(head, fp, Rot.r0).y1 < 0.5, isTrue);
    expect(rotateBox(head, fp, Rot.r1).x1 < 0.5, isTrue);
    expect(rotateBox(head, fp, Rot.r2).y0 > 1.5, isTrue);
    expect(rotateBox(head, fp, Rot.r3).x0 > 1.5, isTrue);
  });

  test('방향 없는 가구는 상자 그림이 없다', () {
    expect(isoBoxesFor(itemById('plant_small')!, (1, 1)), isNull);
    expect(isoBoxesFor(itemById('lamp_stand')!, (1, 1)), isNull);
  });

  testWidgets('검수 그림 (가구 6종 × 4방향)', (tester) async {
    if (reviewPng.isEmpty) return;
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec)..scale(2);
      c.drawRect(const ui.Rect.fromLTWH(0, 0, 640, 760), ui.Paint()..color = const ui.Color(0xFFF6EBDD));
      for (var i = 0; i < ids.length; i++) {
        for (final r in Rot.values) {
          c.save();
          c.translate(-180 + r.index * 150.0, -120 + i * 120.0);
          drawIsoBoxes(c, isoBoxesFor(itemById(ids[i])!, fps[ids[i]]!)!, fps[ids[i]]!, r, 0, 0);
          c.restore();
        }
      }
      final img = await rec.endRecording().toImage(1280, 1520);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(reviewPng).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
