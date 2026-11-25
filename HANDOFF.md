# 이어서 할 일 (2026-11-26)

다른 PC에서 이어서 작업하기 위한 메모. 끝나면 지운다.

> ⚠️ **아직 커밋 안 함.** 아래 "나의 루틴 공유" 작업 전부가 작업 폴더에만 있다 (마지막 커밋 `a912ed3` 은 기획 문서).
> 커밋·푸시는 조직 정책으로 Claude 가 못 한다 → 직접 실행:
> ```
> (2026-11-26 Claude 가 아래 파일을 모두 `git add` 해 두었다 → 바로 commit 하면 된다)
> git add -A PLAN_FRIEND_SHARE.md PLAN_FRIEND_SHARE_STEP1.md HANDOFF.md pubspec.yaml pubspec.lock supabase lib test tool docs art/source/icons assets/icons ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml demo
> git commit -m "나의 루틴 공유 1~3단계, 개발용 로그인·카톡 미리보기, 아이콘, 초대 링크 페이지"
> git push origin main
> ```
> 푸시해야 `docs/` 의 카톡 카드 그림·초대 링크 페이지·개인정보 처리방침이 GitHub Pages 에 올라간다.

---

## 1. 나의 루틴 공유 — 개발 끝, 출시 전

기획: `PLAN_FRIEND_SHARE.md` (전체), `PLAN_FRIEND_SHARE_STEP1.md` (1단계 상세)
시연 캡처 (에뮬레이터, 2026-11-26): `demo/routine_share/index.html` (브라우저로 열기, 캡처 18장) · 온라인 https://claude.ai/artifact/7tWwNxwu8raVcghEPcSMpN
(`docs/` 가 아니라 `demo/` 에 둔 이유: `docs/` 는 GitHub Pages 로 그대로 공개된다)

### 1단계: 공유 · 구경 · 친구 · 내 루틴에 추가
- 나 탭 → **친구** 섹션 → 루틴 공유 / 친구 루틴. 내 루틴 관리 앱바에도 공유 버튼.
- 공유할 루틴 고르기 → **카카오톡으로 보내기** 또는 **다른 앱으로 보내기** → 처음 보낼 때 서버가 초대 코드(`HARU-XXXX-XXXX`, 헷갈리는 0·O·1·I·L 뺀 8자)를 만든다.
- 받는 쪽: 카톡 카드 "구경하러 가기" → 앱이 열리며 구경 화면 / 또는 친구 루틴 → 코드로 추가.
  로그인·첫 설정 전에 받은 코드는 기기에 기억했다가 홈이 뜨면 한 번 연다.
- 친구 추가(10명까지) → 친구 루틴 → 내 루틴에 추가(알림 꺼진 채 복사) · 친구 끊기.
- 공유 멈추기 → 코드 삭제 + 나를 추가한 친구 관계도 끊김. 다시 켜면 새 코드.
- 공유한 루틴·닉네임·미니미를 바꾸면 2초 뒤 서버 스냅숏 자동 갱신 (오프라인이면 다음에).
- 보이는 것: 루틴 이름·이모지·시간·요일·카테고리, 닉네임, 미니미(입은 옷만). 메모·기록·달성률·레벨·코인은 서버로 아예 안 보낸다.

### 2단계: 친구 루틴 알림
- 친구 루틴 화면에서 루틴마다 종 버튼 (흐린 종 = 꺼짐, 흔들리는 종 = 켜짐). **모두 합쳐 5개**까지 (서버가 지킴).
- 알림: "🌱 ○○님의 ‘루틴’ 시간이에요. 같이 해볼까요?" — 매주 반복, 친구가 시간을 바꾸면 앱을 열 때 따라 바뀜.
- iOS 예약 알림 64개 한도 → 내 알림·하루 마감을 먼저 걸고, 친구 알림은 남은 자리(60개 안)에만. 루틴 하나의 요일은 통째로 넣거나 뺀다.

### 3단계: 초대 보상
- 새 친구 30코인 / 초대한 사람 30코인(평생 10명), **가입 48시간 안 · 한 번만**, 내 코드는 안 됨, 재가입은 막지 않음.
- 가입 직후 한 번 "친구에게 초대받았나요?" 창 (대상일 때만). 카톡 카드로 들어온 새 계정은 묻지 않고 바로 보상 → 축하 창.
- Android: "다른 앱으로 보내기" 링크로 설치하면 Install Referrer 로 코드가 미리 채워진다.
  (카톡 카드로 처음 설치하면 카카오 스토어 주소가 고정이라 자동으로 안 넘어온다 → 가입 직후 창에서 입력)
- 익명 계정(개발용 로그인)은 서버가 보상을 막는다.

