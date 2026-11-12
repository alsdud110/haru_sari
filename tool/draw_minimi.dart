// 미니미 레이어 시트를 코드로 그린다 (docs/asset-system/01 §8).
// 프레임 64×96, 발 앵커 (32,88), 가로 4프레임(idle) × 세로 2줄(정면, 측면 오른쪽) → 256×192.
// 피부·머리는 0번 램프로, 기본 옷은 테라코타 램프로 그린다 (앱이 불러올 때 색을 바꾼다).
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
const blush = 0xEDA77F, mouth = 0xB9663D;

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

Part dots(Iterable<(int, int)> at, int color, [int dy = 0]) => {for (final (x, y) in at) (x, y + dy): color};

/// 둥근 네모(초타원) 안인지.
bool sq(int x, int y, double cx, double cy, double rx, double ry, [double n = 2.6]) =>
    math.pow((x + .5 - cx).abs() / rx, n) + math.pow((y + .5 - cy).abs() / ry, n) <= 1;

// ───────── 머리 ─────────

bool inHead(int x, int y) => sq(x, y, 32, 30.5, 16, 14.5); // x 16~47, y 16~44
bool inHair(int x, int y) =>
    sq(x, y, 32, 29.5, 18, 16.5) || (y >= 30 && y <= 43 && x >= 14 && x <= 49) || (y == 44 && x >= 15 && x <= 48);

/// 앞머리 아래 끝 (이 줄까지 머리카락).
int fringe(int x, bool side) {
  if (side) return x <= 29 ? 44 : (x <= 33 ? 37 : 24);
  if (x <= 17 || x >= 46) return 37; // 옆머리
  if (x == 27 || x == 28 || x == 37) return 21; // 가닥 사이
  return 24;
}

void drawHead(Cel c, bool side, int u, bool blink) {
  if (!side) {
    // 귀: 머리보다 먼저 그려 머리 외곽선 뒤로 들어간다
    for (final l in const [13, 49]) {
      c.stamp(
        rect(
          l,
          31 + u,
          l + 1,
          36 + u,
          (x, y) => (y - u == 33 || y - u == 34) && x == (l == 13 ? 14 : 49) ? sk[2] : sk[1],
        ),
      );
    }
  }
  final head = area((x, y) => inHead(x, y - u), (x, y) => y - u == 26 || !inHead(x + 2, y - u + 1) ? sk[2] : sk[1]);
  if (side) head[(48, 34 + u)] = sk[1]; // 코
  c.stamp(head);
  if (side) {
    c.put(pattern(29, 31 + u, const ['.aa.', 'a..a', 'a...', 'a..a', '.aa.'], {'a': sk[2]})); // 귀
    c.put(rect(37, 37 + u, 39, 37 + u, (_, _) => blush));
  } else {
    c.put(rect(20, 37 + u, 22, 37 + u, (_, _) => blush));
    c.put(rect(41, 37 + u, 43, 37 + u, (_, _) => blush));
    c.put(rect(31, 36 + u, 32, 36 + u, (_, _) => sk[2])); // 코
  }
}

// ───────── 눈·입 (Minimi.eyes / Minimi.mouth 번호 순서) ─────────

/// 눈 하나: 4×4, 왼쪽 위 = (눈 x - 1, 31)
const eyeShapes = [
  ['....', '.aa.', '.aa.', '.aa.'], // 기본
  ['aaa.', 'waa.', 'aaa.', 'aaa.'], // 반짝
  ['....', '....', 'a..a', '.aa.'], // 감은 눈
  ['....', '.aa.', 'a..a', '....'], // 웃는 눈
  null, // 윙크: 한쪽은 기본, 한쪽은 웃는 눈
  ['....', 'aaaa', '.aa.', '.aa.'], // 졸린 눈
];
const eyeBlink = ['....', '....', '....', 'aaaa'];

Draw eyesDraw(int k) => (c, side, u, blink) {
  final xs = side ? const [41] : const [24, 38];
  for (var i = 0; i < xs.length; i++) {
    final kind = k == 4 ? (i == 1 ? 3 : 0) : k;
    final open = kind != 2 && kind != 3;
    c.put(pattern(xs[i] - 1, 31 + u, blink && open ? eyeBlink : eyeShapes[kind]!, const {'a': ink, 'w': 0xFFF8EE}));
  }
};

