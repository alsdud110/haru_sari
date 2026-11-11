import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../theme/tokens.dart';

/// 방 안에서 각 자리가 차지하는 영역 (방 크기 대비 비율).
Rect slotRect(RoomSlot slot, Size s) {
  Rect f(double l, double t, double r, double b) => Rect.fromLTRB(l * s.width, t * s.height, r * s.width, b * s.height);
  switch (slot) {
    case RoomSlot.wallpaper:
      return f(0, 0, 1, wallBottom);
    case RoomSlot.window:
      return f(0.17, 0.10, 0.43, 0.40);
    case RoomSlot.wallDecor:
      return f(0.47, 0.13, 0.62, 0.31);
    case RoomSlot.shelf:
      return f(0.70, 0.16, 0.95, 0.34);
    case RoomSlot.bed:
      return f(0.12, 0.47, 0.50, 0.80);
    case RoomSlot.desk:
      return f(0.60, 0.46, 0.96, 0.74);
    case RoomSlot.chair:
      return f(0.66, 0.56, 0.80, 0.84);
    case RoomSlot.lamp:
      return f(0.0, 0.20, 0.13, 0.80);
    case RoomSlot.plant:
      return f(0.86, 0.66, 1.0, 0.92);
    case RoomSlot.rug:
      return f(0.22, 0.76, 0.80, 0.96);
  }
}

const wallBottom = 0.60;

/// 그리는 순서 (뒤 → 앞).
const _drawOrder = [
  RoomSlot.window,
  RoomSlot.wallDecor,
  RoomSlot.shelf,
  RoomSlot.rug,
  RoomSlot.bed,
  RoomSlot.lamp,
  RoomSlot.desk,
  RoomSlot.chair,
  RoomSlot.plant,
];

class RoomPainter extends CustomPainter {
  RoomPainter(this.placed);

  /// 자리 → 가구
  final Map<RoomSlot, ShopItem> placed;

  @override
  void paint(Canvas canvas, Size size) {
    final wallRect = Offset.zero & Size(size.width, size.height * wallBottom);
    final floorRect = Rect.fromLTRB(0, wallRect.bottom, size.width, size.height);

    // 벽
    final wp = placed[RoomSlot.wallpaper];
    drawWallpaper(canvas, wallRect, wp?.variant ?? 0);

    // 바닥 (원목 마루)
    canvas.drawRect(floorRect, Paint()..color = AppColors.floor);
    final plank = Paint()
      ..color = AppColors.floorShade
      ..strokeWidth = 1.2;
    for (var i = 1; i < 5; i++) {
      final y = floorRect.top + floorRect.height * (i / 5) * (0.6 + i * 0.1);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plank);
    }
    // 걸레받이
    canvas.drawRect(Rect.fromLTWH(0, wallRect.bottom - 6, size.width, 6), Paint()..color = AppColors.wood);

    // 창이 없으면 은은한 햇빛만
    if (placed[RoomSlot.window] == null) {
      final light = slotRect(RoomSlot.window, size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(light.deflate(light.width * 0.1), const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }

    for (final slot in _drawOrder) {
      final item = placed[slot];
      if (item == null) continue;
      final rect = slot == RoomSlot.lamp && item.variant == 1
          ? Rect.fromLTRB(size.width * 0.50, 0, size.width * 0.64, size.height * 0.5)
          : slotRect(slot, size);
      drawFurniture(canvas, item, rect);
    }
  }

  @override
  bool shouldRepaint(RoomPainter old) => old.placed != placed;
}

void drawWallpaper(Canvas c, Rect r, int variant) {
  final base = switch (variant) {
    1 => const Color(0xFFDCE6D5),
    2 => const Color(0xFFDCE7F0),
    _ => AppColors.wall,
  };
  c.drawRect(r, Paint()..color = base);
  final stripe = Paint()
    ..color = Color.lerp(base, Colors.black, 0.04)!
    ..strokeWidth = r.width * 0.012;
  if (variant == 1) {
    for (var x = r.left; x < r.right; x += r.width / 14) {
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), stripe);
    }
  } else if (variant == 2) {
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var y = r.top + r.height * 0.08; y < r.bottom; y += r.height / 7) {
      for (var x = r.left + r.width * 0.05; x < r.right; x += r.width / 9) {
        c.drawCircle(Offset(x, y), r.width * 0.008, dot);
      }
    }
  } else {
    c.drawRect(
      Rect.fromLTRB(r.left, r.bottom - r.height * 0.3, r.right, r.bottom),
      Paint()..color = AppColors.wallShade,
    );
  }
}

