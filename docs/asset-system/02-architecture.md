# 02. 에셋 아키텍처 설계 (PART 2)

> 상태: **설계안**. 이번 PART에서는 코드·데이터·에셋을 바꾸지 않았다.
> 수치(좌표 변환, 스프라이트 크기·앵커, 기준 장면 겹침, 깊이 순서)는 별도 스크립트로 계산해 확인했다(§12).
> 승인된 정책(2026-11-11):
> - 64×32 타일 · 8×8 방 · 미니미 64×96
> - 방은 화면 폭 전체, 작은 화면은 가로 스크롤 허용(조작성 우선)
> - **같은 분류 가구 여러 개 배치**, 기존 데이터 호환
> - 미니미는 **정면 + 측면(반전)** 기본, 뒷모습은 별도 검토
> - **AI 초안 + 수동 보정**

## 1. 전체 구조

```
                  ┌──────────── 게임 규칙 (그대로) ────────────┐
shopCatalog ──────► ShopItem(id, price, level, kind, slot)        │
                  │ AppState.canBuy / buy / use / putAway         │
                  └────────────────────┬──────────────────────────┘
                                       │ id = assetId
┌──────────── 그림 정보 (신규) ──────────▼──────────────┐
│ assets/pixel/manifest.json → AssetManifest            │
│ AssetRegistry: 이미지 로드·팔레트 스왑·캐시·누락 판정 │
└───────────────┬──────────────────────────────────────┘
                │
┌───────────────▼──────── 방 (신규) ─────────────────────┐
│ IsoGrid      좌표 변환 · 스프라이트 위치               │
│ RoomLayout   배치 데이터 (Profile.room) + 마이그레이션 │
│ Occupancy    충돌 · 빈 자리 찾기                      │
│ DepthSort    그리는 순서                              │
│ IsoRoomPainter / MinimiSpritePainter (CustomPainter)  │
│ RoomEditor   드래그 · 스냅 · 회전 · 보관              │
└───────────────────────────────────────────────────────┘
```

원칙:
- **게임 규칙(가격·레벨·보상)은 Dart 카탈로그에 그대로 둔다.**
- **그림 규칙(파일·크기·점유)은 매니페스트에만 둔다.**
- 두 곳은 `id` 하나로만 연결한다. 같은 정보를 두 군데에 쓰지 않는다.

## 2. `assets/pixel/manifest.json`

### 2.1 스키마
```jsonc
{
  "version": 1,
  "grid": { "tileW": 64, "tileH": 32, "size": 8, "wallH": 160 },
  "room": {
    "floor":  { "path": "rooms/floors/floor_wood.png" },             // 64×32 타일
    "wallL":  { "path": "rooms/walls/wall_cream_l.png" },            // 32×176 조각
    "status": "draft"
  },
  "items": {
    "<ShopItem.id>": {
      "layer": "object | floorDecor | wall | surface | character",
      "status": "draft | final",          // final만 실제 화면에 쓴다 (§9)
      "rev": 1,                           // 그림을 다시 그리면 +1
      "source": "ai+manual | manual",
      // layer별 필드는 아래 표
    }
  }
}
```

### 2.2 layer별 필드
| layer | 대상 | 필드 |
|---|---|---|
| `object` | 침대·책상·의자·조명·화분·선반형 가구 | `footprint: [w, d]`(R0 기준), `height`, `blocking`(기본 true), `rotations: { "r0": path, "r1": path? }` |
| `floorDecor` | 러그 | `footprint`, `rotations`. 막지 않음(밟을 수 있음). 러그끼리만 안 겹침 |
| `wall` | 창문·액자·벽 선반 | `span`(벽 칸 수), `height`, `zRange: [min, max]`, `path`(왼쪽 벽용, 오른쪽은 반전) |
| `surface` | 벽지·바닥재 | `wallTile` 또는 `floorTile` 경로. 방에 하나만 적용 |
| `character` | 의상·액세서리 | `slot: outfit | head | face`, `sheets: { "idle": path, "walk": path? }`, `hides: [...]` |

