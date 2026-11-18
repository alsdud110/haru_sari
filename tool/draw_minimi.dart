// 미니미 레이어 시트를 코드로 그린다 (docs/asset-system/01 §8).
// 프레임 64×96, 발 앵커 (32,88), 가로 4프레임(idle) × 세로 2줄(정면, 측면 오른쪽) → 256×192.
// 피부·머리는 0번 램프로, 기본 옷은 테라코타 램프로 그린다 (앱이 불러올 때 색을 바꾼다).
// 비율은 싸이월드 미니미처럼 머리를 크게(얼굴 34×31), 몸을 짧게(몸통 17, 다리 17) 잡는다.
//
// 사용: dart run tool/draw_minimi.dart [미리보기.png]
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:haru_sari/room/palette.dart';

const fw = 64, fh = 96, frames = 4;
const idleBob = [0, 1, 1, 0]; // 2·3번 프레임에서 윗몸이 1px 내려간다
const root = 'assets/pixel/characters';

typedef Part = Map<(int, int), int>;
typedef Ramp = List<int>; // [밝음, 기본, 그늘]
typedef Draw = void Function(Cel c, bool side, int u, bool blink);

const ink = 0x4A3628, inkSoft = 0x6B4F3A;
const sk = [0xFDEBDD, 0xFBE3D0, 0xE8C2A6];
const hr = [0x5A463C, 0x3B2E28, 0x251C18];
const Ramp terracotta = [0xEDA77F, 0xE08A5B, 0xB9663D];
const Ramp cream = [0xFFF8EE, 0xF6EBDD, 0xEADBC7];
const Ramp butter = [0xFBEFCB, 0xF2D27A, 0xE5B547];
const Ramp denim = [0xBCD3E8, 0x9DBBD8, 0x6F8FB8];
const Ramp sage = [0xA9C4A3, 0x8FAE8B, 0x6F8F6B];
const Ramp lavender = [0xE6D6E6, 0xC9A3C9, 0x9C789C];
const Ramp pants = [0x8E6240, 0x6A4630, 0x4A3628];
const Ramp beige = [0xE8C9A0, 0xD9B993, 0xC49E74];
const blush = 0xEDA77F, mouth = 0xB9663D;

/// 기본 옷 무늬 색. 앱이 Minimi.outfit 에 맞는 무늬 색으로 바꾼다 (PixelPalette.outfitSheet[3]).
const motif = 0xF8DCCB;

/// 머리끈 (머리색을 바꿔도 그대로)
const tie = 0xE08A5B, tieDark = 0xB9663D;

/// 프레임 한 칸.
class Cel {
  final px = List<int?>.filled(fw * fh, null); // 0xRRGGBB, null = 투명

  void put(Part part) {
    for (final e in part.entries) {
      final (x, y) = e.key;
      if (x >= 0 && x < fw && y >= 0 && y < fh) px[y * fw + x] = e.value;
    }
  }

  /// [part]를 칠하고 둘레 1px에 외곽선을 두른다 (먼저 그린 것 위에도 덮는다).
  void stamp(Part part, [int outline = ink]) {
    put(part);
    put({
      for (final (x, y) in part.keys)
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)])
          if (!part.containsKey((x + dx, y + dy))) (x + dx, y + dy): outline,
    });
  }

  /// 이미 그린 픽셀을 지운다 (아래 레이어가 비치게).
  void cut(Iterable<(int, int)> at) {
    for (final (x, y) in at) {
      px[y * fw + x] = null;
    }
  }

  Cel flipped() {
    final o = Cel();
    for (var y = 0; y < fh; y++) {
      for (var x = 0; x < fw; x++) {
        o.px[y * fw + (fw - 1 - x)] = px[y * fw + x];
      }
    }
    return o;
  }
}

Part area(bool Function(int x, int y) inside, int Function(int x, int y) color) => {
  for (var y = 0; y < fh; y++)
    for (var x = 0; x < fw; x++)
      if (inside(x, y)) (x, y): color(x, y),
};

Part rect(int l, int t, int r, int b, int Function(int x, int y) color) =>
    area((x, y) => x >= l && x <= r && y >= t && y <= b, color);

/// 둥근 네모(초타원) 안인지.
bool sq(int x, int y, double cx, double cy, double rx, double ry, [double n = 2.6]) =>
    math.pow((x + .5 - cx).abs() / rx, n) + math.pow((y + .5 - cy).abs() / ry, n) <= 1;

/// 점들을 잇는 굵은 선(원 여러 개). 반지름은 [r0]에서 [r1]로 줄어든다 — 묶은 머리 꼬리.
bool brush(int x, int y, List<(double, double)> pts, double r0, double r1) {
  for (var i = 0; i < pts.length - 1; i++) {
    final (ax, ay) = pts[i];
    final (bx, by) = pts[i + 1];
    for (var s = 0; s <= 8; s++) {
      final t = s / 8, k = (i + t) / (pts.length - 1);
      final r = r0 + (r1 - r0) * k;
      if (sq(x, y, ax + (bx - ax) * t, ay + (by - ay) * t, r, r, 2)) return true;
    }
  }
  return false;
}

// ───────── 얼굴 ─────────

bool inHead(int x, int y) => sq(x, y, 32, 34.5, 17, 15, 2.4); // x 15~48, y 19~49

void drawHead(Cel c, bool side, int u, bool blink) {
  if (!side) {
    // 귀: 머리보다 먼저 그려 머리 외곽선 뒤로 들어간다
    for (final l in const [13, 49]) {
      c.stamp(
        rect(l, 34 + u, l + 1, 39 + u, (x, y) => (y - u == 36 || y - u == 37) && x == (l == 13 ? 14 : 49) ? sk[2] : sk[1]),
      );
    }
  }
  final head = area((x, y) => inHead(x, y - u), (x, y) => !inHead(x + 2, y - u + 1) ? sk[2] : sk[1]);
  if (side) head[(49, 38 + u)] = sk[1]; // 코
  c.stamp(head);
  if (side) {
    c.put(pattern(29, 34 + u, const ['.aa.', 'a..a', 'a...', 'a..a', '.aa.'], {'a': sk[2]})); // 귀
    c.put(rect(39, 41 + u, 41, 41 + u, (_, _) => blush));
  } else {
    c.put(rect(19, 41 + u, 21, 41 + u, (_, _) => blush));
    c.put(rect(42, 41 + u, 44, 41 + u, (_, _) => blush));
  }
}

// ───────── 눈·입 (Minimi.eyes / Minimi.mouth 번호 순서) ─────────

/// 눈 하나: 3×4, 왼쪽 위 = (눈 x, 34). 싸이월드처럼 크고 낮게, 흰 반짝임을 왼쪽 위에 둔다.
const eyeShapes = [
  ['.a.', 'waa', 'aaa', '.a.'], // 기본
  ['aaa', 'wwa', 'waa', 'aaa'], // 반짝
  ['...', '...', 'a.a', '.a.'], // 감은 눈
  ['...', '.a.', 'a.a', '...'], // 웃는 눈
  null, // 윙크: 한쪽은 기본, 한쪽은 웃는 눈
  ['...', 'aaa', 'waa', '.a.'], // 졸린 눈
];
const eyeBlink = ['...', '...', '...', 'aaa'];

Draw eyesDraw(int k) => (c, side, u, blink) {
  final xs = side ? const [42] : const [24, 38];
  for (var i = 0; i < xs.length; i++) {
    final kind = k == 4 ? (i == 1 ? 3 : 0) : k;
    final open = kind != 2 && kind != 3;
    c.put(pattern(xs[i], 34 + u, blink && open ? eyeBlink : eyeShapes[kind]!, const {'a': ink, 'w': 0xFFF8EE}));
  }
};

const mouthShapes = [
  ['a..a', '.aa.'], // 미소
  ['aaaa', 'abba', '.aa.'], // 활짝
  ['.aa.', 'a..a'], // 시무룩
  ['.aa.', 'a..a', '.aa.'], // 놀람
  ['.aa.'], // 무표정
  ['a.a.a', '.a.a.'], // 고양이
];

Draw mouthDraw(int k) =>
    (c, side, u, _) => c.put(pattern(side ? 43 : 30, 41 + u, mouthShapes[k], const {'a': mouth, 'b': blush}));

// ───────── 머리 모양 (Minimi.hairStyle 번호 순서) ─────────

typedef Region = bool Function(int x, int y, bool side);

