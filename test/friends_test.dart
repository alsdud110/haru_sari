import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/config.dart';
import 'package:haru_sari/data/friends.dart';
import 'package:haru_sari/data/kakao_share.dart';
import 'package:haru_sari/data/models.dart';

void main() {
  group('InviteCode', () {
    test('여러 모양을 8자로 맞춘다', () {
      for (final raw in ['K7QM3XPD', 'k7qm3xpd', 'HARU-K7QM-3XPD', 'haru-k7qm-3xpd', ' K7QM 3XPD ', 'K7QM-3XPD']) {
        expect(InviteCode.parse(raw), 'K7QM3XPD', reason: raw);
      }
    });

    test('헷갈리는 글자·길이가 틀리면 거절한다', () {
      for (final raw in ['K7QM3XP', 'K7QM3XPDA', 'K0QM3XPD', 'KOQM3XPD', 'K1QM3XPD', 'KIQM3XPD', 'KLQM3XPD', 'K7QM3XP!', '', null]) {
        expect(InviteCode.parse(raw), isNull, reason: '$raw');
      }
      expect(InviteCode.parse('A' * 41), isNull);
    });

    test('붙여 넣은 공유 글에서 찾기, 설치 출처에서 꺼내기', () {
      expect(InviteCode.find('하루님이 공유했어요\n코드: HARU-K7QM-3XPD\niPhone: https://...'), 'K7QM3XPD');
      expect(InviteCode.find(' k7qm3xpd '), 'K7QM3XPD');
      expect(InviteCode.find('코드 없음'), isNull);
      expect(InviteCode.fromReferrer('code=K7QM3XPD'), 'K7QM3XPD');
      expect(InviteCode.fromReferrer('utm_source=google-play&utm_medium=organic'), isNull);
      expect(InviteCode.fromReferrer('code=K0QM3XPD'), isNull);
      expect(InviteCode.fromReferrer(null), isNull);
    });

    test('공유 글에는 링크 하나 (폰에 맞는 스토어로 보내는 초대 페이지, 코드 포함)', () {
      final text = ShareCopy.otherApps('하루', 'K7QM3XPD');
      expect(text, contains('코드: HARU-K7QM-3XPD'));
      final links = RegExp(r'https://\S+').allMatches(text).map((m) => m.group(0)!).toList();
      expect(links, ['https://alsdud110.github.io/haru_sari/i/?code=K7QM3XPD']);
      expect(Uri.parse(links.single).queryParameters['code'], 'K7QM3XPD');
    });

    test('보여 주기·로그 가리기', () {
      expect(InviteCode.display('K7QM3XPD'), 'HARU-K7QM-3XPD');
      expect(InviteCode.masked('K7QM3XPD'), 'K7…');
    });
  });

  group('SharedRoutine', () {
    final mine = Routine(
      id: 'r1',
      name: ' 물 한 잔 ',
      emoji: '💧',
      minuteOfDay: 480,
      weekdays: {3, 1, 2},
      alarmOn: true,
      category: '건강',
      memo: '비밀 메모',
      active: false,
    );

    test('메모·알림·쉬는 상태는 보내지 않는다', () {
      final j = SharedRoutine.fromRoutine(mine).toJson();
      expect(j.keys.toSet(), {'id', 'name', 'emoji', 'minute', 'weekdays', 'category'});
      expect(j['name'], '물 한 잔');
      expect(j['weekdays'], [1, 2, 3]);
    });

    test('내 루틴으로 복사하면 새 id, 알림 꺼짐, 메모 없음', () {
      final r = SharedRoutine.fromRoutine(mine).toMyRoutine('new');
      expect(r.id, 'new');
      expect(r.alarmOn, isFalse);
      expect(r.memo, '');
      expect(r.active, isTrue);
      expect(r.minuteOfDay, 480);
      expect(r.weekdays, {1, 2, 3});
    });

    test('서버 값의 틀린 줄은 버린다', () {
      expect(SharedRoutine.tryParse({'id': 'a', 'name': 'a', 'emoji': 'e', 'weekdays': [1]}), isNotNull);
      expect(SharedRoutine.tryParse({'id': 'a', 'name': 'a', 'emoji': 'e', 'weekdays': <int>[]}), isNull);
      expect(SharedRoutine.tryParse({'id': 'a', 'name': ' ', 'emoji': 'e', 'weekdays': [1]}), isNull);
      expect(SharedRoutine.tryParse({'id': 'a', 'name': 'a', 'emoji': 'e', 'minute': 2000, 'weekdays': [1]}), isNull);
      expect(SharedRoutine.tryParse({'id': 1, 'name': 'a', 'emoji': 'e', 'weekdays': [1]}), isNull);
      expect(SharedRoutine.tryParse('x'), isNull);
      final r = SharedRoutine.tryParse({'id': 'a', 'name': 'a', 'emoji': 'e', 'weekdays': [9, 2, 2, 1]})!;
      expect(r.weekdays, [1, 2]);
      expect(r.category, '기타');
    });
  });

  group('SharedLook', () {
    test('입은 것의 색만 보낸다', () {
      final p = Profile(
        minimi: const Minimi(skin: 2, hairStyle: 5),
        outfitId: 'outfit_knit',
        itemColors: {'outfit_knit': 3, 'outfit_other': 7},
        owned: {'outfit_knit', 'outfit_other'},
      );
      final j = SharedLook.fromProfile(p).toJson();
      expect(j['itemColors'], {'outfit_knit': 3});
      expect(j.containsKey('accessoryId'), isFalse);
      expect(j.containsKey('owned'), isFalse);
    });

    test('서버 값을 그리기용 Profile 로 되돌린다', () {
      final look = SharedLook.fromJson({
        'minimi': {'skin': 2, 'hair': 'x'},
        'outfitId': 'outfit_knit',
        'accessoryId': 3,
        'itemColors': {'outfit_knit': 3, 'bad': '1'},
      });
      final p = look.toProfile();
      expect(p.minimi.skin, 2);
      expect(p.minimi.hair, 0);
      expect(p.outfitId, 'outfit_knit');
      expect(p.accessoryId, isNull);
      expect(p.itemColors, {'outfit_knit': 3});
      expect(SharedLook.fromJson(null).toProfile().outfitId, isNull);
    });
  });

  test('카카오 실행 링크에서 코드 꺼내기', () {
    expect(inviteCodeFromKakaoUri(Uri.parse('kakao5ca0://kakaolink?code=K7QM3XPD')), 'K7QM3XPD');
    expect(inviteCodeFromKakaoUri(Uri.parse('kakao5ca0://kakaolink?code=k7qm-3xpd')), 'K7QM3XPD');
    expect(inviteCodeFromKakaoUri(Uri.parse('kakao5ca0://kakaolink?code=K0QM3XPD')), isNull);
    expect(inviteCodeFromKakaoUri(Uri.parse('kakao5ca0://kakaolink')), isNull);
    expect(inviteCodeFromKakaoUri(Uri.parse('kakao5ca0://other?code=K7QM3XPD')), isNull);
    expect(inviteCodeFromKakaoUri(Uri.parse('https://evil.example/kakaolink?code=K7QM3XPD')), isNull);
  });

  group('서버 결과', () {
    test('구경 결과', () {
      final ok = ShareLookup.fromRow({
        'status': 'ok',
        'nickname': '',
        'look': {},
        'routines': [
          {'id': 'a', 'name': '물', 'emoji': '💧', 'weekdays': [1]},
          {'broken': true},
        ],
        'is_me': false,
        'following': true,
      });
      expect(ok.status, LookupStatus.ok);
      expect(ok.following, isTrue);
      expect(ok.share!.routines.map((e) => e.id), ['a']);
      expect(ok.share!.displayName, '친구');
      expect(ShareLookup.fromRow({'status': 'limited'}).status, LookupStatus.limited);
      expect(ShareLookup.fromRow({'status': 'what'}).status, LookupStatus.notFound);
    });

    test('친구 목록 줄', () {
      final f = FriendShare.fromRow({
        'owner': 'u1',
        'nickname': ' 하루 ',
        'look': 'not a map',
        'routines': 'not a list',
        'updated_at': '2026-11-25T01:00:00Z',
      });
      expect(f.owner, 'u1');
      expect(f.displayName, '하루');
      expect(f.routines, isEmpty);
      expect(f.updatedAt, DateTime.utc(2026, 11, 25, 1));
    });
  });
}