### 2.3 크기·앵커는 저장하지 않고 계산한다
크기와 앵커는 `footprint`와 `height`로 정해진다(01 §3.1). 매니페스트에 따로 적으면 서로 어긋날 수 있으므로 **적지 않는다.** 대신 검증 테스트가 실제 PNG 크기를 계산값과 비교한다.
```
w, d = rot == r0 ? footprint : footprint 뒤집기
폭   = (w + d) × 32
높이 = ceil8((w + d) × 16 + height)
앵커 = (d × 32,  높이 − (w + d) × 16)
```
예외가 꼭 필요할 때만 `anchorOverride: [x, y]`를 쓴다. 그 경우 검증 테스트가 경고를 낸다.

### 2.4 기존 아이템 26개 배정 (초안)
| id | layer | footprint / span | height | R1 |
|---|---|---|---|---|
| `bed_single`, `bed_quilt` | object | 1×2 | 52 | 그림 |
| `bed_double` (2026-11-11 추가, 100코인·Lv.3) | object | 2×2 | 56 | 그림 |
| `desk_wood`, `desk_white` | object | 2×1 | 64 | 그림 |
| `chair_wood` | object | 1×1 | 48 | 그림 |
| `lamp_stand` | object | 1×1 | 104 | 반전 허용(대칭) |
| `lamp_pendant` | object, `blocking: false` | 1×1 | 104(천장에서 늘어뜨림) | 반전 허용 |
| `plant_small` / `plant_big` | object | 1×1 | 36 / 92 | 반전 허용 |
| `shelf_book` | wall | 2칸 | 32 | — |
| `window_curtain` | wall | 2칸 | 72 | — |
| `frame_sun` | wall | 1칸 | 40 | — |
| `rug_round` / `rug_stripe` | floorDecor | 2×2 / 2×3 | 0 | 반전 허용 |
| `wall_sage`, `wall_sky` | surface | — | — | — |
| `outfit_*` 5종 | character, slot `outfit` | — | — | — |
| `acc_starpin`, `acc_ribbon`, `acc_beanie`, `acc_headphone` | character, slot `head` | — | — | — |
| `acc_glasses` | character, slot `face` | — | — | — |

## 3. 침대 하나로 본 실제 PNG 규격 (`bed_single`)

### 3.1 파일
| 항목 | R0 | R1 |
|---|---|---|
| 경로 | `assets/pixel/furniture/beds/bed_single_r0.png` | `assets/pixel/furniture/beds/bed_single_r1.png` |
| 점유 (w×d) | 1×2 (gy 방향으로 김) | 2×1 (gx 방향으로 김) |
| 놓이는 모습 | 머리판이 오른쪽 벽(gy=0) 쪽, 발치가 왼쪽 아래 | 머리판이 왼쪽 벽(gx=0) 쪽, 발치가 오른쪽 아래 |
| 크기 | **96 × 104 px** | **96 × 104 px** |
| 앵커 | **(64, 56)** | **(32, 56)** |
| 형식 | PNG, RGBA 8bit, 색 보정 정보 없음 | 같음 |
| 알파 | 0 또는 255만 | 같음 |
| 색 | 01 §6의 57색만 (크림·원목·테라코타 램프 위주) | 같음 |

### 3.2 그림이 들어갈 영역 (R0)
```
 x: 0         32        64        96
 y:0 ┌─────────────────────────────┐
     │  위쪽 여백 (머리판 52px 이내만) │
  56 │          ◆ ← 앵커(64,56) = 점유 영역의 뒤 꼭짓점
     │       ◆     ◆
  72 │ ◆ (0,72)       ◆ (96,72)   ← 점유 영역의 좌·우 꼭짓점 높이
     │    ◆        ◆
 104 │        ◆ (32,104)  ← 앞 꼭짓점 = 스프라이트 맨 아래 줄
     └─────────────────────────────┘
```
- 점유 영역(바닥 마름모, w=1, d=2)의 꼭짓점: 뒤 (64,56) · 오른쪽 (96,72) · 앞 (32,104) · 왼쪽 (0,72).
- **허용 영역** = 이 마름모를 위로 `height`(52px)만큼 밀어 올린 기둥 모양이다. 이 밖의 픽셀은 모두 투명이어야 한다. 그래야 가구가 점유 영역 밖으로 가로로 삐져나오지 않는다.
- 바닥 마름모 자체는 그리지 않는다. 바닥 타일이 보여야 한다.
- 그림자도 그리지 않는다. 엔진이 그린다.
- 명암: 윗면(이불 위)이 가장 밝다. 왼쪽 아래를 보는 긴 옆면은 기본색, 오른쪽 아래를 보는 발치 쪽은 그늘색이다.
- 외곽선은 1px이고, 재질 램프의 가장 짙은 색을 쓴다.