const mouthShapes = [
  ['a..a', '.aa.'], // 미소
  ['aaaa', 'abba', '.aa.'], // 활짝
  ['.aa.', 'a..a'], // 시무룩
  ['.aa.', 'a..a', '.aa.'], // 놀람
  ['aaaa'], // 무표정
  ['a.a.a', '.a.a.'], // 고양이
];

Draw mouthDraw(int k) =>
    (c, side, u, _) => c.put(pattern(side ? 41 : 30, 39 + u, mouthShapes[k], const {'a': mouth, 'b': blush}));

// ───────── 머리 모양 (Minimi.hairStyle 번호 순서) ─────────

typedef Region = bool Function(int x, int y, bool side);

/// 머리를 감싸는 기본 머리카락 덩어리 (x 14~49, y 13~45)
bool shell(int x, int y) => sq(x, y, 32, 29.5, 18, 16.5);

/// 짧은 앞머리 (귀 위에서 끝난다)
int shortFringe(int x, bool side) {
  if (side) return x <= 26 ? 38 : (x <= 33 ? 29 : 23);
  if (x <= 16 || x >= 47) return 30;
  return x == 25 || x == 26 || x == 36 ? 21 : 23;
}

/// 묶은 머리의 앞머리 (옆머리가 귀 앞까지)
int tiedFringe(int x, bool side) {
  if (side) return x <= 26 ? 38 : (x <= 33 ? 32 : 24);
  if (x <= 16 || x >= 47) return 32;
  return fringe(x, false);
}

/// 어깨 아래로 내려오는 머리 ([bottom]까지)
bool hang(int x, int y, bool side, int bottom) =>
    inHair(x, y) || (y >= 30 && y <= bottom && x >= 13 && x <= (side ? 31 : 50));

final _curlCenters = [
  for (var i = 0; i <= 10; i++)
    (32 + 15 * math.cos(math.pi * (1.15 - 1.3 * i / 10)), 27 - 13 * math.sin(math.pi * (1.15 - 1.3 * i / 10))),
];
bool curl(int x, int y) =>
    sq(x, y, 32, 27, 15, 13, 2) ||
    (shell(x, y) && y <= 42) ||
    _curlCenters.any((c) => sq(x, y, c.$1, c.$2, 6.5, 6.5, 2));

class Hair {
  const Hair({this.back, required this.front, this.cut});
  final Region? back; // 몸 뒤 (없으면 빈 시트)
  final Region front; // 얼굴 위
  final List<(int, int)> Function(bool side)? cut; // 머리를 밀어 낸 자리
}

