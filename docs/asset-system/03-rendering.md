# 03. 렌더링 기술 검토 (PART 3)

> 상태: **결정안**. 이번 PART에서는 코드를 바꾸지 않았다.

## 1. 결론

**방 화면은 Flutter `CustomPainter` + `GestureDetector`로 만든다. Flame은 도입하지 않는다.**

방의 성격이 다음과 같기 때문이다.
- 정지 장면에 가깝다. 스프라이트는 30개 이하다.
- 미니미 애니메이션은 4~10fps의 프레임 넘기기다.
- 조작은 격자 위 드래그·스냅뿐이다.

이 정도면 게임 엔진 없이 충분하다. 오히려 기존 앱 상태(`AppScope`), 모션 규칙, 위젯 테스트와 바로 맞물리는 쪽이 이익이 크다.

나중에 아래 조건이 생기면 **방 화면만** Flame `GameWidget`으로 옮기는 방안을 다시 검토한다(§5).

## 2. 비교

| 항목 | CustomPainter (현재 방식 확장) | Flame (방 화면에만 도입) |
|---|---|---|
| 기존 코드 변경 범위 | 방 위젯 내부만 교체. 상태·상점·보관함·모션은 그대로 | 방 화면을 `GameWidget`으로 감싸고, `AppState` ↔ 게임 컴포넌트 연결 계층을 새로 만들어야 함 |
| 아이소메트릭 렌더링 | 직접 구현: 좌표 변환 + `drawImageRect`. 공식이 단순해(§02-4) 코드가 적음 | `IsometricTileMapComponent`가 있지만 타일맵 중심. 가구 깊이 정렬·점유는 어차피 직접 구현 |
| 캐릭터 애니메이션 | `Ticker`로 프레임 번호만 바꿔 시트에서 잘라 그림. 4fps idle이면 초당 4번만 다시 그림 | `SpriteAnimationComponent`로 편함. 다만 게임 루프가 계속 60fps로 돎 |
| 드래그·배치 | `GestureDetector` + 좌표 역변환. 앱의 햅틱·모션 규칙을 그대로 사용 | `DragCallbacks`. 앱 쪽 시트·토스트·팝업과 오가는 코드가 늘어남 |
| 터치 좌표 변환 | 위젯 한 곳에서 `(터치 + 스크롤) × dpr / s` | 카메라·뷰포트 변환을 거침. 정수배 확대를 지키려면 카메라 설정을 따로 맞춰야 함 |
| 픽셀 선명도 | `FilterQuality.none` + 정수 위치를 직접 통제 | 가능하지만 카메라 줌·보간 설정을 모두 맞춰야 함 |
| 성능·배터리 | 바뀔 때와 애니메이션 틱 때만 다시 그림. 정적 층은 `Picture`로 캐시 | 게임 루프가 계속 돌아 정적인 방에서는 낭비 |
| 메모리 | 같은 이미지 수라면 비슷함(`ui.Image` 캐시) | 비슷함 + 엔진 오버헤드 |
| iOS / Android | Flutter 기본 기능만 사용 | 지원되지만 의존성이 하나 늘어남 |
| 테스트 | 좌표·충돌·정렬은 순수 Dart 단위 테스트. 화면은 기존 위젯 테스트 방식 | 게임 테스트 도구(`flame_test`)를 따로 익혀야 함. 지금 테스트 체계와 분리됨 |
| 에셋 확장성 | 매니페스트 + 레지스트리로 수백 개도 문제없음(한 방에 그리는 수는 수십 개) | 같음. Flame만의 이점은 없음 |
| 유지보수 | 앱 전체가 하나의 방식(Flutter 위젯) | 방 화면만 다른 프레임워크 규칙을 따름 |

## 3. 선택한 구조

### 3.1 그리는 층과 다시 그리기
```
RoomViewport (가로 스크롤 · 정수배 s 계산 · 터치 → 캔버스 좌표)
└─ SizedBox(512·s/dpr × 432·s/dpr)
   └─ CustomPaint(painter: IsoRoomPainter)
        ├─ 정적 층 A (Picture 캐시): 바닥 · 러그 · 그림자 · 벽 · 벽 장식 · 미니미보다 뒤의 물체
        ├─ 미니미 (매 프레임 틱마다)
        └─ 정적 층 B (Picture 캐시): 미니미보다 앞의 물체 · 편집 UI
```
- 깊이 정렬 결과를 **미니미 위치에서 둘로 나눠** 두 장의 `Picture`로 녹화한다.
- 배치나 미니미 칸이 바뀔 때만 다시 녹화한다. idle 애니메이션 틱에는 미니미만 다시 그린다.
- 캔버스는 네이티브 512×432 좌표로 그린다. `canvas.scale(s / dpr)` 한 번 + `FilterQuality.none`.
- 숨쉬기 같은 애니메이션은 지금처럼 `TickerMode`로 다른 탭에서는 멈춘다. '동작 줄이기'가 켜지면 idle 첫 프레임에 고정한다.

### 3.2 화면 구성
| 화면 | 역할 |
|---|---|
| 내 방 탭 (`RoomScreen`) | 보기 전용 아이소메트릭 방(화면 폭 전체) + **'방 꾸미기'** 버튼. 아래쪽 미니미 상태·보유 아이템 영역은 그대로 |
| 방 꾸미기 (`RoomEditorScreen`, 신규 전체 화면) | 드래그·스냅·회전·보관. 아래 서랍에서 보관함 가구를 끌어다 놓기 |
| 상점·보관함 | 그대로. 사면 빈 자리에 놓기(02 §5.2) |

