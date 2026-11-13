import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/cheers.dart';
import 'package:haru_sari/ui/today.dart';

void main() {
  const gentle = {'아직 0개': gentleNone, '모두 완료': gentleAll, '오늘 몫 달성': gentleEnough, '몇 개 함': gentleSome};
  const cheers = {'쉬는 날': cheerRest, '모두 완료': cheerAll, '오늘 몫 달성': cheerEnough, '그 밖': cheerAnyway};

  test('오늘 화면의 한마디: 묶음마다 8개, 두 줄이고 한 줄은 15자 안쪽, 서로 겹치지 않는다', () {
    for (final e in gentle.entries) {
      expect(e.value, hasLength(8), reason: e.key);
      expect(e.value.toSet(), hasLength(e.value.length), reason: e.key);
      for (final line in e.value) {
        final rows = line.replaceAll('{n}', '12').split('\n');
        expect(rows, hasLength(2), reason: line);
        for (final r in rows) {
          expect(r.length, lessThanOrEqualTo(15), reason: line);
        }
      }
    }
    for (final line in gentleSome) {
      expect(line, contains('{n}'), reason: line);
    }
  });

  test('한마디 화면: 묶음마다 8개 이상, 제목은 15자 안쪽이고 본문은 두 문장, 서로 겹치지 않는다', () {
    for (final e in cheers.entries) {
      expect(e.value.length, greaterThanOrEqualTo(8), reason: e.key);
      expect(e.value.map((c) => c.$1).toSet(), hasLength(e.value.length), reason: e.key);
      for (final (title, body) in e.value) {
        expect(title.length, lessThanOrEqualTo(15), reason: title);
        expect(body.split('\n'), hasLength(2), reason: title);
      }
    }
  });

  test('다그치거나 지적하는 말을 쓰지 않는다', () {
    final all = [
      for (final g in gentle.values) ...g,
      for (final c in cheers.values)
        for (final (title, body) in c) ...[title, body],
    ];
    expect(all.length, greaterThanOrEqualTo(60));
    for (final line in all) {
      for (final word in ['실패', '못 했', '못했', '게으', '반성', '해야 해', '노력하세요', '분발']) {
        expect(line, isNot(contains(word)), reason: line);
      }
    }
  });

  test('같은 날에는 같은 문장, 다음 날에는 다음 문장이 나오고 한 바퀴 돌면 처음으로 돌아온다', () {
    final d = dayNumber(DateTime(2026, 11, 11, 9));
    expect(dayNumber(DateTime(2026, 11, 11, 23, 59)), d);
    expect(dayNumber(DateTime(2026, 11, 12)), d + 1);
    expect(gentleLine(0, 3, day: d), gentleLine(0, 3, day: d));
    expect(gentleLine(0, 3, day: d), isNot(gentleLine(0, 3, day: d + 1)));
    expect(gentleLine(0, 3, day: d), gentleLine(0, 3, day: d + gentleNone.length));
    expect({for (var i = 0; i < 8; i++) gentleLine(3, 3, day: d + i)}, hasLength(8));
  });

  test('몇 개 했는지는 문장 안에 숫자로 들어간다', () {
    for (var day = 0; day < gentleSome.length; day++) {
      // 화면에 나가는 글에는 낱말이 끊기지 않게 보이지 않는 이음 글자(U+200D)가 끼어 있다
      final line = gentleLine(2, 5, day: day).replaceAll('‍', '');
      expect(line, contains('2개'), reason: line);
      expect(line, isNot(contains('{n}')));
    }
  });
}