Paint _p(Color c) => Paint()..color = c;

RRect _rr(Rect r, double rad) => RRect.fromRectAndRadius(r, Radius.circular(rad));

/// 가구 하나를 [r] 영역 안에 그린다. 상점 썸네일도 이 함수를 쓴다.
void drawFurniture(Canvas c, ShopItem item, Rect r) {
  final w = r.width, h = r.height;
  Rect f(double l, double t, double rr, double b) =>
      Rect.fromLTRB(r.left + l * w, r.top + t * h, r.left + rr * w, r.top + b * h);

  switch (item.slot!) {
    case RoomSlot.wallpaper:
      drawWallpaper(c, r, item.variant);

    case RoomSlot.window:
      final frame = f(0, 0, 1, 1);
      c.drawRRect(_rr(frame, 6), _p(Colors.white));
      final glass = frame.deflate(w * 0.06);
      c.drawRect(
        glass,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFD7EA), Color(0xFFF6D9C4)],
          ).createShader(glass),
      );
      c.drawCircle(
        Offset(glass.left + glass.width * 0.7, glass.top + glass.height * 0.35),
        glass.width * 0.1,
        _p(const Color(0xFFFFF2D6)),
      );
      final bar = _p(Colors.white);
      c.drawRect(Rect.fromCenter(center: glass.center, width: w * 0.04, height: glass.height), bar);
      c.drawRect(Rect.fromCenter(center: glass.center, width: glass.width, height: w * 0.04), bar);
      // 커튼
      final cur = _p(AppColors.primarySoft);
      c.drawPath(
        Path()
          ..moveTo(frame.left - w * 0.04, frame.top - h * 0.04)
          ..lineTo(frame.left + w * 0.2, frame.top - h * 0.04)
          ..quadraticBezierTo(frame.left + w * 0.08, frame.center.dy, frame.left + w * 0.14, frame.bottom + h * 0.06)
          ..lineTo(frame.left - w * 0.04, frame.bottom + h * 0.06)
          ..close(),
        cur,
      );
      c.drawPath(
        Path()
          ..moveTo(frame.right + w * 0.04, frame.top - h * 0.04)
          ..lineTo(frame.right - w * 0.2, frame.top - h * 0.04)
          ..quadraticBezierTo(frame.right - w * 0.08, frame.center.dy, frame.right - w * 0.14, frame.bottom + h * 0.06)
          ..lineTo(frame.right + w * 0.04, frame.bottom + h * 0.06)
          ..close(),
        cur,
      );
      c.drawRect(f(-0.06, -0.08, 1.06, -0.03), _p(AppColors.woodDark));

    case RoomSlot.wallDecor:
      c.drawRect(f(0, 0, 1, 1), _p(AppColors.woodDark));
      final art = f(0.1, 0.1, 0.9, 0.9);
      c.drawRect(art, _p(const Color(0xFFFBE3CF)));
      c.drawCircle(Offset(art.center.dx, art.top + art.height * 0.62), art.width * 0.24, _p(AppColors.primary));
      c.drawRect(
        Rect.fromLTRB(art.left, art.top + art.height * 0.66, art.right, art.bottom),
        _p(const Color(0xFFE9B99A)),
      );

    case RoomSlot.shelf:
      c.drawRect(f(0, 0.82, 1, 0.92), _p(AppColors.wood));
      final books = [AppColors.sage, AppColors.primary, AppColors.sky, AppColors.coin, const Color(0xFFC9A3C9)];
      var x = 0.06;
      for (var i = 0; i < books.length; i++) {
        final bw = 0.1 + (i % 2) * 0.03;
        final top = 0.30 + (i % 3) * 0.1;
        c.drawRRect(_rr(f(x, top, x + bw, 0.82), 2), _p(books[i]));
        x += bw + 0.02;
      }
      c.drawCircle(Offset(r.left + w * 0.86, r.top + h * 0.68), w * 0.07, _p(AppColors.sageSoft));

    case RoomSlot.bed:
      final frameColor = item.variant == 1 ? const Color(0xFFEDE3D6) : AppColors.wood;
      c.drawRRect(_rr(f(0, 0, 0.16, 0.9), 6), _p(frameColor)); // 헤드보드
      c.drawRRect(_rr(f(0.04, 0.42, 1, 0.86), 8), _p(frameColor));
      c.drawRRect(_rr(f(0.06, 0.32, 0.98, 0.62), 10), _p(Colors.white)); // 매트리스
      if (item.variant == 2) {
        // 더블 침대: 베개 두 개를 위아래로
        c.drawRRect(_rr(f(0.10, 0.12, 0.34, 0.30), 8), _p(const Color(0xFFFFFBF5)));
        c.drawRRect(_rr(f(0.10, 0.34, 0.34, 0.52), 8), _p(const Color(0xFFFFFBF5)));
      } else {
        c.drawRRect(_rr(f(0.10, 0.22, 0.34, 0.44), 10), _p(const Color(0xFFFFFBF5))); // 베개
      }
      final blanket = f(0.36, 0.30, 0.98, 0.70);
      c.drawRRect(_rr(blanket, 10), _p(item.variant >= 1 ? AppColors.sageSoft : AppColors.primarySoft));
      if (item.variant == 2) {
        // 체크무늬 이불
        final sq = _p(AppColors.sage.withValues(alpha: 0.55));
        for (var i = 0; i < 4; i++) {
          for (var j = 0; j < 2; j++) {
            if ((i + j).isEven) {
              c.drawRect(
                Rect.fromLTWH(
                  blanket.left + blanket.width * i / 4,
                  blanket.top + blanket.height * j / 2,
                  blanket.width / 4,
                  blanket.height / 2,
                ),
                sq,
              );
            }
          }
        }
      } else if (item.variant == 1) {
        final q = Paint()
          ..color = AppColors.sage.withValues(alpha: 0.5)
          ..strokeWidth = 1.5;
        for (var i = 1; i < 4; i++) {
          final x = blanket.left + blanket.width * i / 4;
          c.drawLine(Offset(x, blanket.top + 4), Offset(x, blanket.bottom - 4), q);
        }
      }
      c.drawRect(f(0.06, 0.86, 0.12, 1), _p(AppColors.woodDark));
      c.drawRect(f(0.92, 0.86, 0.98, 1), _p(AppColors.woodDark));

    case RoomSlot.desk:
      final top = item.variant == 1 ? const Color(0xFFF7F3EE) : AppColors.wood;
      final leg = item.variant == 1 ? const Color(0xFFD9D2C8) : AppColors.woodDark;
      c.drawRect(f(0.04, 0.42, 0.10, 1), _p(leg));
      c.drawRect(f(0.90, 0.42, 0.96, 1), _p(leg));
      c.drawRRect(_rr(f(0.56, 0.42, 0.94, 0.70), 3), _p(leg.withValues(alpha: 0.85))); // 서랍
      c.drawRRect(_rr(f(0, 0.34, 1, 0.44), 3), _p(top));
      // 책상 위 소품: 노트북과 머그
      c.drawRRect(_rr(f(0.14, 0.12, 0.46, 0.34), 3), _p(const Color(0xFF6E6A66)));
      c.drawRRect(_rr(f(0.17, 0.15, 0.43, 0.31), 2), _p(const Color(0xFFCFE1EC)));
      c.drawRRect(_rr(f(0.62, 0.20, 0.72, 0.34), 3), _p(AppColors.primary));

    case RoomSlot.chair:
      c.drawRRect(_rr(f(0.15, 0, 0.85, 0.5), 8), _p(AppColors.woodDark));
      c.drawRRect(_rr(f(0.05, 0.46, 0.95, 0.60), 5), _p(AppColors.wood));
      c.drawRect(f(0.12, 0.60, 0.22, 1), _p(AppColors.woodDark));
      c.drawRect(f(0.78, 0.60, 0.88, 1), _p(AppColors.woodDark));

    case RoomSlot.lamp:
      if (item.variant == 1) {
        // 천장에 매달린 펜던트
        c.drawLine(
          Offset(r.center.dx, r.top),
          Offset(r.center.dx, r.top + h * 0.22),
          Paint()
            ..color = AppColors.text
            ..strokeWidth = 1.5,
        );
        c.drawCircle(
          Offset(r.center.dx, r.top + h * 0.30),
          w * 0.55,
          _p(const Color(0xFFFFE9B8).withValues(alpha: 0.35)),
        );
        c.drawPath(
          Path()
            ..moveTo(r.center.dx - w * 0.3, r.top + h * 0.30)
            ..lineTo(r.center.dx + w * 0.3, r.top + h * 0.30)
            ..lineTo(r.center.dx + w * 0.12, r.top + h * 0.22)
            ..lineTo(r.center.dx - w * 0.12, r.top + h * 0.22)
            ..close(),
          _p(AppColors.sage),
        );
      } else {
        // 스탠드
        final cx = r.center.dx;
        c.drawCircle(Offset(cx, r.top + h * 0.42), w * 0.6, _p(const Color(0xFFFFE9B8).withValues(alpha: 0.30)));
        c.drawLine(
          Offset(cx, r.top + h * 0.42),
          Offset(cx, r.bottom - h * 0.02),
          Paint()
            ..color = AppColors.text
            ..strokeWidth = 2,
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, r.bottom - h * 0.02), width: w * 0.5, height: h * 0.03),
          _p(AppColors.text),
        );
        c.drawPath(
          Path()
            ..moveTo(cx - w * 0.36, r.top + h * 0.44)
            ..lineTo(cx + w * 0.36, r.top + h * 0.44)
            ..lineTo(cx + w * 0.2, r.top + h * 0.33)
            ..lineTo(cx - w * 0.2, r.top + h * 0.33)
            ..close(),
          _p(const Color(0xFFFBE8C8)),
        );
      }

    case RoomSlot.plant:
      final pot = f(0.2, 0.62, 0.8, 1);
      final leaf = _p(AppColors.sage);
      final leafDark = _p(const Color(0xFF6F946C));
      if (item.variant == 1) {
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + (i - 2) * 0.5;
          final center = Offset(r.center.dx + math.cos(a) * w * 0.3, r.top + h * 0.38 + math.sin(a) * h * 0.25);
          c.drawOval(Rect.fromCenter(center: center, width: w * 0.42, height: h * 0.22), i.isEven ? leaf : leafDark);
        }
      } else {
        c.drawOval(f(0.15, 0.30, 0.55, 0.62), leaf);
        c.drawOval(f(0.45, 0.24, 0.85, 0.60), leafDark);
        c.drawOval(f(0.30, 0.10, 0.70, 0.50), leaf);
      }
      c.drawPath(
        Path()
          ..moveTo(pot.left, pot.top)
          ..lineTo(pot.right, pot.top)
          ..lineTo(pot.right - pot.width * 0.12, pot.bottom)
          ..lineTo(pot.left + pot.width * 0.12, pot.bottom)
          ..close(),
        _p(const Color(0xFFD4876A)),
      );

    case RoomSlot.rug:
      if (item.variant == 1) {
        final rug = f(0.04, 0.1, 0.96, 0.9);
        c.drawRRect(_rr(rug, 6), _p(const Color(0xFFF5EEE4)));
        final s = _p(AppColors.sky.withValues(alpha: 0.7));
        for (var i = 0; i < 4; i++) {
          final y = rug.top + rug.height * (0.15 + i * 0.22);
          c.drawRect(Rect.fromLTWH(rug.left, y, rug.width, rug.height * 0.09), s);
        }
      } else {
        c.drawOval(f(0, 0, 1, 1), _p(AppColors.primarySoft));
        c.drawOval(f(0.12, 0.18, 0.88, 0.82), _p(const Color(0xFFF3C9B0)));
      }
  }
}

