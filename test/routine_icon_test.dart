import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/badges.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/reminders.dart';
import 'package:haru_sari/ui/routine_icon.dart';

void main() {
  test('아이콘 32개가 모두 파일로 있고, 서로 다른 그림을 가리킨다 (파일은 배지·안내·광고 버튼용까지 49개)', () {
    expect(routineIconChoices, hasLength(32));
    expect(routineIconAssets.values.toSet(), hasLength(32));
    expect(Directory('assets/icons').listSync().where((f) => f.path.endsWith('.png')), hasLength(49));
    for (final e in routineIconChoices) {
      expect(File(routineIconAsset(e)!).existsSync(), isTrue, reason: '$e 그림 없음');
    }
  });

  test('카테고리와 첫 설정 템플릿의 이모지는 모두 앱 그림으로 이어진다', () {
    for (final e in routineCategoryEmoji.entries) {
      expect(routineIconAsset(e.value), isNotNull, reason: '카테고리 ${e.key}');
    }
    for (final t in routineTemplates) {
      expect(routineIconAsset(t.emoji), isNotNull, reason: '템플릿 ${t.name}');
    }
  });

  test('카테고리마다 먼저 보여 줄 아이콘이 있고, 첫 칸은 카테고리 아이콘이며 모두 고를 수 있는 아이콘이다', () {
    expect(routineCategoryIcons.keys, routineCategories);
    for (final e in routineCategoryIcons.entries) {
      expect(e.value.first, routineCategoryEmoji[e.key], reason: e.key);
      expect(e.value.length, lessThanOrEqualTo(4), reason: '${e.key}: 고른 아이콘·전체 보기 칸까지 한 줄(6칸)에 들어가야 한다');
      expect(e.value.toSet(), hasLength(e.value.length), reason: e.key);
      for (final icon in e.value) {
        expect(routineIconChoices, contains(icon), reason: '${e.key} $icon');
      }
    }
  });

  test('꾸밈 문자가 붙은 이모지와 예전 이모지도 같은 그림을 찾고, 모르는 이모지는 글자로 둔다', () {
    expect(routineIconAsset('🌤️'), 'assets/icons/sun.png');
    expect(routineIconAsset('✍️'), 'assets/icons/note.png');
    expect(routineIconAsset('🌅'), 'assets/icons/sun.png');
    expect(routineIconAsset('🦄'), isNull);
  });

  test('배지 12개와 빈 화면 안내의 이모지도 모두 앱 그림으로 이어진다', () {
    for (final b in badgeDefs) {
      expect(routineIconAsset(b.emoji), isNotNull, reason: '배지 ${b.name}');
      expect(File(routineIconAsset(b.emoji)!).existsSync(), isTrue, reason: '배지 ${b.name}');
    }
    for (final e in ['🌱', '☕', '📭', '🪙', '📦', '💌']) {
      expect(File(routineIconAsset(e)!).existsSync(), isTrue, reason: e);
    }
  });

  test('알림: 루틴 알림은 글에 이모지 없이 옆 그림으로, 마감 알림은 글 앞의 💌만', () {
    final r = Routine(id: 'a', name: '일어나기', emoji: '🌤️');
    expect(routineAlarmBody(r), '일어나기, 할 수 있을 때 해봐요.');
    expect(routineIconAsset(r.emoji), 'assets/icons/sun.png'); // 알림 옆에 붙는 그림
    expect(dayEndTitle, '💌 오늘 하루도 수고했어요');
  });
}