final hairs = <Hair>[
  // 0 단발
  Hair(back: (x, y, _) => inHair(x, y), front: (x, y, side) => inHair(x, y) && y <= fringe(x, side)),
  // 1 짧은 머리
  Hair(front: (x, y, side) => shell(x, y) && y <= shortFringe(x, side)),
  // 2 긴 머리
  Hair(
    back: (x, y, side) => hang(x, y, side, 60),
    front: (x, y, side) =>
        hang(x, y, side, 60) &&
        y <= (side ? (x <= 29 ? 60 : fringe(x, true)) : (x <= 17 || x >= 46 ? 54 : fringe(x, false))),
  ),
  // 3 스크래치 (반삭 + 옆머리에 두 줄)
  Hair(
    front: (x, y, side) =>
        sq(x, y, 32, 30, 17, 15.5) &&
        y <=
            (side
                ? (x <= 27 ? 36 : (x <= 34 ? 28 : 22))
                : (x <= 16 || x >= 47 ? 29 : 22 + ((x - 31.5).abs() / 8).round())),
    cut: (side) => side
        ? const [(22, 26), (23, 27), (24, 28), (25, 29), (21, 29), (22, 30), (23, 31)]
        : const [(40, 18), (41, 19), (42, 20), (43, 21), (43, 18), (44, 19), (45, 20)],
  ),
  // 4 포니테일
  Hair(
    back: (x, y, side) => (shell(x, y) && y <= 40) || (side ? sq(x, y, 11, 30, 5, 14) : sq(x, y, 52, 26, 4, 13)),
    front: (x, y, side) => shell(x, y) && y <= tiedFringe(x, side),
  ),
  // 5 양갈래
  Hair(
    back: (x, y, side) =>
        (shell(x, y) && y <= 40) ||
        (side ? sq(x, y, 14, 40, 5, 13) : sq(x, y, 10, 38, 4.5, 13) || sq(x, y, 54, 38, 4.5, 13)),
    front: (x, y, side) => shell(x, y) && y <= tiedFringe(x, side),
  ),
  // 6 똥머리
  Hair(
    back: (x, y, side) => (shell(x, y) && y <= 40) || sq(x, y, side ? 29 : 32, 9, 6, 5.5, 2),
    front: (x, y, side) => shell(x, y) && y <= tiedFringe(x, side),
  ),
  // 7 곱슬
  Hair(
    back: (x, y, _) => curl(x, y),
    front: (x, y, side) =>
        curl(x, y) &&
        y <=
            (side
                ? (x <= 28 ? 42 : (x <= 34 ? 34 : 23 + (x ~/ 3) % 2))
                : (x <= 17 || x >= 46 ? 38 : 23 + (x ~/ 3) % 2)),
  ),
  // 8 가르마 (가운데를 가른 중단발)
  Hair(
    back: (x, y, side) => hang(x, y, side, 52),
    front: (x, y, side) =>
        hang(x, y, side, 52) &&
        y <=
            (side
                ? (x <= 29 ? 50 : (x <= 40 ? 60 - x : 20))
                : (x <= 18 || x >= 45 ? 50 : 19 + ((x - 31.5).abs() * 0.7).round())),
  ),
  // 9 삐죽 (짧은 머리 + 위로 솟은 가닥)
  Hair(
    front: (x, y, side) =>
        (shell(x, y) && y <= shortFringe(x, side)) ||
        (x >= 19 && x <= 45 && y <= 18 && y >= 13 - 2 * (3 - ((x - 19) % 6 - 3).abs())),
  ),
];

Draw hairBack(Hair h) => (c, side, u, _) {
  if (h.back == null) return;
  c.stamp(area((x, y) => h.back!(x, y - u, side), (x, y) => y - u >= 39 || x >= 47 ? hr[2] : hr[1]), hr[2]);
};

Draw hairFront(Hair h) => (c, side, u, _) {
  final part = area((x, y) => h.front(x, y - u, side), (x, y) => (side ? x <= 16 : x >= 47) ? hr[2] : hr[1]);
  c.stamp(part, hr[2]);
  // 윤기
  c.put({
    for (final (x, y) in const [
      (21, 17),
      (22, 17),
      (23, 17),
      (24, 17),
      (25, 17),
      (26, 17),
      (27, 17),
      (28, 17),
      (19, 18),
      (20, 18),
      (21, 18),
      (19, 19),
      (20, 19),
      (21, 19),
    ])
      if (part.containsKey((x, y + u))) (x, y + u): hr[0],
  });
  if (h.cut != null) c.cut([for (final (x, y) in h.cut!(side)) (x, y + u)]);
};

// ───────── 몸 ─────────

typedef Fill = int Function(int x, int y, int l, int r); // y는 흔들림을 뺀 값

Fill shaded(Ramp k) =>
    (x, y, l, r) => y <= 46 || x >= r - 2 ? k[2] : (x == l + 1 && y >= 49 && y <= 60 ? k[0] : k[1]);
Fill limb(Ramp k) =>
    (x, y, l, r) => x >= r - 1 ? k[2] : k[1];

class Body {
  const Body({required this.torso, required this.arm, this.sleeve, required this.leg, this.shoe, this.extra});
  final Fill torso;
  final Fill? arm; // 팔 전체 (맨몸). null이면 팔을 그리지 않고 소매만
  final (Fill, int)? sleeve; // (색, 길이 px)
  final Fill leg;
  final Fill? shoe;
  final void Function(Cel c, bool side, int u)? extra;
}

