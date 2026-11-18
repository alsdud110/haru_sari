/// 픽셀 아트 고정 팔레트 (docs/asset-system/01 §6). 이 밖의 색은 쓰지 않는다.
/// 값은 0xRRGGBB.
class PixelPalette {
  static const ink = [0x6B4F3A, 0x4A3628];
  static const cream = [0xFFF8EE, 0xF6EBDD, 0xEADBC7, 0xD6C2A8];
  static const floor = [0xE8C9A0, 0xD9B993, 0xC49E74, 0xA57E57];
  static const wood = [0xD49E6E, 0xB98559, 0x8E6240, 0x6A4630];
  static const sage = [0xCFE0C8, 0xA9C4A3, 0x8FAE8B, 0x6F8F6B];
  static const terracotta = [0xF8DCCB, 0xEDA77F, 0xE08A5B, 0xB9663D];
  static const butter = [0xFBEFCB, 0xF2D27A, 0xE5B547, 0xB98A2A];
  static const sky = [0xE3EEF7, 0xBCD3E8, 0x9DBBD8, 0x6F8FB8];
  static const lavender = [0xE6D6E6, 0xC9A3C9, 0x9C789C];

  /// 피부 8종 × (밝음, 기본, 그늘). 에셋은 0번으로 그린다. 이름은 Minimi.skinNames.
  static const skin = [
    [0xFDEBDD, 0xFBE3D0, 0xE8C2A6], // 크림
    [0xF6D8BC, 0xF1CBAA, 0xD9A884], // 헬시
    [0xE6BC98, 0xD9A57E, 0xB5805C], // 태닝
    [0xC08A63, 0xA9714D, 0x865438], // 브론즈
    [0xFFF7F0, 0xFDF0E6, 0xEBD5C6], // 밀키
    [0xE4DAD6, 0xD6C8C4, 0xB3A19D], // 스산
    [0xF3EDF2, 0xE9E0EA, 0xC9BCCB], // 창백
    [0xFFEAE6, 0xFBDDD8, 0xE5B5AE], // 노블레스
  ];

  /// 머리색(염색) 8종 × (밝음, 기본, 그늘). 에셋은 0번으로 그린다.
  static const hair = [
    [0x5A463C, 0x3B2E28, 0x251C18], // 흑갈색
    [0x9A6C4A, 0x7A5236, 0x5A3A25], // 갈색
    [0xE2BC7E, 0xC99A5E, 0xA47843], // 금발
    [0xBDBDC6, 0x9A9AA6, 0x77778A], // 회색
    [0xF4B8C8, 0xE893AC, 0xBF6A85], // 핑크
    [0x8FB4E0, 0x6A93C9, 0x4A6FA3], // 블루
    [0xD9694F, 0xB94A36, 0x8C3323], // 레드
    [0xB79AD6, 0x9378BD, 0x6C5693], // 퍼플
  ];

  /// 기본 상의 시트에 쓴 색 (밝음, 기본, 그늘, 무늬). 앱이 [outfit] 색으로 바꾼다.
  static const outfitSheet = [0xEDA77F, 0xE08A5B, 0xB9663D, 0xF8DCCB];

  /// 기본 옷 색 12종 × (밝음, 기본, 그늘, 무늬). 이름은 Minimi.outfitNames.
  static const outfit = [
    [0xEDA77F, 0xE08A5B, 0xB9663D, 0xFFF8EE], // 테라코타
    [0xA9C4A3, 0x8FAE8B, 0x6F8F6B, 0xFFF8EE], // 세이지
    [0xBCD3E8, 0x9DBBD8, 0x6F8FB8, 0xFFF8EE], // 하늘
    [0xE6D6E6, 0xC9A3C9, 0x9C789C, 0xFFF8EE], // 라벤더
    [0xFBEFCB, 0xF2D27A, 0xE5B547, 0xFFF8EE], // 버터
    [0xFFF8EE, 0xF6EBDD, 0xEADBC7, 0x9DBBD8], // 화이트 (무늬는 하늘색)
    [0xF4B8C8, 0xE893AC, 0xBF6A85, 0xFFF8EE], // 핑크
    [0x8FB4E0, 0x6A93C9, 0x4A6FA3, 0xFFF8EE], // 블루
    [0xD9694F, 0xB94A36, 0x8C3323, 0xFFF8EE], // 레드
    [0xB79AD6, 0x9378BD, 0x6C5693, 0xFFF8EE], // 퍼플
    [0xBDBDC6, 0x9A9AA6, 0x77778A, 0xFFF8EE], // 그레이
    [0xB98559, 0x8E6240, 0x6A4630, 0xF2D27A], // 브라운 (무늬는 버터색)
  ];

