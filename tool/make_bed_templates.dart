// 침대 에셋 제작 기준 템플릿 생성 (docs/asset-system/02 §14)
//
//   dart run tool/make_bed_templates.dart
//
// art/templates/ 아래에 만든다 (앱 번들에 들어가지 않음):
//   beds/<id>/<id>_guide.png    가이드 레이어 (점유·허용 영역·앵커·머리판/발치·광원)
//   beds/<id>/<id>_art.png      빈 그림 레이어 (투명, 같은 크기)
//   beds/<id>/<id>_template.ase Aseprite 형식 (레이어 2개 + 팔레트 57색)
//   beds/<id>/<id>_preview.png  확대 미리보기 + 범례 (문서용)
//   palette/oneul_sari_57.gpl   GIMP 팔레트 (Pixelorama·Aseprite에서 불러오기)
//
// 실제 침대 그림은 만들지 않는다. 기준선만 그린다.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:oneul_sari/room/palette.dart';

class BedTemplate {
  const BedTemplate(this.id, this.w, this.d, this.h, {required this.headboardBackRight, required this.label});
  final String id;
  final int w; // gx 방향 칸 수
  final int d; // gy 방향 칸 수
  final int h; // 물체 높이
  /// true: 머리판이 뒤-오른쪽 변(오른쪽 벽 쪽, R0) / false: 뒤-왼쪽 변(왼쪽 벽 쪽, R1)
  final bool headboardBackRight;
  final String label;
}

const templates = [
  BedTemplate('bed_single_r0', 1, 2, 52, headboardBackRight: true, label: 'single R0 1x2 h52'),
  BedTemplate('bed_single_r1', 2, 1, 52, headboardBackRight: false, label: 'single R1 2x1 h52'),
  BedTemplate('bed_double_r0', 2, 2, 56, headboardBackRight: true, label: 'double R0 2x2 h56'),
  BedTemplate('bed_double_r1', 2, 2, 56, headboardBackRight: false, label: 'double R1 2x2 h56'),
];

/// 가이드 색 (가이드 전용 — 실제 그림에는 쓰지 않는다)
class GuideColor {
  static const footprint = 0x6F8F6B; // 바닥 점유 마름모
  static const tile = 0xA9C4A3; // 칸 경계 (점선)
  static const top = 0xB98A2A; // 물체 높이 면 (점선)
  static const region = 0xE08A5B; // 허용 영역 경계
  static const outsideAlpha = 48; // 허용 영역 밖 옅은 붉은 칠
  static const anchor = 0xD03030; // 앵커
  static const headboard = 0x6F8FB8; // 머리판 변
  static const foot = 0xE5B547; // 발치 변
  static const light = 0xB98A2A; // 광원 화살표
}

({int width, int height, int ax, int ay}) spriteSpec(int w, int d, int h) {
  final width = (w + d) * 32;
  final height = ((w + d) * 16 + h + 7) ~/ 8 * 8;
  return (width: width, height: height, ax: d * 32, ay: height - (w + d) * 16);
}

/// 바닥 마름모 꼭짓점: 뒤, 오른쪽, 앞, 왼쪽
List<(int, int)> footprintVerts(int w, int d, int ax, int ay) => [
      (ax, ay),
      (ax + w * 32, ay + w * 16),
      (ax + (w - d) * 32, ay + (w + d) * 16),
      (ax - d * 32, ay + d * 16),
    ];

/// 허용 영역 (lib/room/asset_check.dart 와 같은 정의, 1px 여유)
List<(double, double)> allowedRegion(int w, int d, int h, int ax, int ay) {
  final up = h.toDouble();
  final b = (ax.toDouble(), ay.toDouble());
  final r = (ax + w * 32.0, ay + w * 16.0);
  final f = (ax + (w - d) * 32.0, ay + (w + d) * 16.0);
  final l = (ax - d * 32.0, ay + d * 16.0);
  return [
    (b.$1, b.$2 - up - 1),
    (r.$1 + 1, r.$2 - up),
    (r.$1 + 1, r.$2),
    (f.$1, f.$2 + 1),
    (l.$1 - 1, l.$2),
    (l.$1 - 1, l.$2 - up),
  ];
}