/// 머리를 감싸는 기본 머리카락 덩어리 (x 13~50, y 15~49). 싸이월드처럼 부피를 크게 잡는다.
bool shell(int x, int y) => sq(x, y, 32, 32.5, 19, 17.5, 2.4);

/// 둥근 앞머리 아래 끝. 가운데가 눈썹 위(28)이고 관자놀이로 갈수록 내려온다. 가닥 사이는 조금 올라간다.
int bangs(int x, bool side, {int sides = 46}) {
  if (side) return x <= 29 ? sides : (x <= 36 ? 35 : 28);
  if (x <= 16 || x >= 47) return sides; // 옆머리
  final d = (x - 31.5).abs();
  if (x == 27 || x == 36) return 26; // 가닥 사이
  return 28 + (d > 9 ? ((d - 9) / 2).round() : 0);
}

/// 묶은 머리의 앞머리: 옆머리는 귀 위에서 끝난다
int tiedBangs(int x, bool side) => bangs(x, side, sides: 34);

/// 짧은 머리 앞머리 (이마가 조금 보인다)
int shortBangs(int x, bool side) {
  if (side) return x <= 26 ? 38 : (x <= 33 ? 30 : 25);
  if (x <= 16 || x >= 47) return 32;
  return x == 26 || x == 37 ? 23 : 25;
}

/// 단발: 머리 + 턱선까지 내려오는 옆머리, 끝은 안으로 둥글게
bool bob(int x, int y) => shell(x, y) || sq(x, y, 32, 38, 19.5, 10.5, 3.2);

/// 어깨 아래로 내려오는 긴 머리 ([bottom]까지). [wave]면 바깥 선이 물결친다.
bool hang(int x, int y, bool side, int bottom, {bool wave = false}) {
  if (shell(x, y)) return true;
  if (y < 32 || y > bottom) return false;
  final w = wave ? (1.6 * math.sin(y / 2.2)).round() : 0;
  final l = 12 - w, r = (side ? 33 : 51) + w;
  if (x < l || x > r) return false;
  // 끝은 둥글게
  final tip = bottom - y;
  return tip >= 2 || (x > l + 1 - tip && x < r - 1 + tip);
}

/// 옆으로 늘어뜨린 머리 가닥 (정면 얼굴 양옆, 측면은 뒤쪽)
bool locks(int x, int y, bool side, int bottom) =>
    y <= bottom && (side ? x <= 29 : (x <= 17 || x >= 46));

final _curlCenters = [
  for (var i = 0; i <= 12; i++)
    (32 + 17 * math.cos(math.pi * (1.1 - 1.2 * i / 12)), 30 - 15 * math.sin(math.pi * (1.1 - 1.2 * i / 12))),
];
bool curl(int x, int y) =>
    sq(x, y, 32, 30, 17, 15, 2) || (shell(x, y) && y <= 44) || _curlCenters.any((c) => sq(x, y, c.$1, c.$2, 6, 6, 2));

/// 묶은 머리 꼬리. 정면: 포니테일은 오른쪽 위에서 어깨로, 양갈래는 귀 위에서 양쪽 아래로.
const ponyFront = [(47.0, 17.0), (54.0, 24.0), (56.0, 34.0), (55.0, 45.0), (52.0, 55.0)];
const ponySide = [(16.0, 18.0), (9.0, 25.0), (8.0, 36.0), (9.0, 47.0), (12.0, 56.0)];
const twinLeft = [(13.0, 33.0), (9.0, 41.0), (8.0, 50.0), (9.0, 58.0), (11.0, 64.0)];
const twinSide = [(17.0, 33.0), (12.0, 42.0), (11.0, 52.0), (12.0, 61.0)];
List<(double, double)> mirror(List<(double, double)> p) => [for (final (x, y) in p) (63 - x, y)];

class Hair {
  const Hair({this.back, required this.front, this.cut, this.ties = const [], this.strands});
  final Region? back; // 몸 뒤 (없으면 빈 시트)
  final Region front; // 얼굴 위
  final List<(int, int)> Function(bool side)? cut; // 머리를 밀어 낸 자리
  /// 머리끈 자리 (정면, 측면) — 앞 레이어에 그린다
  final List<(int, int, bool)> ties; // (x, y, 측면이면 true)
  /// 결 무늬를 넣을 자리 (물결·곱슬)
  final bool Function(int x, int y)? strands;
}

bool waveLine(int x, int y) => (x + (2 * math.sin(y / 2.2)).round()) % 4 == 0 && y >= 30;

final hairs = <Hair>[
  // 0 단발 (둥근 앞머리 + 턱선 단발)
  Hair(back: (x, y, _) => bob(x, y), front: (x, y, side) => bob(x, y) && y <= bangs(x, side)),
  // 1 짧은 머리
  Hair(front: (x, y, side) => sq(x, y, 32, 32, 18.5, 17, 2.4) && y <= shortBangs(x, side)),
  // 2 긴 생머리 (가슴까지, 앞으로 넘긴 옆머리)
  Hair(
    back: (x, y, side) => hang(x, y, side, 64),
    front: (x, y, side) => hang(x, y, side, 64) && (locks(x, y, side, 62) || y <= bangs(x, side, sides: 62)),
  ),
  // 3 스크래치 (짧게 친 머리 + 옆머리에 두 줄)
  Hair(
    front: (x, y, side) =>
        sq(x, y, 32, 32, 18, 16.5) &&
        y <= (side ? (x <= 27 ? 38 : (x <= 34 ? 30 : 24)) : (x <= 16 || x >= 47 ? 31 : 24 + ((x - 31.5).abs() / 8).round())),
    cut: (side) => side
        ? const [(22, 28), (23, 29), (24, 30), (25, 31), (21, 31), (22, 32), (23, 33)]
        : const [(41, 20), (42, 21), (43, 22), (44, 23), (44, 20), (45, 21), (46, 22)],
  ),
  // 4 포니테일 (높이 묶어 어깨까지 늘어진다)
  Hair(
    back: (x, y, side) => (shell(x, y) && y <= 44) || brush(x, y, side ? ponySide : ponyFront, 5.5, 2.5),
    front: (x, y, side) => shell(x, y) && y <= tiedBangs(x, side),
    ties: const [(46, 16, false), (17, 16, true)],
  ),
  // 5 양갈래 (귀 위에서 묶어 가슴까지)
  Hair(
    back: (x, y, side) =>
        (shell(x, y) && y <= 44) ||
        (side ? brush(x, y, twinSide, 4.5, 2.5) : brush(x, y, twinLeft, 4.5, 2.5) || brush(x, y, mirror(twinLeft), 4.5, 2.5)),
    front: (x, y, side) => shell(x, y) && y <= tiedBangs(x, side),
    ties: const [(12, 32, false), (50, 32, false), (16, 32, true)],
  ),
  // 6 똥머리 (정수리에 하나)
  Hair(
    back: (x, y, side) => (shell(x, y) && y <= 44) || sq(x, y, side ? 27 : 32, 10, 7.5, 6.5, 2),
    front: (x, y, side) => (shell(x, y) && y <= tiedBangs(x, side)) || sq(x, y, side ? 27 : 32, 10, 7.5, 6.5, 2),
    ties: const [(30, 16, false), (25, 16, true)],
  ),
  // 7 곱슬
  Hair(
    back: (x, y, _) => curl(x, y),
    front: (x, y, side) =>
        curl(x, y) &&
        y <= (side ? (x <= 28 ? 44 : (x <= 34 ? 36 : 26 + (x ~/ 3) % 2)) : (x <= 17 || x >= 46 ? 40 : 26 + (x ~/ 3) % 2)),
    strands: (x, y) => (x * 3 + y * 5) % 11 == 0,
  ),
  // 8 가르마 (가운데를 가른 어깨 길이)
  Hair(
    back: (x, y, side) => hang(x, y, side, 54),
    front: (x, y, side) =>
        hang(x, y, side, 54) &&
        y <= (side ? (x <= 29 ? 52 : (x <= 40 ? 63 - x : 22)) : (x <= 17 || x >= 46 ? 52 : 20 + ((x - 31.5).abs() * 0.8).round())),
  ),
  // 9 삐죽 (짧은 머리 + 위로 솟은 가닥)
  Hair(
    front: (x, y, side) =>
        (sq(x, y, 32, 32, 18.5, 17, 2.4) && y <= shortBangs(x, side)) ||
        (x >= 19 && x <= 45 && y <= 20 && y >= 15 - 2 * (3 - ((x - 19) % 6 - 3).abs())),
  ),
  // 10 단발 웨이브 (C컬, 끝이 바깥으로 뻗친다)
  Hair(
    back: (x, y, side) => hang(x, y, side, 50, wave: true) || (!side && y >= 46 && y <= 50 && (x == 10 || x == 53)),
    front: (x, y, side) => hang(x, y, side, 50, wave: true) && (locks(x, y, side, 50) || y <= bangs(x, side, sides: 50)),
    strands: waveLine,
  ),
  // 11 긴 웨이브 (긴 파마머리)
  Hair(
    back: (x, y, side) => hang(x, y, side, 66, wave: true),
    front: (x, y, side) => hang(x, y, side, 66, wave: true) && (locks(x, y, side, 64) || y <= bangs(x, side, sides: 64)),
    strands: waveLine,
  ),
  // 12 양쪽 똥머리
  Hair(
    back: (x, y, side) =>
        (shell(x, y) && y <= 44) || (side ? sq(x, y, 22, 13, 6.5, 6, 2) : sq(x, y, 15, 14, 6.5, 6, 2) || sq(x, y, 49, 14, 6.5, 6, 2)),
    front: (x, y, side) =>
        (shell(x, y) && y <= tiedBangs(x, side)) ||
        (side ? sq(x, y, 22, 13, 6.5, 6, 2) : sq(x, y, 15, 14, 6.5, 6, 2) || sq(x, y, 49, 14, 6.5, 6, 2)),
    ties: const [(19, 18, false), (42, 18, false), (25, 18, true)],
  ),
];

