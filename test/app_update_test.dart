import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/config.dart';
import 'package:haru_sari/data/app_update.dart';

void main() {
  test('AppVersion.build 가 pubspec 빌드 번호와 같다', () {
    final m = RegExp(r'^version:\s*\S+\+(\d+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(AppVersion.build, int.parse(m.group(1)!));
  });

  group('AppUpdate.decide', () {
    Map<String, dynamic> row({int latest = 0, int min = 0, String url = 'https://apps.apple.com/app/id6834387060'}) => {
      'latest_build': latest,
      'min_build': min,
      'message': '',
      'store_url': url,
    };

    test('최신이면 띄우지 않는다', () => expect(AppUpdate.decide(row(latest: 3), build: 3), isNull));
    test('낮으면 닫을 수 있는 안내', () => expect(AppUpdate.decide(row(latest: 4), build: 3)!.force, isFalse));
    test('나중에 누른 번호는 다시 안 뜬다', () => expect(AppUpdate.decide(row(latest: 4), build: 3, dismissed: 4), isNull));
    test('더 새 번호가 오면 다시 뜬다', () => expect(AppUpdate.decide(row(latest: 5), build: 3, dismissed: 4), isNotNull));
    test('최소보다 낮으면 나중에를 눌렀어도 꼭 해야 하는 안내', () {
      final u = AppUpdate.decide(row(latest: 4, min: 4), build: 3, dismissed: 4)!;
      expect(u.force, isTrue);
    });
    test('스토어 주소가 없으면 띄우지 않는다', () => expect(AppUpdate.decide(row(latest: 9, min: 9, url: ''), build: 3), isNull));
    test('Play 스토어 주소도 연다', () {
      final u = AppUpdate.decide(row(latest: 9, url: 'https://play.google.com/store/apps/details?id=com.harusari.app'), build: 3);
      expect(u, isNotNull);
    });
    test('스토어가 아닌 주소는 띄우지 않는다', () {
      for (final url in [
        'https://evil.example.com/app',
        'http://apps.apple.com/app/id6834387060',
        'https://apps.apple.com.evil.example/app',
        'javascript:alert(1)',
      ]) {
        expect(AppUpdate.decide(row(latest: 9, min: 9, url: url), build: 3), isNull, reason: url);
      }
    });
  });
}
