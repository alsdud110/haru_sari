// 카카오톡 공유 카드 그림 (800×400)을 만든다.
//
//   dart run tool/make_share_card.dart
//
// 입력  art/source/app_icon/splash_original.png  투명 바탕의 미니미 전신
// 출력  docs/share/card.png  → GitHub Pages: https://alsdud110.github.io/haru_sari/share/card.png
//       (lib/config.dart ShareCopy.cardImage). 글자는 카드 아래에 카카오가 따로 붙이므로 그림만 둔다.
import 'dart:io';

import 'package:image/image.dart' as img;

const width = 800, height = 400;
const cream = 0xF7F0E6; // AppColors.background
const sun = 0xD47B52; // 앱 아이콘 바탕색 (노을)
const sunLight = 0xF2C9A8;

img.ColorRgba8 rgb(int v, [int a = 255]) => img.ColorRgba8(v >> 16 & 255, v >> 8 & 255, v & 255, a);

/// 원본의 반투명 빛 번짐을 지우고(픽셀 그림만 남김) 투명한 가장자리를 잘라 낸다.
img.Image trim(img.Image m) {
  for (final p in m) {
    if (p.a < 200) p.a = 0;
  }
  var l = m.width, t = m.height, r = 0, b = 0;
  for (final p in m) {
    if (p.a > 0) {
      if (p.x < l) l = p.x;
      if (p.x > r) r = p.x;
      if (p.y < t) t = p.y;
      if (p.y > b) b = p.y;
    }
  }
  return img.copyCrop(m, x: l, y: t, width: r - l + 1, height: b - t + 1);
}

void main() {
  final minimi = trim(
    img.decodePng(File('art/source/app_icon/splash_original.png').readAsBytesSync())!.convert(numChannels: 4),
  );
  final card = img.Image(width: width, height: height, numChannels: 4)..clear(rgb(cream));

  // 양옆에 작은 해 두 개 (원본 그림에 미니미 뒤 원이 이미 있어 가운데는 비운다)
  const cx = width ~/ 2;
  img.fillCircle(card, x: 130, y: 120, radius: 46, color: rgb(sunLight));
  img.fillCircle(card, x: 130, y: 120, radius: 34, color: rgb(sun));
  img.fillCircle(card, x: 676, y: 292, radius: 30, color: rgb(sunLight));
  img.fillCircle(card, x: 676, y: 292, radius: 21, color: rgb(sun));

  // 미니미: 높이 340 에 맞춰 가운데 아래쪽
  final h = 340;
  final w = (minimi.width * h / minimi.height).round();
  final m = img.copyResize(minimi, width: w, height: h, interpolation: img.Interpolation.average);
  img.compositeImage(card, m, dstX: cx - w ~/ 2, dstY: height - h - 18);

  Directory('docs/share').createSync(recursive: true);
  File('docs/share/card.png').writeAsBytesSync(img.encodePng(card));
  stdout.writeln('docs/share/card.png ${card.width}x${card.height}');
}
