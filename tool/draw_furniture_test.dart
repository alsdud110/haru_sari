// 상자를 쌓아 만든 가구(lib/ui/room/iso_boxes.dart)를 픽셀 그림 PNG로 뽑는다.
//
//   flutter test tool/draw_furniture_test.dart
//
// 화면 그리기 코드(dart:ui)를 그대로 써야 해서 테스트 실행기로 돌린다. `flutter test`(인자 없이)에는 포함되지 않는다.
//
// 러그와 벽 장식도 같은 방식으로 뽑는다 (러그는 네 방향, 벽 장식은 왼쪽 벽 기울기로 한 장).
//
// 가구 하나를 네 방향(r0~r3)으로 그린 뒤:
//   1. 번짐 없이(안티에일리어싱 끔) 스프라이트 크기 그대로 그린다 → 팔레트 색만 남는다.
//   2. 바깥 둘레에 1px 짙은 외곽선을 두른다 (미니미·화분과 같은 방식).
//   3. 규격 검사(AssetCheck)를 통과한 것만 assets/pixel/ 에 쓴다.
// 그리고 매니페스트의 rotations 를 네 방향으로 채우고, 만든 가구 목록을 lib/room/generated_sprites.dart 에 적는다.
//
// 사람이 그린 그림이 있는 가구([_handDrawn])는 건드리지 않는다.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/room/asset_check.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/manifest.dart';
import 'package:haru_sari/room/palette.dart';
import 'package:flutter/widgets.dart' show Matrix4;
import 'package:haru_sari/room/registry.dart';
import 'package:haru_sari/ui/room/iso_boxes.dart';
import 'package:haru_sari/ui/room/iso_room_painter.dart';
import 'package:haru_sari/ui/room/room_painter.dart' show drawFurniture;
import 'package:haru_sari/ui/room/surfaces.dart' show drawFloor, drawRug, floorStyleOf, floorStyles, rugStyleOf, wallStyleOf, wallStyles;
import 'package:image/image.dart' as img;

const _handDrawn = {'bed_double', 'plant_small'};
const _outline = 0x4A3628; // PixelPalette.ink[1]

