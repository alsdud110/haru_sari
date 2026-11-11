import 'dart:math' as math;
import 'dart:ui';

/// 가구 방향 (90°씩 돈다). 앞면이 R0 = 왼쪽 아래, R1 = 오른쪽 아래, R2 = 오른쪽 위(뒷모습), R3 = 왼쪽 위(뒷모습).
/// R1·R3은 w·d가 바뀐다. 저장은 index라 순서를 바꾸면 안 된다.
enum Rot { r0, r1, r2, r3 }

/// 스프라이트 하나가 캔버스에 놓이는 상자.
class SpriteBox {
  const SpriteBox({required this.left, required this.top, required this.width, required this.height});
  final int left;
  final int top;
  final int width;
  final int height;

  Rect get rect => Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), height.toDouble());
  bool contains(Offset p) => rect.contains(p);
}

/// 2:1 아이소메트릭 좌표계 (docs/asset-system/01 §1).
///
/// 캔버스는 네이티브 해상도 512×432. 1 아트 픽셀 = 1 네이티브 픽셀.
class IsoGrid {
  static const tileW = 64;
  static const tileH = 32;
  static const size = 8;
  static const wallH = 160;
  static const canvasW = 512;
  static const canvasH = 432;
  static const originX = 256;
  static const originY = 168;
  static const canvas = Size(512, 432);

  /// 타일 꼭짓점 (gx, gy) → 캔버스 좌표.
  static Offset toCanvas(num gx, num gy) =>
      Offset(originX + (gx - gy) * (tileW / 2), originY + (gx + gy) * (tileH / 2));

  /// 캔버스 좌표 → 그리드 좌표 (소수).
  static (double, double) toGrid(Offset p) {
    final a = (p.dx - originX) / (tileW / 2);
    final b = (p.dy - originY) / (tileH / 2);
    return ((a + b) / 2, (b - a) / 2);
  }

  /// 캔버스 좌표가 놓인 타일 (방 밖일 수 있음).
  static (int, int) tileAt(Offset p) {
    final (gx, gy) = toGrid(p);
    return (gx.floor(), gy.floor());
  }

  /// 타일 중심.
  static Offset tileCenter(int gx, int gy) => toCanvas(gx + 0.5, gy + 0.5);

  static bool inRoom(int gx, int gy, [int w = 1, int d = 1]) => gx >= 0 && gy >= 0 && gx + w <= size && gy + d <= size;

  static int _ceil8(int v) => (v + 7) ~/ 8 * 8;

  /// 점유 w×d, 물체 높이 h인 스프라이트의 크기와 앵커 (01 §3.1).
  static ({int width, int height, int ax, int ay}) spriteSpec(int w, int d, int h) {
    final width = (w + d) * (tileW ~/ 2);
    final height = _ceil8((w + d) * (tileH ~/ 2) + h);
    return (width: width, height: height, ax: d * (tileW ~/ 2), ay: height - (w + d) * (tileH ~/ 2));
  }

  /// (gx, gy)에 놓인 w×d·h 물체의 스프라이트 상자.
  static SpriteBox spriteBox(int gx, int gy, int w, int d, int h) {
    final s = spriteSpec(w, d, h);
    final p = toCanvas(gx, gy);
    return SpriteBox(left: p.dx.round() - s.ax, top: p.dy.round() - s.ay, width: s.width, height: s.height);
  }

  /// 벽 장식 상자. 왼쪽 벽(gx=0 변)은 u가 gy, 오른쪽 벽(gy=0 변)은 u가 gx.
  /// [z]는 바닥에서 장식 아래 변까지 높이(px), [h]는 장식 높이.
  static SpriteBox wallBox({required bool left, required int u, required int span, required int z, required int h}) {
    final width = span * (tileW ~/ 2);
    final height = _ceil8(span * (tileH ~/ 2) + h);
    // 벽 위 시작점: 왼쪽 벽은 (0,u), 오른쪽 벽은 (u,0) 꼭짓점. 벽면 위로 z만큼 올린다.
    final base = left ? toCanvas(0, u) : toCanvas(u, 0);
    final leftX = left ? base.dx.round() - width : base.dx.round();
    // 벽 아래 변은 기울어 있다. 상자 아래 = 가장 낮은 쪽 끝 (+span*16).
    final bottom = base.dy.round() + span * (tileH ~/ 2) - z;
    return SpriteBox(left: leftX, top: bottom - height, width: width, height: height);
  }

  /// 물리 픽셀 기준 정수 확대 배율 (01 §1.4).
  /// 계산한 방 폭이 화면 폭의 70% 미만이면 한 단계 키운다(가로 스크롤 허용).
  static int pixelScale(double physicalWidth) {
    var s = math.max(1, physicalWidth ~/ canvasW);
    if (canvasW * s < physicalWidth * 0.7) s += 1;
    return s;
  }
}