void drawBody(Cel c, bool side, int u, Body b) {
  final (tl, tr) = side ? (26, 37) : (23, 40);
  final arms = side ? [(30, 34)] : [(18, 22), (41, 45)];
  final legs = side ? [(28, 35)] : [(25, 30), (33, 38)];
  final shoes = side ? [(28, 38)] : [(24, 30), (33, 39)];
  final armTop = (side ? 48 : 47) + u, armBottom = 61 + u;

  void drawArms() {
    for (final (l, r) in arms) {
      if (b.arm != null) c.stamp(rect(l, armTop, r, armBottom, (x, y) => b.arm!(x, y - u, l, r)));
      if (b.sleeve case (final fill, final len)) {
        c.stamp(rect(l, armTop, r, armTop + len - 1, (x, y) => fill(x, y - u, l, r)));
      }
    }
  }

  for (final (l, r) in legs) {
    c.stamp(rect(l, 64, r, b.shoe == null ? 86 : 83, (x, y) => b.leg(x, y, l, r)));
  }
  if (b.shoe != null) {
    for (final (l, r) in shoes) {
      c.stamp(rect(l, 84, r, 86, (x, y) => b.shoe!(x, y, l, r)));
    }
  }
  if (!side) drawArms(); // 정면: 팔이 몸통 뒤
  final torso = rect(tl, 45 + u, tr, 67 + u, (x, y) => b.torso(x, y - u, tl, tr));
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

final nude = Body(torso: (x, y, l, r) => y >= 60 ? cream[2] : shaded(sk)(x, y, l, r), arm: limb(sk), leg: limb(sk));

Body tee(Ramp k) => Body(torso: shaded(k), arm: null, sleeve: (limb(k), 6), leg: limb(pants), shoe: shoeFill);

final outfits = <String, Body>{
  'default': tee(terracotta),
  // 크림 니트: 세로 골지, 목 밴드, 긴 소매
  'knit': Body(
    torso: (x, y, l, r) =>
        y <= 47 || (y >= 65) ? cream[2] : (x % 3 == 0 ? cream[2] : (x >= r - 2 ? cream[1] : cream[0])),
    arm: null,
    sleeve: ((x, y, l, r) => y >= 57 || x >= r - 1 ? cream[2] : cream[0], 12),
    leg: limb(pants),
    shoe: shoeFill,
  ),
  // 줄무늬 셔츠: 2px 가로 줄
  'stripe': Body(
    torso: (x, y, l, r) => y % 4 < 2 ? denim[2] : (x >= r - 2 || y <= 46 ? cream[2] : cream[0]),
    arm: null,
    sleeve: ((x, y, l, r) => y % 4 < 2 ? denim[2] : cream[0], 6),
    leg: limb(pants),
    shoe: shoeFill,
  ),
  // 멜빵 바지: 버터색 셔츠 + 데님
  'overall': Body(
    torso: (x, y, l, r) {
      final strap = y >= 47 && (x - l == 3 || x - l == 4 || r - x == 3 || r - x == 4);
      if (y == 54 && strap) return butter[2]; // 단추
      if (y >= 54 || strap) return x >= r - 2 ? denim[2] : denim[1];
      return shaded(butter)(x, y, l, r);
    },
    arm: null,
    sleeve: (limb(butter), 6),
    leg: limb(denim),
    shoe: shoeFill,
  ),
  // 후드티: 주머니, 끈, 목 뒤 후드
  'hoodie': Body(
    torso: (x, y, l, r) {
      final m = (l + r) ~/ 2;
      if (y >= 48 && y <= 52 && (x == m - 1 || x == m + 2)) return cream[0]; // 끈
      if ((y == 59 && x >= l + 4 && x <= r - 4) || (y > 59 && y <= 64 && (x == l + 4 || x == r - 4))) return sage[2];
      return shaded(sage)(x, y, l, r);
    },
    arm: null,
    sleeve: ((x, y, l, r) => y >= 57 || x >= r - 1 ? sage[2] : sage[1], 12),
    leg: limb(pants),
    shoe: shoeFill,
    extra: (c, side, u) => c.stamp(
      area(
        (x, y) =>
            y - u >= 43 &&
            y - u <= 46 &&
            x >= (side ? 22 : 18) &&
            x <= (side ? 33 : 45) &&
            !inHead(x, y - u) &&
            !inHead(x - 1, y - u) &&
            !inHead(x + 1, y - u) &&
            !inHead(x, y - u - 1),
        (x, y) => y - u >= 46 ? sage[2] : sage[1],
      ),
    ),
  ),
  // 별무늬 잠옷: 위아래 한 벌
  'pajama': Body(
    torso: (x, y, l, r) {
      final m = (l + r) ~/ 2;
      if ((x == m || x == m + 1) && (y == 50 || y == 55 || y == 60)) return lavender[2]; // 단추
      if (const [(-5, 52), (4, 49), (-3, 59), (5, 57), (-6, 64), (3, 64)].contains((x - m, y))) return butter[1]; // 별
      return y <= 46 || x >= r - 2 ? lavender[1] : lavender[0];
    },
    arm: null,
    sleeve: ((x, y, l, r) => y >= 57 || x >= r - 1 ? lavender[1] : lavender[0], 12),
    leg: (x, y, l, r) => (x + y) % 7 == 0 && y % 3 == 0 ? butter[1] : (x >= r - 1 ? lavender[1] : lavender[0]),
    shoe: shoeFill,
  ),
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

final accessories = <String, Draw>{
  // 머리핀은 미니미의 왼쪽 머리에 꽂는다 → 오른쪽을 볼 때는 보이지 않는다 (왼쪽 시트에만 그림)
  'starpin': (c, side, u, _) => side ? null : star(c, 41, 20 + u),
  'ribbon': (c, side, u, _) => bow(c, side ? 22 : 36, 10 + u),
  'beanie': (c, side, u, _) {
    c.stamp(
      area(
        (x, y) => y - u <= 24 && (inHair(x, y - u) || sq(x, y - u, 32, 27, 18, 16)),
        (x, y) => y - u >= 20
            ? (x % 3 == 1 ? cream[2] : cream[1]) // 접은 단
            : (x >= 45 ? terracotta[2] : (x % 4 == 0 ? terracotta[2] : terracotta[1])),
      ),
    );
    c.stamp(area((x, y) => sq(x, y - u, 32, 8, 3.5, 3.5, 2), (x, y) => x >= 33 && y - u >= 8 ? cream[2] : cream[0]));
  },
  'glasses': (c, side, u, _) {
    Part ring(int ox) => pattern(
      ox,
      29 + u,
      const ['.aaaaaa.', 'a......a', 'a......a', 'a......a', 'a......a', 'a......a', 'a......a', '.aaaaaa.'],
      {'a': inkSoft},
    );
    if (side) {
      c.put(ring(38));
      c.put(rect(30, 32 + u, 37, 32 + u, (_, _) => inkSoft)); // 다리
    } else {
      c.put(ring(21));
      c.put(ring(35));
      c.put(rect(29, 32 + u, 34, 32 + u, (_, _) => inkSoft));
    }
  },
  'headphone': (c, side, u, _) {
    if (side) {
      c.put(rect(29, 11 + u, 30, 28 + u, (_, _) => inkSoft));
      c.stamp(area((x, y) => sq(x, y - u, 30, 33, 4.5, 5.5, 2), (x, y) => x >= 32 ? denim[2] : denim[1]));
    } else {
      c.put(
        area(
          (x, y) => y - u <= 27 && sq(x, y - u, 32, 30, 20, 19, 2.6) && !sq(x, y - u, 32, 30, 18, 17, 2.6),
          (_, _) => inkSoft,
        ),
      );
      for (final l in const [13, 47]) {
        c.stamp(rect(l, 27 + u, l + 3, 37 + u, (x, y) => x == l + 3 ? denim[2] : denim[1]));
      }
    }
  },
};

/// 안경: 렌즈 그림 하나를 양쪽 눈에 찍고 코걸이·다리를 잇는다.
Draw spectacles(List<String> rows, Map<String, int> colors, int frame, {int? outline}) => (c, side, u, _) {
  void lens(int ox) {
    final p = pattern(ox, 29 + u, rows, colors);
    outline == null ? c.put(p) : c.stamp(p, outline);
  }

  if (side) {
    c.put(rect(30, 32 + u, 37, 32 + u, (_, _) => frame)); // 다리
    lens(38);
  } else {
    c.put(rect(29, 32 + u, 34, 32 + u, (_, _) => frame));
    lens(21);
    lens(35);
  }
};

/// 귀고리: 귓불 아래에 단다 (정면은 양쪽, 측면은 보이는 귀 하나).
Draw earring(List<String> rows, Map<String, int> colors, {int? outline}) => (c, side, u, _) {
  for (final ox in side ? const [30] : const [12, 49]) {
    final p = pattern(ox, 37 + u, rows, colors);
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
  'starpin': (c, side, u, _) => star(c, side ? 34 : 41, 20 + u),
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
    for (final e in outfits.entries)
      'outfits/outfit_${e.key}_idle.png': sheetOf((c, side, u, _) => drawBody(c, side, u, e.value)),
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

  // (머리 모양, 눈, 입, 피부, 머리색, 옷, 액세서리, 기본 옷 색)
  const looks = <(int, int, int, int, int, String, String?, int)>[
    (0, 0, 0, 0, 0, 'default', null, 0),
    (1, 1, 1, 1, 1, 'default', null, 1),
    (2, 2, 2, 2, 2, 'default', null, 2),
    (3, 3, 3, 3, 3, 'default', null, 3),
    (4, 4, 4, 4, 4, 'knit', null, 0),
    (5, 5, 5, 5, 5, 'stripe', null, 0),
    (6, 0, 0, 6, 6, 'overall', null, 0),
    (7, 1, 1, 7, 7, 'hoodie', null, 0),
    (8, 3, 0, 0, 1, 'pajama', null, 0),
    (9, 0, 4, 1, 0, 'default', null, 1),
    (1, 0, 0, 0, 0, 'default', 'glasses', 0),
    (1, 0, 0, 0, 1, 'default', 'glasses_horn', 0),
    (1, 0, 0, 0, 2, 'default', 'glasses_rimless', 0),
    (9, 0, 1, 2, 0, 'default', 'sunglasses', 0),
    (6, 0, 1, 0, 4, 'default', 'sunglasses_heart', 0),
    (1, 3, 0, 0, 0, 'knit', 'ear_pearl', 0),
    (6, 0, 0, 1, 1, 'knit', 'ear_hoop', 0),
    (3, 4, 1, 2, 0, 'knit', 'ear_star', 0),
    (4, 1, 1, 0, 6, 'knit', 'ear_heart', 0),
    (0, 0, 0, 7, 5, 'knit', 'ear_drop', 0),
    (0, 0, 0, 0, 0, 'knit', 'starpin', 0),
    (2, 0, 0, 0, 1, 'stripe', 'ribbon', 0),
    (2, 0, 0, 1, 0, 'overall', 'beanie', 0),
    (8, 0, 0, 2, 0, 'pajama', 'headphone', 0),
  ];
  const cols = 12;
  final rowsN = (looks.length / cols).ceil();
  final out = img.Image(width: fw * cols, height: fh * 2 * rowsN, numChannels: 4);
  img.fill(out, color: img.ColorRgba8(0xF6, 0xEB, 0xDD, 255));
  for (var i = 0; i < looks.length; i++) {
    final (hs, ey, mo, skin, hair, o, a, oc) = looks[i];
    final table = PixelPalette.swapFor(skinIndex: skin, hairIndex: hair);
    final layers = [
      swap(s('hair/hair_${hs}_back_idle.png'), table),
      swap(s('base/base_idle.png'), table),
      s('face/eyes_${ey}_idle.png'),
      s('face/mouth_${mo}_idle.png'),
      o == 'default'
          ? swap(s('outfits/outfit_default_idle.png'), PixelPalette.outfitSwap(oc))
          : s('outfits/outfit_${o}_idle.png'),
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
  final big = img.copyResize(
    out,
    width: out.width * 4,
    height: out.height * 4,
    interpolation: img.Interpolation.nearest,
  );
  File(path).writeAsBytesSync(img.encodePng(big));
  stdout.writeln('preview → $path');
}