bool inside(List<(double, double)> poly, double x, double y) {
  var c = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (xi, yi) = poly[i];
    final (xj, yj) = poly[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}

// ───────── 그리기 (안티앨리어싱 없음) ─────────

void put(img.Image im, int x, int y, int rgb, [int a = 255]) {
  if (x < 0 || y < 0 || x >= im.width || y >= im.height) return;
  im.setPixelRgba(x, y, rgb >> 16, (rgb >> 8) & 255, rgb & 255, a);
}

/// 2:1 아이소 선(가로 2 : 세로 1)과 수직선. 캔버스 밖 끝점(x=W, y=H)은 안쪽으로 붙인다.
void line(img.Image im, (int, int) a, (int, int) b, int rgb, {int dash = 0, int thick = 1}) {
  var (x0, y0) = a;
  var (x1, y1) = b;
  x0 = math.min(x0, im.width - 1);
  x1 = math.min(x1, im.width - 1);
  y0 = math.min(y0, im.height - 1);
  y1 = math.min(y1, im.height - 1);
  final n = math.max((x1 - x0).abs(), (y1 - y0).abs());
  for (var i = 0; i <= n; i++) {
    if (dash > 0 && (i ~/ dash).isOdd) continue;
    final t = n == 0 ? 0.0 : i / n;
    final x = (x0 + (x1 - x0) * t).round();
    final y = (y0 + (y1 - y0) * t).round();
    for (var k = 0; k < thick; k++) {
      put(im, x, y + k, rgb);
    }
  }
}

img.Image guide(BedTemplate t) {
  final s = spriteSpec(t.w, t.d, t.h);
  final im = img.Image(width: s.width, height: s.height, numChannels: 4);
  final poly = allowedRegion(t.w, t.d, t.h, s.ax, s.ay);

  // 1) 허용 영역 밖: 옅은 붉은 칠
  for (var y = 0; y < s.height; y++) {
    for (var x = 0; x < s.width; x++) {
      if (!inside(poly, x + 0.5, y + 0.5)) put(im, x, y, GuideColor.region, GuideColor.outsideAlpha);
    }
  }

  final v = footprintVerts(t.w, t.d, s.ax, s.ay);
  final (b, r, f, l) = (v[0], v[1], v[2], v[3]);
  (int, int) up((int, int) p) => (p.$1, p.$2 - t.h);

  // 2) 칸 경계 (점선): 점유 안쪽의 타일 나눔선
  for (var i = 1; i < t.w; i++) {
    line(im, (b.$1 + i * 32, b.$2 + i * 16), (l.$1 + i * 32, l.$2 + i * 16), GuideColor.tile, dash: 2);
  }
  for (var j = 1; j < t.d; j++) {
    line(im, (b.$1 - j * 32, b.$2 + j * 16), (r.$1 - j * 32, r.$2 + j * 16), GuideColor.tile, dash: 2);
  }

  // 3) 물체 높이 면 (점선): 바닥 마름모를 h만큼 올린 모양
  for (final (p, q) in [(b, r), (r, f), (f, l), (l, b)]) {
    line(im, up(p), up(q), GuideColor.top, dash: 3);
  }

  // 4) 허용 영역 경계 (실선): 위쪽 두 변 + 좌우 수직 + 아래쪽 두 변은 바닥 마름모와 같다
  line(im, up(l), up(b), GuideColor.region);
  line(im, up(b), up(r), GuideColor.region);
  line(im, up(r), r, GuideColor.region);
  line(im, up(l), l, GuideColor.region);

  // 5) 바닥 점유 마름모 (실선)
  for (final (p, q) in [(b, r), (r, f), (f, l), (l, b)]) {
    line(im, p, q, GuideColor.footprint);
  }

  // 6) 머리판 변 / 발치 변 (2px, 마름모 안쪽으로)
  final (hA, hB, fA, fB) = t.headboardBackRight ? (b, r, l, f) : (b, l, r, f);
  line(im, (hA.$1, hA.$2 + 1), (hB.$1, hB.$2 + 1), GuideColor.headboard, thick: 2);
  line(im, (fA.$1, fA.$2 - 2), (fB.$1, fB.$2 - 2), GuideColor.foot, thick: 2);

  // 7) 머리판 → 발치 방향 화살표 (바닥 가운데)
  final hc = ((hA.$1 + hB.$1) ~/ 2, (hA.$2 + hB.$2) ~/ 2);
  final fc = ((fA.$1 + fB.$1) ~/ 2, (fA.$2 + fB.$2) ~/ 2);
  final from = (hc.$1 + (fc.$1 - hc.$1) ~/ 4, hc.$2 + (fc.$2 - hc.$2) ~/ 4);
  final to = (hc.$1 + (fc.$1 - hc.$1) * 3 ~/ 4, hc.$2 + (fc.$2 - hc.$2) * 3 ~/ 4);
  line(im, from, to, GuideColor.headboard);
  final dx = (fc.$1 - hc.$1).sign, dy = (fc.$2 - hc.$2).sign;
  line(im, to, (to.$1 - dx * 4, to.$2), GuideColor.headboard);
  line(im, to, (to.$1, to.$2 - dy * 3), GuideColor.headboard);

  // 8) 광원 (왼쪽 위 → 오른쪽 아래): 해 3×3 + 화살표
  for (var y = 1; y <= 3; y++) {
    for (var x = 1; x <= 3; x++) {
      put(im, x, y, GuideColor.light);
    }
  }
  line(im, (5, 5), (13, 9), GuideColor.light);
  line(im, (13, 9), (10, 9), GuideColor.light);
  line(im, (13, 9), (12, 6), GuideColor.light);

  // 9) 앵커: 정확한 1px + 십자 팔 (가운데 1px 띄움)
  put(im, s.ax, s.ay, GuideColor.anchor);
  for (var k = 2; k <= 4; k++) {
    put(im, s.ax + k, s.ay, GuideColor.anchor);
    put(im, s.ax - k, s.ay, GuideColor.anchor);
    put(im, s.ax, s.ay + k, GuideColor.anchor);
    put(im, s.ax, s.ay - k, GuideColor.anchor);
  }
  return im;
}

// ───────── Aseprite (.ase) 쓰기 — 공개 사양 기준 ─────────
// https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

class _W {
  final b = BytesBuilder();
  void u8(int v) => b.addByte(v & 255);
  void u16(int v) => b.add([v & 255, (v >> 8) & 255]);
  void i16(int v) => u16(v & 0xFFFF);
  void u32(int v) => b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
  void bytes(List<int> v) => b.add(v);
  void zeros(int n) => b.add(List.filled(n, 0));
  void str(String s) {
    final e = s.codeUnits.any((c) => c > 127) ? Uint8List.fromList(s.runes.expand((r) => String.fromCharCode(r).codeUnits).toList()) : Uint8List.fromList(s.codeUnits);
    u16(e.length);
    bytes(e);
  }

  Uint8List done() => b.toBytes();
}

Uint8List _chunk(int type, Uint8List data) {
  final w = _W()
    ..u32(6 + data.length)
    ..u16(type)
    ..bytes(data);
  return w.done();
}

/// 레이어 2개(아래: art, 위: guide) + 팔레트. guide 레이어는 잠금(편집 불가), 불투명도 160.
Uint8List writeAse(img.Image guideImg, String name) {
  final chunks = <Uint8List>[];

  // 팔레트 (0x2019)
  final pal = PixelPalette.all.toList();
  final p = _W()
    ..u32(pal.length)
    ..u32(0)
    ..u32(pal.length - 1)
    ..zeros(8);
  for (final c in pal) {
    p
      ..u16(0)
      ..u8(c >> 16)
      ..u8((c >> 8) & 255)
      ..u8(c & 255)
      ..u8(255);
  }
  chunks.add(_chunk(0x2019, p.done()));

  // 레이어 (0x2004): 0 = art(편집 가능), 1 = guide(보이기만, 잠금)
  for (final (flags, opacity, lname) in [(3, 255, 'art'), (1, 160, 'guide (do not export)')]) {
    final l = _W()
      ..u16(flags)
      ..u16(0) // normal
      ..u16(0) // child level
      ..u16(0)
      ..u16(0)
      ..u16(0) // blend normal
      ..u8(opacity)
      ..zeros(3)
      ..str(lname);
    chunks.add(_chunk(0x2004, l.done()));
  }

  // guide 셀 (0x2005), 압축 이미지(type 2)
  final raw = guideImg.getBytes(order: img.ChannelOrder.rgba);
  final c = _W()
    ..u16(1) // layer index = guide
    ..i16(0)
    ..i16(0)
    ..u8(255)
    ..u16(2)
    ..i16(0)
    ..zeros(5)
    ..u16(guideImg.width)
    ..u16(guideImg.height)
    ..bytes(ZLibCodec().encode(raw));
  chunks.add(_chunk(0x2005, c.done()));

  final body = BytesBuilder();
  for (final ch in chunks) {
    body.add(ch);
  }
  final frameBody = body.toBytes();
  final frame = _W()
    ..u32(16 + frameBody.length)
    ..u16(0xF1FA)
    ..u16(chunks.length)
    ..u16(100)
    ..zeros(2)
    ..u32(chunks.length)
    ..bytes(frameBody);
  final frameBytes = frame.done();

  final h = _W()
    ..u32(128 + frameBytes.length)
    ..u16(0xA5E0)
    ..u16(1) // frames
    ..u16(guideImg.width)
    ..u16(guideImg.height)
    ..u16(32) // RGBA
    ..u32(1) // layer opacity valid
    ..u16(100)
    ..u32(0)
    ..u32(0)
    ..u8(0)
    ..zeros(3)
    ..u16(pal.length)
    ..u8(1)
    ..u8(1)
    ..i16(0)
    ..i16(0)
    ..u16(32) // 그리드: 반 타일 (32×16)
    ..u16(16)
    ..zeros(84);
  final header = h.done();
  assert(header.length == 128);
  return Uint8List.fromList([...header, ...frameBytes]);
}

// ───────── 미리보기 ─────────

img.Image preview(img.Image g, BedTemplate t) {
  const s = 5;
  final spec = spriteSpec(t.w, t.d, t.h);
  final w = g.width * s + 260, h = math.max(g.height * s + 40, 330);
  final out = img.Image(width: w, height: h, numChannels: 4);
  img.fill(out, color: img.ColorRgba8(0xFB, 0xF6, 0xEF, 255));
  // 체커 배경 위에 가이드
  final board = img.Image(width: g.width * s, height: g.height * s, numChannels: 4);
  for (final p in board) {
    final on = ((p.x ~/ (s * 4)) + (p.y ~/ (s * 4))).isEven;
    p
      ..r = on ? 0xF0 : 0xE4
      ..g = on ? 0xF0 : 0xE4
      ..b = on ? 0xF0 : 0xE4
      ..a = 255;
  }
  img.compositeImage(board, img.copyResize(g, width: g.width * s, height: g.height * s, interpolation: img.Interpolation.nearest));
  img.compositeImage(out, board, dstX: 10, dstY: 30);
  final ink = img.ColorRgba8(0x4A, 0x36, 0x28, 255);
  img.drawString(out, '${t.id}  ${spec.width}x${spec.height}  ${t.label}', font: img.arial14, x: 10, y: 8, color: ink);
  final v = footprintVerts(t.w, t.d, spec.ax, spec.ay);
  final lines = <(int, String)>[
    (GuideColor.anchor, 'anchor (${spec.ax}, ${spec.ay})'),
    (GuideColor.footprint, 'footprint ${t.w}x${t.d}'),
    (GuideColor.footprint, ' back ${v[0]}'),
    (GuideColor.footprint, ' right ${v[1]}'),
    (GuideColor.footprint, ' front ${v[2]}'),
    (GuideColor.footprint, ' left ${v[3]}'),
    (GuideColor.region, 'allowed region (h ${t.h})'),
    (GuideColor.top, 'top plane (dotted)'),
    (GuideColor.headboard, t.headboardBackRight ? 'headboard: back-right' : 'headboard: back-left'),
    (GuideColor.foot, t.headboardBackRight ? 'foot: front-left' : 'foot: front-right'),
    (GuideColor.light, 'light: top-left'),
  ];
  var y = 34;
  for (final (c, text) in lines) {
    final col = img.ColorRgba8(c >> 16, (c >> 8) & 255, c & 255, 255);
    img.fillRect(out, x1: g.width * s + 24, y1: y + 3, x2: g.width * s + 34, y2: y + 13, color: col);
    img.drawString(out, text, font: img.arial14, x: g.width * s + 40, y: y, color: ink);
    y += 24;
  }
  return out;
}

String gpl() {
  final b = StringBuffer('GIMP Palette\nName: oneul_sari_57\nColumns: 8\n#\n');
  for (final c in PixelPalette.all) {
    final r = c >> 16, g = (c >> 8) & 255, bl = c & 255;
    b.writeln('${r.toString().padLeft(3)} ${g.toString().padLeft(3)} ${bl.toString().padLeft(3)}\t#${c.toRadixString(16).padLeft(6, '0').toUpperCase()}');
  }
  return b.toString();
}

/// 검수용: 실제 그림 위에 가이드를 겹친 확대 이미지
///   dart run tool/make_bed_templates.dart overlay <그림.png> <템플릿 id> <출력.png>
void overlay(String artPath, String id, String outPath) {
  final t = templates.firstWhere((e) => e.id == id);
  final g = guide(t);
  final a = img.decodePng(File(artPath).readAsBytesSync())!.convert(numChannels: 4);
  if (a.width != g.width || a.height != g.height) {
    stderr.writeln('크기 다름: 그림 ${a.width}x${a.height}, 템플릿 ${g.width}x${g.height}');
    exit(1);
  }
  final both = img.Image(width: g.width, height: g.height, numChannels: 4);
  img.compositeImage(both, a);
  img.compositeImage(both, g);
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(preview(both, t)));
  stdout.writeln('wrote $outPath');
}

