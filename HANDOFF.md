# 이어서 할 일 (2026-11-20)

다른 PC에서 이어서 작업하기 위한 메모. 끝나면 지운다.

## 이번에 한 것

**업데이트 안내 팝업** (커밋 `89b6fa9`, `58b1b27`)
- 앱을 켤 때 Supabase `app_updates` 테이블을 한 번 확인하고, 필요하면 팝업을 띄운다.
- 코드: `lib/data/app_update.dart` (서버 조회·판단), `lib/ui/update_prompt.dart` (팝업), `lib/app.dart` (연결), `lib/main.dart`
- 빌드 번호: `lib/config.dart` 의 `AppVersion.build` — `pubspec.yaml` 의 `+` 뒤 번호와 같아야 한다 (다르면 `test/app_update_test.dart` 실패).
- 서버에 연결이 안 되거나 5초 넘게 걸리면 팝업 없이 넘어간다.

**팝업 제목 글꼴** — `lib/theme/tokens.dart` 의 `dialogTheme` 에서 MaruBuri SemiBold로 바꿨다 (iOS 22 / Android 24). 앱의 모든 팝업 제목에 적용된다.

## app_updates 테이블

플랫폼(`ios` / `android`)마다 한 줄. 대시보드 Table Editor에서 값만 바꾸면 다음에 앱을 켤 때 반영된다.

| 칸 | 하는 일 |
|---|---|
| `latest_build` | 이보다 낮은 빌드에 "나중에 / 업데이트" 팝업. 나중에를 누르면 이 번호로는 다시 안 뜬다 |
| `min_build` | 이보다 낮은 빌드에 닫을 수 없는 팝업 |
| `message` | 팝업 본문 (비우면 "더 편해진 하루살이를 만나 보세요.") |
| `store_url` | 업데이트 버튼이 여는 주소. 비우면 팝업이 안 뜬다 |

처음 넣는 주소
- iOS: `https://apps.apple.com/app/id6834387060` (RELEASE_IOS.md 의 Apple ID)
- Android: `https://play.google.com/store/apps/details?id=com.harusari.app`

## 남은 일

- [x] Supabase 대시보드 SQL Editor에서 `supabase/migrations/20261120000000_app_updates.sql` 실행 (2026-11-20, android/ios 두 줄 확인)
- [x] Android 는 Play 비공개 테스트 중(프로덕션 전) → 마이그레이션의 android `store_url` 을 비움. 프로덕션 출시 후 Table Editor 에서 채운다
- [x] 버전을 `1.1.1+5` 로, `AppVersion.build` 를 5 로 올림 (iOS 1.1.0 이 이미 출시돼 버전 이름도 올림)
- [x] 업데이트 버튼이 `https://apps.apple.com`, `https://play.google.com` 주소만 열게 막음 (`AppUpdate.isStoreUrl`, 테스트 추가)
- [ ] 실제 기기에서 "업데이트" 버튼이 스토어를 여는지 확인 (시뮬레이터에는 App Store가 없어 못 봄)
- [ ] 새 버전이 스토어에 올라가면 테이블의 `latest_build` 를 그 번호로 바꾼다

## 팝업을 서버 없이 띄워 보는 법

`lib/main.dart` 를 복사해서 import 를 `package:haru_sari/...` 로 바꾸고, `checkUpdate` 를 아래처럼 바꾼 파일을 `-t` 로 실행한다.

```dart
checkUpdate: () async => const AppUpdate(latest: 99, force: false, message: '테스트 문구', storeUrl: 'https://apps.apple.com/app/id6834387060'),
```

```bash
flutter run -t <그 파일 경로>
```

## 다음 기능 후보 (정리만 함)

1. 홈 화면 위젯 (오늘 달성률)
2. 한 달 돌아보기 카드 — `lib/ui/room/room_share.dart` 공유 코드 재사용
3. 루틴 템플릿 묶음
4. 기분 한 칸 (한 줄 메모 옆)
5. 방 방문 + 정해진 응원 스티커
6. 계절·기념일 한정 아이템 — 연말이라 2번과 묶어 내기 좋음
7. 함께하는 루틴 (순위 없음)