## 4. 구현 구조와 변경 파일 제안

### 4.1 새 파일
| 파일 | 내용 | 의존 |
|---|---|---|
| `lib/room/iso.dart` | `IsoGrid`: 상수, `toCanvas`/`toGrid`/`tileAt`, `spriteBox`, `pixelScale` | 없음 |
| `lib/room/manifest.dart` | `AssetManifest`·`ItemArt` 파싱, 크기·앵커 계산 | iso |
| `lib/room/layout.dart` | `RoomLayout`(floor·wall·surface·minimi), JSON, `fromLegacyPlaced` 마이그레이션 | catalog |
| `lib/room/occupancy.dart` | `canPlace`, `findFreeSpot`, 벽 칸 | layout, manifest |
| `lib/room/depth.dart` | `sortObjects` | layout, manifest |
| `lib/room/registry.dart` | 이미지 로드·캐시·알파 마스크·팔레트 스왑·누락 판정 | manifest |
| `lib/room/iso_room_painter.dart` | 층 그리기, `Picture` 캐시, 대체 그림 | 위 전부 + `room_painter.dart`(대체 그림) |
| `lib/room/minimi_sprite.dart` | 레이어 순서, 방향(정면·측면·반전), 프레임 | registry |
| `lib/room/room_viewport.dart` | 정수배 크기, 가로 스크롤, 좌표 변환 | iso |
| `lib/ui/room/room_editor_screen.dart` | 편집 화면 | room/* , motion |
| `assets/pixel/manifest.json` | 상태 표시 없음, 처음엔 파일 없음 | — |

### 4.2 바뀌는 파일
| 파일 | 변경 |
|---|---|
| `lib/data/models.dart` | `Profile.room` 추가 (기존 필드 유지) |
| `lib/data/store.dart` | 가구 구매·사용·보관·판정을 `room` 기반으로, 마이그레이션 |
| `lib/data/catalog.dart` | `assetPath` 제거 |
| `lib/ui/room/room_screen.dart` | `RoomView` → `RoomViewport` + 렌더 모드 분기, '방 꾸미기' 버튼 |
| `lib/ui/room/room_painter.dart` | 대체 그림으로 유지, `ItemThumb` 개선 |
| `pubspec.yaml` | `assets/pixel/` 등록. **새 패키지 없음** |
| `test/store_test.dart` | 자동 교체 테스트 1개를 빈 자리 배치 테스트로 교체 |

### 4.3 구현 순서 (PART 4)
각 단계마다 테스트하고 커밋한다.
1. `iso` + `manifest` + 테스트 — 그림 없이 수학만
2. `layout` + 마이그레이션 + `occupancy` + `depth` + 테스트 — 저장 데이터 호환을 먼저 확정
3. `store` 연결(빈 자리 배치) + 기존 테스트 회귀
4. `registry` + `IsoRoomPainter` — **에셋 0개 상태**에서 대체 그림으로 아이소메트릭 방이 그려지는지 확인(플래그 켠 개발 모드에서만)
5. `RoomViewport`(정수배·스크롤) + 보기 전용 방
6. `RoomEditorScreen`(드래그·스냅·회전·보관) + 위젯 테스트
7. `minimi_sprite`(정면·측면·반전, idle) — 레이어가 없으면 기존 미니미
8. 첫 실제 PNG(침대) 적용 → 검증 테스트 → 기준 장면 검수
9. 바닥·벽 PNG가 준비되면 렌더 모드 기본값을 아이소메트릭으로 전환

## 5. Flame을 다시 검토할 조건
- 미니미가 길을 찾아 돌아다니고, 반려동물처럼 여러 캐릭터가 동시에 움직일 때
- 파티클·날씨·조명 변화처럼 매 프레임 갱신이 많은 효과가 필요할 때
- 한 화면 스프라이트가 100개를 넘거나, 카메라 이동·줌이 핵심 조작이 될 때

이때도 방 화면만 `GameWidget`으로 옮긴다. 좌표·충돌·정렬·매니페스트 모듈은 순수 Dart라서 그대로 재사용할 수 있다.

## 6. 미니미 방향 (승인 정책 반영)
- 그리는 것: **정면**(카메라를 봄)과 **측면**(오른쪽을 봄) 두 방향.
- 왼쪽 측면은 측면을 반전해서 만든다. 좌우가 다른 액세서리는 `mirror: false`로 표시하고 왼쪽용을 따로 그린다.
- 아이소메트릭에서 고르는 규칙:
  - 서 있을 때·보상을 받을 때 = 정면
  - 화면 오른쪽으로 움직일 때(+gx, 위쪽 −gy 포함) = 측면
  - 화면 왼쪽으로 움직일 때 = 측면 반전
- 뒷모습은 만들지 않는다. 화면 위쪽으로 걸어가도 측면을 쓴다. 뒷모습이 필요한 기능(예: 창밖 보기)은 별도로 검토한다.
- 시트: idle = 정면 4프레임 + 측면 4프레임 → 256×192. walk(나중) = 측면 6프레임.