Draw hairBack(Hair h) => (c, side, u, _) {
  if (h.back == null) return;
  c.stamp(area((x, y) => h.back!(x, y - u, side), (x, y) => y - u >= 42 || x >= 48 ? hr[2] : hr[1]), hr[2]);
};

Draw hairFront(Hair h) => (c, side, u, _) {
  final part = area((x, y) => h.front(x, y - u, side), (x, y) {
    final yy = y - u;
    if (h.strands != null && h.strands!(x, yy)) return hr[2];
    return (side ? x <= 15 : x >= 48) ? hr[2] : hr[1];
  });
  c.stamp(part, hr[2]);
  // 윤기: 정수리 왼쪽에 둥근 띠
  c.put({
    for (final (x, y) in part.keys)
      if (y - u <= 24 &&
          x <= 33 &&
          sq(x, y - u, 32, 31, 14, 12, 2) &&
          !sq(x, y - u, 32, 31, 12.5, 10.5, 2))
        (x, y): hr[0],
  });
  for (final (x, y, s) in h.ties) {
    if (s != side) continue;
    c.stamp(rect(x, y + u, x + 2, y + 1 + u, (xx, _) => xx == x + 2 ? tieDark : tie), tieDark);
  }
  if (h.cut != null) c.cut([for (final (x, y) in h.cut!(side)) (x, y + u)]);
};

// ───────── 몸 ─────────

typedef Fill = int Function(int x, int y, int l, int r); // y는 흔들림을 뺀 값

const torsoTop = 50, torsoBottom = 66, legTop = 67, shoeTop = 84;

Fill shaded(Ramp k) =>
    (x, y, l, r) => y <= torsoTop + 1 || x >= r - 2 ? k[2] : (x == l + 1 && y >= 54 && y <= 63 ? k[0] : k[1]);
Fill limb(Ramp k) => (x, y, l, r) => x >= r - 1 ? k[2] : k[1];

class Body {
  const Body({required this.torso, required this.arm, this.sleeve, this.leg, this.shoe, this.extra});
  final Fill torso;
  final Fill? arm; // 팔 전체 (맨몸). null이면 팔을 그리지 않고 소매만
  final (Fill, int)? sleeve; // (색, 길이 px)
  final Fill? leg; // null 이면 다리를 그리지 않는다 (기본 상의: 하의는 따로)
  final Fill? shoe;
  final void Function(Cel c, bool side, int u)? extra;
}

const frontArms = [(20, 23), (40, 43)], sideArm = (30, 33);
const frontLegs = [(26, 30), (33, 37)], sideLeg = (28, 35);
const frontShoes = [(25, 30), (33, 38)], sideShoe = (28, 38);

void drawLegs(Cel c, bool side, Fill leg, Fill? shoe, {int bottom = 86}) {
  for (final (l, r) in side ? [sideLeg] : frontLegs) {
    c.stamp(rect(l, legTop, r, shoe == null ? bottom : math.min(bottom, shoeTop - 1), (x, y) => leg(x, y, l, r)));
  }
  if (shoe != null) {
    for (final (l, r) in side ? [sideShoe] : frontShoes) {
      c.stamp(rect(l, shoeTop, r, 86, (x, y) => shoe(x, y, l, r)));
    }
  }
}

void drawBody(Cel c, bool side, int u, Body b) {
  final (tl, tr) = side ? (26, 37) : (24, 39);
  final arms = side ? [sideArm] : frontArms;
  final armTop = torsoTop + 1 + u, armBottom = 60 + u;

  void drawArms() {
    for (final (l, r) in arms) {
      if (b.arm != null) c.stamp(rect(l, armTop, r, armBottom, (x, y) => b.arm!(x, y - u, l, r)));
      if (b.sleeve case (final fill, final len)) {
        c.stamp(rect(l, armTop, r, armTop + len - 1, (x, y) => fill(x, y - u, l, r)));
      }
    }
  }

  if (b.leg != null) drawLegs(c, side, b.leg!, b.shoe);
  if (!side) drawArms(); // 정면: 팔이 몸통 뒤
  final torso = rect(tl, torsoTop + u, tr, torsoBottom + u, (x, y) => b.torso(x, y - u, tl, tr));
  if (side && b.arm == null) {
    // 옷 시트에는 피부색을 넣지 않는다 → 소매 아래 팔·손 자리는 비워 몸 레이어가 비치게 한다
    final (l, r) = arms.single;
    torso.removeWhere((k, _) => k.$1 >= l - 1 && k.$1 <= r + 1 && k.$2 >= armTop && k.$2 <= armBottom + 1);
  }
  c.stamp(torso);
  if (side) drawArms(); // 측면: 팔이 몸통 앞
  b.extra?.call(c, side, u);
}

int shoeFill(int x, int y, int l, int r) => y == 86 ? 0xD6C2A8 : cream[0];

final nude = Body(
  torso: (x, y, l, r) => y >= 62 ? cream[2] : shaded(sk)(x, y, l, r),
  arm: limb(sk),
  leg: limb(sk),
);

Body tee(Ramp k) => Body(torso: shaded(k), arm: null, sleeve: (limb(k), 5), leg: limb(pants), shoe: shoeFill);

// ───────── 기본 상의 무늬 (Minimi.pattern 번호 순서) ─────────
// 테라코타 램프 + 무늬 색(motif)으로 그린다. 앱이 Minimi.outfit 색으로 바꾼다.

typedef Motif = int? Function(int x, int y, int l, int r); // null 이면 바탕색

final motifs = <Motif>[
  // 0 무지
  (x, y, l, r) => null,
  // 1 줄무늬
  (x, y, l, r) => y > torsoTop + 1 && (y - torsoTop) % 4 == 0 ? motif : null,
  // 2 땡땡이
  (x, y, l, r) => y > torsoTop + 2 && (y - torsoTop) % 4 == 1 && (x + ((y - torsoTop) ~/ 4) * 2) % 4 == 0 ? motif : null,
  // 3 체크
  (x, y, l, r) {
    final a = (x - l) % 4 < 2, b = (y - torsoTop) % 4 < 2;
    if (a && b) return terracotta[2];
    if (a || b) return null;
    return motif;
  },
  // 4 하트 (가슴에 하나)
  (x, y, l, r) {
    const heart = ['.m.m.', 'mmmmm', '.mmm.', '..m..'];
    final m = (l + r) ~/ 2 - 2, dy = y - 55, dx = x - m;
    if (dy < 0 || dy >= heart.length || dx < 0 || dx >= 5) return null;
    return heart[dy][dx] == 'm' ? motif : null;
  },
];