### 3.3 매니페스트 항목
```json
"bed_single": {
  "layer": "object",
  "footprint": [1, 2],
  "height": 52,
  "blocking": true,
  "rotations": {
    "r0": "furniture/beds/bed_single_r0.png",
    "r1": "furniture/beds/bed_single_r1.png"
  },
  "status": "draft",
  "rev": 1,
  "source": "ai+manual"
}
```

### 3.4 화면에서 실제로 놓이는 위치 (검증값)
`bed_single` R0을 (gx 0, gy 1)에 놓으면:
- 뒤 꼭짓점의 캔버스 좌표 = (256 + (0−1)×32, 168 + 1×16) = **(224, 184)**
- 스프라이트를 그릴 위치 = (224, 184) − (64, 56) = **(160, 128)**, 크기 96×104
- 스프라이트 맨 아래 줄 y = 232. 점유 영역의 앞 꼭짓점 (gx 1, gy 3) = (192, 232)와 **일치**
- 화면에서는 s=2이므로 물리 픽셀로 (320, 256)부터 192×208 크기로 그린다. 확대는 nearest(`FilterQuality.none`)

## 4. 아이소메트릭 좌표 변환 — `IsoGrid`

```dart
// lib/room/iso.dart (제안)
class IsoGrid {
  static const tileW = 64, tileH = 32, size = 8, wallH = 160;
  static const origin = Offset(256, 168);       // 바닥 (0,0) 꼭짓점
  static const canvas = Size(512, 432);

  static Offset toCanvas(double gx, double gy);   // 01 §1.3 공식
  static (double, double) toGrid(Offset p);       // 역변환
  static (int, int) tileAt(Offset p);             // floor()
  static SpriteBox spriteBox(ItemArt art, int gx, int gy, Rot rot); // 위치·크기·앵커
  static int pixelScale(double physicalWidth);    // max(1, floor(w / 512)) + 작은 화면 규칙
}
```
- 화면 좌표 → 캔버스 좌표: `(터치 위치 + 가로 스크롤) × dpr / s`. 이 계산은 위젯 한 곳(`RoomViewport`)에서만 한다.
- 모든 그리기 위치는 캔버스 정수 픽셀로 반올림한다.

## 5. 배치 데이터 — `Profile.room`

### 5.1 형식
```jsonc
"room": {
  "v": 1,
  "floor": {                       // 바닥 물체 + 러그. 키 = ShopItem.id
    "bed_single": { "x": 0, "y": 1, "r": 0 },
    "rug_round":  { "x": 3, "y": 2, "r": 0 }
  },
  "wall": {
    "window_curtain": { "w": "L", "u": 2, "z": 40 }
  },
  "surface": { "wall": "wall_sage", "floor": null },
  "minimi": { "x": 4, "y": 4 }
}
```
- **같은 분류 여러 개**: 키가 분류가 아니라 **아이템 id**이므로 침대 두 개(`bed_single`, `bed_quilt`)를 함께 둘 수 있다.
- 같은 아이템은 원래 정책대로 한 번만 산다. 그래서 별도의 인스턴스 id가 필요 없다.
- `surface`(벽지·바닥재)는 방 전체에 하나만 적용되므로 지금처럼 교체 방식을 유지한다.

### 5.2 상태 변화 (`AppState`)
| 동작 | 지금 | 바뀐 뒤 |
|---|---|---|
| 가구 구매 | 같은 자리 가구를 보관으로 밀고 그 자리에 놓음 | **빈 자리를 찾아 놓는다**(§6.3). 자리가 없으면 보관함으로 보내고 토스트로 안내 |
| 사용(놓기) | `placed[slot] = id` | 마지막 위치나 빈 자리에 놓기 |
| 보관 | `placed`에서 제거 | `room.floor`/`wall`에서 제거. 위치는 `lastPos`로 기억 |
| 사용 중 판정 `isInUse` | `placed[slot] == id` | `room`에 id가 있음 |
| 벽지 | 자리 교체 | `surface.wall` 교체 (그대로) |
| 옷·액세서리 | 그대로 | 그대로 |

