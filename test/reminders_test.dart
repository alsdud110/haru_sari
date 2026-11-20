import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/reminders.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  final seoul = tz.getLocation('Asia/Seoul');
  tz.TZDateTime at(int y, int m, int d, int h, [int min = 0]) => tz.TZDateTime(seoul, y, m, d, h, min);

  // 2026-11-11 은 수요일 (weekday 3), 오전 9:00
  final now = at(2026, 11, 11, 9);
  const wed = 3, thu = 4;

  group('routineSlot', () {
    test('안 한 루틴: 오늘 시간이 남았으면 오늘부터 매주', () {
      final s = routineSlot(10 * 60, wed, doneToday: false, now: now);
      expect((s.at, s.weekly), (at(2026, 11, 11, 10), true));
    });

    test('오늘 이미 한 루틴: 오늘 몫을 건너뛰고 다음 주 한 번만', () {
      final s = routineSlot(10 * 60 + 30, wed, doneToday: true, now: now);
      expect((s.at, s.weekly), (at(2026, 11, 18, 10, 30), false));
    });

    test('오늘 이미 한 루틴이라도 오늘 시간이 지났으면 그대로 매주 (다음 알림이 이미 다음 주)', () {
      final s = routineSlot(8 * 60, wed, doneToday: true, now: now);
      expect((s.at, s.weekly), (at(2026, 11, 18, 8), true));
    });

    test('정확히 지금 시각이면 지난 것으로 본다', () {
      final s = routineSlot(9 * 60, wed, doneToday: true, now: now);
      expect((s.at, s.weekly), (at(2026, 11, 18, 9), true));
    });

    test('오늘 한 루틴이라도 다른 요일 알림은 그대로 매주', () {
      final s = routineSlot(10 * 60, thu, doneToday: true, now: now);
      expect((s.at, s.weekly), (at(2026, 11, 12, 10), true));
    });

    test('다음 주가 다음 달로 넘어간다', () {
      final s = routineSlot(22 * 60, wed, doneToday: true, now: at(2026, 11, 25, 9));
      expect((s.at, s.weekly), (at(2026, 12, 2, 22), false));
    });

    test('다음 주가 다음 해로 넘어간다', () {
      final s = routineSlot(10 * 60, 3, doneToday: true, now: at(2025, 12, 31, 9)); // 2025-12-31 수요일
      expect((s.at, s.weekly), (at(2026, 1, 7, 10), false));
    });
  });

  group('nextAt', () {
    test('오늘 시간이 남았으면 오늘, 지났으면 내일', () {
      expect(nextAt(23 * 60 + 59, now), at(2026, 11, 11, 23, 59));
      expect(nextAt(0, now), at(2026, 11, 12, 0));
    });

    test('요일을 주면 그 요일 중 가장 가까운 날', () {
      expect(nextAt(9 * 60, now, weekday: 7), at(2026, 11, 15, 9)); // 일요일
    });
  });
}
