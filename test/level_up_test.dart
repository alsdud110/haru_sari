import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/app.dart';
import 'package:haru_sari/data/rewards.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/ui/today.dart';

import 'room/manifest_test.dart' show loadManifest;

void main() {
  testWidgets('레벨 달성 창: 새로 열린 아이템에 맞춰 가구 상점·미니미 상점 버튼을 보여 준다', (tester) async {
    final s = AppState(MemoryKeyValue(), clock: () => DateTime(2026, 11, 18, 9), manifest: loadManifest());
    Future<void> open(int level) async {
      await tester.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLevelUp(
                  context,
                  DailyReward(xp: 0, coins: 0, perfect: false, levelsGained: 1, newLevel: level),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    // Lv.2 에는 가구와 미니미 옷이 함께 열린다
    expect(s.unlockedAt(2).any((i) => i.isFurniture) && s.unlockedAt(2).any((i) => !i.isFurniture), isTrue);
    await open(2);
    expect(find.text('가구 상점'), findsOneWidget);
    expect(find.text('미니미 상점'), findsOneWidget);
  });
}
