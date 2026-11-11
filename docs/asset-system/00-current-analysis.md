# 00. 현재 시스템 분석 (PART 0)

> 조사일: 2026-11-11 · 기준 커밋: `1e02361` (README 작성)
> PART 0에서는 코드를 바꾸지 않았다. 아래 내용은 모두 현재 소스에서 직접 확인한 사실이다.

## 1. 요약

| 질문 | 현재 상태 | 픽셀·아이소메트릭 전환 시 의미 |
|---|---|---|
| 미니미 렌더링 | `MinimiPainter`(CustomPainter)가 **벡터 도형**으로 그림. 정면 1방향, 프레임 없음 | 스프라이트 레이어 렌더러로 **새로 작성** 필요. 데이터 모델(`Minimi`, `outfitId`, `accessoryId`)은 재사용 가능 |
| 방 렌더링 | `RoomPainter`가 **정면 2D 단면**(벽 60% + 바닥 40%)을 벡터로 그림 | 아이소메트릭 좌표계·깊이 정렬이 없음 → **렌더러 교체**. 위젯 껍데기(`RoomView`)는 재사용 |
| 가구 위치 | 자리(`RoomSlot`) **10개 고정**, 자리당 가구 1개. 좌표는 방 크기 대비 비율 상수 | 그리드 좌표·회전 **저장 불가**. 저장 구조 확장 필요 (마이그레이션 포함) |
| 구매·장착·보관 | `AppState.buy/use/putAway`, 같은 자리에 놓으면 기존 가구는 자동 보관 | 규칙은 재사용하되, '자리당 1개' 규칙은 자유 배치와 충돌 → 결정 필요 |
| 아이템 ID | `ShopItem.id` 문자열 (예: `desk_wood`), 26개 | 그대로 **assetId로 재사용** 가능 |
| 에셋 로딩 | `pubspec.yaml`에 assets 없음. `ShopItem.assetPath`가 있지만 **모두 null**, 썸네일에서만 참조 | 에셋 레지스트리·프리로드·누락 처리 **없음** |
| 커스터마이징 | 색 인덱스 3개(피부·머리·옷 색) + 의상 1개 + 액세서리 1개 | 색 바꾸기는 **팔레트 스왑**으로 이어갈 수 있음 |

결론: **데이터·상태·상점·보상 계층은 거의 그대로 재사용**할 수 있다. 반면 **그림을 그리는 계층(painter 두 개)은 교체 대상**이다. 기존 벡터 그림은 에셋이 없을 때의 대체 그림과 테스트용 그림으로 남길 수 있다.

## 2. 관련 파일 지도

| 파일 | 줄 수 | 역할 |
|---|---|---|
| `lib/ui/room/room_painter.dart` | 726 | `slotRect`(자리 → 비율 영역), `RoomPainter`, `drawFurniture`, `drawWallpaper`, `MinimiPainter`, `MinimiView`, `ItemThumb`, `_ThumbPainter` |
| `lib/ui/room/room_screen.dart` | 626 | `RoomScreen`(내 방 탭), `RoomView`(방 + 숨 쉬는 미니미), `ShopScreen`, `StorageScreen`, `showItemSheet` |
| `lib/data/catalog.dart` | 149 | `RoomSlot`(10), `ItemKind`(가구·의상·액세서리), `ShopCategory`, `ShopItem`, `shopCatalog`(26), 루틴 템플릿 |
| `lib/data/store.dart` | 385 | `AppState`: 구매·사용·보관, `placedFurniture`, `storedItems`, 저장(`KeyValue`) |
| `lib/data/models.dart` | 260 | `Minimi`, `Profile`(owned·placed·acquired·outfitId·accessoryId·badges), `DayLog`, `Routine` |
| `lib/theme/tokens.dart` | — | `AppColors`(방 색 `wall`, `floor`, `wood` 등 포함), `Space`, `Radii`, `Motion` |
| `pubspec.yaml` | — | 에셋 선언 없음. 렌더링 관련 패키지 없음(Flame 없음) |

## 3. 미니미 렌더링 구조

- `MinimiPainter(Minimi m, {happy, outfit, accessory})`
  - `outfit`, `accessory`는 **ShopItem.variant 번호**(0~5)다. 번호마다 `switch`로 그린다.
  - 그리는 순서: 그림자 → 다리 → (후드) → 몸통/옷 → 팔 → 머리 → 머리카락 → 얼굴 → 액세서리.
  - 비율: 머리가 캔버스 높이의 50%라 이미 약 2등신이다.
