# 나의 루틴 공유 — 1단계 상세 기획 (2026-11-25)

전체 기획은 `PLAN_FRIEND_SHARE.md`. 이 문서는 그중 **1단계: 공유 · 구경 · 친구 추가 · 친구 목록 · 내 루틴에 추가** 만 다룬다.
친구 루틴 알림(2단계), 초대 보상 · Install Referrer · 가입 직후 코드 붙여넣기 안내(3단계)는 넣지 않는다.

## 1. 범위

| 넣는다 | 넣지 않는다 (다음 단계) |
|---|---|
| 공유할 루틴 고르기, 초대 코드 만들기 | 친구 루틴 시간 알림 (2단계) |
| 카카오톡 공유 카드 + 다른 앱으로 글 공유 | 초대 보상 코인 (3단계) |
| 카톡 카드 버튼으로 앱 열기 → 구경 화면 | Android Install Referrer 자동 이어받기 (3단계) |
| 코드 직접 입력해서 구경 | 가입 직후 "받은 코드 있나요?" 안내 (3단계) |
| 친구 추가 · 친구 목록 · 친구 끊기 | 친구 완료 여부 · 기록 · 레벨 · 순위 (계속 안 함) |
| 친구 루틴을 내 루틴에 복사 | |
| 공유 루틴 바꾸기 · 공유 멈추기 | |
| 개인정보 처리방침 문구 추가 | |

앱이 없는 친구도 1단계에서 들어올 수 있다: 카톡 카드 → 스토어 설치 → 가입 → **친구 화면에서 코드 입력** (3단계에서 자동화).

## 2. 화면과 흐름

### 2-1. 보내는 사람

**진입**: 루틴 관리 화면 앱바에 공유 아이콘(`Icons.ios_share_rounded`) 추가 (지금은 "알림 설정" 버튼 하나뿐).
나 화면에 새 섹션 "친구" → "루틴 공유" 타일 (켜짐 · N개 / 꺼짐) 에서도 같은 화면으로 간다.

**루틴 공유 화면** (`RoutineShareScreen`)
```
┌ 루틴 공유 ───────────────────┐
│ 친구에게 보여 줄 루틴을 골라요   │
│ ☑ 🧘 아침 스트레칭  07:00 월~금 │
│ ☑ 💧 물 한 잔       언제든 매일 │
│ ☐ 📖 독서           22:00 매일 │
│                               │
│ 보이는 것: 이름·시간·요일·미니미 │
│ 안 보이는 것: 메모·기록·달성률   │
│                               │
│ 내 코드  HARU-K7QM-3XPD [복사]  │
│                               │
│ [ 카카오톡으로 보내기 ]          │
│ [ 다른 앱으로 보내기 ]           │
│ 공유 멈추기                     │
└───────────────────────────────┘
```
- 처음 열면 모두 선택. 쉬는 루틴(`active == false`)도 목록에 보이되 처음엔 선택 안 함.
- 하나도 안 고르면 보내기 버튼 비활성.
- 처음 보낼 때 서버에 공유를 만들고 코드를 받는다. 이후엔 같은 코드.
- 선택을 바꾸면 바로 저장(서버 스냅숏 갱신).
- **공유 멈추기** → 확인 창 "멈추면 지금 코드는 더는 쓸 수 없고, 친구 목록에서도 빠져요" → 서버 줄 삭제.

**자동 갱신**: 공유 중인 루틴의 이름·이모지·시간·요일을 고치거나 지우면, 미니미·닉네임을 바꾸면 스냅숏을 다시 올린다.
(앱 저장 직후 시도, 실패하면 "올려야 함" 표시를 남겨 다음 실행·동기화 때 다시.)

### 2-2. 받는 사람

**카톡 카드 → 앱이 있을 때**: "구경하러 가기" → 앱이 열리며 코드 수신 → 로그인·온보딩이 끝난 상태면 바로 구경 화면.
아직이면 코드를 기기에 저장해 두었다가 온보딩이 끝난 직후 구경 화면을 띄운다.