/// 줄무늬·체크는 소매까지 잇는다
Body patternTee(int i) => Body(
  torso: (x, y, l, r) => motifs[i](x, y, l, r) ?? shaded(terracotta)(x, y, l, r),
  arm: null,
  sleeve: ((x, y, l, r) => (i == 1 || i == 3 ? motifs[i](x, y, l, r) : null) ?? limb(terracotta)(x, y, l, r), 5),
);

// ───────── 하의 (Minimi.bottom 번호 순서). 기본 상의일 때만 입는다 (상점 옷은 위아래 한 벌) ─────────
// 천은 하늘색 램프(cloth)로 그리고 앱이 Minimi.bottomColor 색으로 바꾼다 (PixelPalette.bottomSheet). 신발·옆줄은 크림색이라 그대로.

typedef Bottom = void Function(Cel c, bool side, int u);

const Ramp cloth = denim;

void shoes(Cel c, bool side) {
  for (final (l, r) in side ? [sideShoe] : frontShoes) {
    c.stamp(rect(l, shoeTop, r, 86, (x, y) => shoeFill(x, y, l, r)));
  }
}

/// 허리([top], 기본 y 63)에서 [length]px 내려오는 치마. [flare]px 내려올 때마다 양옆으로 1px 퍼진다.
void skirt(
  Cel c,
  bool side,
  int length,
  int flare,
  int Function(int x, int y, int l, int r) color, {
  int top = 63,
  bool withShoes = true,
}) {
  final (l, r) = side ? (25, 38) : (23, 40);
  int f(int y) => (y - top) ~/ flare;
  c.stamp(
    area(
      (x, y) => y >= top && y <= top + length && x >= l - f(y) && x <= r + f(y),
      (x, y) => color(x, y, l - f(y), r + f(y)),
    ),
  );
  if (withShoes) shoes(c, side);
}

/// 치마 바탕: 오른쪽 끝은 그늘, 밑단 한 줄은 밝게
int Function(int x, int y, int l, int r) plainSkirt(int hem) =>
    (x, y, l, r) => x >= r - 1 ? cloth[2] : (y == hem ? cloth[0] : cloth[1]);

final bottoms = <Bottom>[
  // 0 긴 바지
  (c, side, u) => drawLegs(c, side, limb(cloth), shoeFill),
  // 1 와이드 바지 (통이 넓고 가운데 박음질)
  (c, side, u) {
    for (final (l, r) in side ? [(27, 36)] : [(24, 31), (32, 39)]) {
      c.stamp(
        rect(l, legTop, r, shoeTop - 1, (x, y) => x >= r - 1 ? cloth[2] : (x == l + 2 && y % 3 == 0 ? cloth[0] : cloth[1])),
      );
    }
    shoes(c, side);
  },
  // 2 반바지 (무릎 위)
  (c, side, u) {
    for (final (l, r) in side ? [sideLeg] : frontLegs) {
      c.stamp(rect(l - 1, legTop, r + 1, legTop + 6, (x, y) => x >= r ? cloth[2] : cloth[1]));
    }
    shoes(c, side);
  },
  // 3 플리츠 치마 (짧은 주름 치마)
  (c, side, u) => skirt(c, side, 9, 3, (x, y, l, r) => x % 3 == 0 ? cloth[2] : cloth[1]),
  // 4 체크 치마 (천 색 + 크림)
  (c, side, u) => skirt(c, side, 9, 3, (x, y, l, r) {
    final a = x % 4 < 2, b = y % 4 < 2;
    return a && b ? cloth[2] : (a || b ? cloth[1] : cream[0]);
  }),
  // 5 트레이닝 (크림 옆줄)
  (c, side, u) => drawLegs(c, side, (x, y, l, r) => x == l + 1 ? cream[0] : (x >= r - 1 ? cloth[2] : cloth[1]), shoeFill),
  // 6 롱 스커트 (발목까지, 세로 주름)
  (c, side, u) => skirt(c, side, 19, 5, (x, y, l, r) => (x - l) % 5 == 2 && y > 66 ? cloth[2] : plainSkirt(82)(x, y, l, r)),
  // 7 미디 스커트 (무릎 아래 A라인)
  (c, side, u) => skirt(c, side, 14, 3, (x, y, l, r) => x == l + 2 && y < 75 ? cloth[0] : plainSkirt(77)(x, y, l, r)),
];

/// 상점 옷. 상의(니트·셔츠·후드)는 다리를 그리지 않아 하의와 따로 입고, 멜빵·잠옷은 위아래 한 벌이다.
final outfits = <String, Body>{
  // 크림 니트: 세로 골지, 목 밴드, 긴 소매
  'knit': Body(
    torso: (x, y, l, r) =>
        y <= torsoTop + 1 || (y >= torsoBottom - 1) ? cream[2] : (x % 3 == 0 ? cream[2] : (x >= r - 2 ? cream[1] : cream[0])),
    arm: null,
    sleeve: ((x, y, l, r) => y >= 57 || x >= r - 1 ? cream[2] : cream[0], 10),
  ),
  // 줄무늬 셔츠: 2px 가로 줄
  'stripe': Body(
    torso: (x, y, l, r) => y % 4 < 2 ? denim[2] : (x >= r - 2 || y <= torsoTop + 1 ? cream[2] : cream[0]),
    arm: null,
    sleeve: ((x, y, l, r) => y % 4 < 2 ? denim[2] : cream[0], 5),
  ),
  // 멜빵 바지: 버터색 셔츠 + 데님
  'overall': Body(
    torso: (x, y, l, r) {
      final strap = y >= torsoTop + 2 && (x - l == 3 || x - l == 4 || r - x == 3 || r - x == 4);
      if (y == 57 && strap) return butter[2]; // 단추
      if (y >= 57 || strap) return x >= r - 2 ? denim[2] : denim[1];
      return shaded(butter)(x, y, l, r);
    },
    arm: null,
    sleeve: (limb(butter), 5),
    leg: limb(denim),
    shoe: shoeFill,
  ),
  // 후드티: 주머니, 끈, 목 뒤 후드
  'hoodie': Body(
    torso: (x, y, l, r) {
      final m = (l + r) ~/ 2;
      if (y >= 52 && y <= 55 && (x == m - 1 || x == m + 2)) return cream[0]; // 끈
      if ((y == 60 && x >= l + 3 && x <= r - 3) || (y > 60 && y <= 64 && (x == l + 3 || x == r - 3))) return sage[2];
      return shaded(sage)(x, y, l, r);
    },
    arm: null,
    sleeve: ((x, y, l, r) => y >= 57 || x >= r - 1 ? sage[2] : sage[1], 10),
    extra: (c, side, u) => c.stamp(
      area(
        (x, y) =>
            y - u >= 47 &&
            y - u <= 50 &&
            x >= (side ? 22 : 19) &&
            x <= (side ? 33 : 44) &&
            !inHead(x, y - u) &&
            !inHead(x - 1, y - u) &&
            !inHead(x + 1, y - u) &&
            !inHead(x, y - u - 1),
        (x, y) => y - u >= 50 ? sage[2] : sage[1],
      ),
    ),
  ),
  // 별무늬 잠옷: 위아래 한 벌
  'pajama': Body(
    torso: (x, y, l, r) {
      final m = (l + r) ~/ 2;
      if ((x == m || x == m + 1) && (y == 53 || y == 57 || y == 61)) return lavender[2]; // 단추
      if (const [(-5, 54), (4, 52), (-4, 60), (5, 59), (-5, 65), (3, 65)].contains((x - m, y))) return butter[1]; // 별
      return y <= torsoTop + 1 || x >= r - 2 ? lavender[1] : lavender[0];
    },
    arm: null,
    sleeve: ((x, y, l, r) => y >= 57 || x >= r - 1 ? lavender[1] : lavender[0], 10),
    leg: (x, y, l, r) => (x + y) % 7 == 0 && y % 3 == 0 ? butter[1] : (x >= r - 1 ? lavender[1] : lavender[0]),
    shoe: shoeFill,
  ),
};


// ───────── 미니미 상점 옷·액세서리 (2026-11-18 추가) ─────────
// 상의는 다리를 그리지 않고, 하의는 다리·신발만, 원피스·세트는 위아래를 함께 그린다.

const Ramp pinkR = [0xF4B8C8, 0xE893AC, 0xBF6A85];
const Ramp blueR = [0x8FB4E0, 0x6A93C9, 0x4A6FA3];
const Ramp redR = [0xD9694F, 0xB94A36, 0x8C3323];
const Ramp charcoal = [0x5A463C, 0x3B2E28, 0x251C18];
const Ramp grayR = [0xBDBDC6, 0x9A9AA6, 0x77778A];
const Ramp woodR = [0xD49E6E, 0xB98559, 0x8E6240];