void main(List<String> args) {
  if (args.length == 4 && args.first == 'overlay') return overlay(args[1], args[2], args[3]);
  const root = 'art/templates';
  for (final t in templates) {
    final dir = Directory('$root/beds/${t.id}')..createSync(recursive: true);
    final g = guide(t);
    final art = img.Image(width: g.width, height: g.height, numChannels: 4); // 완전 투명
    File('${dir.path}/${t.id}_guide.png').writeAsBytesSync(img.encodePng(g));
    File('${dir.path}/${t.id}_art.png').writeAsBytesSync(img.encodePng(art));
    File('${dir.path}/${t.id}_template.ase').writeAsBytesSync(writeAse(g, t.id));
    File('${dir.path}/${t.id}_preview.png').writeAsBytesSync(img.encodePng(preview(g, t)));
    final s = spriteSpec(t.w, t.d, t.h);
    stdout.writeln('${t.id}: ${s.width}x${s.height} anchor (${s.ax},${s.ay}) verts ${footprintVerts(t.w, t.d, s.ax, s.ay)}');
  }
  Directory('$root/palette').createSync(recursive: true);
  File('$root/palette/oneul_sari_57.gpl').writeAsStringSync(gpl());
  stdout.writeln('palette: ${PixelPalette.all.length} colors');
}