- `MinimiView(profile)`: `itemById(profile.outfitId)?.variant`로 변형 번호를 꺼내 넘긴다.
- 색: `skinTones`(4), `hairColors`(4), `outfitColors`(4). `Minimi`가 인덱스를 저장한다.
- 애니메이션: `RoomView`에서 2.6초 주기로 위아래 2px 흔들리는 **숨쉬기** 하나뿐이다(`Transform.translate`).
- 방향·프레임·레이어 분리: **없음**.

**재사용 가능**
- `Minimi` 모델(색 인덱스) → 팔레트 스왑 인덱스로 그대로 쓴다.
- `outfitId`, `accessoryId` 저장 → 그대로 쓴다.
- `MinimiView`의 API(프로필을 받아 그림) → 내부만 스프라이트로 바꾼다.

**재사용 불가**
- 벡터 그림 코드. 픽셀 아트로 자동 변환되지 않는다.

## 4. 방·가구 렌더링 구조

- `RoomView`: `AspectRatio(1.1)` 안에서 `RoomPainter`와 미니미를 `Stack`으로 겹친다.
  - 미니미는 방 폭의 20%, 세로 60% 지점에 고정된다(이동 없음).
  - 폭 390pt 폰 기준으로 방은 약 350×318 논리 픽셀이다.
- `RoomPainter`
  - 벽(높이 60%) → 바닥(마루 줄 5개) → 걸레받이 → 정해진 순서(`_drawOrder`)로 가구를 그린다.
  - 깊이는 **고정 순서**(창문 → … → 화분)로 처리한다. 위치가 고정이라 가능한 방식이다.
- `slotRect(slot, size)`: 자리마다 방 크기 대비 비율 영역이 하드코딩돼 있다.
  - 예: 침대 `(0.12, 0.47) ~ (0.50, 0.80)`
- `drawFurniture(canvas, item, rect)`: `item.slot`과 `variant`로 분기해 벡터로 그린다. 썸네일도 같은 함수를 쓴다.
- **`RoomPainter`는 `assetPath`를 보지 않는다.** 에셋이 생겨도 방에는 반영되지 않는 구조다.

## 5. 구매·장착·보관 방식

| 동작 | 코드 | 규칙 |
|---|---|---|
| 구매 | `AppState.buy(item)` | 레벨 ≥ `item.level`, 코인 ≥ `price`, 미보유일 때만. 사면 바로 사용(`_use`). `acquired[id]`에 날짜 기록 |
| 사용 | `use(item)` | 가구: `placed[slot.name] = id` (같은 자리의 기존 가구는 보관으로 밀려남). 옷: `outfitId`. 액세서리: `accessoryId` |
| 보관 | `putAway(item)` | 가구: `placed`에서 제거. 옷·액세서리: null |
| 목록 | `placedFurniture`, `storedItems` | 보관함 = 보유했지만 사용 중이 아닌 것 |

- 보상 정책(PL-BBQESH)과 레벨 잠금은 `canBuy`에만 있고, 그림 계층과 독립적이다. **전환해도 그대로 유지할 수 있다.**
- **'자리당 1개' 규칙**은 지금 상점의 핵심 동작이다(사면 자동 교체). 자유 배치로 가면 같은 종류(침대 2개 등)를 여러 개 둘지 결정해야 한다 → PART 2의 결정 사항.

## 6. 아이템 ID와 저장 구조

- 저장소: `KeyValue`(SharedPreferences), 계정별 접두어 `u/<uid>/`.
- 키: `routines`, `logs`, `profile`, `onboarded`(JSON 문자열).
- `Profile` 중 방 관련 필드:
  ```json
  "owned":    ["rug_round", "desk_wood", "outfit_knit"],
  "placed":   {"rug": "rug_round", "desk": "desk_wood"},
  "acquired": {"desk_wood": "2026-11-11"},
  "outfitId": "outfit_knit", "accessoryId": null
  ```
- `Profile.fromJson`은 없는 필드에 기본값을 쓴다. **필드를 추가해도 기존 데이터가 깨지지 않는 구조다**(지금까지 그렇게 확장해 왔다).
- **가구 위치(그리드 좌표·회전) 저장: 불가.** `placed`는 자리 이름 → id 매핑뿐이다.
  - 마이그레이션 경로: 기존 `placed`의 각 자리를 "기본 타일 위치"로 바꿔 새 레이아웃을 만든다. `placed`는 호환을 위해 남기고 읽기만 한다.

