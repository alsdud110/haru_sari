import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/room/asset_check.dart';
import 'package:haru_sari/room/iso.dart';

void main() {
  test('바닥 네 꼭짓점', () {
    expect(IsoGrid.toCanvas(0, 0), const Offset(256, 168));
    expect(IsoGrid.toCanvas(8, 0), const Offset(512, 296));
    expect(IsoGrid.toCanvas(0, 8), const Offset(0, 296));
    expect(IsoGrid.toCanvas(8, 8), const Offset(256, 424));
    expect(AssetCheck.gridConsistent(), isTrue);
  });

  test('왕복 변환', () {
    for (final (gx, gy) in [(0.0, 0.0), (3.0, 5.0), (7.5, 2.5), (1.25, 6.75)]) {
      final (x, y) = IsoGrid.toGrid(IsoGrid.toCanvas(gx, gy));
      expect(x, closeTo(gx, 1e-9));
      expect(y, closeTo(gy, 1e-9));
    }
  });

  test('tileAt: 타일 중심과 방 밖', () {
    expect(IsoGrid.tileAt(IsoGrid.tileCenter(3, 4)), (3, 4));
    expect(IsoGrid.tileAt(IsoGrid.tileCenter(0, 0)), (0, 0));
    final (gx, gy) = IsoGrid.tileAt(const Offset(10, 10));
    expect(IsoGrid.inRoom(gx, gy), isFalse);
  });

  test('스프라이트 규격 (02 §12 검증값)', () {
    expect(IsoGrid.spriteSpec(1, 2, 52), (width: 96, height: 104, ax: 64, ay: 56)); // 침대 R0
    expect(IsoGrid.spriteSpec(2, 1, 52), (width: 96, height: 104, ax: 32, ay: 56)); // 침대 R1
    expect(IsoGrid.spriteSpec(2, 1, 64), (width: 96, height: 112, ax: 32, ay: 64)); // 책상
    expect(IsoGrid.spriteSpec(1, 1, 48), (width: 64, height: 80, ax: 32, ay: 48)); // 의자
    expect(IsoGrid.spriteSpec(1, 1, 104), (width: 64, height: 136, ax: 32, ay: 104)); // 조명
    expect(IsoGrid.spriteSpec(1, 1, 36), (width: 64, height: 72, ax: 32, ay: 40)); // 화분
    expect(IsoGrid.spriteSpec(2, 2, 0), (width: 128, height: 64, ax: 64, ay: 0)); // 러그
  });

  test('침대 (0,1) 배치: 상자 아래 끝 = 점유 앞 꼭짓점', () {
    final box = IsoGrid.spriteBox(0, 1, 1, 2, 52);
    expect((box.left, box.top, box.width, box.height), (160, 128, 96, 104));
    expect(box.top + box.height, IsoGrid.toCanvas(1, 3).dy);
  });

  test('벽 장식 상자: 왼쪽·오른쪽 벽 안에 있다', () {
    final l = IsoGrid.wallBox(left: true, u: 2, span: 2, z: 40, h: 72);
    expect(l.left, 256 - 4 * 32);
    expect(l.left + l.width, 256 - 2 * 32);
    final r = IsoGrid.wallBox(left: false, u: 5, span: 2, z: 72, h: 32);
    expect(r.left, 256 + 5 * 32);
    // 벽 꼭대기(바닥에서 160)보다 위로 나가지 않는다
    expect(r.top, greaterThanOrEqualTo(IsoGrid.toCanvas(5, 0).dy - 160));
  });

  test('정수 확대 배율', () {
    expect(IsoGrid.pixelScale(1179), 2); // iPhone 15
    expect(IsoGrid.pixelScale(1080), 2); // S23
    expect(IsoGrid.pixelScale(1440), 2); // QHD
    expect(IsoGrid.pixelScale(750), 2); // iPhone SE: 1배면 68% → 한 단계 키움
    expect(IsoGrid.pixelScale(300), 1);
  });
}