보상·가격·레벨 잠금(`canBuy`)은 바꾸지 않는다.

### 5.3 마이그레이션 (기존 사용자 데이터)
조건: `profile.room`이 **없고** `profile.placed`가 있을 때, 처음 불러올 때 한 번만 실행한다.

| 기존 `placed` 자리 | 새 위치 (기준 장면) |
|---|---|
| bed | floor (0,1) r0 |
| lamp | floor (1,1) |
| desk | floor (5,1) r0 |
| chair | floor (5,2) |
| plant | floor (7,3) |
| rug | floor (3,2) |
| shelf | wall R, u 5, z 72 |
| window | wall L, u 2, z 40 |
| wallDecor | wall L, u 5, z 72 |
| wallpaper | surface.wall |

- 이 위치들은 서로 겹치지 않는다(검증 완료). 그래서 마이그레이션은 실패하지 않는다.
- 혹시 겹치면 `findFreeSpot`으로 옮기고, 그래도 자리가 없으면 보관함으로 보낸다.
- `owned`, `acquired`, `outfitId`, `accessoryId`, `badges`, 코인·레벨은 **건드리지 않는다.**
- `placed`는 지우지 않고 남겨 둔다(되돌리기 대비). `room`이 생긴 뒤에는 읽지 않는다.
- 미니미 위치가 없으면 (4,4)에 둔다. 그 자리가 막혀 있으면 가장 가까운 빈 칸에 둔다.

## 6. 충돌 검사 — `Occupancy`

### 6.1 칸 점유
- 8×8 격자 두 장을 쓴다: `blocking`(바닥 물체), `decor`(러그).
- `canPlace(item, x, y, rot, {ignore})`의 결과: `ok` · `outOfRoom` · `blockedBy(id)` · `onMinimi`.
  - 물체는 `blocking` 격자와만 충돌을 검사한다. 러그는 `decor` 격자와만 검사한다.
  - `blocking: false`인 물체(펜던트 조명)는 어디에도 표시하지 않는다.
- 미니미 칸에는 가구를 놓을 수 있다. 놓으면 미니미가 가장 가까운 빈 칸으로 옮겨 간다.

### 6.2 벽
- 벽마다 8칸짜리 1차원 점유. 같은 벽에서 칸이 겹치면 안 된다.
- `z`는 `zRange` 안에서 8px 단위로 맞춘다(`[16, 160 − height − 8]`).

### 6.3 빈 자리 찾기 `findFreeSpot(item)`
방 가운데 (4,4)에서 가까운 순(맨해튼 거리 → gy → gx)으로 R0, R1을 차례로 시도한다. 64칸 × 2방향이라 계산량은 무시할 만하다. (뒷모습인 R2·R3은 자동 배치에 쓰지 않는다.)

## 7. 드래그·그리드 스냅 — `RoomEditor`

- **방 꾸미기 전용 화면**(전체 화면 페이지)에서만 편집한다. 내 방 탭은 보기 전용으로 둔다. 탭 안의 `ListView` 세로 스크롤과 드래그가 충돌하지 않게 하려는 것이다(00 §9-2).
- 흐름:
  1. 가구를 길게 누르거나 탭하면 선택된다. 위에 도구막대(회전 · 보관함으로 · 완료)가 뜬다.
  2. 끄는 동안: 손가락 캔버스 좌표 − 잡은 지점 오프셋 → `toGrid` → 반올림한 칸에 **고스트**(반투명 스프라이트 + 점유 마름모)를 그린다. 놓을 수 있으면 세이지, 없으면 테라코타로 표시한다.
  3. 놓으면: 가능할 때만 확정하고 저장한다. 불가능하면 원래 자리로 돌아간다(모션 규칙: ease-out 160ms).
  4. 회전: 바닥에 놓는 것은 모두 가능하다. 누를 때마다 R0 → R1 → R2 → R3로 90°씩 돌고, 겹치거나 방 밖으로 나가는 방향은 건너뛴다. 놓을 수 있는 방향이 하나도 없으면 그대로 두고 알림을 띄운다.