## 7. 에셋 로딩 방식

- `pubspec.yaml`의 `assets:`가 주석 처리돼 있다. 프로젝트에 이미지 파일이 하나도 없다.
- `ShopItem.assetPath`가 있으면 `ItemThumb`가 `Image.asset(..., fit: BoxFit.contain)`으로 그린다.
  - **`filterQuality` 지정이 없어** 픽셀 아트가 흐리게 확대된다(기본값 사용).
  - **`errorBuilder`가 없어** 파일이 없으면 깨진 이미지가 표시된다.
- 레지스트리, 프리로드(`precacheImage`), 크기 검증: 없음.

## 8. 기존 테스트

| 파일 | 개수 | 방·에셋 관련 |
|---|---|---|
| `test/store_test.dart` | 26 | 가구 구매·레벨/코인 조건, 같은 자리 교체와 보관, 옷·액세서리 입고 벗기, `first_item`·`room_5`·`first_outfit` 배지 |
| `test/widget_test.dart` | 3 | 가입 → 보상 → 내 방 → 상점까지 흐름. 방 화면은 `미니미 상태` 텍스트만 확인 |
| `test/motion_test.dart` | 7 | 모션 공용 컴포넌트 |

- 방 그림 자체(위치·깊이)는 테스트되지 않는다. 고정 배치라 검증할 로직이 없었다.
- 회귀 기준: 위 36개 테스트는 전환 뒤에도 **수정 없이 통과해야 한다**(`placed` 의미가 바뀌면 `store_test`의 가구 테스트 3개는 함께 손봐야 함 → PART 2에서 결정).

## 9. 기술적 제약

1. **폰마다 화면 폭과 DPR이 다르다.** 픽셀 아트는 *물리 픽셀 기준 정수배*로 확대해야 선명하다. 지금 방은 화면 폭에 맞춰 비율로 늘어나는 구조라, 그대로 픽셀 이미지를 넣으면 픽셀 크기가 들쭉날쭉해진다(→ 01 문서 §2).
2. **방이 탭 안의 `ListView`에 들어 있다.** 가구 드래그와 세로 스크롤 제스처가 충돌하므로, 편집 모드에서는 스크롤을 잠가야 한다.
3. **숨쉬기 애니메이션이 `Ticker`를 계속 돌린다.** 위젯 테스트는 `pumpAndSettle` 대신 시간을 흘리는 방식에 의존한다(`settleish`). 스프라이트 애니메이션도 같은 제약을 받는다.
4. **에셋 파이프라인이 없다.** 이미지 생성 도구도 이 작업 환경에는 없다. 그래서 PART 1의 기준 장면은 **실제 이미지가 아니라 규격과 제작 프롬프트**로 남긴다.
5. 방 탭의 `RoomView`는 레이아웃이 단순해서 렌더러를 교체해도 바깥 화면(상점·보관함·미니미 상태)에는 영향이 적다.

## 10. 재사용 판단 (핵심 질문 1)

| 구성요소 | 판단 | 이유 |
|---|---|---|
| `AppState` 구매·보관·잠금·보상 | **그대로** | 그림과 독립적인 규칙 |
| `ShopItem`·`shopCatalog` | **확장** | id를 assetId로 쓰고, 그림 정보는 별도 매니페스트에서 찾는다(중복 모델 금지) |
| `Profile` 저장 | **확장 + 마이그레이션** | `room` 필드 추가 (02 §5), 기존 `placed`는 읽어서 변환 |
| `Minimi` 색 인덱스 | **그대로** | 팔레트 스왑 인덱스로 사용 |
| `RoomView` 위젯 | **껍데기만** | 크기 계산·제스처·애니메이션을 새 렌더러로 바꾼다 |
| `RoomPainter`·`drawFurniture` | **대체 그림(fallback)으로 강등** | 에셋이 없을 때와 테스트용. 최종 그림은 아님 |
| `MinimiPainter` | **대체 그림으로 강등** | 위와 같음 |
| `ItemThumb` | **수정** | `FilterQuality.none` + `errorBuilder`(벡터 그림으로 대체) |
| `CustomPainter` 방식 자체 | **유지 가능성 높음** | 정적 스프라이트 그리기, 드래그, 스냅, 단순 프레임 애니메이션은 CustomPainter로 충분하다. Flame 도입 여부는 PART 3에서 비교한다 |
