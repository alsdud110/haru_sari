// 아이콘 시트(4×4)를 아이콘 하나씩 잘라 투명 배경 PNG로 만든다.
//
//   dart run tool/make_icons.dart
//
// 입력: art/source/icons/*_sheet_original.png (흰 배경, 갈색 외곽선 아이콘 16개씩), 낱장은 *_original.png (아이콘 하나)
// 출력: assets/icons/<이름>.png (256×256, 투명 배경), art/source/icons/_preview.png (확인용)
//
// 방법
// 1. 가장자리에서 흰 배경을 따라 번져 가며 배경을 찾는다 (외곽선 안쪽의 밝은 칠은 건드리지 않는다).
// 2. 배경과 맞닿은 가장자리 픽셀은 외곽선 색 + 밝기에 따른 투명도로 바꿔 흰 테두리가 남지 않게 한다.
// 3. 이어진 덩어리를 찾아 중심이 속한 칸(4×4)에 모은 뒤, 칸마다 내용에 맞게 잘라 정사각형으로 줄인다.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const size = 256; // 빈 화면 안내(64pt × 3배 화면 = 192px)에서도 흐려지지 않게
const outline = (0x3B, 0x31, 0x29);

const sheets = {
  'art/source/icons/category_sheet_original.png': [
    'moon', 'soap', 'rice', 'drop',
    'shoe', 'heart', 'train', 'briefcase',
    'book_open', 'broom', 'dog', 'lotus',
    'headphones', 'chat', 'coin', 'sparkle',
  ],
  'art/source/icons/routine_sheet_original.png': [
    'sun', 'glass', 'shirt', 'bus',
    'cutlery', 'dumbbell', 'house', 'bath',
    'book', 'pill', 'plant', 'note',
    'music', 'toothbrush', 'bed', 'mug',
  ],
  // 배지·빈 화면 안내·온보딩용
  'art/source/icons/badge_sheet_original.png': [
    'sprout', 'full_moon', 'rainbow', 'clover',
    'tree', 'home_tree', 'sofa', 'tshirt',
    'star', 'star_sparkle', 'mailbox', 'box',
    'letter', 'sun_full', 'check', 'trophy',
  ],
  // 낱장 아이콘 (한 장에 하나)
  'art/source/icons/play_original.png': ['play'], // 광고 보고 코인 받기 버튼
};