- 선택 판정은 깊이 순서의 **역순**으로, 스프라이트 사각형 안에 있고 그 픽셀의 알파가 255인 첫 아이템을 고른다. 알파 마스크는 이미지 로드 때 한 번 만들어 둔다.
- 끄는 손가락이 화면 가장자리에 닿으면 가로 스크롤을 천천히 옮긴다(작은 화면).
- 햅틱: 칸이 바뀔 때 `selectionClick`, 놓을 때 `lightImpact`.

## 8. 깊이 정렬 — `DepthSort`

- 층 순서: 바닥 → 러그 → 그림자 → 벽·벽 장식 → **물체**(가구 + 미니미) → 편집 UI.
- 물체끼리: `A.x ≥ B.x + B.w` 또는 `A.y ≥ B.y + B.d`이면 A를 B보다 나중에 그린다.
  - 이 관계로 위상 정렬하고, 순위가 같으면 `(x + y)` → `id` 순으로 정한다.
  - 점유가 겹치지 않는 직사각형끼리는 이 관계에 순환이 생기지 않는다.
- 미니미: 1×1. 걷는 중에는 들어가는 칸을 기준으로 한다.
- `blocking: false`인 펜던트는 자기 칸 기준으로 같은 규칙을 적용한다.
- 기준 장면 결과(검증): `bed → lamp → desk → chair → minimi → plant`

## 9. 에셋 레지스트리와 누락 시 대체 그림 — `AssetRegistry`

### 9.1 불러오기
- 방 화면에 들어갈 때 매니페스트를 읽고, 필요한 이미지만 `ui.Image`로 미리 디코드해 캐시한다.
  - 필요한 이미지 = 배치된 가구 + 미니미 레이어 + 바닥·벽
  - 로딩 중에는 `AppSpinner`를 보여준다.
- 팔레트 스왑: 미니미 base·hair 레이어의 픽셀 중 피부 0·머리 0 램프 색과 **정확히 같은 픽셀**만 고른 램프 색으로 바꾼다. 바꾼 이미지는 `(경로, 피부, 머리, 옷 색)` 단위로 캐시한다.
  - 처리 순서: `toByteData(rawRgba)` → 색 교체 → `decodeImageFromPixels`

### 9.2 단계별 대체

> **구현 변경 (2026-11-11, PART 4)**: 아래 첫 줄 대신, 방은 항상 아이소메트릭으로 그리고 바닥·벽은 PNG가 없으면 팔레트 색 코드 그림으로 대신한다. 편집 결과가 내 방 탭에 그대로 보이게 하려는 것이다. 자세한 내용은 PROGRESS.md.
| 상황 | 그리는 방식 |
|---|---|
| 방 기본 에셋(바닥·벽)이 `final`이 아님 | **방 전체를 기존 `RoomPainter`(정면 2D)로 그린다.** 지금 앱과 똑같다. 기능 플래그 `RoomRenderMode.legacy` |
| 방은 아이소메트릭인데 가구 PNG가 없거나 `draft`이거나 크기가 틀림 | 그 가구만 기존 `drawFurniture` 벡터 그림을 **계산된 스프라이트 상자 안에** 그리고, 점유 마름모 외곽선을 덧그린다. 디버그 빌드에서는 '임시' 표시 |
| 미니미 레이어가 하나라도 없음 | 미니미 전체를 기존 `MinimiPainter`로 그린다. 레이어를 섞지 않는다 |
| 상점 썸네일 | `ItemThumb`: PNG가 있으면 정수배로 키워 `FilterQuality.none`으로, 없으면 지금 벡터 그림. `errorBuilder`도 벡터 그림 |

- `draft` 에셋은 개발자 설정(`kShowDraftAssets`)이 켜져 있을 때만 화면에 나온다. 출시 빌드에는 `final`만 나온다.
- 누락은 앱을 멈추지 않는다. 디버그 로그에 id와 이유만 남긴다.

## 10. 검증 (테스트로 자동화)

