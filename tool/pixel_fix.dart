// 픽셀 아트 에셋 분석·보정 도구 (docs/asset-system/02 §13.1, 05 파이프라인 초안)
//
// 사용:
//   dart run tool/pixel_fix.dart <원본.png> <보정본.png> --footprint 1x2 --height 52 --rot r0 \
//       [--compare <비교.png>] [--alpha 128]
//
// 원본 파일은 읽기만 한다. 보정본·비교 이미지는 새 파일로 쓴다.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:haru_sari/room/palette.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/pixel_fix.dart <in.png> <out.png> --footprint WxD --height H --rot r0|r1');
    exit(64);
  }
  String opt(String name, String dflt) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : dflt;
  }

  final fp = opt('footprint', '1x2').split('x').map(int.parse).toList();
  final h = int.parse(opt('height', '52'));
  final rot = opt('rot', 'r0');
  final alphaCut = int.parse(opt('alpha', '128'));
  final comparePath = args.contains('--compare') ? opt('compare', '') : null;
  final (w, d) = rot == 'r0' ? (fp[0], fp[1]) : (fp[1], fp[0]);

  final raw = img.decodePng(File(args[0]).readAsBytesSync())!.convert(numChannels: 4);
  final spec = spriteSpec(w, d, h);
  final out = StringBuffer();
  out.writeln('# ${args[0]}');

  // --canvas WxH --offset x,y|auto : 크기를 바꾸지 않고 더 큰 캔버스에 옮겨 놓는다 (늘리기·줄이기 없음)
  var src = raw;
  if (args.contains('--canvas')) {
    final cv = opt('canvas', '${spec.width}x${spec.height}').split('x').map(int.parse).toList();
    final off = opt('offset', 'auto');
    int ox, oy;
    if (off == 'auto') {
      // 그림 바닥 마름모의 중심 ≈ (좌우 끝의 가운데, 좌우 끝 열이 가장 낮게 내려온 y)
      var minX = raw.width, maxX = -1;
      for (final p in raw) {
        if (p.a.toInt() < alphaCut) continue;
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
      }
      var sideY = 0;
      for (final p in raw) {
        if (p.a.toInt() >= alphaCut && (p.x == minX || p.x == maxX)) sideY = math.max(sideY, p.y);
      }
      final cx = spec.ax + (w - d) * 16; // 점유 마름모 중심 x
      final cy = spec.ay + (w + d) * 8; // 점유 마름모 중심 y
      ox = (cx - (minX + maxX) / 2).floor();
      oy = cy - sideY;
    } else {
      final o = off.split(',').map(int.parse).toList();
      ox = o[0];
      oy = o[1];
    }
    src = img.Image(width: cv[0], height: cv[1], numChannels: 4);
    for (final p in raw) {
      final x = p.x + ox, y = p.y + oy;
      if (x < 0 || y < 0 || x >= cv[0] || y >= cv[1]) continue;
      src.setPixelRgba(x, y, p.r, p.g, p.b, p.a);
    }
    out.writeln('placed ${raw.width}x${raw.height} onto ${cv[0]}x${cv[1]} at offset ($ox, $oy), no scaling');
  }
  out.writeln('size: ${src.width}x${src.height} (expected ${spec.width}x${spec.height})');

  // ── 원본 통계
  final colors = <int>{};
  var opaque = 0, semi = 0, semiHi = 0;
  for (final p in src) {
    final a = p.a.toInt();
    if (a == 0) continue;
    colors.add(rgb(p));
    if (a == 255) {
      opaque++;
    } else {
      semi++;
      if (a >= alphaCut) semiHi++;
    }
  }
  out.writeln('original: distinct RGB ${colors.length}, opaque(255) $opaque, semi-alpha $semi '
      '($semiHi kept at cut $alphaCut)');

  // ── 보정: 알파 0/255 + 팔레트 최근접 (CIE Lab ΔE76)
  final palette = PixelPalette.all.toList();
  final paletteLab = palette.map(toLab).toList();
  final fixed = img.Image(width: src.width, height: src.height, numChannels: 4);
  final cache = <int, (int, double)>{};
  // --clusters N: 비슷한 색을 먼저 N개로 묶고, 묶음 대표색을 팔레트에 맞춘다 (얼룩 방지)
  final k = int.parse(opt('clusters', '0'));
  final clusterOf = <int, int>{};
  if (k > 0) {
    final weights = <int, int>{};
    for (final p in src) {
      if (p.a.toInt() >= alphaCut) weights[rgb(p)] = (weights[rgb(p)] ?? 0) + 1;
    }
    final keys = weights.keys.toList()..sort();
    final labs = {for (final c in keys) c: toLab(c)};
    // 결정적 초기값: 빈도 높은 색부터, 이미 고른 중심과 충분히 먼 색
    final byFreq = [...keys]..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    final centers = <(double, double, double)>[];
    for (final c in byFreq) {
      if (centers.length >= k) break;
      if (centers.every((m) => dist(m, labs[c]!) > 8)) centers.add(labs[c]!);
    }
    for (var iter = 0; iter < 20; iter++) {
      final sums = List.generate(centers.length, (_) => [0.0, 0.0, 0.0, 0.0]);
      for (final c in keys) {
        var bi = 0;
        var bd = double.infinity;
        for (var i = 0; i < centers.length; i++) {
          final dd = dist(labs[c]!, centers[i]);
          if (dd < bd) {
            bd = dd;
            bi = i;
          }
        }
        clusterOf[c] = bi;
        final wgt = weights[c]!.toDouble();
        final l = labs[c]!;
        sums[bi][0] += l.$1 * wgt;
        sums[bi][1] += l.$2 * wgt;
        sums[bi][2] += l.$3 * wgt;
        sums[bi][3] += wgt;
      }
      for (var i = 0; i < centers.length; i++) {
        if (sums[i][3] > 0) centers[i] = (sums[i][0] / sums[i][3], sums[i][1] / sums[i][3], sums[i][2] / sums[i][3]);
      }
    }
    // 묶음 대표색 → 팔레트
    final clusterColor = <int, int>{};
    for (var i = 0; i < centers.length; i++) {
      var bi = 0;
      var bd = double.infinity;
      for (var j = 0; j < palette.length; j++) {
        final dd = dist(centers[i], paletteLab[j]);
        if (dd < bd) {
          bd = dd;
          bi = j;
        }
      }
      clusterColor[i] = palette[bi];
    }
    for (final c in keys) {
      final pc = clusterColor[clusterOf[c]!]!;
      cache[c] = (pc, dist(labs[c]!, toLab(pc)));
    }
    out.writeln('clusters: ${centers.length} → palette colors ${clusterColor.values.toSet().length}');
  }
  var changed = 0, removed = 0, sumDe = 0.0, maxDe = 0.0, big = 0;
  final deMap = List<double>.filled(src.width * src.height, -1);
  for (final p in src) {
    final a = p.a.toInt();
    if (a < alphaCut) {
      if (a > 0) removed++;
      fixed.setPixelRgba(p.x, p.y, 0, 0, 0, 0);
      continue;
    }
    final c = rgb(p);
    final (best, de) = cache.putIfAbsent(c, () {
      final lab = toLab(c);
      var bi = 0;
      var bd = double.infinity;
      for (var i = 0; i < palette.length; i++) {
        final dd = dist(lab, paletteLab[i]);
        if (dd < bd) {
          bd = dd;
          bi = i;
        }
      }
      return (palette[bi], bd);
    });
    fixed.setPixelRgba(p.x, p.y, best >> 16, (best >> 8) & 255, best & 255, 255);
    if (best != c) changed++;
    sumDe += de;
    maxDe = math.max(maxDe, de);
    if (de > 15) big++;
    deMap[p.y * src.width + p.x] = de;
  }
  final kept = opaque + semiHi;
  final usedAfter = <int>{for (final p in fixed) if (p.a > 0) rgb(p)};
  out.writeln('fixed: distinct RGB ${usedAfter.length}, kept pixels $kept, semi removed $removed, '
      'recolored $changed (${pct(changed, kept)}), mean dE ${(sumDe / math.max(kept, 1)).toStringAsFixed(2)}, '
      'max dE ${maxDe.toStringAsFixed(1)}, dE>15 $big px (${pct(big, kept)})');

  // ── 영역·잘림·앵커
  for (final (rw, rd, label) in [(w, d, rot), (d, w, rot == 'r0' ? 'r1' : 'r0')]) {
    final s = spriteSpec(rw, rd, h);
    if (s.width != src.width || s.height != src.height) continue;
    final poly = region(rw, rd, h, s.ax, s.ay);
    var outside = 0;
    for (final p in fixed) {
      if (p.a > 0 && !inside(poly, p.x + 0.5, p.y + 0.5)) outside++;
    }
    out.writeln('region as $label (footprint ${rw}x$rd, anchor ${s.ax},${s.ay}): outside $outside px');
  }
  // 테두리 잘림: 맨 가장자리 줄에 그림이 닿아 있는지
  int edge(bool Function(int x, int y) f) {
    var n = 0;
    for (final p in fixed) {
      if (p.a > 0 && f(p.x, p.y)) n++;
    }
    return n;
  }

  out.writeln('edge touch: top ${edge((x, y) => y == 0)}, left ${edge((x, y) => x == 0)}, '
      'right ${edge((x, y) => x == src.width - 1)}, bottom ${edge((x, y) => y == src.height - 1)}');
  // 실제 그림의 바닥 접점: 가장 아래 줄, 가장 왼쪽/오른쪽 열이 어디인지
  var minX = src.width, maxX = -1, minY = src.height, maxY = -1;
  for (final p in fixed) {
    if (p.a == 0) continue;
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  final bottomXs = [for (final p in fixed) if (p.a > 0 && p.y == maxY) p.x];
  final leftYs = [for (final p in fixed) if (p.a > 0 && p.x == minX) p.y];
  final rightYs = [for (final p in fixed) if (p.a > 0 && p.x == maxX) p.y];
  out.writeln('content bbox: x $minX..$maxX, y $minY..$maxY');
  out.writeln('lowest row y=$maxY at x ${bottomXs.first}..${bottomXs.last} '
      '(front vertex expected at x ${(spec.ax + (w - d) * 32)}, y ${spec.height})');
  out.writeln('leftmost col x=$minX at y ${leftYs.first}..${leftYs.last} (left vertex expected y ${spec.ay + d * 16})');
  out.writeln('rightmost col x=$maxX at y ${rightYs.first}..${rightYs.last} (right vertex expected y ${spec.ay + w * 16})');

  File(args[1])
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(fixed));
  out.writeln('wrote ${args[1]}');

  if (comparePath != null && comparePath.isNotEmpty) {
    writeCompare(src, fixed, deMap, w, d, h, comparePath);
    out.writeln('wrote $comparePath');
  }
  stdout.write(out);
}