**카톡 카드 → 앱이 없을 때**: 카카오가 스토어로 보냄 → 설치 → 가입 → 나 → 친구 → **코드로 추가**.

**다른 앱으로 받은 글**: 코드를 복사 → 나 → 친구 → 코드로 추가.

**구경 화면** (`FriendPreviewScreen`)
```
┌───────────────────────────────┐
│        (미니미)                 │
│   민영님이 루틴을 공유했어요       │
│ 🧘 아침 스트레칭  07:00 월~금    │
│ 💧 물 한 잔       언제든 매일    │
│                               │
│ [ 친구 추가 ]   [ 닫기 ]        │
└───────────────────────────────┘
```
- 이미 친구면 버튼이 "친구 루틴 보기".
- 내 코드면 "내가 공유한 루틴이에요" + 닫기만.
- 코드가 없거나 멈춘 공유면 "공유가 끝났거나 코드가 맞지 않아요".
- 조회 제한에 걸리면 "잠시 후 다시 해 주세요".

**친구 화면** (나 → 친구 → "친구 루틴 · N명")
- 친구 카드 목록: 미니미 · 닉네임 · 루틴 N개. 빈 상태 "친구에게 받은 코드를 넣어 보세요" + [코드로 추가].
- 앱바 [코드로 추가] → 입력 창 (대소문자·하이픈·공백 무시, 8자 맞으면 확인 활성).

**친구 루틴 화면** (`FriendRoutinesScreen`)
- 루틴마다 [내 루틴에 추가] → 새 id로 복사 (이름·이모지·시간·요일·카테고리, 알림은 꺼진 채, 메모 없음) → 스낵바 "내 루틴에 추가했어요".
  이미 복사한 루틴은 "추가함 ✓" (기기에 원본 id 기록, 지워도 다시 추가 가능).
- 앱바 메뉴 "친구 끊기" → 확인 → 목록에서 빠짐. (상대에게 알리지 않음)
- 당겨서 새로고침. 친구 목록은 화면 열 때마다 서버에서 받는다 (기기 캐시는 오프라인 표시용).

## 3. 초대 코드