(Fill, int) sleeveOf(Ramp k, int len) => ((x, y, l, r) => x >= r - 1 ? k[2] : k[1], len);

/// 목 아래 셔츠 칼라 (양쪽 삼각형)
bool flap(int x, int y, int l, int r) {
  final d = (x + .5 - (l + r + 1) / 2).abs(), k = y - torsoTop;
  return k >= 0 && k <= 3 && d >= k + .5 && d <= k + 3.5;
}

/// 가운데에서 [depth]줄 내려오는 V넥 안쪽
bool vNeck(int x, int y, int l, int r, int depth) {
  final d = (x + .5 - (l + r + 1) / 2).abs();
  return y < torsoTop + depth && d <= (torsoTop + depth - y) / 2;
}

int check(Ramp k, int x, int y, int light) {
  final a = x % 4 < 2, b = y % 4 < 2;
  return a && b ? k[2] : (a || b ? k[1] : light);
}

/// 작은 꽃무늬 자리
bool floret(int x, int y) => (x * 5 + y * 3) % 9 == 0;

Body top(Fill torso, (Fill, int) sleeve, {void Function(Cel c, bool side, int u)? extra}) =>
    Body(torso: torso, arm: null, sleeve: sleeve, extra: extra);

final shopTops = <String, Body>{
  'blouse': top((x, y, l, r) {
    if (flap(x, y, l, r)) return cream[0];
    if (x == (l + r + 1) ~/ 2 && y >= 55 && y % 3 == 0) return cream[2]; // 단추
    return shaded(cream)(x, y, l, r);
  }, ((x, y, l, r) => x >= r - 1 ? cream[2] : cream[0], 4)),
  'check_shirt': top(
    (x, y, l, r) => flap(x, y, l, r) ? redR[1] : check(redR, x, y, cream[0]),
    ((x, y, l, r) => check(redR, x, y, cream[0]), 10),
  ),
  'sweatshirt': top((x, y, l, r) {
    const heart = ['.r.r.', 'rrrrr', '.rrr.', '..r..'];
    final dx = x - ((l + r) ~/ 2 - 2), dy = y - 54;
    if (dy >= 0 && dy < 4 && dx >= 0 && dx < 5 && heart[dy][dx] == 'r') return terracotta[1];
    if (y >= torsoBottom - 1) return lavender[2];
    return y <= torsoTop + 1 || x >= r - 2 ? lavender[1] : lavender[0];
  }, ((x, y, l, r) => y >= 59 || x >= r - 1 ? lavender[1] : lavender[0], 10)),
  'cardigan': top((x, y, l, r) {
    final m = (l + r) ~/ 2;
    if (x == m || x == m + 1) return cream[0]; // 안에 입은 티
    if (x == m - 1 && y >= 53 && (y - 53) % 4 == 0) return woodR[2]; // 단추
    return shaded(butter)(x, y, l, r);
  }, ((x, y, l, r) => y >= 59 || x >= r - 1 ? butter[2] : butter[1], 10)),
  'denim_jacket': top((x, y, l, r) {
    if (flap(x, y, l, r)) return denim[0];
    if (y >= 54 && y <= 56 && ((x >= l + 2 && x <= l + 5) || (x >= r - 5 && x <= r - 2))) return y == 54 ? denim[2] : denim[1];
    if (x == (l + r + 1) ~/ 2) return denim[2];
    return x >= r - 2 ? denim[2] : denim[1];
  }, ((x, y, l, r) => y >= 59 ? denim[2] : (x >= r - 1 ? denim[2] : denim[1]), 10)),
  'sailor': top((x, y, l, r) {
    final m = (l + r) ~/ 2;
    if (y >= 53 && y <= 54 && x >= m - 1 && x <= m + 2) return terracotta[1]; // 리본
    if (y <= torsoTop + 3 && !vNeck(x, y, l, r, 5)) return denim[1];
    if (vNeck(x, y, l, r, 5)) return cream[0];
    return shaded(cream)(x, y, l, r);
  }, ((x, y, l, r) => y == torsoTop + 5 ? denim[1] : (x >= r - 1 ? cream[2] : cream[0]), 5)),
  'vest': top(
    (x, y, l, r) => vNeck(x, y, l, r, 8) ? cream[0] : (x >= r - 2 ? sage[2] : ((x + y) % 4 == 0 ? sage[2] : sage[1])),
    ((x, y, l, r) => x >= r - 1 ? cream[2] : cream[0], 5),
  ),
  'turtleneck': top(
    (x, y, l, r) => x % 3 == 0 || x >= r - 1 ? woodR[2] : woodR[1],
    ((x, y, l, r) => y >= 59 || x >= r - 1 ? woodR[2] : woodR[1], 10),
    // 목 부분은 턱 아래(몸통 맨 위)에만 둔다 — 더 올리면 턱을 덮어 수염처럼 보인다
    extra: (c, side, u) => c.stamp(rect(side ? 30 : 28, 50 + u, 35, 51 + u, (x, y) => x.isEven ? woodR[1] : woodR[0])),
  ),
  'varsity': top((x, y, l, r) {
    const h = ['c.c', 'ccc', 'c.c'];
    final dx = x - (l + 3), dy = y - 54;
    if (dy >= 0 && dy < 3 && dx >= 0 && dx < 3 && h[dy][dx] == 'c') return cream[0];
    if (y <= torsoTop || y >= torsoBottom - 1) return cream[0]; // 목·밑단 줄
    return x >= r - 2 ? blueR[2] : blueR[1];
  }, ((x, y, l, r) => y >= 59 ? blueR[1] : (x >= r - 1 ? cream[2] : cream[0]), 10)),
  'puffer': top(
    (x, y, l, r) => y <= torsoTop + 1 || (y - torsoTop) % 4 == 1 || x >= r - 1 ? butter[2] : (x == l + 1 ? butter[0] : butter[1]),
    ((x, y, l, r) => (y - torsoTop) % 4 == 1 || x >= r - 1 ? butter[2] : butter[1], 10),
  ),
  'floral_blouse': top((x, y, l, r) {
    if (flap(x, y, l, r)) return pinkR[0];
    if (floret(x, y)) return (x + y).isEven ? cream[0] : butter[1];
    return x >= r - 2 ? pinkR[2] : pinkR[1];
  }, ((x, y, l, r) => floret(x, y) ? cream[0] : (x >= r - 1 ? pinkR[2] : pinkR[1]), 5)),
};

/// 하의: 다리와 신발 (기본 하의처럼, 색은 고정)
final shopBottoms = <String, Bottom>{
  'jeans': (c, side, u) => drawLegs(
    c,
    side,
    (x, y, l, r) => y >= 81 ? blueR[0] : (x >= r - 1 ? blueR[2] : (x == l + 1 && y % 3 == 0 ? blueR[0] : blueR[1])),
    shoeFill,
  ),
  'cargo': (c, side, u) => drawLegs(
    c,
    side,
    (x, y, l, r) => y >= 72 && y <= 75 && x <= l + 1 ? sage[2] : (x >= r - 1 ? sage[2] : sage[1]),
    shoeFill,
  ),
  'check_pants': (c, side, u) => drawLegs(c, side, (x, y, l, r) => check(grayR, x, y, grayR[0]), shoeFill),
  'denim_shorts': (c, side, u) {
    for (final (l, r) in side ? [sideLeg] : frontLegs) {
      c.stamp(rect(l - 1, legTop, r + 1, legTop + 5, (x, y) => y == legTop + 5 && x.isEven ? cream[0] : (x >= r ? denim[2] : denim[1])));
    }
    shoes(c, side);
  },
  // 신발(크림 0번)과 색이 겹치지 않게 크림 1·2번만 쓴다 — 색을 바꿀 때 신발까지 바뀌지 않게
  'tennis_skirt': (c, side, u) => skirt(c, side, 8, 3, (x, y, l, r) => x % 3 == 0 ? cream[2] : cream[1]),
  'floral_long': (c, side, u) =>
      skirt(c, side, 19, 5, (x, y, l, r) => floret(x, y) ? pinkR[1] : (x >= r - 1 ? lavender[1] : lavender[0])),
  'leather_mini': (c, side, u) =>
      skirt(c, side, 7, 4, (x, y, l, r) => x == l + 2 ? charcoal[0] : (x >= r - 1 ? charcoal[2] : charcoal[1])),
};

