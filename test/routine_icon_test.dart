import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/badges.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/ui/routine_icon.dart';

void main() {
  test('아이콘 32개가 모두 파일로 있고, 서로 다른 그림을 가리킨다', () {
    expect(routineIconChoices, hasLength(32));
    expect(routineIconAssets.values.toSet(), hasLength(32));
    expect(Directory('assets/icons').listSync().where((f) => f.path.endsWith('.png')), hasLength(48));
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
}
