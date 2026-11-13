// 앱 아이콘과 시작 화면 그림을 원본 두 장에서 규격별로 만든다.
//
//   dart run tool/make_app_icon.dart
//
// 입력
//   art/source/app_icon/icon_original.png    꽉 찬 정사각형 아이콘 (노을빛 바탕 + 크림색 해 + 미니미)
//   art/source/app_icon/splash_original.png  투명 바탕의 미니미 전신
// 출력
//   android/app/src/main/res/mipmap-*/ic_launcher.png             예전 기기용 아이콘
//   android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  적응형 아이콘 앞 그림 (바탕색은 colors.xml)
//   android/app/src/main/res/drawable-*/splash.png                시작 화면 가운데 그림
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
//   ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png
//   art/source/app_icon/_preview.png                              확인용
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const src = 'art/source/app_icon';
const iconBg = 0xD47B52; // 아이콘 원본의 바탕색. android colors.xml 의 ic_launcher_background 와 같아야 한다
const cream = 0xF7F0E6; // 시작 화면 바탕 (AppColors.background)
const splashDp = 200; // 시작 화면 그림 한 변

img.Image load(String name) => img.decodePng(File('$src/$name').readAsBytesSync())!.convert(numChannels: 4);

img.ColorRgba8 rgb(int v) => img.ColorRgba8(v >> 16 & 255, v >> 8 & 255, v & 255, 255);

img.Image sized(img.Image m, int px) =>
    img.copyResize(m, width: px, height: px, interpolation: img.Interpolation.average);

/// 투명하지 않은 부분을 가운데에 두고 [pad] 비율만큼 여백을 둔 정사각형으로 자른다.
img.Image trimmed(img.Image m, double pad) {
  var l = m.width, t = m.height, r = -1, b = -1;
  for (final p in m) {
    if (p.a < 128) continue; // 흐릿한 잡티는 범위에서 뺀다
    l = math.min(l, p.x);
    r = math.max(r, p.x);
    t = math.min(t, p.y);
    b = math.max(b, p.y);
  }
  final side = (math.max(r - l + 1, b - t + 1) * (1 + pad * 2)).round();
  // 원본 밖으로 나가는 부분은 투명으로 둔다 (크기가 다른 그림을 compositeImage 로 겹치면 늘어나므로 픽셀을 직접 옮긴다)
  final out = img.Image(width: side, height: side, numChannels: 4);
  final ox = (l + r) ~/ 2 - side ~/ 2, oy = (t + b) ~/ 2 - side ~/ 2;
  for (final p in out) {
    final x = p.x + ox, y = p.y + oy;
    if (x >= 0 && y >= 0 && x < m.width && y < m.height) p.set(m.getPixel(x, y));
  }
  return out;
}

void save(String path, img.Image m, {bool opaque = false}) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(opaque ? m.convert(numChannels: 3) : m));
}

void main() {
  final icon = load('icon_original.png');
  final splash = trimmed(load('splash_original.png'), 0.04);

  // Android: mdpi 기준 배수
  const res = 'android/app/src/main/res';
  const dpi = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
  for (final e in dpi.entries) {
    final k = e.value;
    save('$res/mipmap-${e.key}/ic_launcher.png', sized(icon, (48 * k).round()), opaque: true);
    // 적응형 아이콘은 108dp 판의 가운데 66dp만 늘 보인다. 원본의 해(그림 폭의 71%)가 그 안에 들어오게
    // 그림을 80dp로 줄여 가운데에 놓고, 둘레는 같은 바탕색으로 채운다.
    final full = (108 * k).round(), inner = (80 * k).round();
    final fore = img.Image(width: full, height: full, numChannels: 4);
    img.fill(fore, color: rgb(iconBg));
    img.compositeImage(fore, sized(icon, inner), dstX: (full - inner) ~/ 2, dstY: (full - inner) ~/ 2);
    save('$res/mipmap-${e.key}/ic_launcher_foreground.png', fore, opaque: true);
    save('$res/drawable-${e.key}/splash.png', sized(splash, (splashDp * k).round()));
  }

  // iOS: 파일 이름에 적힌 크기 그대로 (투명 없이)
  const ios = 'ios/Runner/Assets.xcassets';
  for (final f in Directory('$ios/AppIcon.appiconset').listSync().whereType<File>()) {
    final m = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$').firstMatch(f.path);
    if (m == null) continue;
    save(f.path, sized(icon, (double.parse(m[1]!) * int.parse(m[2]!)).round()), opaque: true);
  }
  for (final (name, k) in const [('LaunchImage.png', 1), ('LaunchImage@2x.png', 2), ('LaunchImage@3x.png', 3)]) {
    save('$ios/LaunchImage.imageset/$name', sized(splash, splashDp * k));
  }

  // 확인용: 네모, 적응형 아이콘을 둥근 네모·동그라미로 가린 모습, 작은 크기, 시작 화면
  final pv = img.Image(width: 1400, height: 760, numChannels: 4);
  img.fill(pv, color: rgb(0xDDDDDD));
  img.compositeImage(pv, sized(icon, 320), dstX: 30, dstY: 30);
  final fore = load('../../../$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
  final seen = sized(img.copyCrop(fore, x: 72, y: 72, width: 288, height: 288), 320); // 가운데 72dp
  for (final (i, radius) in const [(1, 72.0), (2, 160.0)]) {
    final masked = seen.clone();
    for (final p in masked) {
      final dx = math.max(0, math.max(radius - p.x, p.x - (319 - radius))).toDouble();
      final dy = math.max(0, math.max(radius - p.y, p.y - (319 - radius))).toDouble();
      if (dx * dx + dy * dy > radius * radius) p.a = 0;
    }
    img.compositeImage(pv, masked, dstX: 30 + i * 350, dstY: 30);
  }
  for (final (i, px) in const [(0, 180), (1, 120), (2, 60), (3, 29)]) {
    img.compositeImage(pv, sized(icon, px), dstX: 30 + i * 200, dstY: 400);
  }
  final phone = img.Image(width: 300, height: 650, numChannels: 4); // 360dp 폭 화면을 줄인 것
  img.fill(phone, color: rgb(cream));
  final s = (splashDp * 300 / 360).round();
  img.compositeImage(phone, sized(splash, s), dstX: (300 - s) ~/ 2, dstY: (650 - s) ~/ 2);
  img.compositeImage(pv, phone, dstX: 1080, dstY: 30);
  save('$src/_preview.png', pv);
  stdout.writeln('만들었다: 아이콘·시작 화면 그림');
}
