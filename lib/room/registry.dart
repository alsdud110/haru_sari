import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'iso.dart';
import 'manifest.dart';

/// draft 에셋을 화면에 쓸지. 출시 빌드는 false (final만 씀).
/// 개발 중 확인: `flutter run --dart-define=SHOW_DRAFT_ASSETS=true`
const kShowDraftAssets = bool.fromEnvironment('SHOW_DRAFT_ASSETS');

class LoadedSprite {
  LoadedSprite(this.image, this.alpha, {this.mirror = false});
  final ui.Image image;

  /// 픽셀별 알파 (터치 판정용)
  final Uint8List alpha;

  /// R1이 없어 R0을 좌우 반전해 쓰는 경우
  final bool mirror;

  bool opaqueAt(int x, int y) {
    final lx = mirror ? image.width - 1 - x : x;
    if (lx < 0 || y < 0 || lx >= image.width || y >= image.height) return false;
    return alpha[y * image.width + lx] > 0;
  }
}

/// 에셋 이미지 로드·캐시·누락 판정 (docs/asset-system/02 §9).
/// 없거나 크기가 틀리거나 draft(출시 빌드)면 null을 돌려준다 → 그리는 쪽이 기존 그림으로 대체한다.
class AssetRegistry extends ChangeNotifier {
  AssetRegistry(this.manifest, {AssetBundle? bundle, bool? showDraft})
      : _bundle = bundle ?? rootBundle,
        showDraft = showDraft ?? kShowDraftAssets;

  final PixelManifest manifest;
  final AssetBundle _bundle;
  final bool showDraft;

  final Map<String, LoadedSprite> _sprites = {};

  /// id·방향 → 쓰지 못한 이유 (디버그용)
  final Map<String, String> problems = {};
  final Set<String> _tried = {};

  bool _usable(ItemArt art) => art.isFinal || showDraft;

  static String _key(String id, Rot r) => '$id#${r.name}';

  /// 그 아이템·방향에 쓸 스프라이트. 없으면 null (대체 그림).
  LoadedSprite? sprite(String id, Rot r) {
    final art = manifest[id];
    if (art == null || !_usable(art)) return null;
    final s = _sprites[_key(id, r)];
    if (s != null) return s;
    if (r == Rot.r1 && art.mirrorR1 && !art.rotations.containsKey(Rot.r1)) {
      final base = _sprites[_key(id, Rot.r0)];
      if (base != null) return LoadedSprite(base.image, base.alpha, mirror: true);
    }
    return null;
  }

  /// 방에 있는 아이템들의 이미지를 미리 읽는다. 한 번 시도한 것은 다시 읽지 않는다.
  Future<void> preload(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      final art = manifest[id];
      if (art == null || !art.isFloor || !_usable(art)) continue;
      for (final e in art.rotations.entries) {
        final k = _key(id, e.key);
        if (!_tried.add(k)) continue;
        final loaded = await _load(art, e.key, e.value);
        if (loaded != null) {
          _sprites[k] = loaded;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  Future<LoadedSprite?> _load(ItemArt art, Rot r, String path) async {
    final k = _key(art.id, r);
    try {
      final data = await _bundle.load('${PixelManifest.assetRoot}$path');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final img = (await codec.getNextFrame()).image;
      final spec = art.spriteSpec(r);
      if (img.width != spec.width || img.height != spec.height) {
        problems[k] = '크기 ${img.width}×${img.height} ≠ ${spec.width}×${spec.height}';
        return null;
      }
      final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
      final alpha = Uint8List(img.width * img.height);
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = rgba[i * 4 + 3];
      }
      return LoadedSprite(img, alpha);
    } catch (e) {
      problems[k] = '불러오기 실패: $path';
      if (kDebugMode) debugPrint('[asset] ${art.id} ${r.name}: 없음 → 기존 그림으로 대체');
      return null;
    }
  }
}

/// 위젯 트리에서 레지스트리를 꺼낸다. 로드가 끝나면 다시 그린다.
class RegistryScope extends InheritedNotifier<AssetRegistry> {
  const RegistryScope({super.key, required AssetRegistry registry, required super.child}) : super(notifier: registry);

  static AssetRegistry? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RegistryScope>()?.notifier;
}