/// 원피스·세트: 위아래를 함께 그린다
final shopSets = <String, Draw>{
  'dress_floral': (c, side, u, _) {
    drawBody(c, side, u, top((x, y, l, r) => floret(x, y) ? cream[0] : (x >= r - 2 ? pinkR[2] : pinkR[1]), sleeveOf(pinkR, 4)));
    skirt(c, side, 13, 3, (x, y, l, r) => floret(x, y) ? cream[0] : (x >= r - 1 ? pinkR[2] : pinkR[1]));
  },
  'dress_sailor': (c, side, u, _) {
    drawBody(
      c,
      side,
      u,
      top(
        (x, y, l, r) => y <= torsoTop + 3 && !vNeck(x, y, l, r, 5)
            ? cream[0]
            : (vNeck(x, y, l, r, 5) ? cream[0] : (x >= r - 2 ? denim[2] : denim[1])),
        sleeveOf(denim, 4),
      ),
    );
    skirt(c, side, 12, 3, (x, y, l, r) => x % 3 == 0 ? denim[2] : denim[1]);
  },
  // 노랑 저고리 + 다홍 치마
  'hanbok': (c, side, u, _) {
    drawBody(
      c,
      side,
      u,
      top((x, y, l, r) {
        final m = (l + r) ~/ 2;
        if (vNeck(x, y, l, r, 4)) return cream[0]; // 동정
        if (y >= 54 && y <= 56 && x >= m && x <= m + 1) return redR[1]; // 고름
        return x >= r - 2 ? butter[2] : butter[1];
      }, ((x, y, l, r) => y >= 58 ? redR[1] : (x >= r - 1 ? butter[2] : butter[1]), 9)),
    );
    // 고름 끈
    if (!side) c.put(rect(32, 57 + u, 32, 61 + u, (_, _) => redR[1]));
    skirt(c, side, 25, 5, (x, y, l, r) => x >= r - 1 ? redR[2] : ((x - l) % 5 == 2 ? redR[2] : redR[1]), top: 58);
  },
  'suit': (c, side, u, _) {
    drawBody(
      c,
      side,
      u,
      Body(
        torso: (x, y, l, r) {
          final d = (x + .5 - (l + r + 1) / 2).abs();
          if (d < 1 && y >= torsoTop + 1 && y <= 60) return redR[1]; // 넥타이
          if (vNeck(x, y, l, r, 9)) return cream[0];
          return x >= r - 2 ? charcoal[2] : charcoal[1];
        },
        arm: null,
        sleeve: sleeveOf(charcoal, 10),
        leg: limb(charcoal),
        shoe: (x, y, l, r) => y == 86 ? charcoal[2] : charcoal[1],
      ),
    );
  },
  // 노랑 우비: 무릎까지 오는 코트 + 장화
  'raincoat': (c, side, u, _) {
    for (final (l, r) in side ? [sideShoe] : frontShoes) {
      c.stamp(rect(l, 79, r, 86, (x, y) => x >= r - 1 ? butter[2] : butter[1]));
    }
    drawBody(c, side, u, top((x, y, l, r) => x == (l + r + 1) ~/ 2 && y % 4 == 1 ? woodR[2] : shaded(butter)(x, y, l, r), sleeveOf(butter, 10)));
    skirt(c, side, 12, 4, (x, y, l, r) => x == (l + r + 1) ~/ 2 && y % 4 == 1 ? woodR[2] : (x >= r - 1 ? butter[2] : butter[1]), withShoes: false);
  },
};

// 머리띠: 머리카락 테두리를 따라 두르는 띠
bool bandAt(int x, int y, bool side) =>
    sq(x, y, 32, 32.5, 20.5, 19, 2.4) && !sq(x, y, 32, 32.5, 18.5, 17, 2.4) && y <= (side ? 30 : 26) && (!side || (x >= 22 && x <= 44));

Draw band(int Function(int x, int y) color, [void Function(Cel c, bool side, int u)? more]) => (c, side, u, _) {
  c.stamp(area((x, y) => bandAt(x, y - u, side), (x, y) => color(x, y - u)));
  more?.call(c, side, u);
};

/// 모자 공통: 머리 위를 덮는 둥근 모자 + 챙. 앞머리 레이어는 가린다 (manifest hides).
Draw hat({
  required bool Function(int x, int y, bool side) crown,
  required int Function(int x, int y) crownColor,
  bool Function(int x, int y, bool side)? brim,
  int Function(int x, int y)? brimColor,
}) => (c, side, u, _) {
  if (brim != null) c.stamp(area((x, y) => brim(x, y - u, side), (x, y) => brimColor!(x, y - u)));
  c.stamp(area((x, y) => crown(x, y - u, side), (x, y) => crownColor(x, y - u)));
};

void flower(Cel c, int ox, int oy, int petal) =>
    c.stamp(pattern(ox, oy, const ['.p.', 'pcp', '.p.'], {'p': petal, 'c': butter[1]}), terracotta[2]);

final shopAccessories = <String, Draw>{
  // 머리핀 (미니미 왼쪽 머리, 정면에서만 보인다)
  'pin_heart': (c, side, u, _) =>
      side ? null : c.stamp(pattern(42, 22 + u, const ['.r.r.', 'rrrrr', '.rrr.', '..r..'], {'r': terracotta[1]}), redR[2]),
  'pin_flower': (c, side, u, _) => side ? null : flower(c, 43, 21 + u, pinkR[1]),
  'pin_pearl': (c, side, u, _) => side
      ? null
      : c.stamp(pattern(41, 21 + u, const ['ww..', 'ws..', '..ww', '..ws'], {'w': cream[0], 's': cream[2]}), 0xD6C2A8),
  // 머리띠
  'band_ribbon': band((x, y) => x >= 44 ? terracotta[2] : terracotta[1], (c, side, u) => bow(c, side ? 24 : 39, 10 + u)),
  'band_pearl': band((x, y) => x.isEven ? cream[0] : cream[2]),
  'band_cat': band((x, y) => charcoal[1], (c, side, u) {
    for (final ox in side ? const [27] : const [16, 40]) {
      c.stamp(pattern(ox, 9 + u, const ['a.....', 'aa....', 'apa...', 'appa..', 'appaa.', 'aaaaaa'], {'a': charcoal[1], 'p': pinkR[0]}));
    }
  }),
  'band_bunny': band((x, y) => cream[1], (c, side, u) {
    for (final cx in side ? const [27.0] : const [23.0, 41.0]) {
      c.stamp(area((x, y) => sq(x, y - u, cx, 8, 3.2, 7.5, 2), (x, y) => (x + .5 - cx).abs() < 1.2 && y - u >= 4 && y - u <= 12 ? pinkR[0] : cream[0]));
    }
  }),
  'band_flower': band((x, y) => sage[1], (c, side, u) {
    final spots = side ? const [(26, 16), (31, 14), (36, 15), (40, 19)] : const [(14, 22), (19, 15), (26, 11), (32, 10), (38, 11), (44, 15), (48, 22)];
    for (var i = 0; i < spots.length; i++) {
      final (x, y) = spots[i];
      flower(c, x - 1, y - 1 + u, const [0xE893AC, 0xFFF8EE, 0xC9A3C9][i % 3]);
    }
  }),
  // 모자
  'cap': hat(
    crown: (x, y, side) => y <= 27 && sq(x, y, 32, 30, 19.5, 15.5, 2.2),
    crownColor: (x, y) => y == 27 ? blueR[2] : (x >= 44 ? blueR[2] : blueR[1]),
    brim: (x, y, side) => y >= 26 && y <= 28 && (side ? x >= 40 && x <= 55 : x >= 15 && x <= 48),
    brimColor: (x, y) => blueR[2],
  ),
  'beret': hat(
    crown: (x, y, side) => (y <= 27 && sq(x, y, side ? 31 : 30, 21, 21, 8, 2.2)) || (x == 30 && y >= 11 && y <= 13),
    crownColor: (x, y) => y >= 26 ? redR[2] : (x >= 44 ? redR[2] : redR[1]),
  ),
  'straw': hat(
    crown: (x, y, side) => y <= 25 && sq(x, y, 32, 21, 16, 9, 2.4),
    crownColor: (x, y) => y >= 23 ? terracotta[1] : (x % 3 == 0 ? butter[2] : butter[1]),
    brim: (x, y, side) => sq(x, y, 32, 26.5, 29, 3.2, 2),
    brimColor: (x, y) => (x + y) % 3 == 0 ? butter[2] : butter[1],
  ),
  'bucket': hat(
    crown: (x, y, side) => y <= 26 && sq(x, y, 32, 23, 17.5, 10, 2.4),
    crownColor: (x, y) => x >= 44 ? sage[2] : sage[1],
    brim: (x, y, side) => y >= 25 && y <= 29 && x >= 13 - (y - 25) && x <= 50 + (y - 25),
    brimColor: (x, y) => y >= 28 ? sage[2] : sage[1],
  ),
  // 안경
  'glasses_gold': spectacles(
    const ['.aaaaaa.', 'a......a', 'a......a', 'a......a', 'a......a', 'a......a', '.aaaaaa.'],
    const {'a': _gold},
    _goldDark,
  ),
  'glasses_pink': spectacles(
    const ['aaaaaaaa', 'aaaaaaaa', 'a......a', 'a......a', 'a......a', 'a......a', 'aaaaaaaa'],
    const {'a': 0xE893AC},
    0xE893AC,
  ),
  // 선글라스
  'sunglasses_round': spectacles(
    const ['.aaaaaa.', 'aaaaaaaa', 'asaaaaaa', 'aaaaaaaa', 'aaaaaaaa', '.aaaaaa.'],
    const {'a': 0x3B2E28, 's': 0xD6C2A8},
    _gold,
  ),
  'sunglasses_star': spectacles(
    const ['...a....', '..aaa...', 'aaawaaa.', '.aaaaa..', '.aa.aa..', 'a.....a.'],
    const {'a': 0xF2D27A, 'w': 0xFFF8EE},
    _goldDark,
    outline: _goldDark,
  ),
  // 귀고리
  'ear_cherry': earring(const ['.d.', 'd.d', 'r.r'], const {'r': 0xB94A36, 'd': 0x6F8F6B}),
  'ear_ribbon': earring(const ['p.p', '.p.', 'p.p'], const {'p': 0xE893AC}),
};