- 서버에서 만든다. 글자: `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (헷갈리는 0 O 1 I L 뺀 31자), **8자** → 31⁸ ≈ 8.5 × 10¹¹.
- 보여 줄 때 `HARU-K7QM-3XPD`. 입력은 `HARU-` · 하이픈 · 공백 · 소문자 모두 받아서 8자로 정규화.
- 형식 검사는 앱(입력 창·카카오 값)과 서버(함수 첫 줄) 양쪽에서. 안 맞으면 서버에 묻지도 않는다.
- **조회 제한**: 없는 코드 조회를 계정당 하루 20번까지 (`share_lookups` 표). 넘으면 거절. → 무작위 대입 차단.
- 공유를 멈추면 줄이 지워지며 코드도 사라진다. 다시 켜면 새 코드.

## 4. 서버 (Supabase) — `supabase/migrations/2026112xxxxxxx_routine_shares.sql`

### 표

```sql
routine_shares (
  user_id    uuid primary key references auth.users on delete cascade,
  code       text not null unique,          -- 8자
  nickname   text not null default '',      -- 최대 20자
  look       jsonb not null default '{}',   -- 미니미 그리기용 (아래)
  routines   jsonb not null default '[]',   -- 공유 루틴 스냅숏, 최대 30개
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
)
friend_follows (
  follower   uuid references auth.users on delete cascade,
  owner      uuid references auth.users on delete cascade,
  alarm      boolean not null default false,   -- 2단계에서 씀. 지금 만들어 두어 마이그레이션을 줄인다
  created_at timestamptz not null default now(),
  primary key (follower, owner)
)
share_lookups ( user_id uuid, day date, misses int, primary key (user_id, day) )
```

RLS
- `routine_shares`: 본인 줄 select/delete 만. insert/update 는 함수로만 (코드를 직접 정하지 못하게).
- `friend_follows`: follower 본인 줄 select/delete 만. insert 는 함수로만.
- `share_lookups`: 정책 없음 (함수만 씀).
- **다른 사람 줄은 어떤 표도 직접 못 읽는다.** 남의 공유는 함수로만, 정해진 칸만 돌려준다.

### 함수 (모두 `security definer set search_path = ''`, anon 실행 권한 회수)

| 함수 | 하는 일 |
|---|---|
| `save_routine_share(p_nickname, p_look, p_routines)` → code | 없으면 만들고(코드 생성, 충돌 시 재시도) 있으면 스냅숏 갱신. 입력 검사 (아래) |
| `stop_routine_share()` | 내 공유 줄 삭제 + 나를 따르는 `friend_follows` 삭제 |
| `get_shared_routines(p_code)` → nickname, look, routines, is_me, following | 코드 형식 검사 → 조회 제한 확인 → 없으면 misses+1 하고 빈 결과 |
| `follow_share(p_code)` → ok, reason | 본인 코드 거절, 친구 10명 넘으면 거절, 이미 친구면 그대로 ok |
| `my_friend_routines()` → owner, nickname, look, routines, updated_at | 내가 따르는 사람 중 **지금 공유 중인** 사람만 |
| 친구 끊기 | `friend_follows` delete (RLS로 본인 줄만) |

입력 검사 (`save_routine_share`) — 앱이 보내는 값을 믿지 않는다
- `p_routines`: 배열, 30개 이하. 각 항목은 아래 칸만 남기고 버린다.
  `id`(문자 40자 이하) · `name`(1~30자) · `emoji`(1~16바이트) · `minute`(null 또는 0~1439) · `weekdays`(1~7 숫자 배열, 7개 이하) · `category`(20자 이하)
  → 하나라도 틀리면 예외 (앱은 일반 문구로 "저장하지 못했어요").
- `p_nickname`: 앞뒤 공백 제거, 20자 이하.
- `p_look`: 정해진 키만 (`minimi` 9개 정수 0~99, `outfitId`·`accessoryId`·`earringId`·`bottomId` 40자 이하 문자 또는 null, `itemColors` 10개 이하 문자→정수). 그 밖의 키는 버린다.
- 전체 크기 상한 (예: routines 16KB, look 2KB).

메모(`memo`) · 알림 여부(`alarmOn`) · 쉬는 상태(`active`)는 **앱이 아예 보내지 않고**, 서버도 받으면 버린다.

## 5. 앱 코드

### 새 파일
| 파일 | 내용 |
|---|---|
| `lib/data/friends.dart` | `InviteCode` (정규화·형식 검사·표시), `SharedRoutine` (스냅숏 한 줄, `fromRoutine` / `toMyRoutine`), `SharedLook` (Profile ↔ look json), `FriendShare` (닉네임·look·루틴들) |
| `lib/ui/friends/routine_share_screen.dart` | 루틴 공유 화면 |
| `lib/ui/friends/friend_preview_screen.dart` | 구경 화면 |
| `lib/ui/friends/friends_screen.dart` | 친구 목록 + 코드 입력 창 |
| `lib/ui/friends/friend_routines_screen.dart` | 친구 루틴 + 내 루틴에 추가 |
| `lib/data/kakao_share.dart` | 카카오 SDK 감싸기 (보내기, 앱 실행 값 받기). 테스트에선 가짜로 바꿈 |
| `supabase/migrations/…_routine_shares.sql` | 위 4장 |
| `test/friends_test.dart` | 아래 7장 |

### 고치는 파일
| 파일 | 바뀌는 것 |
|---|---|
| `lib/data/sync.dart` | `Remote` 에 `saveRoutineShare` · `stopRoutineShare` · `myRoutineShare` · `lookupShare` · `follow` · `unfollow` · `friendRoutines` 추가 (방 공개처럼 동기화를 거치지 않고 바로 묻는 것) |
| `lib/data/supabase_remote.dart` | 위 메서드 구현 (rpc) |
| `test/sync_test.dart` | `FakeServer` 에 같은 메서드 |
| `lib/data/models.dart` | `Profile.sharedRoutineIds` (Set, 동기화됨), `Profile.copiedFrom` (원본 id → 내 id, 기기만이어도 됨) |
| `lib/data/store.dart` | 루틴 고치기·지우기·미니미·닉네임 변경 시 공유 갱신 예약. 지운 루틴은 `sharedRoutineIds` 에서 빠짐 |
| `lib/ui/routines.dart` | 앱바 공유 버튼 |
| `lib/ui/settings.dart` | 나 화면 "친구" 섹션 (루틴 공유 · 친구 루틴) |
| `lib/app.dart` | 카카오 실행 값 수신 → 기기에 코드 저장 → 로그인·온보딩 뒤 구경 화면 |
| `lib/config.dart` | `KakaoConfig.nativeAppKey`, 카드 이미지 주소, 스토어 주소 |
| `pubspec.yaml` | `kakao_flutter_sdk_share` |
| `ios/Runner/Info.plist` | URL scheme `kakao{키}`, `LSApplicationQueriesSchemes` 에 `kakaokompassauth` · `kakaolink` |
| `android/app/src/main/AndroidManifest.xml` | `kakao{키}://kakaolink` intent-filter, `<queries>` 에 카카오톡 패키지 |
| `docs/privacy/index.html` | 공유 항목 추가 (아래 8장) |
| `docs/share/card.png` (새) | 카톡 카드 이미지. GitHub Pages 로 공개 (자체 도메인 불필요) |

