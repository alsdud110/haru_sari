# 에셋 제작 템플릿

AI 초안을 Pixelorama(또는 Aseprite)에서 보정할 때 쓰는 **기준 가이드**입니다. 침대 그림은 들어 있지 않고 기준선만 있습니다.

- 규격 출처: `docs/asset-system/02-architecture.md` §14
- 다시 만들기: `dart run tool/make_bed_templates.dart`
- 픽셀 검증: `flutter test test/room/template_test.dart`

## 파일

| 파일 | 내용 |
|---|---|
| `beds/<id>/<id>_guide.png` | **가이드 레이어**. 실제 에셋과 같은 크기, 투명 배경 |
| `beds/<id>/<id>_art.png` | **그림 레이어** (완전 투명, 같은 크기) |
| `beds/<id>/<id>_template.ase` | Aseprite 형식. 레이어 `art`(아래) + `guide (do not export)`(위, 잠금, 불투명도 160), 팔레트 57색 |
| `beds/<id>/<id>_preview.png` | 5배 확대 + 범례 (참고용, 작업 파일 아님) |
| `palette/oneul_sari_57.gpl` | 팔레트 57색 (GIMP 형식) |

| id | 캔버스 | 점유 | 높이 | 앵커 | 머리판 | 발치 |
|---|---|---|---|---|---|---|
| `bed_single_r0` | 96×104 | 1×2 | 52 | (64, 56) | 뒤-오른쪽 변 | 앞-왼쪽 변 |
| `bed_single_r1` | 96×104 | 2×1 | 52 | (32, 56) | 뒤-왼쪽 변 | 앞-오른쪽 변 |
| `bed_double_r0` | 128×120 | 2×2 | 56 | (64, 56) | 뒤-오른쪽 변 | 앞-왼쪽 변 |
| `bed_double_r1` | 128×120 | 2×2 | 56 | (64, 56) | 뒤-왼쪽 변 | 앞-오른쪽 변 |

## 가이드 색 (가이드 레이어에만 있음 — 그림에는 쓰지 않는다)

| 색 | 의미 |
|---|---|
| 빨강 십자 `#D03030` | **앵커**. 가운데 1px이 정확한 좌표 = 바닥 점유의 뒤 꼭짓점 |
| 초록 실선 `#6F8F6B` | **바닥 점유 마름모**. 침대 다리·바닥 접점이 이 안에 있어야 한다 |
| 연초록 점선 `#A9C4A3` | 칸 경계 (1칸 = 64×32) |
| 주황 실선 `#E08A5B` | **허용 영역 경계** (바닥 마름모를 높이만큼 올린 기둥) |
| 옅은 붉은 칠 | 허용 영역 밖. **여기에는 한 픽셀도 그리지 않는다** |
| 황토 점선 `#B98A2A` | 물체 높이 면 (높이 52/56의 윗면 기준) |
| 파랑 2px `#6F8FB8` | **머리판이 붙는 변**. 파랑 화살표 = 머리판 → 발치 방향 |
| 노랑 2px `#E5B547` | **발치 변** |
| 왼쪽 위 해와 화살표 | **광원**: 왼쪽 위에서 오른쪽 아래로. 윗면이 가장 밝고, 오른쪽을 향한 면이 가장 어둡다 |

## Pixelorama에서 쓰는 법

> 메뉴 이름은 Pixelorama 버전에 따라 조금 다를 수 있다. 이 환경에서는 Pixelorama를 실행해 확인하지 못했다.

1. **팔레트 불러오기**
   - Palette 패널에서 팔레트 불러오기(Import)를 누르고 `palette/oneul_sari_57.gpl`을 고른다.
   - 이 57색만 쓴다.
2. **가이드 열기**
   - `File > Open`으로 `<id>_guide.png`를 연다.
   - 캔버스 크기가 실제 에셋과 같은 프로젝트가 된다. 이 레이어 이름을 `guide`로 바꾼다.
3. **그림 레이어 추가**
   - 새 레이어를 추가하고 이름을 `art`로 바꾼다. 또는 `File > Import`로 `<id>_art.png`를 **새 레이어**로 가져온다.
   - `art`를 `guide` **아래**로 내린다.
   - `guide` 레이어는 **잠그고** 불투명도를 50~70%로 낮춘다.
4. **(선택) AI 초안 대기**
   - AI 초안을 `File > Import`로 새 레이어(`draft`)에 가져온다. 미리 nearest 방식으로 목표 크기로 줄여 둔다.
   - 초안의 바닥 접점을 초록 마름모에 맞춘다.
5. **`art` 레이어에 그리기**
   - 머리판은 파랑 변에, 발치는 노랑 변 쪽에 둔다.
   - 다리·바닥 접점은 초록 마름모 안에 둔다. 붉은 칠 영역에는 그리지 않는다.
   - 외곽선은 1px, 아이소 선은 가로 2 : 세로 1 계단으로 긋는다.
   - 펜은 안티앨리어싱 없이 불투명도 100%로 쓴다(반투명 픽셀 금지).
   - 바닥과 그림자는 그리지 않는다.
6. **보관용 저장**: 나중에 고칠 수 있게 Pixelorama 프로젝트(`.pxo`)로 `art/source/furniture/beds/`에 저장한다.
7. **PNG 내보내기**
   - `guide`와 `draft` 레이어를 숨긴다(눈 아이콘).
   - `File > Export`로 PNG를 **크기 1배(100%)**로 내보낸다.
   - 결과 크기가 템플릿과 같은지(96×104 또는 128×120) 확인한다.
   - 파일 이름: `art/source/furniture/beds/<id>_<날짜>.png`
8. **앱 에셋으로 만들기와 검증**
   ```
   dart run tool/pixel_fix.dart art/source/furniture/beds/<id>_<날짜>.png assets/pixel/furniture/beds/<id>.png \
     --footprint 1x2|2x1|2x2 --height 52|56 --rot r0|r1 --compare docs/asset-system/review/<id>_compare.png
   dart run tool/make_bed_templates.dart overlay assets/pixel/furniture/beds/<id>.png <id> docs/asset-system/review/<id>_on_template.png
   flutter test test/room/manifest_test.dart test/room/bed_asset_test.dart
   ```
   - 이미 팔레트 색으로만 그렸다면 `--clusters`를 쓰지 않아도 색이 바뀌지 않는다.
   - `--footprint`는 R0 기준으로 적는다. 싱글은 `1x2`로 적고 `--rot r1`을 주면 2×1로 계산된다.
9. **실제 앱에서 보기**
   - `flutter run --dart-define=SHOW_DRAFT_ASSETS=true`
   - 내 방 → 방 꾸미기에서 배치·회전·깊이 순서를 확인한다.
   - 검수가 끝나면 `assets/pixel/manifest.json`의 `status`를 `"final"`로 바꾼다.

## Aseprite에서 쓰는 법

- `<id>_template.ase`를 연다.
  - `guide` 레이어는 잠겨 있고 반투명이다. `art` 레이어에 그린다. 팔레트 57색이 들어 있다.
- 내보내기: `guide` 레이어를 숨기고 `File > Export Sprite Sheet`가 아닌 `File > Save As/Export`로 PNG를 1배로 저장한다.
- `.ase` 파일은 Aseprite 공개 사양(헤더, 팔레트 0x2019, 레이어 0x2004, 압축 셀 0x2005)에 맞춰 만들었다.
  - 테스트로 다시 읽어 구조를 확인했지만, **실제 Aseprite로 열어 보지는 않았다.**
  - 안 열리면 PNG 두 장(`guide`, `art`)으로 같은 작업을 할 수 있다.