### 공유 링크
- 카톡 카드: 카카오가 OS 에 맞게 앱 열기 / 스토어 이동.
- 다른 앱 글: 링크 하나 `https://alsdud110.github.io/haru_sari/i/?code=XXXXXXXX` → iPhone 은 App Store, Android 는 Play(코드 포함), PC 는 버튼+코드.
  이동할 곳은 두 스토어로 고정 (오픈 리다이렉트 방지), 코드는 8자 형식만 받음.

### 서버 (Supabase) — 3개 모두 실행함 (2026-11-25~26)
| 파일 | 내용 |
|---|---|
| `supabase/migrations/20261125000000_routine_shares.sql` | `routine_shares`, `friend_follows`, `share_lookups` + 함수 5개. 틀린 코드 조회 하루 20회 제한 |
| `supabase/migrations/20261126000000_friend_alarms.sql` | `friend_follows.alarm_ids`, `set_friend_alarm`, `my_friend_routines` 다시 만듦 |
| `supabase/migrations/20261127000000_invite_rewards.sql` | `invite_claims`, `invite_status`, `claim_invite` (익명 계정 제외) |

남의 공유는 표를 직접 못 읽고 함수로 정해진 칸만 받는다. 앱이 보낸 값은 서버가 다시 검사한다.
세 파일 모두 로컬 Docker(Postgres 16)에서 먼저 검증했다.

### 카카오 개발자 콘솔 — 설정 끝
- 앱 "하루살이"(ID 1647466) → 플랫폼 키 → 네이티브 앱 키 `5ca008b29b4d7516d31e55049ad7b6d9`
  - iOS 번들 ID `com.harusari.app`, 앱스토어 ID `6834387060`
  - Android 패키지 `com.harusari.app`, 키 해시 4개: 업로드 키 `11rzsWdCyd8Ccd0PQlqTyMWk358=` + Play 앱 서명 키 3개
- 카카오톡 공유는 따로 켤 것 없음 (카카오톡 메시지 API·추가 기능 신청 불필요).
- 네이티브 앱 키는 앱 안에 들어가는 공개값. **REST API 키·Client Secret 은 앱·저장소에 넣지 않는다.**

### 주요 코드
| 파일 | 하는 일 |
|---|---|
| `lib/data/friends.dart` | 초대 코드 규칙, 공유 루틴·미니미 모습·친구·알림 모델 |
| `lib/data/routine_sharing.dart` | 내 공유 상태와 자동 갱신 |
| `lib/data/friend_alarm_sync.dart` | 친구 알림을 서버 친구 목록에 맞춤 |
| `lib/data/kakao_share.dart` | 카카오톡 공유·링크 받기·Install Referrer |
| `lib/ui/friends/` | 공유·친구 목록·구경·친구 루틴·초대 보상·초대 받기 화면 |
| `lib/config.dart` | `KakaoConfig`, `ShareCopy`(문구·링크는 여기서만 바꾼다) |
| `docs/i/` | 초대 링크 이동 페이지 (GitHub Pages) |
| `docs/share/card.png` | 카톡 카드 그림 (`dart run tool/make_share_card.dart`) |

새 패키지: `kakao_flutter_sdk_share` 2.1.0, `play_install_referrer` 0.6.0.
iOS `Info.plist`·Android 매니페스트에 `kakao5ca008b2…` 스킴 추가.

### 개인정보 처리방침 (`docs/privacy/index.html`)
루틴 공유 항목·공개 범위·카카오로 가는 정보·친구 알림·초대 보상 기록·Install Referrer·삭제 시점 추가. 시행일 2026-11-25. 푸시하면 바로 공개된다.

---

## 2. 같이 고친 것

- **이모지 줄바꿈 오류** (`lib/theme/tokens.dart` `keepWords`): 이모지를 반으로 갈라 "string is not well-formed UTF-16" 으로 그리지 못하던 원래 있던 버그. 루틴 이름·메모에 이모지를 쓰면 지금 출시 버전에서도 날 수 있었다. `unicode: true` 로 해결, 테스트 추가.
- **빈 화면 안내 가운데 정렬**: 친구 화면들의 `EmptyHint` 가 왼쪽 위에 붙던 것.
- **기본 이모지 → 앱 그림**: 화면에서 기본 이모지로 보이던 곳을 모두 `assets/icons` 그림으로. 새 그림 `bell.png`, `bell_ring.png` (원본 `art/source/icons/bell*_original.png`, `dart run tool/make_icons.dart`), 기존 `check.png` 연결. 알림 문구·공유 글처럼 글자만 들어가는 자리는 이모지 그대로.
- **카카오톡 보내기 버튼**: 로그인 화면과 같은 카카오 공식 말풍선 심볼 (`auth_screens.dart` 의 `kakaoSymbolSvg` 공용으로).

## 3. 개발용 도구 (개발 빌드에서만, 출시 빌드에는 없음)