// ───────── 미니미 ─────────

const skinTones = [Color(0xFFFBE3D0), Color(0xFFF1CBAA), Color(0xFFD9A57E), Color(0xFFA9714D)];
const hairColors = [Color(0xFF3B2E28), Color(0xFF7A5236), Color(0xFFC99A5E), Color(0xFF9A9AA6)];
const outfitColors = [AppColors.primary, AppColors.sage, AppColors.sky, Color(0xFFC9A3C9)];

/// 미니미. [outfit]·[accessory]는 아이템 variant (0이면 기본 옷 / 없음).
class MinimiPainter extends CustomPainter {
  MinimiPainter(this.m, {this.happy = false, this.outfit = 0, this.accessory = 0});
  final Minimi m;
  final bool happy;
  final int outfit;
  final int accessory;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final skin = _p(skinTones[m.skin % skinTones.length]);
    final hair = _p(hairColors[m.hair % hairColors.length]);
    final base = outfitColors[m.outfit % outfitColors.length];
    final cx = w / 2;
    final body = Rect.fromLTWH(cx - w * 0.26, h * 0.52, w * 0.52, h * 0.32);
    final head = Rect.fromCenter(center: Offset(cx, h * 0.32), width: w * 0.78, height: h * 0.5);

    // 그림자
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.97), width: w * 0.62, height: h * 0.06),
      _p(Colors.black.withValues(alpha: 0.08)),
    );
    // 다리
    final legColor = outfit == 3
        ? const Color(0xFF6F8FB8)
        : (outfit == 5 ? Color.lerp(base, Colors.white, 0.45)! : AppColors.text);
    c.drawRRect(_rr(Rect.fromLTWH(cx - w * 0.16, h * 0.78, w * 0.12, h * 0.18), 6), _p(legColor));
    c.drawRRect(_rr(Rect.fromLTWH(cx + w * 0.04, h * 0.78, w * 0.12, h * 0.18), 6), _p(legColor));

    // 후드는 머리 뒤에
    if (outfit == 4) {
      c.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.47), width: w * 0.62, height: h * 0.2),
        _p(Color.lerp(base, Colors.black, 0.12)!),
      );
    }
    _drawBody(c, body, base, w, h);
    // 팔
    final sleeve = _sleeveColor(base);
    c.drawOval(Rect.fromLTWH(cx - w * 0.36, h * 0.56, w * 0.14, h * 0.2), sleeve == null ? skin : _p(sleeve));
    c.drawOval(Rect.fromLTWH(cx + w * 0.22, h * 0.56, w * 0.14, h * 0.2), sleeve == null ? skin : _p(sleeve));

    // 머리
    c.drawOval(head, skin);
    if (accessory != 3) {
      c.drawPath(
        Path()
          ..addArc(head.inflate(w * 0.02), math.pi * 1.02, math.pi * 0.96)
          ..quadraticBezierTo(head.right - w * 0.1, head.top + head.height * 0.3, cx, head.top + head.height * 0.26)
          ..quadraticBezierTo(head.left + w * 0.1, head.top + head.height * 0.3, head.left - w * 0.01, head.center.dy)
          ..close(),
        hair,
      );
    }
    _drawFace(c, head, w, h);
    _drawAccessory(c, head, w, h, hair.color);
  }

  Color? _sleeveColor(Color base) => switch (outfit) {
    1 => const Color(0xFFF3E6D3),
    2 => Colors.white,
    3 => base,
    4 => base,
    5 => Color.lerp(base, Colors.white, 0.45),
    _ => null,
  };

  void _drawBody(Canvas c, Rect body, Color base, double w, double h) {
    final r = _rr(body, w * 0.18);
    switch (outfit) {
      case 1: // 크림 니트
        c.drawRRect(r, _p(const Color(0xFFF3E6D3)));
        c.save();
        c.clipRRect(r);
        final rib = Paint()
          ..color = const Color(0xFFE2CFB6)
          ..strokeWidth = w * 0.012;
        for (var x = body.left + w * 0.05; x < body.right; x += w * 0.06) {
          c.drawLine(Offset(x, body.top + h * 0.04), Offset(x, body.bottom), rib);
        }
        c.restore();
        c.drawRRect(
          _rr(
            Rect.fromCenter(center: Offset(body.center.dx, body.top + h * 0.015), width: w * 0.24, height: h * 0.04),
            6,
          ),
          _p(const Color(0xFFE2CFB6)),
        );
      case 2: // 줄무늬 셔츠
        c.drawRRect(r, _p(Colors.white));
        c.save();
        c.clipRRect(r);
        final st = _p(base);
        for (var y = body.top + h * 0.05; y < body.bottom; y += h * 0.06) {
          c.drawRect(Rect.fromLTWH(body.left, y, body.width, h * 0.025), st);
        }
        c.restore();
        c.drawPath(
          Path()
            ..moveTo(body.center.dx - w * 0.1, body.top)
            ..lineTo(body.center.dx, body.top + h * 0.06)
            ..lineTo(body.center.dx + w * 0.1, body.top)
            ..close(),
          _p(Colors.white),
        );
      case 3: // 멜빵 바지
        c.drawRRect(r, _p(base));
        final denim = _p(const Color(0xFF6F8FB8));
        c.drawRRect(
          _rr(Rect.fromLTRB(body.left, body.top + body.height * 0.45, body.right, body.bottom), w * 0.12),
          denim,
        );
        c.drawRect(Rect.fromLTWH(body.left + w * 0.1, body.top, w * 0.06, body.height * 0.5), denim);
        c.drawRect(Rect.fromLTWH(body.right - w * 0.16, body.top, w * 0.06, body.height * 0.5), denim);
        c.drawCircle(Offset(body.left + w * 0.13, body.top + body.height * 0.45), w * 0.025, _p(AppColors.coin));
        c.drawCircle(Offset(body.right - w * 0.13, body.top + body.height * 0.45), w * 0.025, _p(AppColors.coin));
      case 4: // 후드티
        c.drawRRect(r, _p(base));
        c.drawRRect(
          _rr(
            Rect.fromCenter(
              center: Offset(body.center.dx, body.top + body.height * 0.68),
              width: w * 0.3,
              height: h * 0.08,
            ),
            8,
          ),
          _p(Color.lerp(base, Colors.black, 0.1)!),
        );
        final str = Paint()
          ..color = Colors.white
          ..strokeWidth = w * 0.015
          ..strokeCap = StrokeCap.round;
        c.drawLine(
          Offset(body.center.dx - w * 0.06, body.top + h * 0.02),
          Offset(body.center.dx - w * 0.06, body.top + h * 0.1),
          str,
        );
        c.drawLine(
          Offset(body.center.dx + w * 0.06, body.top + h * 0.02),
          Offset(body.center.dx + w * 0.06, body.top + h * 0.1),
          str,
        );
      case 5: // 별무늬 잠옷
        final soft = Color.lerp(base, Colors.white, 0.45)!;
        c.drawRRect(r, _p(soft));
        final star = _p(Colors.white);
        for (final o in [
          const Offset(-0.12, 0.08),
          const Offset(0.1, 0.13),
          const Offset(-0.04, 0.22),
          const Offset(0.14, 0.26),
        ]) {
          _star(c, Offset(body.center.dx + o.dx * w, body.top + o.dy * h), w * 0.03, star);
        }
      default: // 기본 티셔츠
        c.drawRRect(r, _p(base));
    }
  }

  void _drawFace(Canvas c, Rect head, double w, double h) {
    final cx = head.center.dx;
    final eye = _p(AppColors.text);
    final ey = head.top + head.height * 0.58;
    if (happy) {
      final st = Paint()
        ..color = AppColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..strokeCap = StrokeCap.round;
      c.drawArc(
        Rect.fromCenter(center: Offset(cx - w * 0.14, ey), width: w * 0.1, height: h * 0.06),
        math.pi,
        math.pi,
        false,
        st,
      );
      c.drawArc(
        Rect.fromCenter(center: Offset(cx + w * 0.14, ey), width: w * 0.1, height: h * 0.06),
        math.pi,
        math.pi,
        false,
        st,
      );
    } else {
      c.drawCircle(Offset(cx - w * 0.14, ey), w * 0.035, eye);
      c.drawCircle(Offset(cx + w * 0.14, ey), w * 0.035, eye);
    }
    final blush = _p(const Color(0xFFF2A99A).withValues(alpha: 0.6));
    c.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.23, ey + h * 0.05), width: w * 0.1, height: h * 0.035), blush);
    c.drawOval(Rect.fromCenter(center: Offset(cx + w * 0.23, ey + h * 0.05), width: w * 0.1, height: h * 0.035), blush);
    c.drawArc(
      Rect.fromCenter(center: Offset(cx, ey + h * 0.05), width: w * 0.08, height: h * 0.04),
      0,
      math.pi,
      false,
      Paint()
        ..color = AppColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawAccessory(Canvas c, Rect head, double w, double h, Color hairColor) {
    final cx = head.center.dx;
    switch (accessory) {
      case 1: // 별 머리핀
        _star(c, Offset(head.right - w * 0.16, head.top + h * 0.1), w * 0.07, _p(AppColors.coin));
      case 2: // 리본
        final rib = _p(const Color(0xFFE88B8B));
        final o = Offset(head.left + w * 0.2, head.top + h * 0.06);
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx - w * 0.11, o.dy - h * 0.05)
            ..lineTo(o.dx - w * 0.11, o.dy + h * 0.05)
            ..close(),
          rib,
        );
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + w * 0.11, o.dy - h * 0.05)
            ..lineTo(o.dx + w * 0.11, o.dy + h * 0.05)
            ..close(),
          rib,
        );
        c.drawCircle(o, w * 0.03, _p(const Color(0xFFD06F6F)));
      case 3: // 니트 비니
        final hat = Rect.fromLTRB(
          head.left - w * 0.02,
          head.top - h * 0.03,
          head.right + w * 0.02,
          head.top + head.height * 0.42,
        );
        c.drawPath(
          Path()
            ..addArc(Rect.fromLTRB(hat.left, hat.top, hat.right, hat.bottom + head.height * 0.3), math.pi, math.pi)
            ..close(),
          _p(AppColors.primary),
        );
        c.drawRRect(
          _rr(Rect.fromLTRB(hat.left, hat.bottom - h * 0.06, hat.right, hat.bottom + h * 0.02), 8),
          _p(const Color(0xFFC9714A)),
        );
        c.drawCircle(Offset(cx, hat.top), w * 0.07, _p(const Color(0xFFF7E3D6)));
        // 비니 아래 머리카락
        c.drawRect(Rect.fromLTWH(head.left + w * 0.02, hat.bottom + h * 0.02, w * 0.1, h * 0.06), _p(hairColor));
        c.drawRect(Rect.fromLTWH(head.right - w * 0.12, hat.bottom + h * 0.02, w * 0.1, h * 0.06), _p(hairColor));
      case 4: // 동그란 안경
        final ey = head.top + head.height * 0.58;
        final st = Paint()
          ..color = AppColors.woodDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02;
        c.drawCircle(Offset(cx - w * 0.14, ey), w * 0.09, st);
        c.drawCircle(Offset(cx + w * 0.14, ey), w * 0.09, st);
        c.drawLine(Offset(cx - w * 0.05, ey), Offset(cx + w * 0.05, ey), st);
      case 5: // 헤드폰
        final band = Paint()
          ..color = AppColors.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04;
        c.drawArc(head.inflate(w * 0.03), math.pi * 1.05, math.pi * 0.9, false, band);
        final cup = _p(AppColors.primary);
        c.drawRRect(
          _rr(
            Rect.fromCenter(center: Offset(head.left, head.center.dy + h * 0.02), width: w * 0.12, height: h * 0.14),
            8,
          ),
          cup,
        );
        c.drawRRect(
          _rr(
            Rect.fromCenter(center: Offset(head.right, head.center.dy + h * 0.02), width: w * 0.12, height: h * 0.14),
            8,
          ),
          cup,
        );
    }
  }

  static void _star(Canvas c, Offset o, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(o.dx + math.cos(a) * rr, o.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(MinimiPainter old) =>
      old.m != m || old.happy != happy || old.outfit != outfit || old.accessory != accessory;
}

/// 프로필의 옷·액세서리를 입은 미니미.
class MinimiView extends StatelessWidget {
  const MinimiView({super.key, required this.profile, this.happy = false, this.width = 96});
  final Profile profile;
  final bool happy;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width * 1.2,
    child: CustomPaint(
      painter: MinimiPainter(
        profile.minimi,
        happy: happy,
        outfit: itemById(profile.outfitId)?.variant ?? 0,
        accessory: itemById(profile.accessoryId)?.variant ?? 0,
      ),
    ),
  );
}