| 테스트 | 확인 내용 |
|---|---|
| `iso_test` | 꼭짓점·왕복 변환, `tileAt`, 정수 확대 계산 |
| `manifest_test` | 상점 26개 id가 모두 매니페스트에 있음 (`final`이면 파일 필수). 파일 존재, PNG 크기 = 계산값, 알파 0/255, 팔레트 밖 색 없음, 허용 영역 밖 픽셀 없음, 캐릭터 시트 크기 일치 |
| `occupancy_test` | 범위 밖·겹침·러그·벽 칸, `findFreeSpot`, 회전 충돌 |
| `depth_test` | 기준 장면 순서, 무작위 배치 200개에서 '겹치는 화면 영역'이 있는 쌍의 순서가 항상 맞음 |
| `layout_test` | `room` 저장·복원, `placed` → `room` 마이그레이션, 기존 필드 보존, 같은 분류 여러 개 |
| `store_test` (수정) | '같은 자리 자동 교체' 테스트 → '빈 자리에 놓기 / 자리가 없으면 보관함' 테스트로 바꿈. 나머지 26개 중 25개는 그대로 통과해야 함 |
| 위젯 테스트 | 에셋이 없을 때 대체 그림으로 방이 그려짐, 편집 화면에서 끌어 놓으면 저장됨 |

## 11. 영향 범위 요약

| 파일 | 변경 |
|---|---|
| `lib/data/models.dart` | `Profile.room`(+ JSON) 추가. 기존 필드는 그대로 |
| `lib/data/store.dart` | `buy`/`use`/`putAway`/`isInUse`/`placedFurniture` 가구 경로를 `room` 기반으로 변경, 마이그레이션 호출 |
| `lib/data/catalog.dart` | `assetPath` 제거(매니페스트로 이동). 가격·레벨은 그대로 |
| `lib/ui/room/room_painter.dart` | 대체 그림으로 유지. `ItemThumb` 정수배·nearest·errorBuilder |
| `lib/ui/room/room_screen.dart` | `RoomView` → 렌더 모드 분기, '방 꾸미기' 버튼 |
| 신규 `lib/room/*` | iso, layout, occupancy, depth, manifest, registry, painters, editor |
| `pubspec.yaml` | `assets: - assets/pixel/` |
| 신규 `assets/pixel/manifest.json` | 처음에는 모든 항목 `draft` |

## 12. 이번 설계의 수치 검증 기록
프로젝트 밖 임시 스크립트로 계산했다(프로젝트 파일은 바꾸지 않음).
- 바닥 꼭짓점: (0,0)=(256,168) · (8,0)=(512,296) · (0,8)=(0,296) · (8,8)=(256,424)
- 왕복 변환: (3,5)→(192,296)→(3,5), (7.5,2.5)→(416,328)→(7.5,2.5)
- 스프라이트(폭, 높이, 앵커):
  - 침대 R0 (96,104,64,56) · R1 (96,104,32,56)
  - 책상 (96,112,32,64) · 의자 (64,80,32,48)
  - 조명 (64,136,32,104) · 작은 화분 (64,72,32,40) · 큰 화분 (64,128,32,96)
  - 러그 2×2 (128,64,64,0)
- 기준 장면 6개 물체: 겹침 없음. 깊이 순서 bed → lamp → desk → chair → minimi → plant
- 침대 (0,1) 배치: 그릴 위치 (160,128), 아래 끝 y=232 = 점유 앞 꼭짓점 y
- 정수 확대: iPhone 15·S23·Pixel 7·QHD는 s=2, iPhone SE 3은 s=1 → 70% 규칙에 따라 s=2 + 가로 스크롤

## 13. 첫 실제 에셋: 침대 PNG 적용 절차

### 13.1 이미지 처리
1. **가이드 템플릿**: 96×104 투명 PNG에 점유 마름모(§3.2)와 높이 52px 기둥 윤곽을 1px 가이드선으로 그린다. 별도 레이어로 두고, 내보낼 때는 뺀다.
2. **AI 초안**: 01 §9.2·9.3 프롬프트로 만든다.
   - `{object}` = "single bed with cream quilt, terracotta pillow, warm wood frame"
   - `footprint 1x2` 지정
   - 목표 크기의 8배(768×832)로 2~4장을 만들고, 각도와 비율이 가장 맞는 1장을 고른다
3. **배경 제거**: 바닥·그림자를 포함해 모두 지운다.
4. **축소**: 최근접 이웃(nearest) 방식으로 1/8 축소해 96×104로 만든다. 격자가 어긋나면 원래 픽셀 크기를 추정해 맞춘다.
5. **팔레트 맞춤**: 57색으로 강제 변환한다(디더링 없이).
6. **손 보정 (Aseprite 등)**: 가이드 레이어를 켜고 다음을 다듬는다.
   - 2:1 계단선, 1px 셀아웃 외곽선
   - 명암: 윗면 밝게, 오른쪽 아래 면 그늘
   - 허용 영역 밖 픽셀 지우기, 반투명 픽셀 제거
