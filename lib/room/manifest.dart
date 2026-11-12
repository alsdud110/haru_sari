import 'dart:convert';

import 'package:flutter/services.dart';

import 'iso.dart';

enum ArtLayer { object, floorDecor, wall, surface, character }

enum ArtStatus { draft, finalArt }

ArtStatus _status(Object? v) => v == 'final' ? ArtStatus.finalArt : ArtStatus.draft;

/// 아이템 하나의 그림 정보 (docs/asset-system/02 §2). 키는 ShopItem.id.
/// 크기·앵커는 저장하지 않고 [footprint]·[height]로 계산한다.
class ItemArt {
  ItemArt({
    required this.id,
    required this.layer,
    this.status = ArtStatus.draft,
    this.rev = 1,
    this.footprint = (1, 1),
    this.height = 0,
    this.blocking = true,
    this.rotations = const {},
    this.mirrorR1 = false,
    this.span = 1,
    this.zRange = (16, 120),
    this.path,
    this.slot,
    this.sheets = const {},
    this.hides = const [],
    this.mirror = true,
  });

  final String id;
  final ArtLayer layer;
  final ArtStatus status;
  final int rev;

  /// R0 기준 점유 (w, d)
  final (int, int) footprint;
  final int height;
  final bool blocking;
  final Map<Rot, String> rotations;

  /// R1 그림이 없을 때 R0을 반전해 R1로 써도 되는지 (대칭 물체)
  final bool mirrorR1;

  // 벽 장식
  final int span;
  final (int, int) zRange;

  /// 벽 장식·벽지 등 단일 경로
  final String? path;

  // 캐릭터
  final String? slot;
  final Map<String, String> sheets;
  final List<String> hides;
  final bool mirror;

  bool get isFinal => status == ArtStatus.finalArt;

  /// 바닥에 놓는 것은 모두 네 방향으로 돌릴 수 있다 (그림이 없는 방향은 대체 그림).
  bool get rotatable => isFloor;
  bool get isFloor => layer == ArtLayer.object || layer == ArtLayer.floorDecor;

  (int, int) footprintFor(Rot r) => r.index.isEven ? footprint : (footprint.$2, footprint.$1);

  ({int width, int height, int ax, int ay}) spriteSpec(Rot r) {
    final (w, d) = footprintFor(r);
    return IsoGrid.spriteSpec(w, d, height);
  }

  factory ItemArt.fromJson(String id, Map<String, dynamic> j) {
    (int, int) pair(Object? v, (int, int) dflt) {
      if (v is List && v.length == 2) return ((v[0] as num).toInt(), (v[1] as num).toInt());
      return dflt;
    }

    final rots = <Rot, String>{};
    final r = j['rotations'];
    if (r is Map) {
      if (r['r0'] is String) rots[Rot.r0] = r['r0'] as String;
      if (r['r1'] is String) rots[Rot.r1] = r['r1'] as String;
    }
    return ItemArt(
      id: id,
      layer: ArtLayer.values.byName(j['layer'] as String),
      status: _status(j['status']),
      rev: (j['rev'] as num?)?.toInt() ?? 1,
      footprint: pair(j['footprint'], (1, 1)),
      height: (j['height'] as num?)?.toInt() ?? 0,
      blocking: j['blocking'] as bool? ?? (j['layer'] == 'object'),
      rotations: rots,
      mirrorR1: j['mirrorR1'] as bool? ?? false,
      span: (j['span'] as num?)?.toInt() ?? 1,
      zRange: pair(j['zRange'], (16, 120)),
      path: j['path'] as String?,
      slot: j['slot'] as String?,
      sheets: ((j['sheets'] as Map?) ?? {}).cast<String, String>(),
      hides: ((j['hides'] as List?) ?? []).cast<String>(),
      mirror: j['mirror'] as bool? ?? true,
    );
  }
}

/// 방 바닥·벽 기본 에셋과 미니미 기본 레이어.
class BaseArt {
  BaseArt({required this.key, required this.path, this.status = ArtStatus.draft, this.sheets = const {}});
  final String key;
  final String? path;
  final ArtStatus status;
  final Map<String, String> sheets;
  bool get isFinal => status == ArtStatus.finalArt;
}

class PixelManifest {
  PixelManifest({required this.version, required this.items, required this.base});

  final int version;
  final Map<String, ItemArt> items;

  /// 'floor', 'wallL', 'minimi_base', 'minimi_outfit'(기본 옷), 'minimi_hair_front', 'minimi_hair_back'
  final Map<String, BaseArt> base;

  static const assetRoot = 'assets/pixel/';
  static const manifestPath = 'assets/pixel/manifest.json';

  ItemArt? operator [](String id) => items[id];

  /// 바닥·벽이 모두 final이어야 아이소메트릭 기본 그림을 쓴다.
  bool get roomBaseFinal => (base['floor']?.isFinal ?? false) && (base['wallL']?.isFinal ?? false);

  factory PixelManifest.parse(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final items = <String, ItemArt>{};
    ((j['items'] as Map?) ?? {}).forEach((k, v) {
      items[k as String] = ItemArt.fromJson(k, (v as Map).cast<String, dynamic>());
    });
    final base = <String, BaseArt>{};
    ((j['base'] as Map?) ?? {}).forEach((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      base[k as String] = BaseArt(
        key: k,
        path: m['path'] as String?,
        status: _status(m['status']),
        sheets: ((m['sheets'] as Map?) ?? {}).cast<String, String>(),
      );
    });
    return PixelManifest(version: (j['version'] as num?)?.toInt() ?? 1, items: items, base: base);
  }

  static Future<PixelManifest> load([AssetBundle? bundle]) async =>
      PixelManifest.parse(await (bundle ?? rootBundle).loadString(manifestPath));
}