  /// 기본 옷 색 인덱스로 바꿀 색 표.
  static Map<int, int> outfitSwap(int index) {
    final to = outfit[index % outfit.length];
    return {
      for (var i = 0; i < 4; i++)
        if (outfitSheet[i] != to[i]) outfitSheet[i]: to[i],
    };
  }

  /// 하의 시트에 쓴 천 색 (밝음, 기본, 그늘). 앱이 [bottom] 색으로 바꾼다.
  static const bottomSheet = [0xBCD3E8, 0x9DBBD8, 0x6F8FB8];

  /// 하의 색 12종 × (밝음, 기본, 그늘). 이름은 Minimi.bottomColorNames.
  static const bottom = [
    [0x8E6240, 0x6A4630, 0x4A3628], // 브라운
    [0xBCD3E8, 0x9DBBD8, 0x6F8FB8], // 데님
    [0xE8C9A0, 0xD9B993, 0xC49E74], // 베이지
    [0x5A463C, 0x3B2E28, 0x251C18], // 차콜
    [0xBDBDC6, 0x9A9AA6, 0x77778A], // 그레이
    [0xFFF8EE, 0xF6EBDD, 0xEADBC7], // 화이트
    [0x8FB4E0, 0x6A93C9, 0x4A6FA3], // 블루
    [0xA9C4A3, 0x8FAE8B, 0x6F8F6B], // 세이지
    [0xF4B8C8, 0xE893AC, 0xBF6A85], // 핑크
    [0xE6D6E6, 0xC9A3C9, 0x9C789C], // 라벤더
    [0xFBEFCB, 0xF2D27A, 0xE5B547], // 버터
    [0xEDA77F, 0xE08A5B, 0xB9663D], // 테라코타
  ];

  /// 하의 색 인덱스로 바꿀 색 표.
  static Map<int, int> bottomSwap(int index) {
    final to = bottom[index % bottom.length];
    return {
      for (var i = 0; i < 3; i++)
        if (bottomSheet[i] != to[i]) bottomSheet[i]: to[i],
    };
  }

  /// 산 옷의 색 바꾸기: 옷 그림의 [from] 세 색(밝음, 기본, 그늘)을 기본 옷 색 [index]번으로.
  static Map<int, int> recolorSwap(List<int> from, int index) {
    final to = outfit[index % outfit.length];
    return {
      for (var i = 0; i < 3; i++)
        if (from[i] != to[i]) from[i]: to[i],
    };
  }

  /// 가구 색 바꾸기에 쓰는 램프. 앞 다섯 개는 ItemColor 순서다.
  static const ramps = [terracotta, sage, butter, sky, lavender, cream, floor, wood];

  /// 엔진이 그리는 그림자 (반투명, 에셋에는 쓰지 않음)
  static const shadow = 0x6B4F3A;
  static const shadowAlpha = 0.28;

  static final Set<int> all = {
    ...ink,
    ...cream,
    ...floor,
    ...wood,
    ...sage,
    ...terracotta,
    ...butter,
    ...sky,
    ...lavender,
    for (final r in skin) ...r,
    for (final r in hair) ...r,
  };

  /// 피부·머리 색 인덱스로 바꿀 색 표. 0번 램프 → 고른 램프.
  static Map<int, int> swapFor({required int skinIndex, required int hairIndex}) {
    final out = <int, int>{};
    final s = skin[skinIndex % skin.length], h = hair[hairIndex % hair.length];
    for (var i = 0; i < 3; i++) {
      if (skinIndex % skin.length != 0) out[skin[0][i]] = s[i];
      if (hairIndex % hair.length != 0) out[hair[0][i]] = h[i];
    }
    return out;
  }
}
