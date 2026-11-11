# 검수 기록: `bed_single_r0` ChatGPT 생성 v1 (2026-11-11)

워크플로: ChatGPT 생성 → 자동 보정 → 자동 검증 → 방 적용 → 구조 문제면 재생성 (Pixelorama 수동 보정 없음)

**판정: 구조 실패 → 재생성** (앱 에셋에 넣지 않음, final 아님)

## 파일
| 구분 | 경로 |
|---|---|
| 원본 (보존) | `art/source/furniture/beds/bed_single_r0_gpt_v1.png` — 1312×1199 RGBA, sha256 `c3d894dc…e396` |
| 자동 보정 후보 | `art/work/bed_single_r0_gpt_v1_fit.png` (96×104) — **`assets`에는 넣지 않았다** |
| 수치 | `bed_single_r0_gpt_v1_report.txt` |
| 비교 | `bed_single_r0_gpt_v1_compare.png` |
| 템플릿 겹침 | `bed_single_r0_gpt_v1_on_template.png` |
| 방 안 | `bed_single_r0_gpt_v1_room.png`, `bed_single_r0_gpt_v1_room_footprint.png` |

명령:
```
dart run tool/pixel_fix.dart <원본> art/work/bed_single_r0_gpt_v1_fit.png --footprint 1x2 --height 52 --rot r0 \
  --grid fit --canvas 96x104 --offset 0,17 --clusters 16 --compare <비교.png>
flutter test test/room/asset_review_test.dart --dart-define=REVIEW_ID=bed_single --dart-define=REVIEW_ROT=r0 \
  --dart-define=REVIEW_PNG=art/work/bed_single_r0_gpt_v1_fit.png --dart-define=REVIEW_OUT=docs/asset-system/review/bed_single_r0_gpt_v1
```

## 자동 보정 결과
| 항목 | 결과 | 판정 |
|---|---|---|
| 배경 | 흰 안개(알파 약 60~70) + 후광 → 알파 128 기준으로 제거 | 해결 |
| 본체 알파 | 252~253 → 255 | 해결 |
| 팔레트 | 12색, 평균 ΔE 5.0, 최대 13.8 | 해결 (원본 색 유지 좋음) |
| 방향·디자인 | 머리판 오른쪽 위, 발치 왼쪽 아래, 싱글, 베개 1개, 테라코타 이불 | 통과 |
| 픽셀 격자 | 블록 13~17px로 불규칙. 원래 해상도는 약 70×63 (요청 96×104) | **구조** |
| 바닥선 기울기 | 왼쪽 0.576, 오른쪽 0.580 (2:1 = 0.500) | **구조 — 투영이 2:1이 아님 (약 30°)** |
| 허용 영역 | 밖 9px | 불통과 |
| 바닥 접점 | 왼쪽 꼭짓점 2px, 오른쪽 꼭짓점 7px 뜸 | 불통과 |

시도한 위치 맞춤:
- 원래 격자(14px): 침대가 작고(70px 폭) 기울기는 그대로다.
- 규격 폭에 맞춤(10.2px) + 앞 꼭짓점 맞춤: 머리판 기둥 2열이 잘린다.
- 규격 폭에 맞춤 + 자르지 않음: 9px이 넘치고 7px이 뜬다.
- 어느 쪽도 억지 보정 없이는 맞출 수 없다.

## 재생성 프롬프트 v2 — 바뀐 점
1. **템플릿을 그림판으로 준다**:
   - `art/templates/beds/bed_single_r0/bed_single_r0_guide_x10.png` (960×1040, 아트 픽셀 1개 = 10×10 블록)
   - "이 이미지 위에 그리고, 가이드 선은 지우라"고 요청한다.
2. 블록 크기를 **정확히 10px**로 고정한다. 결과 크기는 960×1040이다.
3. 침대가 **96열 전체 폭**을 쓰게 한다(왼쪽 발치 기둥 ~ 오른쪽 머리판 기둥).
4. 긴 옆면 두 개를 **바닥 마름모의 긴 변과 평행하게, 정확히 2:1**로 그리게 한다. 1:1 계단과 30° 투영을 금지한다.
5. 배경에 **흰 안개·후광·그림자를 금지**하고 완전 투명을 요구한다.

```
Edit the attached image. It is a 960 x 1040 layout guide for ONE pixel-art sprite on a 96 x 104 grid where every art pixel is an exact 10 x 10 block.

Draw a cozy SINGLE bed so that:
- Its floor outline matches the GREEN diamond exactly: the four legs stand on the diamond's corners. The bed fills the whole 96-pixel width: the foot post touches the left edge and the right headboard post touches the right edge.
- The HEADBOARD stands on the BLUE edge (upper-right short side). The FOOT is at the YELLOW edge (lower-left short side). The bed is long and narrow, running from the upper-right down to the lower-left.
- Everything stays inside the area that is NOT tinted red. Max height: the headboard reaches the dotted brown line.
- Projection is exact 2:1 dimetric: every edge that runs along the floor (the bed's long sides, the headboard and footboard tops) steps exactly 2 blocks across for 1 block down, parallel to the green diamond's edges. No 1:1 steps, no 30-degree isometric, no perspective.
- Light from the top-left (sun mark): top surfaces lightest, foot panel facing lower-left mid-tone, long side facing lower-right darkest.

Style: warm natural wood frame with rounded posts, cream sheet, ONE pillow by the headboard, soft terracotta-peach blanket over the lower two thirds. 1-block dark brown outline (#4A3628). Flat cel shading, 3-4 tones per material. Colors only: #4A3628 #6B4F3A #D49E6E #B98559 #8E6240 #6A4630 #FFF8EE #F6EBDD #EADBC7 #D6C2A8 #F8DCCB #EDA77F #E08A5B #B9663D.

Then REMOVE every guide mark (green, blue, yellow, red tint, dotted lines, cross, arrows, sun). Output: the same 960 x 1040 canvas, fully transparent background with no white haze, no glow, no halo, no shadow, no floor. Hard 10 x 10 blocks only, no anti-aliasing, no blur, no semi-transparent pixels.

Avoid: double bed, two pillows, square bed, headboard on the left, bed pointing to the lower-right, steeper than 2:1 edges, perspective, gradients, soft shading, drop shadow, text, cropped posts.
```
- ChatGPT 이미지 편집이 결과 크기를 1024 계열로 바꿀 수 있다. 그래도 블록이 10px에 가까우면 `--grid 10` 또는 `--grid fit`으로 처리할 수 있다.
