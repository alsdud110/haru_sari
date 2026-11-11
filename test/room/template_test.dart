import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:oneul_sari/room/asset_check.dart';
import 'package:oneul_sari/room/iso.dart';
import 'package:oneul_sari/room/palette.dart';

import 'manifest_test.dart' show loadManifest;

/// art/templates/beds 템플릿을 앱 기준(매니페스트·허용 영역 계산)과 픽셀 단위로 대조한다.
/// 템플릿 다시 만들기: `dart run tool/make_bed_templates.dart`
const anchorColor = 0xD03030;
const footprintColor = 0x6F8F6B;
const headboardColor = 0x6F8FB8;
const footColor = 0xE5B547;
const regionColor = 0xE08A5B;

int rgbAt(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  return (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
}

int alphaAt(img.Image im, int x, int y) => im.getPixel(x, y).a.toInt();

/// .ase 최소 파서 (검증용): 헤더 + 첫 프레임 청크들
class AseInfo {
  late int width, height, depth, frames;
  final layers = <String>[];
  final palette = <int>[];
  final cels = <int, Uint8List>{}; // layer index → RGBA
}

AseInfo parseAse(Uint8List b) {
  final d = ByteData.sublistView(b);
  int u16(int o) => d.getUint16(o, Endian.little);
  int u32(int o) => d.getUint32(o, Endian.little);
  final a = AseInfo();
  expect(u32(0), b.length, reason: '헤더의 파일 크기');
  expect(u16(4), 0xA5E0, reason: '매직');
  a
    ..frames = u16(6)
    ..width = u16(8)
    ..height = u16(10)
    ..depth = u16(12);
  var o = 128;
  final frameSize = u32(o);
  expect(u16(o + 4), 0xF1FA);
  final nChunks = u32(o + 12);
  var c = o + 16;
  for (var i = 0; i < nChunks; i++) {
    final size = u32(c), type = u16(c + 4);
    final p = c + 6;
    switch (type) {
      case 0x2019:
        final n = u32(p);
        for (var k = 0; k < n; k++) {
          final e = p + 20 + k * 6;
          a.palette.add((b[e + 2] << 16) | (b[e + 3] << 8) | b[e + 4]);
        }
      case 0x2004:
        final len = u16(p + 16);
        a.layers.add(String.fromCharCodes(b.sublist(p + 18, p + 18 + len)));
      case 0x2005:
        final layer = u16(p);
        expect(u16(p + 7), 2, reason: '압축 이미지 셀');
        final w = u16(p + 16), h = u16(p + 18);
        final raw = ZLibCodec().decode(b.sublist(p + 20, c + size));
        expect(raw.length, w * h * 4);
        a.cels[layer] = Uint8List.fromList(raw);
    }
    c += size;
  }
  expect(c, o + frameSize, reason: '청크 크기 합 = 프레임 크기');
  return a;
}

void main() {
  final m = loadManifest();
  final cases = [
    ('bed_single_r0', 'bed_single', Rot.r0, true),
    ('bed_single_r1', 'bed_single', Rot.r1, false),
    ('bed_double_r0', 'bed_double', Rot.r0, true),
    ('bed_double_r1', 'bed_double', Rot.r1, false),
  ];

  for (final (name, id, rot, backRight) in cases) {
    group(name, () {
      final dir = 'art/templates/beds/$name';
      final guide = img.decodePng(File('$dir/${name}_guide.png').readAsBytesSync())!.convert(numChannels: 4);
      final art = img.decodePng(File('$dir/${name}_art.png').readAsBytesSync())!.convert(numChannels: 4);
      final a = m[id]!;
      final spec = a.spriteSpec(rot);
      final (w, d) = a.footprintFor(rot);

      test('캔버스 크기 = 매니페스트 규격 (${spec.width}×${spec.height})', () {
        expect((guide.width, guide.height), (spec.width, spec.height));
        expect((art.width, art.height), (spec.width, spec.height));
      });

      test('그림 레이어는 완전히 투명', () {
        expect(art.every((p) => p.a == 0), isTrue);
      });

      test('앵커 픽셀 (${spec.ax}, ${spec.ay})', () {
        expect(rgbAt(guide, spec.ax, spec.ay), anchorColor);
        expect(alphaAt(guide, spec.ax, spec.ay), 255);
        // 십자 팔은 가운데에서 2~4px
        expect(rgbAt(guide, spec.ax + 2, spec.ay), anchorColor);
        expect(rgbAt(guide, spec.ax, spec.ay - 4), anchorColor);
      });

      test('바닥 마름모 꼭짓점과 변', () {
        final verts = [
          (spec.ax + w * 32, spec.ay + w * 16), // 오른쪽
          (spec.ax + (w - d) * 32, spec.ay + (w + d) * 16), // 앞
          (spec.ax - d * 32, spec.ay + d * 16), // 왼쪽
        ];
        for (final (x, y) in verts) {
          final cx = x.clamp(0, guide.width - 1), cy = y.clamp(0, guide.height - 1);
          expect(alphaAt(guide, cx, cy), 255, reason: '꼭짓점 ($x,$y)');
        }
        // 변 위의 점: 뒤→오른쪽 변 1/4 지점 (2:1 기울기)
        final q = (spec.ax + w * 8, spec.ay + w * 4);
        expect([footprintColor, headboardColor, anchorColor], contains(rgbAt(guide, q.$1, q.$2)));
      });

      test('허용 영역: 가이드의 붉은 칠 = 앱 검증기의 영역 밖과 일치', () {
        final poly = AssetCheck.allowedRegion(w, d, a.height, spec.ax, spec.ay);
        bool inside(double x, double y) {
          var c = false;
          for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            final (xi, yi) = poly[i];
            final (xj, yj) = poly[j];
            if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
          }
          return c;
        }

        var tinted = 0;
        for (var y = 0; y < guide.height; y++) {
          for (var x = 0; x < guide.width; x++) {
            final isIn = inside(x + 0.5, y + 0.5);
            final al = alphaAt(guide, x, y);
            if (al == 48) {
              tinted++;
              expect(isIn, isFalse, reason: '붉은 칠이 영역 안 ($x,$y)');
            }
            if (!isIn) expect(al, greaterThan(0), reason: '영역 밖인데 표시 없음 ($x,$y)');
          }
        }
        expect(tinted, greaterThan(0));
      });

      test('머리판·발치 방향', () {
        final b = (spec.ax, spec.ay);
        final r = (spec.ax + w * 32, spec.ay + w * 16);
        final l = (spec.ax - d * 32, spec.ay + d * 16);
        final f = (spec.ax + (w - d) * 32, spec.ay + (w + d) * 16);
        final (h1, h2, f1, f2) = backRight ? (b, r, l, f) : (b, l, r, f);
        final hm = ((h1.$1 + h2.$1) ~/ 2, (h1.$2 + h2.$2) ~/ 2 + 1);
        final fm = ((f1.$1 + f2.$1) ~/ 2, (f1.$2 + f2.$2) ~/ 2 - 2);
        expect(rgbAt(guide, hm.$1, hm.$2), headboardColor, reason: '머리판 변 중간 $hm');
        expect(rgbAt(guide, fm.$1, fm.$2), footColor, reason: '발치 변 중간 $fm');
        // 반대쪽 변에는 머리판 표시가 없다
        final (o1, o2) = backRight ? (b, l) : (b, r);
        final om = ((o1.$1 + o2.$1) ~/ 2, (o1.$2 + o2.$2) ~/ 2 + 1);
        expect(rgbAt(guide, om.$1, om.$2), isNot(headboardColor));
      });

      test('광원 표시 (왼쪽 위)', () {
        expect(alphaAt(guide, 2, 2), 255);
        expect(rgbAt(guide, 2, 2), 0xB98A2A);
      });

      test('.ase: 크기·레이어 2개·팔레트 57색·가이드 셀 = 가이드 PNG', () {
        final ase = parseAse(File('$dir/${name}_template.ase').readAsBytesSync());
        expect((ase.width, ase.height, ase.depth, ase.frames), (spec.width, spec.height, 32, 1));
        expect(ase.layers, ['art', 'guide (do not export)']);
        expect(ase.palette.toSet(), PixelPalette.all);
        expect(ase.cels.keys, [1], reason: '그림 레이어(0)는 비어 있음');
        expect(ase.cels[1], guide.getBytes(order: img.ChannelOrder.rgba));
      });
    });
  }

  test('GIMP 팔레트: 57색, 앱 팔레트와 같음', () {
    final lines = File('art/templates/palette/oneul_sari_57.gpl').readAsLinesSync();
    expect(lines.first, 'GIMP Palette');
    final colors = lines
        .where((l) => RegExp(r'^\s*\d+\s+\d+\s+\d+').hasMatch(l))
        .map((l) => l.trim().split(RegExp(r'\s+')).take(3).map(int.parse).toList())
        .map((c) => (c[0] << 16) | (c[1] << 8) | c[2])
        .toSet();
    expect(colors, PixelPalette.all);
  });
}