### 카카오톡 공유
- 기본 피드 템플릿 (콘솔에 템플릿을 따로 만들지 않는다).
  - 제목 "민영님의 루틴을 구경해 보세요", 설명 "하루살이에서 같이 해요 · 코드 HARU-K7QM-3XPD", 이미지 `docs/share/card.png`
  - 버튼 "구경하러 가기": `androidExecutionParams` · `iosExecutionParams` = `{code: K7QM3XPD}`
- 카카오톡이 없으면 "다른 앱으로 보내기"로 넘긴다 (웹 공유는 쓰지 않음).
- 네이티브 앱 키는 비밀값이 아니라 앱 안(Info.plist URL scheme)에 들어갈 수밖에 없는 공개 식별자다. 대신 카카오 콘솔에 번들 ID · 패키지 · 키 해시를 등록해 다른 앱이 이 키로 공유하지 못하게 한다.
- 받은 실행 값도 외부 입력 → `InviteCode.parse` 통과한 것만 쓴다.

### 다른 앱으로 공유 (`share_plus`, 이미 있음)
```
민영님이 하루살이에서 루틴을 공유했어요 🌱
앱에서 나 → 친구 → 코드로 추가에 넣어 주세요.
코드: HARU-K7QM-3XPD

iPhone: https://apps.apple.com/app/id6834387060
Android: https://play.google.com/store/apps/details?id=com.harusari.app
```
(Android 링크는 프로덕션 출시 전엔 테스터만 받을 수 있다.)

### 오류 처리
- 서버 오류·네트워크 실패는 화면에 일반 문구만 ("지금은 불러오지 못했어요. 잠시 후 다시 해 주세요"), 자세한 건 `debugPrint` 로만.
- 로그에 초대 코드 전체를 남기지 않는다 (앞 2자 + `…`).

## 6. 작업 순서

1. ✅ 마이그레이션 SQL 작성 → 대시보드에서 실행 (2026-11-25, 임시 Postgres 16 에서 먼저 검증)
2. ✅ `friends.dart` 모델 + `Remote` 메서드 + `FakeServer` + 단위 테스트
3. ✅ 루틴 공유 화면 + 자동 갱신 (`routine_sharing.dart`)
4. ✅ 친구 화면 · 코드 입력 · 구경 화면 · 친구 루틴 화면 · 내 루틴에 추가 (`lib/ui/friends/`)
5. ✅ 카카오 SDK 연동 (`kakao_flutter_sdk_share` 2.1.0, `kakao_share.dart`, `invite_scope.dart`). 콘솔: 네이티브 앱 키, iOS 번들·앱스토어 ID, Android 패키지·키 해시 4개(업로드 1, Play 앱 서명 3) 등록함
6. ✅ 개인정보 처리방침(`docs/privacy`) · 카드 이미지(`docs/share/card.png`, `tool/make_share_card.dart`)
7. 실기기 두 대로 확인 (아래 9장) → 출시