bool _inside(List<(double, double)> poly, double x, double y) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (xi, yi) = poly[i];
    final (xj, yj) = poly[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

void main() {
  testWidgets('가구 픽셀 그림 만들기', (tester) async {
    await tester.runAsync(() async {
      final manifestFile = File(PixelManifest.manifestPath);
      var manifestText = manifestFile.readAsStringSync();
      final manifest = PixelManifest.parse(manifestText);
      final made = <String>[], skipped = <String>[];
      final dirs = <String>{};

      for (final item in shopCatalog) {
        final art = manifest[item.id];
        if (art == null || art.layer != ArtLayer.object || _handDrawn.contains(item.id)) continue;
        final boxes = isoBoxesFor(item, art.footprint);
        if (boxes == null) continue;
        final r0 = art.rotations[Rot.r0];
        if (r0 == null) continue;
        final dir = r0.substring(0, r0.lastIndexOf('/'));
        final files = <Rot, Uint8List>{};
        String? problem;

        for (final rot in Rot.values) {
          final spec = art.spriteSpec(rot);
          final (w, d) = art.footprintFor(rot);
          final box = IsoGrid.spriteBox(0, 0, w, d, art.height);
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec)..translate(-box.left.toDouble(), -box.top.toDouble());
          drawIsoBoxes(c, boxes, art.footprint, rot, 0, 0, antiAlias: false);
          final image = await rec.endRecording().toImage(spec.width, spec.height);
          final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();

          // 1. 불투명/투명으로 나누고 팔레트 색인지 확인
          final px = List<int?>.filled(spec.width * spec.height, null);
          for (var i = 0; i < px.length; i++) {
            if (rgba[i * 4 + 3] < 128) continue;
            px[i] = (rgba[i * 4] << 16) | (rgba[i * 4 + 1] << 8) | rgba[i * 4 + 2];
          }
          // 2. 바깥 외곽선 (허용 영역 안에서만)
          final region = AssetCheck.allowedRegion(w, d, art.height, spec.ax, spec.ay);
          final out = [...px];
          for (var y = 0; y < spec.height; y++) {
            for (var x = 0; x < spec.width; x++) {
              if (px[y * spec.width + x] != null) continue;
              var touches = false;
              for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
                final nx = x + dx, ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= spec.width || ny >= spec.height) continue;
                if (px[ny * spec.width + nx] != null) touches = true;
              }
              if (touches && _inside(region, x + 0.5, y + 0.5)) out[y * spec.width + x] = _outline;
            }
          }
          final pic = img.Image(width: spec.width, height: spec.height, numChannels: 4);
          for (var i = 0; i < out.length; i++) {
            final v = out[i];
            if (v == null) continue;
            pic.setPixelRgba(i % spec.width, i ~/ spec.width, v >> 16, (v >> 8) & 0xFF, v & 0xFF, 255);
          }
          final png = Uint8List.fromList(img.encodePng(pic));
          // 3. 규격 검사
          final problems = await AssetCheck.objectSprite(art, rot, png);
          if (problems.isNotEmpty) {
            problem = '${rot.name}: ${problems.join(', ')}';
            break;
          }
          files[rot] = png;
        }

        if (problem != null) {
          skipped.add('${item.id} ($problem)');
          continue;
        }
        final paths = {for (final r in Rot.values) r: r == Rot.r0 ? r0 : '$dir/${item.id}_${r.name}.png'};
        for (final r in Rot.values) {
          final f = File('${PixelManifest.assetRoot}${paths[r]}');
          f.parent.createSync(recursive: true);
          f.writeAsBytesSync(files[r]!);
        }
        dirs.add(dir);
        // 매니페스트의 이 가구 rotations 를 네 방향으로 바꾼다 (다른 줄은 건드리지 않는다)
        final entry = RegExp('("${item.id}": \\{[^\\n]*?"rotations": )\\{[^}]*\\}');
        final json = '{ ${[for (final r in Rot.values) '"${r.name}": "${paths[r]}"'].join(', ')} }';
        expect(entry.hasMatch(manifestText), isTrue, reason: '${item.id} 매니페스트 줄을 찾지 못함');
        manifestText = manifestText.replaceFirstMapped(entry, (m) => '${m[1]}$json');
        made.add(item.id);
      }

      // ───────── 러그 (바닥 장식): 화면에서 그리던 그림을 픽셀로 뽑는다 ─────────
      final rugs = <String>[];
      for (final item in shopCatalog) {
        final art = manifest[item.id];
        if (art == null || art.layer != ArtLayer.floorDecor) continue;
        final r0 = art.rotations[Rot.r0];
        if (r0 == null) continue;
        final dir = r0.substring(0, r0.lastIndexOf('/'));
        final files = <Rot, Uint8List>{};
        String? problem;
        for (final rot in Rot.values) {
          final spec = art.spriteSpec(rot);
          final (w, d) = art.footprintFor(rot);
          final box = IsoGrid.spriteBox(0, 0, w, d, art.height);
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec)..translate(-box.left.toDouble(), -box.top.toDouble());
          drawRug(c, rugStyleOf(item.id), (0, 0, w, d));
          final px = await _snap(rec, spec.width, spec.height);
          // 러그는 칸을 꽉 채우기도 해서 안쪽 가장자리를 외곽선으로 바꾼다
          final png = _encode(_innerOutline(px, spec.width, spec.height, PixelPalette.ink[0]), spec.width, spec.height);
          final problems = await AssetCheck.objectSprite(art, rot, png);
          if (problems.isNotEmpty) {
            problem = '${rot.name}: ${problems.join(', ')}';
            break;
          }
          files[rot] = png;
        }
        if (problem != null) {
          skipped.add('${item.id} ($problem)');
          continue;
        }
        final paths = {for (final r in Rot.values) r: r == Rot.r0 ? r0 : '$dir/${item.id}_${r.name}.png'};
        for (final r in Rot.values) {
          File('${PixelManifest.assetRoot}${paths[r]}')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(files[r]!);
        }
        dirs.add(dir);
        final entry = RegExp('("${item.id}": \\{[^\\n]*?"rotations": )\\{[^}]*\\}');
        final json = '{ ${[for (final r in Rot.values) '"${r.name}": "${paths[r]}"'].join(', ')} }';
        manifestText = manifestText.replaceFirstMapped(entry, (m) => '${m[1]}$json');
        rugs.add(item.id);
      }

      // ───────── 벽 장식: 왼쪽 벽 기울기로 한 장 (오른쪽 벽은 화면에서 좌우로 뒤집어 쓴다) ─────────
      final walls = <String>[];
      for (final item in shopCatalog) {
        final art = manifest[item.id];
        if (art == null || art.layer != ArtLayer.wall || art.path == null) continue;
        final box = IsoGrid.wallBox(left: true, u: 0, span: art.span, z: 0, h: art.height);
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec)
          ..translate(0, (box.height - art.height).toDouble())
          ..transform((Matrix4.identity()..setEntry(1, 0, -0.5)).storage);
        drawFurniture(c, item, ui.Rect.fromLTWH(0, 0, box.width.toDouble(), art.height.toDouble()));
        final px = await _snap(rec, box.width, box.height);
        final png = _encode(_outerOutline(px, box.width, box.height, _outline), box.width, box.height);
        File('${PixelManifest.assetRoot}${art.path}')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png);
        dirs.add(art.path!.substring(0, art.path!.lastIndexOf('/')));
        walls.add(item.id);
      }

      // ───────── 방 바닥·벽: 방 전체 크기(512×432) 한 장씩 ─────────
      var surfaces = 0;
      Future<void> surface(String kind, String? id, void Function(ui.Canvas c) draw) async {
        final rec = ui.PictureRecorder();
        draw(ui.Canvas(rec));
        // 바닥·벽은 팔레트에 없는 중간 색(그늘진 벽 등)을 쓰므로 팔레트에 맞추지 않고, 그 그림에 많이 쓰인 색으로만 정리한다.
        final px = await _snapDominant(rec, IsoGrid.canvasW, IsoGrid.canvasH);
        File('${PixelManifest.assetRoot}${AssetRegistry.surfacePath(kind, id)}')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(_encode(px, IsoGrid.canvasW, IsoGrid.canvasH));
        dirs.add('rooms/$kind');
        surfaces++;
      }

      for (final id in <String?>[null, ...floorStyles.keys]) {
        await surface('floors', id, (c) => drawFloor(c, floorStyleOf(id)));
      }
      for (final id in <String?>[null, ...wallStyles.keys]) {
        await surface('walls', id, (c) => IsoRoomPainter.drawRoomWalls(c, wallStyleOf(id)));
      }

      // ───────── 사람이 그린 가구: 그림이 없는 방향만 코드 그림으로 채운다 ─────────
      final filled = <String>[];
      for (final id in _handDrawn) {
        final item = itemById(id), art = manifest[id];
        if (item == null || art == null) continue;
        final boxes = isoBoxesFor(item, art.footprint);
        final r0 = art.rotations[Rot.r0];
        if (boxes == null || r0 == null) continue;
        final dir = r0.substring(0, r0.lastIndexOf('/'));
        final paths = {...art.rotations};
        for (final rot in Rot.values) {
          if (art.rotations.containsKey(rot) && File('${PixelManifest.assetRoot}${art.rotations[rot]}').existsSync()) {
            continue;
          }
          final spec = art.spriteSpec(rot);
          final (w, d) = art.footprintFor(rot);
          final box = IsoGrid.spriteBox(0, 0, w, d, art.height);
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec)..translate(-box.left.toDouble(), -box.top.toDouble());
          drawIsoBoxes(c, boxes, art.footprint, rot, 0, 0, antiAlias: false);
          final region = AssetCheck.allowedRegion(w, d, art.height, spec.ax, spec.ay);
          final raw = await _snap(rec, spec.width, spec.height);
          final outlined = _outerOutline(raw, spec.width, spec.height, _outline);
          final px = [
            for (var i = 0; i < raw.length; i++)
              raw[i] ?? (_inside(region, i % spec.width + 0.5, i ~/ spec.width + 0.5) ? outlined[i] : null),
          ];
          final png = _encode(px, spec.width, spec.height);
          final problems = await AssetCheck.objectSprite(art, rot, png);
          if (problems.isNotEmpty) {
            skipped.add('$id ${rot.name} (${problems.join(', ')})');
            continue;
          }
          paths[rot] = '$dir/${id}_${rot.name}.png';
          File('${PixelManifest.assetRoot}${paths[rot]}').writeAsBytesSync(png);
          filled.add('$id ${rot.name}');
        }
        final entry = RegExp('("$id": \\{[^\\n]*?"rotations": )\\{[^}]*\\}');
        final json = '{ ${[for (final r in Rot.values) if (paths[r] != null) '"${r.name}": "${paths[r]}"'].join(', ')} }';
        manifestText = manifestText.replaceFirstMapped(entry, (m) => '${m[1]}$json');
      }
      // ignore: avoid_print
      print('바닥·벽 $surfaces장, 채운 방향: ${filled.join(', ')}');

      manifestFile.writeAsStringSync(manifestText);
      File('lib/room/generated_sprites.dart').writeAsStringSync(
        '// tool/draw_furniture_test.dart 가 만든다. 직접 고치지 않는다.\n'
        '//\n'
        '// 코드로 그린 픽셀 그림이 있는 가구 (상점·보관함 목록에서도 그 그림을 쓴다).\n'
        'const generatedSprites = <String>{\n${[for (final id in [...made, ...rugs]) "  '$id',\n"].join()}};\n'
        '\n'
        '// 코드로 그린 픽셀 그림이 있는 벽 장식 (방 안에서만 쓴다. 목록에서는 정면 그림 그대로).\n'
        'const generatedWallSprites = <String>{\n${[for (final id in walls) "  '$id',\n"].join()}};\n',
      );
      // ignore: avoid_print
      print('가구 ${made.length}개, 러그 ${rugs.length}개, 벽 장식 ${walls.length}개\n폴더: ${(dirs.toList()..sort()).join(', ')}');
      // ignore: avoid_print
      if (skipped.isNotEmpty) print('건너뜀 ${skipped.length}개:\n  ${skipped.join('\n  ')}');
      expect(PixelPalette.all.contains(_outline), isTrue);
    });
  });
}