- **로그인 화면 "개발용: 새 익명 계정으로 시작"** — Supabase 익명 로그인 (대시보드에서 켜 둠). 누를 때마다 새 계정.
  - 익명 로그인이 켜져 있으면 공개 키로 누구나 익명 계정을 만들 수 있다. 코인이 걸린 초대 보상은 서버에서 익명 제외.
  - 더 깔끔하게 하려면 개발용 Supabase 프로젝트를 따로 두는 것 (아직 안 함).
  - 시연하면서 운영 DB 에 익명 계정이 4개쯤 생겼다 → Supabase Authentication → Users 에서 Anonymous 지워도 됨.
- **카카오톡 미리보기 (개발용)** — 카카오톡이 없는 기기(에뮬레이터)에서 카카오톡으로 보내기를 누르면 카톡에 카드가 온 모습을 그려 보여 준다. 카드 버튼은 실제 수신 경로를 탄다.
- 에뮬레이터에서 카톡 링크 받기 흉내:
  `adb shell am start -a android.intent.action.VIEW -d "kakao5ca008b29b4d7516d31e55049ad7b6d9://kakaolink?code=XXXXXXXX" com.harusari.app`

## 4. 확인 상태

- 자동 테스트 229개 통과, `flutter analyze` 문제없음, Android 출시 빌드 성공.
- 에뮬레이터(Pixel 7 Pro, API 36)에서 보내기 → 카톡 링크 수신 → 친구 추가 → 내 루틴에 추가 → 종 알림(기기 예약 목록 확인) → 틀린 코드까지 확인.
- **아직 못 한 것**
  - [ ] 카카오톡이 있는 실제 폰: 친구 고르기 화면, 카드 모양, 카드 버튼으로 앱 열기
  - [ ] 소셜 로그인 새 계정으로 초대 보상 창·30코인 (익명은 막혀서 화면은 위젯 테스트로만 확인)
  - [ ] iOS 빌드 (Mac): 카카오 SDK 가 SPM 으로 들어간다 → `flutter build ipa` 확인
  - [ ] 푸시 뒤 `https://alsdud110.github.io/haru_sari/i/?code=…` 를 폰에서 열어 스토어 이동 확인

## 5. 다음 순서

1. 커밋·푸시 (맨 위)
2. 위 "아직 못 한 것" 실기기 확인
3. **1.2.0 출시** — 버전 `1.2.0+9` (`pubspec.yaml` + `lib/config.dart` `AppVersion.build`), Android AAB → Play 비공개 테스트, Mac 에서 iOS → App Store, 태그 `android/v1.2.0+9` `ios/v1.2.0+9`
   - 새 기능이라 출시 뒤 Supabase `app_updates.latest_build` 를 9 로 올려 업데이트 팝업을 띄울 만하다
4. 크리스마스 한정 아이템 (1.3.0, 12월 중순 목표)
5. Android 프로덕션 신청 (비공개 테스트 14일 뒤). 프로덕션 전에는 테스터가 아닌 친구가 Play 에서 앱을 못 받는다
   - 프로덕션 공개 뒤: AdMob "확인할 앱" → 기존 하루살이 Android 앱(`~3779707649`)에 Google Play 연결, `app_updates` android `store_url` 채우기

---

## 참고: 업데이트 안내 팝업 (`app_updates` 표)

앱을 켤 때 Supabase `app_updates` 를 확인해 팝업을 띄운다. 플랫폼마다 한 줄, 대시보드 Table Editor 에서 값만 바꾸면 된다.

| 칸 | 하는 일 |
|---|---|
| `latest_build` | 이보다 낮은 빌드에 "나중에 / 업데이트" 팝업. 알릴 만한 버전이 출시된 뒤에만 올린다 |
| `min_build` | 이보다 낮은 빌드에 닫을 수 없는 팝업 (꼭 필요할 때만) |
| `message` | 팝업 본문 (비우면 기본 문구) |
| `store_url` | 업데이트 버튼이 여는 주소. 비우면 팝업이 안 뜬다. android 는 프로덕션 전이라 비어 있음 |

빌드 번호: `lib/config.dart` 의 `AppVersion.build` 가 `pubspec.yaml` `+` 뒤 번호와 같아야 한다 (`test/app_update_test.dart`).

## 다음 기능 후보 (정리만 함)

1. 홈 화면 위젯 (오늘 달성률)
2. 한 달 돌아보기 카드 — `lib/ui/room/room_share.dart` 공유 코드 재사용
3. 루틴 템플릿 묶음
4. 기분 한 칸 (한 줄 메모 옆)
5. 방 방문 + 정해진 응원 스티커
6. 계절·기념일 한정 아이템 — 크리스마스로 1.3.0
7. 함께하는 루틴 (순위 없음)