1~4는 카카오 준비 없이 진행할 수 있다.

## 7. 테스트 (자동)

- `InviteCode`: 소문자·하이픈·`HARU-`·공백 정규화, 0/O/1/I/L 들어간 값 거절, 7자·9자 거절
- `SharedRoutine.fromRoutine`: 메모·알림·active 가 빠지는지
- `toMyRoutine`: 새 id, 알림 꺼짐, 메모 빈 값
- 루틴을 지우면 `sharedRoutineIds` 에서 빠지고 갱신이 예약되는지
- 공유 꺼짐 상태에선 루틴을 고쳐도 서버에 올리지 않는지
- 로그인 전에 받은 코드가 온보딩 뒤에 한 번만 처리되는지
- FakeServer 로: 본인 코드 follow 거절, 멈춘 공유는 친구 목록에서 빠짐

## 8. 개인정보 처리방침에 넣을 것

- 루틴 공유를 켜면 고른 루틴의 이름·이모지·시간·요일·카테고리와 닉네임·미니미 모습이 **코드를 가진 사람**에게 보인다.
- 메모, 기록, 달성률, 코인·레벨은 보이지 않는다.
- 공유를 멈추거나 탈퇴하면 서버의 공유 정보와 친구 관계가 지워진다.

## 9. 실기기 확인 (사람)

| # | 상황 | 기대 |
|---|---|---|
| 1 | A가 루틴 2개 골라 카톡 공유 | 카드에 닉네임·코드·버튼 |
| 2 | 앱 있는 B가 카드 버튼 | 앱이 열리고 구경 화면 |
| 3 | 앱 없는 B (또는 삭제 후) | 스토어로 이동 → 설치·가입 → 코드 입력 → 구경 |
| 4 | B 친구 추가 → 내 루틴에 추가 | 내 루틴에 생기고 알림은 꺼져 있음 |
| 5 | A가 루틴 시간 바꿈 | B가 친구 화면 새로고침하면 바뀐 시간 |
| 6 | A가 공유 멈춤 | B 친구 목록에서 빠짐, 예전 코드 입력 시 "공유가 끝났어요" |
| 7 | 틀린 코드 21번 | 21번째부터 "잠시 후 다시" |
| 8 | 로그아웃 상태에서 카드 버튼 → 로그인 | 로그인·온보딩 뒤 구경 화면 |

## 10. 사용자가 미리 할 일

- 카카오 개발자 콘솔 → 내 애플리케이션 (없으면 만들기)
  - 플랫폼 iOS: 번들 ID, App Store ID `6834387060`
  - 플랫폼 Android: 패키지 `com.harusari.app`, 키 해시 2개 — 업로드 키, **Play 앱 서명 키** (Play Console → 앱 무결성 → 앱 서명의 SHA-1을 변환)
  - 카카오톡 공유 사용 설정, **네이티브 앱 키** 알려 주기
- 1단계 마이그레이션 실행 (작성 후)

## 11. 정한 것 (2026-11-25)

1. 친구 수 상한 **10명** (`follow_share` 에서 거절, 앱은 "친구는 10명까지 추가할 수 있어요")
2. 공유를 멈추면 **친구 관계도 끊는다**. 다시 켜면 새 코드로 다시 친구 추가해야 한다
3. 공유 문구는 **위 초안대로**. `lib/config.dart` 한 곳에 모아 나중에 바꾸기 쉽게
4. **따로 먼저 출시**: 루틴 공유 1단계 = 1.2.0 (12월 초), 크리스마스 한정 아이템 = 1.3.0 (12월 중순)