// ───────── 액세서리 ─────────

Part pattern(int ox, int oy, List<String> rows, Map<String, int> colors) => {
  for (var y = 0; y < rows.length; y++)
    for (var x = 0; x < rows[y].length; x++) (ox + x, oy + y): ?colors[rows[y][x]],
};

void star(Cel c, int ox, int oy) => c.stamp(
  pattern(ox, oy, const ['..a..', '.aba.', 'aabaa', '.aaa.', '.a.a.'], {'a': butter[1], 'b': butter[0]}),
  0xB98A2A,
);

void bow(Cel c, int ox, int oy) => c.stamp(
  pattern(
    ox,
    oy,
    const ['aa.....bb', 'aaa.c.bbb', 'aaaacbbbb', 'abb.c.bcc', 'bb.....cc'],
    {'a': terracotta[0], 'b': terracotta[1], 'c': terracotta[2]},
  ),
);

/// 안경알 왼쪽 위 x (정면 두 개, 측면 하나), 위 y
const lensXs = [21, 35], lensSideX = 39, lensY = 32;

final accessories = <String, Draw>{
  // 머리핀은 미니미의 왼쪽 머리에 꽂는다 → 오른쪽을 볼 때는 보이지 않는다 (왼쪽 시트에만 그림)
  'starpin': (c, side, u, _) => side ? null : star(c, 42, 22 + u),
  'ribbon': (c, side, u, _) => bow(c, side ? 22 : 38, 11 + u),
  'beanie': (c, side, u, _) {
    c.stamp(
      area(
        (x, y) => y - u <= 27 && (shell(x, y - u) || sq(x, y - u, 32, 30, 19.5, 17)),
        (x, y) => y - u >= 23
            ? (x % 3 == 1 ? cream[2] : cream[1]) // 접은 단
            : (x >= 46 ? terracotta[2] : (x % 4 == 0 ? terracotta[2] : terracotta[1])),
      ),
    );
    c.stamp(area((x, y) => sq(x, y - u, 32, 10, 3.5, 3.5, 2), (x, y) => x >= 33 && y - u >= 10 ? cream[2] : cream[0]));
  },
  'glasses': (c, side, u, _) {
    Part ring(int ox) => pattern(
      ox,
      lensY + u,
      const ['.aaaaaa.', 'a......a', 'a......a', 'a......a', 'a......a', 'a......a', 'a......a', '.aaaaaa.'],
      {'a': inkSoft},
    );
    if (side) {
      c.put(ring(lensSideX));
      c.put(rect(30, 35 + u, lensSideX - 1, 35 + u, (_, _) => inkSoft)); // 다리
    } else {
      c.put(ring(lensXs[0]));
      c.put(ring(lensXs[1]));
      c.put(rect(29, 35 + u, 34, 35 + u, (_, _) => inkSoft));
    }
  },
  'headphone': (c, side, u, _) {
    if (side) {
      c.put(rect(29, 13 + u, 30, 31 + u, (_, _) => inkSoft));
      c.stamp(area((x, y) => sq(x, y - u, 30, 36, 4.5, 5.5, 2), (x, y) => x >= 32 ? denim[2] : denim[1]));
    } else {
      c.put(
        area(
          (x, y) => y - u <= 30 && sq(x, y - u, 32, 32.5, 21, 19.5, 2.6) && !sq(x, y - u, 32, 32.5, 19, 17.5, 2.6),
          (_, _) => inkSoft,
        ),
      );
      for (final l in const [10, 50]) {
        c.stamp(rect(l, 30 + u, l + 3, 40 + u, (x, y) => x == l + 3 ? denim[2] : denim[1]));
      }
    }
  },
};

/// 안경: 렌즈 그림 하나를 양쪽 눈에 찍고 코걸이·다리를 잇는다.
Draw spectacles(List<String> rows, Map<String, int> colors, int frame, {int? outline}) => (c, side, u, _) {
  void lens(int ox) {
    final p = pattern(ox, lensY + u, rows, colors);
    outline == null ? c.put(p) : c.stamp(p, outline);
  }

  if (side) {
    c.put(rect(30, 35 + u, lensSideX - 1, 35 + u, (_, _) => frame)); // 다리
    lens(lensSideX);
  } else {
    c.put(rect(29, 35 + u, 34, 35 + u, (_, _) => frame));
    lens(lensXs[0]);
    lens(lensXs[1]);
  }
};

/// 귀고리: 귓불 아래에 단다 (정면은 양쪽, 측면은 보이는 귀 하나).
Draw earring(List<String> rows, Map<String, int> colors, {int? outline}) => (c, side, u, _) {
  for (final ox in side ? const [30] : const [12, 49]) {
    final p = pattern(ox, 40 + u, rows, colors);
    outline == null ? c.put(p) : c.stamp(p, outline);
  }
};

const _gold = 0xE5B547, _goldDark = 0xB98A2A;

final moreAccessories = <String, Draw>{
  // 뿔테: 두껍고 네모난 테
  'glasses_horn': spectacles(
    const ['aaaaaaaa', 'aaaaaaaa', 'a......a', 'a......a', 'a......a', 'a......a', 'aaaaaaaa'],
    const {'a': ink},
    ink,
  ),
  // 무테: 렌즈 아래 선만, 금색 코걸이
  'glasses_rimless': spectacles(
    const ['........', 'b......b', 'b.w....b', 'b......b', 'b......b', 'b......b', '.bbbbbb.'],
    const {'b': 0x9DBBD8, 'w': 0xFFF8EE},
    _gold,
  ),
  'sunglasses': spectacles(
    const ['aaaaaaaa', 'aasaaaaa', 'asaaaaaa', 'aaaaaaaa', 'aaaaaaaa', '.aaaaaa.'],
    const {'a': ink, 's': 0xD6C2A8},
    ink,
  ),
  'sunglasses_heart': spectacles(
    const ['.aa.aa.', 'awaaaaa', 'aaaaaaa', '.aaaaa.', '..aaa..', '...a...'],
    const {'a': 0xE08A5B, 'w': 0xF8DCCB},
    0xB9663D,
    outline: 0xB9663D,
  ),
  'ear_pearl': earring(const ['.ww', '.ws'], const {'w': 0xFFF8EE, 's': 0xEADBC7}, outline: 0xD6C2A8),
  'ear_hoop': earring(const ['.g.', 'g.d', 'g.d', '.d.'], const {'g': _gold, 'd': _goldDark}),
  'ear_star': earring(const ['.d.', '.g.', 'ggg', 'g.g'], const {'g': 0xF2D27A, 'd': _goldDark}),
  'ear_heart': earring(const ['.d.', 'r.r', 'rrr', '.r.'], const {'r': 0xE08A5B, 'd': _goldDark}),
  'ear_drop': earring(const ['.d.', '.d.', '.b.', 'bbs', '.s.'], const {'b': 0x9DBBD8, 's': 0x6F8FB8, 'd': _goldDark}),
};