7. **R1 만들기**: R0을 좌우 반전한 뒤 **명암을 다시 칠한다**(광원 왼쪽 위 유지). 반전만 하고 끝내지 않는다.
8. **내보내기**: `bed_single_r0.png`, `bed_single_r1.png`. RGBA 8bit, 메타데이터 없음.
9. **자동 검증**: `manifest_test` — 크기 96×104, 알파 0/255, 팔레트, 허용 영역.
10. **사람 검수**: 개발 모드의 기준 장면에서 s=2로 미니미·의자·러그 옆에 두고 확인한다. 크기 비율, 외곽선 두께, 명암 방향이 맞으면 `status: final`로 바꾼다.

### 13.2 Flutter 쪽 순서
1. PART 4의 1~5단계(03 §4.3)가 먼저 있어야 한다. 좌표·매니페스트·배치 데이터·레지스트리·아이소메트릭 렌더러(대체 그림 상태)·뷰포트를 뜻한다.
2. PNG 두 장을 `assets/pixel/furniture/beds/`에 넣는다. `pubspec.yaml`에는 `assets/pixel/`이 이미 등록돼 있다(1단계에서 등록).
3. 매니페스트 `bed_single` 항목을 §3.3대로 쓴다. 처음에는 `status: draft`로 둔다.
4. `flutter test test/manifest_test.dart` — 크기·알파·팔레트·영역 통과를 확인한다.
5. 개발 모드(`kShowDraftAssets = true`)에서 기준 장면을 확인한다. 이때 **이 침대만 PNG**로 그려지고 나머지는 대체 그림이다.
6. 편집 화면에서 R0↔R1 회전과 드래그를 확인한다. 깊이 정렬도 본다(침대 앞 칸의 의자가 침대를 가림).
7. 검수가 끝나면 `status: final`로 바꾸고 커밋한다. 바닥·벽이 아직 `draft`면 출시 빌드는 여전히 기존 2D 방이다(§9.2).

## 14. 침대 두 종 규격 (2026-11-11 확정)

| 항목 | 싱글 `bed_single` | 더블 `bed_double` |
|---|---|---|
| 상점 | 60코인 · Lv.3 (기존 그대로) | 100코인 · Lv.3 (신규) |
| 점유 w×d | R0 1×2 / R1 2×1 | R0·R1 모두 2×2 |
| 물체 높이 h | 52 | 56 |
| 캔버스 | 96×104 (R0·R1) | 128×120 (R0·R1) |
| 앵커 (뒤 꼭짓점) | R0 (64, 56) · R1 (32, 56) | (64, 56) |
| 바닥 마름모 (뒤·오른쪽·앞·왼쪽) | R0 (64,56) (96,72) (32,104) (0,88) / R1 (32,56) (96,88) (64,104) (0,72) | (64,56) (128,88) (64,120) (0,88) |
| 허용 영역 | 바닥 마름모를 위로 52px 올린 기둥 | 바닥 마름모를 위로 56px 올린 기둥 |
| R0 방향 | 머리판: 오른쪽 벽 쪽(뒤-오른쪽 변), 발치: 왼쪽 아래 | 같음 |
| R1 방향 | 머리판: 왼쪽 벽 쪽(뒤-왼쪽 변), 발치: 오른쪽 아래 | 같음 |
| 반전 | 금지 (광원) | 금지 (광원) |
| 베개 | 1개 | 2개 |
| 파일 | `furniture/beds/bed_single_r0.png`, `bed_single_r1.png` | `furniture/beds/bed_double_r0.png`, `bed_double_r1.png` |
| 현재 상태 | PNG 없음 (대체 그림) | R1 draft PNG (사용자 그림 재분류), R0은 R1을 좌우로 뒤집은 임시본 (명암 미보정) |

- 더블은 점유가 정사각형이라 회전해도 점유·캔버스·앵커가 같다. 그림만 R0·R1 두 장을 그린다.
- R2·R3(뒷모습)은 PNG가 없어 두 침대 모두 상자 입체 대체 그림으로 그린다 (01 §3.2).
