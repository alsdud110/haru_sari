import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/ui/today.dart';

void main() {
  test('keepWords: 좁은 폭에서도 낱말 중간이 아니라 띄어쓰기에서 줄이 바뀐다', () {
    List<String> lines(String text) {
      final p = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 75); // 7글자 반
      return [
        for (final m in p.computeLineMetrics())
          text
              .substring(
                p.getLineBoundary(p.getPositionForOffset(Offset(0, m.baseline - 1))).start,
                p.getLineBoundary(p.getPositionForOffset(Offset(0, m.baseline - 1))).end,
              )
              .replaceAll('‍', '')
              .trim(),
      ];
    }

    const s = '천천히 시작해도 괜찮아요';
    expect(lines(s), isNot(['천천히', '시작해도', '괜찮아요'])); // 그냥 두면 낱말이 잘린다
    expect(lines(keepWords(s)), ['천천히', '시작해도', '괜찮아요']);
  });

  test('keepWords: 이모지(UTF-16 두 칸)를 반으로 가르지 않는다', () {
    for (final s in ['물🥤 마시기', '🔔을 누르면', '🌱하루', '👍👍']) {
      final out = keepWords(s);
      // 짝 없는 서로게이트가 있으면 well-formed 가 아니다
      expect(out.runes.any((r) => r >= 0xD800 && r <= 0xDFFF), isFalse, reason: s);
      expect(out.replaceAll('‍', ''), s.replaceAll(' ', ' '));
    }
  });
}