/// 그린 그림을 픽셀 표로 바꾼다: 반투명은 버리거나 채우고, 색은 가장 가까운 팔레트 색으로 맞춘다.
Future<List<int?>> _snap(ui.PictureRecorder rec, int w, int h) async {
  final image = await rec.endRecording().toImage(w, h);
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  final palette = PixelPalette.all.toList();
  final cache = <int, int>{};
  final px = List<int?>.filled(w * h, null);
  for (var i = 0; i < px.length; i++) {
    if (rgba[i * 4 + 3] < 128) continue;
    final r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
    px[i] = cache.putIfAbsent((r << 16) | (g << 8) | b, () {
      var best = palette.first, bestD = 1 << 30;
      for (final p in palette) {
        final dr = (p >> 16) - r, dg = ((p >> 8) & 0xFF) - g, db = (p & 0xFF) - b;
        final dist = dr * dr * 2 + dg * dg * 4 + db * db * 3;
        if (dist < bestD) {
          bestD = dist;
          best = p;
        }
      }
      return best;
    });
  }
  return px;
}

bool _edge(List<int?> px, int w, int h, int x, int y, {required bool filled}) {
  if ((px[y * w + x] != null) != filled) return false;
  for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
    final nx = x + dx, ny = y + dy;
    final outside = nx < 0 || ny < 0 || nx >= w || ny >= h;
    if (filled ? (outside || px[ny * w + nx] == null) : (!outside && px[ny * w + nx] != null)) return true;
  }
  return false;
}

