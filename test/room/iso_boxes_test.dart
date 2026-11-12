import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/manifest.dart';
import 'package:haru_sari/ui/room/iso_boxes.dart';

import 'manifest_test.dart' show loadManifest;

/// 검수 그림: `flutter test test/room/iso_boxes_test.dart --dart-define=REVIEW_PNG=<파일>`
const reviewPng = String.fromEnvironment('REVIEW_PNG');

void main() {
  // 상자로 그리는 모든 바닥 가구와 그 점유 칸 (manifest 기준)
  final manifest = loadManifest();
  final fps = {
    for (final i in shopCatalog)
      if (i.isFurniture && manifest[i.id]?.layer == ArtLayer.object && isoBoxesFor(i, manifest[i.id]!.footprint) != null)
        i.id: manifest[i.id]!.footprint,
  };
  final ids = fps.keys.toList();

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

  test('상자끼리 부피가 겹치지 않고(그리는 순서의 전제), 높이는 manifest 안이다', () {
    expect(ids.length, greaterThan(35));
    for (final id in ids) {
      final boxes = isoBoxesFor(itemById(id)!, fps[id]!)!;
      for (final (i, a) in boxes.indexed) {
        expect(a.z1 <= manifest[id]!.height, isTrue, reason: '$id 높이 ${a.z1}');
        for (final b in boxes.skip(i + 1)) {
          final apart = a.x1 <= b.x0 || b.x1 <= a.x0 || a.y1 <= b.y0 || b.y1 <= a.y0 || a.z1 <= b.z0 || b.z1 <= a.z0;
          expect(apart, isTrue, reason: '$id 상자 $i');
        }
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
  });

  testWidgets('검수 그림 (가구 × 4방향)', (tester) async {
    if (reviewPng.isEmpty) return;
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec)..scale(2);
      const cols = 3;
      final rows = (ids.length / cols).ceil();
      c.drawRect(ui.Rect.fromLTWH(0, 0, cols * 620.0, rows * 150.0), ui.Paint()..color = const ui.Color(0xFFF6EBDD));
      for (var i = 0; i < ids.length; i++) {
        for (final r in Rot.values) {
          c.save();
          c.translate(-180 + (i % cols) * 620 + r.index * 150.0, -80 + (i ~/ cols) * 150.0);
          drawIsoBoxes(c, isoBoxesFor(itemById(ids[i])!, fps[ids[i]]!)!, fps[ids[i]]!, r, 0, 0);
          c.restore();
        }
      }
      final img = await rec.endRecording().toImage(cols * 1240, rows * 300);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(reviewPng).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
