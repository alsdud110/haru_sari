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

  /// 피부 4종 × (밝음, 기본, 그늘). 에셋은 0번으로 그린다.
  static const skin = [
    [0xFDEBDD, 0xFBE3D0, 0xE8C2A6],
    [0xF6D8BC, 0xF1CBAA, 0xD9A884],
    [0xE6BC98, 0xD9A57E, 0xB5805C],
    [0xC08A63, 0xA9714D, 0x865438],
  ];

  /// 머리 4종 × (밝음, 기본, 그늘). 에셋은 0번으로 그린다.
  static const hair = [
    [0x5A463C, 0x3B2E28, 0x251C18],
    [0x9A6C4A, 0x7A5236, 0x5A3A25],
    [0xE2BC7E, 0xC99A5E, 0xA47843],
    [0xBDBDC6, 0x9A9AA6, 0x77778A],
  ];

  /// 엔진이 그리는 그림자 (반투명, 에셋에는 쓰지 않음)
  static const shadow = 0x6B4F3A;
  static const shadowAlpha = 0.28;

  static final Set<int> all = {
    ...ink, ...cream, ...floor, ...wood, ...sage, ...terracotta, ...butter, ...sky, ...lavender,
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