/// 그림의 가장 바깥 픽셀을 외곽선 색으로 바꾼다.
List<int?> _innerOutline(List<int?> px, int w, int h, int color) => [
  for (var i = 0; i < px.length; i++) _edge(px, w, h, i % w, i ~/ w, filled: true) ? color : px[i],
];

/// 그림 바깥 둘레에 외곽선을 두른다 (그림 밖으로 나가는 부분은 잘린다).
List<int?> _outerOutline(List<int?> px, int w, int h, int color) => [
  for (var i = 0; i < px.length; i++) _edge(px, w, h, i % w, i ~/ w, filled: false) ? color : px[i],
];

Uint8List _encode(List<int?> px, int w, int h) {
  final pic = img.Image(width: w, height: h, numChannels: 4);
  for (var i = 0; i < px.length; i++) {
    final v = px[i];
    if (v == null) continue;
    pic.setPixelRgba(i % w, i ~/ w, v >> 16, (v >> 8) & 0xFF, v & 0xFF, 255);
  }
  return Uint8List.fromList(img.encodePng(pic));
}

/// 그림에 많이 쓰인 색만 남긴다: 가장자리가 번지며 생긴 드문 색은 가장 가까운 주된 색으로 바꾼다.
Future<List<int?>> _snapDominant(ui.PictureRecorder rec, int w, int h, {int minCount = 60}) async {
  final image = await rec.endRecording().toImage(w, h);
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  final count = <int, int>{};
  final px = List<int?>.filled(w * h, null);
  for (var i = 0; i < px.length; i++) {
    if (rgba[i * 4 + 3] < 128) continue;
    final v = (rgba[i * 4] << 16) | (rgba[i * 4 + 1] << 8) | rgba[i * 4 + 2];
    px[i] = v;
    count[v] = (count[v] ?? 0) + 1;
  }
  final main = [for (final e in count.entries) if (e.value >= minCount) e.key];
  if (main.isEmpty) return px;
  final cache = <int, int>{};
  int nearest(int v) => cache.putIfAbsent(v, () {
    var best = main.first, bestD = 1 << 30;
    for (final p in main) {
      final dr = (p >> 16) - (v >> 16), dg = ((p >> 8) & 0xFF) - ((v >> 8) & 0xFF), db = (p & 0xFF) - (v & 0xFF);
      final dist = dr * dr * 2 + dg * dg * 4 + db * db * 3;
      if (dist < bestD) {
        bestD = dist;
        best = p;
      }
    }
    return best;
  });
  return [for (final v in px) v == null ? null : ((count[v] ?? 0) >= minCount ? v : nearest(v))];
}