// ───────── 비교 이미지 ─────────

void writeCompare(img.Image src, img.Image fixed, List<double> deMap, int w, int d, int h, String path) {
  const s = 4, gap = 8, label = 20;
  final pw = src.width * s;
  final ph = src.height * s;
  final out = img.Image(width: pw * 4 + gap * 5, height: ph + label + gap * 2, numChannels: 4);
  img.fill(out, color: img.ColorRgba8(0xFB, 0xF6, 0xEF, 255));

  void panel(int i, img.Image Function(img.Image) build, String title) {
    final ox = gap + i * (pw + gap);
    final panelImg = build(src);
    img.compositeImage(out, panelImg, dstX: ox, dstY: label + gap);
    img.drawString(out, title, font: img.arial14, x: ox, y: 4, color: img.ColorRgba8(0x4A, 0x36, 0x28, 255));
  }

  img.Image checker(int width, int height) {
    final c = img.Image(width: width, height: height, numChannels: 4);
    for (final p in c) {
      final on = ((p.x ~/ 8) + (p.y ~/ 8)).isEven;
      p
        ..r = on ? 0xEE : 0xDD
        ..g = on ? 0xEE : 0xDD
        ..b = on ? 0xEE : 0xDD
        ..a = 255;
    }
    return c;
  }

  img.Image scaled(img.Image a) {
    final bg = checker(pw, ph);
    img.compositeImage(bg, img.copyResize(a, width: pw, height: ph, interpolation: img.Interpolation.nearest));
    return bg;
  }

  panel(0, (_) => scaled(src), 'original');
  panel(1, (_) => scaled(fixed), 'fixed (palette + alpha)');
  panel(2, (_) {
    final m = img.Image(width: src.width, height: src.height, numChannels: 4);
    for (final p in src) {
      final i = p.y * src.width + p.x;
      final a = p.a.toInt();
      final fa = fixed.getPixel(p.x, p.y).a.toInt();
      if (a > 0 && fa == 0) {
        m.setPixelRgba(p.x, p.y, 60, 110, 220, 255); // 지워진 반투명 픽셀
      } else if (deMap[i] >= 0) {
        final t = (deMap[i] / 20).clamp(0.0, 1.0);
        m.setPixelRgba(p.x, p.y, 255, (255 * (1 - t)).round(), (255 * (1 - t)).round(), 255);
      }
    }
    return scaled(m);
  }, 'change (red=dE, blue=alpha cut)');
  panel(3, (_) {
    final base = scaled(fixed);
    final spec = spriteSpec(w, d, h);
    final poly = region(w, d, h, spec.ax, spec.ay);
    final c = img.ColorRgba8(0xE0, 0x8A, 0x5B, 255);
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      img.drawLine(base, x1: (a.$1 * s).round(), y1: (a.$2 * s).round(), x2: (b.$1 * s).round(), y2: (b.$2 * s).round(), color: c);
    }
    // 바닥 점유 마름모
    final fpc = img.ColorRgba8(0x6F, 0x8F, 0x6B, 255);
    final verts = [
      (spec.ax, spec.ay),
      (spec.ax + w * 32, spec.ay + w * 16),
      (spec.ax + (w - d) * 32, spec.ay + (w + d) * 16),
      (spec.ax - d * 32, spec.ay + d * 16),
    ];
    for (var i = 0; i < 4; i++) {
      final a = verts[i], b = verts[(i + 1) % 4];
      img.drawLine(base, x1: a.$1 * s, y1: a.$2 * s, x2: b.$1 * s, y2: b.$2 * s, color: fpc);
    }
    img.fillCircle(base, x: spec.ax * s, y: spec.ay * s, radius: 5, color: img.ColorRgba8(0xD0, 0x30, 0x30, 255));
    return base;
  }, 'region + footprint + anchor');
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(out));
}

// ───────── 규격·기하 (lib/room/iso.dart와 같은 공식) ─────────

({int width, int height, int ax, int ay}) spriteSpec(int w, int d, int h) {
  final width = (w + d) * 32;
  final height = ((w + d) * 16 + h + 7) ~/ 8 * 8;
  return (width: width, height: height, ax: d * 32, ay: height - (w + d) * 16);
}

List<(double, double)> region(int w, int d, int h, int ax, int ay) {
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
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final (xi, yi) = poly[i];
    final (xj, yj) = poly[j];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

// ───────── 색 ─────────

int rgb(img.Pixel p) => (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();

String pct(int a, int b) => '${(100 * a / math.max(b, 1)).toStringAsFixed(1)}%';

(double, double, double) toLab(int c) {
  double lin(int v) {
    final s = v / 255;
    return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = lin(c >> 16), g = lin((c >> 8) & 255), b = lin(c & 255);
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = r * 0.2126 + g * 0.7152 + b * 0.0722;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;
  double f(double t) => t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}

double dist((double, double, double) a, (double, double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2) + math.pow(a.$3 - b.$3, 2));