/// 측면 왼쪽용 시트를 따로 그리는 액세서리 (manifest에서 mirror: false). 값 = 왼쪽을 볼 때의 그림(오른쪽 기준 좌표, 뒤집어 쓴다).
final leftSheets = <String, Draw>{
  'starpin': (c, side, u, _) => star(c, side ? 34 : 42, 22 + u),
  'ribbon': accessories['ribbon']!,
};

// ───────── 시트 ─────────

Cel cel(Draw d, bool side, int frame) {
  final c = Cel();
  d(c, side, idleBob[frame], frame == 3);
  return c;
}

img.Image sheetOf(Draw d, {bool flipSide = false}) {
  final out = img.Image(width: fw * frames, height: fh * 2, numChannels: 4);
  for (var row = 0; row < 2; row++) {
    for (var f = 0; f < frames; f++) {
      var c = cel(d, row == 1, f);
      if (row == 1 && flipSide) c = c.flipped();
      for (var i = 0; i < c.px.length; i++) {
        final v = c.px[i];
        if (v == null) continue;
        if (!PixelPalette.all.contains(v)) throw StateError('팔레트 밖 색 #${v.toRadixString(16)}');
        out.setPixelRgba(f * fw + i % fw, row * fh + i ~/ fw, v >> 16, (v >> 8) & 0xFF, v & 0xFF, 255);
      }
    }
  }
  return out;
}

/// 기본 상의 시트 경로 (무늬 0번은 번호 없음)
String outfitPath(int p) => p == 0 ? 'outfits/outfit_default_idle.png' : 'outfits/outfit_default_${p}_idle.png';

void main(List<String> args) {
  final sheets = <String, img.Image>{
    'base/base_idle.png': sheetOf((c, side, u, blink) {
      drawBody(c, side, u, nude);
      drawHead(c, side, u, blink);
    }),
    for (var i = 0; i < hairs.length; i++) ...{
      'hair/hair_${i}_back_idle.png': sheetOf(hairBack(hairs[i])),
      'hair/hair_${i}_front_idle.png': sheetOf(hairFront(hairs[i])),
    },
    for (var i = 0; i < eyeShapes.length; i++) 'face/eyes_${i}_idle.png': sheetOf(eyesDraw(i)),
    for (var i = 0; i < mouthShapes.length; i++) 'face/mouth_${i}_idle.png': sheetOf(mouthDraw(i)),
    for (var i = 0; i < motifs.length; i++)
      outfitPath(i): sheetOf((c, side, u, _) => drawBody(c, side, u, patternTee(i))),
    for (var i = 0; i < bottoms.length; i++) 'bottoms/bottom_${i}_idle.png': sheetOf((c, side, u, _) => bottoms[i](c, side, u)),
    for (final e in outfits.entries)
      'outfits/outfit_${e.key}_idle.png': sheetOf((c, side, u, _) => drawBody(c, side, u, e.value)),
    for (final e in shopTops.entries)
      'outfits/outfit_${e.key}_idle.png': sheetOf((c, side, u, _) => drawBody(c, side, u, e.value)),
    for (final e in shopBottoms.entries) 'outfits/outfit_${e.key}_idle.png': sheetOf((c, side, u, _) => e.value(c, side, u)),
    for (final e in shopSets.entries) 'outfits/outfit_${e.key}_idle.png': sheetOf(e.value),
    for (final e in shopAccessories.entries) 'accessories/acc_${e.key}_idle.png': sheetOf(e.value),
    for (final e in {...accessories, ...moreAccessories}.entries) 'accessories/acc_${e.key}_idle.png': sheetOf(e.value),
    for (final e in leftSheets.entries) 'accessories/acc_${e.key}_idle_left.png': sheetOf(e.value, flipSide: true),
  };
  for (final e in sheets.entries) {
    File('$root/${e.key}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(e.value));
  }
  stdout.writeln('wrote ${sheets.length} sheets → $root');
  if (args.isNotEmpty) preview(sheets, args.first);
}

/// 확인용: 조합별로 겹쳐 4배로 키운 그림.
void preview(Map<String, img.Image> sheets, String path) {
  img.Image s(String k) => sheets[k]!;
  img.Image swap(img.Image src, Map<int, int> table) {
    final o = src.clone();
    for (final p in o) {
      final to = table[(p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt()];
      if (to != null && p.a > 0) p.setRgb(to >> 16, (to >> 8) & 255, to & 255);
    }
    return o;
  }

  // (머리 모양, 눈, 입, 피부, 머리색, 옷, 액세서리, 기본 옷 색, 무늬, 하의)
  final looks = <(int, int, int, int, int, String, String?, int, int, int)>[
    for (var h = 0; h < hairs.length; h++) (h, h % 6, h % 6, h % 4, h % 8, 'default', null, h % 12, h % 5, h % 8),
    (0, 0, 0, 0, 0, 'default', null, 0, 0, 0),
    (4, 1, 1, 1, 2, 'default', null, 6, 1, 3),
    (11, 3, 0, 0, 1, 'default', null, 5, 2, 4),
    (5, 0, 1, 4, 4, 'default', null, 9, 3, 2),
    (12, 3, 5, 0, 2, 'default', null, 1, 4, 1),
    (1, 0, 0, 2, 0, 'knit', 'glasses', 0, 0, 0),
    (2, 0, 0, 0, 1, 'stripe', 'ribbon', 0, 0, 0),
    (0, 0, 0, 1, 0, 'overall', 'beanie', 0, 0, 0),
    (8, 0, 0, 2, 0, 'pajama', 'headphone', 0, 0, 0),
    (10, 0, 0, 0, 1, 'hoodie', 'starpin', 0, 0, 0),
    (6, 0, 1, 0, 4, 'default', 'sunglasses_heart', 3, 0, 1),
    (3, 0, 0, 0, 0, 'default', 'ear_hoop', 7, 1, 5),
  ];
  const cols = 13;
  final rowsN = (looks.length / cols).ceil();
  final out = img.Image(width: fw * cols, height: fh * 2 * rowsN, numChannels: 4);
  img.fill(out, color: img.ColorRgba8(0xF6, 0xEB, 0xDD, 255));
  for (var i = 0; i < looks.length; i++) {
    final (hs, ey, mo, skin, hair, o, a, oc, pt, bt) = looks[i];
    final table = PixelPalette.swapFor(skinIndex: skin, hairIndex: hair);
    final layers = [
      swap(s('hair/hair_${hs}_back_idle.png'), table),
      swap(s('base/base_idle.png'), table),
      s('face/eyes_${ey}_idle.png'),
      s('face/mouth_${mo}_idle.png'),
      if (o == 'default') swap(s('bottoms/bottom_${bt}_idle.png'), PixelPalette.bottomSwap(i % 12)),
      o == 'default' ? swap(s(outfitPath(pt)), PixelPalette.outfitSwap(oc)) : s('outfits/outfit_${o}_idle.png'),
      if (a != 'beanie') swap(s('hair/hair_${hs}_front_idle.png'), table),
      if (a != null) s('accessories/acc_${a}_idle.png'),
    ];
    // 줄: 정면 0번, 측면 0번
    for (final (row, srcRow, frame) in const [(0, 0, 0), (1, 1, 0)]) {
      for (final l in layers) {
        img.compositeImage(
          out,
          l,
          dstX: (i % cols) * fw,
          dstY: (i ~/ cols * 2 + row) * fh,
          srcX: frame * fw,
          srcY: srcRow * fh,
          srcW: fw,
          srcH: fh,
          dstW: fw,
          dstH: fh,
        );
      }
    }
  }
  final big = img.copyResize(out, width: out.width * 4, height: out.height * 4, interpolation: img.Interpolation.nearest);
  File(path).writeAsBytesSync(img.encodePng(big));
  stdout.writeln('preview → $path');
}