void main() {
  final made = <img.Image>[];
  for (final e in sheets.entries) {
    final src = img.decodePng(File(e.key).readAsBytesSync())!.convert(numChannels: 4);
    final w = src.width, h = src.height;
    final grid = e.value.length == 1 ? 1 : 4; // 한 장에 아이콘 하나면 칸을 나누지 않는다
    bool white(int x, int y) {
      final p = src.getPixel(x, y);
      final lo = math.min(p.r, math.min(p.g, p.b)), hi = math.max(p.r, math.max(p.g, p.b));
      return lo >= 246 && hi - lo <= 8;
    }

    // 1. 배경
    final bg = List.filled(w * h, false);
    final queue = <int>[];
    void seed(int x, int y) {
      if (!bg[y * w + x] && white(x, y)) {
        bg[y * w + x] = true;
        queue.add(y * w + x);
      }
    }

    for (var x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }
    for (var i = 0; i < queue.length; i++) {
      final x = queue[i] % w, y = queue[i] ~/ w;
      if (x > 0) seed(x - 1, y);
      if (x < w - 1) seed(x + 1, y);
      if (y > 0) seed(x, y - 1);
      if (y < h - 1) seed(x, y + 1);
    }

    // 2. 가장자리 (배경에서 2픽셀 안쪽까지)
    final dist = List.filled(w * h, 99);
    var frontier = [for (var i = 0; i < w * h; i++) if (bg[i]) i];
    for (final i in frontier) {
      dist[i] = 0;
    }
    for (var d = 1; d <= 2; d++) {
      final next = <int>[];
      for (final i in frontier) {
        final x = i % w, y = i ~/ w;
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          if (dist[j] > d) {
            dist[j] = d;
            next.add(j);
          }
        }
      }
      frontier = next;
    }
    final out = img.Image(width: w, height: h, numChannels: 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (bg[i]) continue; // 투명
        final p = src.getPixel(x, y);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        if (dist[i] <= 2 && lum > 90) {
          final a = ((255 - lum) / (255 - 52)).clamp(0.0, 1.0);
          out.setPixelRgba(x, y, outline.$1, outline.$2, outline.$3, (a * 255).round());
        } else {
          out.setPixelRgba(x, y, p.r, p.g, p.b, 255);
        }
      }
    }

    // 3. 덩어리 → 칸
    final label = List.filled(w * h, -1);
    final boxes = List.generate(grid * grid, (_) => [w, h, -1, -1]); // minX, minY, maxX, maxY
    final owner = <int, int>{};
    var n = 0;
    for (var s = 0; s < w * h; s++) {
      if (bg[s] || label[s] >= 0) continue;
      final comp = <int>[s];
      label[s] = n;
      var sx = 0, sy = 0, minX = w, minY = h, maxX = -1, maxY = -1;
      for (var k = 0; k < comp.length; k++) {
        final x = comp[k] % w, y = comp[k] ~/ w;
        sx += x;
        sy += y;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final j = ny * w + nx;
          if (bg[j] || label[j] >= 0) continue;
          label[j] = n;
          comp.add(j);
        }
      }
      if (comp.length >= 12) {
        final cell =
            (sy / comp.length * grid ~/ h).clamp(0, grid - 1) * grid + (sx / comp.length * grid ~/ w).clamp(0, grid - 1);
        owner[n] = cell;
        final b = boxes[cell];
        b[0] = math.min(b[0], minX);
        b[1] = math.min(b[1], minY);
        b[2] = math.max(b[2], maxX);
        b[3] = math.max(b[3], maxY);
      }
      n++;
    }

    for (var c = 0; c < grid * grid; c++) {
      final b = boxes[c];
      if (b[2] < 0) {
        stderr.writeln('${e.key}: 칸 $c 가 비어 있다');
        exit(1);
      }
      final bw = b[2] - b[0] + 1, bh = b[3] - b[1] + 1;
      final side = (math.max(bw, bh) * 1.06).ceil();
      final square = img.Image(width: side, height: side, numChannels: 4);
      final ox = (side - bw) ~/ 2, oy = (side - bh) ~/ 2;
      for (var y = 0; y < bh; y++) {
        for (var x = 0; x < bw; x++) {
          final i = (b[1] + y) * w + b[0] + x;
          if (bg[i] || owner[label[i]] != c) continue; // 옆 칸에서 넘어온 조각은 뺀다
          square.setPixel(ox + x, oy + y, out.getPixel(b[0] + x, b[1] + y));
        }
      }
      final icon = img.copyResize(square, width: size, height: size, interpolation: img.Interpolation.average);
      File('assets/icons/${e.value[c]}.png').writeAsBytesSync(img.encodePng(icon));
      made.add(icon);
      stdout.writeln('${e.value[c].padRight(12)} ${bw}x$bh');
    }
  }

  // 확인용: 크림·어두운 바탕 위에 실제 크기(작게)와 크게 나란히
  final cols = 8, pad = 16, cell = size + pad;
  final sheet = img.Image(width: cols * cell + pad, height: (made.length / cols).ceil() * cell * 2 + pad, numChannels: 4);
  img.fill(sheet, color: img.ColorRgba8(0xFB, 0xF6, 0xEF, 255));
  final half = (made.length / cols).ceil() * cell;
  img.fillRect(sheet, x1: 0, y1: half + pad ~/ 2, x2: sheet.width, y2: sheet.height, color: img.ColorRgba8(0x8F, 0xAE, 0x8B, 255));
  for (var i = 0; i < made.length; i++) {
    final x = pad + (i % cols) * cell, y = pad + (i ~/ cols) * cell;
    img.compositeImage(sheet, made[i], dstX: x, dstY: y);
    img.compositeImage(sheet, made[i], dstX: x, dstY: y + half);
  }
  File('art/source/icons/_preview.png').writeAsBytesSync(img.encodePng(sheet));
}