/// 아이템 썸네일 (가구는 가구만, 옷·액세서리는 입은 미니미).
class ItemThumb extends StatelessWidget {
  const ItemThumb(this.item, {super.key, this.size = 64, this.minimi = const Minimi()});
  final ShopItem item;
  final double size;
  final Minimi minimi;

  @override
  Widget build(BuildContext context) {
    if (item.assetPath != null) {
      return Image.asset(item.assetPath!, width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.none);
    }
    if (!item.isFurniture) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: SizedBox(
            width: size * 0.66,
            height: size * 0.8,
            child: CustomPaint(
              painter: MinimiPainter(
                minimi,
                outfit: item.kind == ItemKind.outfit ? item.variant : 0,
                accessory: item.kind == ItemKind.accessory ? item.variant : 0,
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ThumbPainter(item)),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.item);
  final ShopItem item;

  @override
  void paint(Canvas canvas, Size size) {
    // 자리의 가로세로 비율을 유지해서 가운데 그린다.
    final ref = slotRect(item.slot!, const Size(300, 300));
    final ratio = ref.width / math.max(ref.height, 1);
    var w = size.width * 0.82, h = w / ratio;
    if (h > size.height * 0.82) {
      h = size.height * 0.82;
      w = h * ratio;
    }
    final r = Rect.fromCenter(center: size.center(Offset.zero), width: w, height: h);
    if (item.slot == RoomSlot.wallpaper) {
      canvas.clipRRect(_rr(r, 8));
    }
    drawFurniture(canvas, item, r);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.item != item;
}
