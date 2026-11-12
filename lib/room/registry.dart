import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/catalog.dart';
import 'iso.dart';
import 'manifest.dart';
import 'palette.dart';

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
/// 없거나 크기가 틀리면 null을 돌려준다 → 그리는 쪽이 기존 그림으로 대체한다.
class AssetRegistry extends ChangeNotifier {
  AssetRegistry(this.manifest, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final PixelManifest manifest;
  final AssetBundle _bundle;

  final Map<String, LoadedSprite> _sprites = {};
  final Map<String, ui.Image> _minimiCache = {};
  final Set<String> _minimiTried = {};

  void _changed() => notifyListeners();

  /// id·방향 → 쓰지 못한 이유 (디버그용)
  final Map<String, String> problems = {};
  final Set<String> _tried = {};

  static String _key(String id, Rot r) => '$id#${r.name}';

  final Map<String, int> _ramps = {};

  /// 그 가구에서 색이 바뀌는 램프 번호 (PixelPalette.ramps). 아직 안 읽었으면 null, 바꿀 색이 없으면 -1.
  int? recolorRampOf(String id) => _ramps[baseIdOf(id)];

  /// 그 아이템·방향에 쓸 스프라이트. 없으면 null (대체 그림).
  LoadedSprite? sprite(String id, Rot r) {
    final art = manifest[id];
    if (art == null) return null;
    final s = _sprites[_key(id, r)];
    if (s != null) return s;
    // 대칭 물체: R0 한 장으로 네 방향을 그린다 (R1·R3은 좌우 반전)
    if (art.mirrorR1 && !art.rotations.containsKey(r)) {
      final base = _sprites[_key(id, Rot.r0)];
      if (base != null) return LoadedSprite(base.image, base.alpha, mirror: r.index.isOdd);
    }
    return null;
  }

  /// 방 바닥('floors')·벽('walls')의 픽셀 그림. 방 전체 크기(512×432) 한 장이다. 없으면 null.
  ui.Image? surface(String kind, String? id) => _surfaces[surfacePath(kind, id)];

  static String surfacePath(String kind, String? id) => 'rooms/$kind/${id ?? 'default'}.png';

  final Map<String, ui.Image> _surfaces = {};

  /// 지금 방의 바닥·벽 그림을 미리 읽는다.
  Future<void> preloadSurfaces({String? floor, String? wall}) async {
    var changed = false;
    for (final path in [surfacePath('floors', floor), surfacePath('walls', wall)]) {
      if (!_tried.add(path)) continue;
      try {
        final data = await _bundle.load('${PixelManifest.assetRoot}$path');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final img = (await codec.getNextFrame()).image;
        if (img.width == IsoGrid.canvasW && img.height == IsoGrid.canvasH) {
          _surfaces[path] = img;
          changed = true;
        }
      } catch (_) {
        // 그림이 없으면 화면에서 바로 그린다
      }
    }
    if (changed) notifyListeners();
  }

  /// 벽 장식 그림 (왼쪽 벽 기울기로 그린 한 장). 오른쪽 벽에서는 그리는 쪽이 좌우로 뒤집는다. 없으면 null.
  LoadedSprite? wallSprite(String id) => _sprites['$id#wall'];

  /// 방에 있는 아이템들의 이미지를 미리 읽는다. 한 번 시도한 것은 다시 읽지 않는다.
  Future<void> preload(Iterable<String> ids) async {
    var changed = false;
    for (final id in ids) {
      final art = manifest[id];
      if (art != null && art.layer == ArtLayer.wall && art.path != null) {
        if (_tried.add('$id#wall')) {
          final loaded = await _loadWall(art);
          if (loaded != null) {
            _sprites['$id#wall'] = loaded;
            changed = true;
          }
        }
        continue;
      }
      if (art == null || !art.isFloor) continue;
      for (final e in art.rotations.entries) {
        final k = _key(id, e.key);
        if (!_tried.add(k)) continue;
        final loaded = await _load(art, e.key, e.value, id);
        if (loaded != null) {
          _sprites[k] = loaded;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  Future<LoadedSprite?> _loadWall(ItemArt art) async {
    try {
      final data = await _bundle.load('${PixelManifest.assetRoot}${art.path}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final img = (await codec.getNextFrame()).image;
      final box = IsoGrid.wallBox(left: true, u: 0, span: art.span, z: 0, h: art.height);
      if (img.width != box.width || img.height != box.height) {
        problems['${art.id}#wall'] = '크기 ${img.width}×${img.height} ≠ ${box.width}×${box.height}';
        return null;
      }
      return LoadedSprite(img, Uint8List(0));
    } catch (_) {
      return null; // 그림이 없으면 기존 그림으로 그린다
    }
  }

  Future<LoadedSprite?> _load(ItemArt art, Rot r, String path, String id) async {
    final k = _key(id, r);
    try {
      final data = await _bundle.load('${PixelManifest.assetRoot}$path');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      var img = (await codec.getNextFrame()).image;
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
      // 방향마다 많이 쓰인 색이 다를 수 있어 R0에서 정한 램프를 네 방향에 같이 쓴다
      final ramp = _ramps[art.id] ??= recolorRamp(rgba);
      final color = itemById(id)?.color;
      if (color != null && ramp >= 0) {
        final from = PixelPalette.ramps[ramp], to = PixelPalette.ramps[color.index];
        img = await paletteSwap(img, {
          for (var i = 0; i < from.length; i++) from[i]: to[i < to.length ? i : to.length - 1],
        });
      }
      return LoadedSprite(img, alpha);
    } catch (e) {
      problems[k] = '불러오기 실패: $path';
      if (kDebugMode) debugPrint('[asset] ${art.id} ${r.name}: 없음 → 기존 그림으로 대체');
      return null;
    }
  }
}

/// 미니미 방향 (01 §8.2): 정면, 측면 오른쪽, 측면 왼쪽(오른쪽 반전). 뒷모습은 없다.
enum MinimiFacing { front, sideRight, sideLeft }

/// 미니미 레이어 하나 (시트 + 반전 여부)
class MinimiLayer {
  const MinimiLayer(this.name, this.sheet, {this.mirror = false});
  final String name;
  final ui.Image sheet;
  final bool mirror;
}

/// 미니미 시트 규격: 프레임 64×96, 가로 4프레임, 세로 2줄(정면, 측면) → 256×192
class MinimiSheet {
  static const frameW = 64, frameH = 96, frames = 4, rows = 2;
  static const width = frameW * frames, height = frameH * rows;

  /// 그리는 순서 (01 §8.4). 정면·측면 같음.
  static const order = [
    'hair_back',
    'base',
    'eyes',
    'mouth',
    'outfit',
    'hair_front',
    'acc_ear',
    'acc_head',
    'acc_face',
  ];

  static ui.Rect src(int frame, MinimiFacing f) => ui.Rect.fromLTWH(
    (frame % frames) * frameW.toDouble(),
    (f == MinimiFacing.front ? 0 : 1) * frameH.toDouble(),
    frameW.toDouble(),
    frameH.toDouble(),
  );
}

extension MinimiAssets on AssetRegistry {
  /// 필요한 레이어 경로들 (이름 → (경로, 반전 가능, 색 바꾸기 대상, 쓸 수 있는지))
  List<(String, String, bool, String?, bool)> _minimiPaths(
    String? outfitId,
    String? accessoryId,
    MinimiFacing f, [
    int hairStyle = 0,
    int eyes = 0,
    int mouth = 0,
    String? earringId,
  ]) {
    final out = <(String, String, bool, String?, bool)>[];
    void base(String name, String key, String? swap) {
      final b = manifest.base[key];
      final path = b?.sheets['idle'];
      out.add((name, path ?? '', true, swap, path != null));
    }

    void item(String name, String? id) {
      if (id == null) return;
      final a = manifest[id];
      final left = f == MinimiFacing.sideLeft && a != null && !a.mirror;
      final path = a?.sheets[left ? 'idle_left' : 'idle'];
      out.add((name, path ?? '', a?.mirror ?? true, null, path != null));
    }

    final acc = accessoryId == null ? null : manifest[accessoryId];
    // 머리 모양 0번은 번호 없는 키, 그 밖에는 `_번호`가 붙는다
    final style = hairStyle == 0 ? '' : '_$hairStyle';
    base('hair_back', 'minimi_hair_back$style', 'hair');
    base('base', 'minimi_base', 'skin');
    if (manifest.base.containsKey('minimi_eyes_0')) {
      base('eyes', 'minimi_eyes_$eyes', null);
      base('mouth', 'minimi_mouth_$mouth', null);
    }
    // 옷을 안 입었으면 기본 옷 (Minimi.outfit 색으로 바꿔 칠한다)
    if (outfitId == null && manifest.base.containsKey('minimi_outfit')) base('outfit', 'minimi_outfit', 'outfit');
    item('outfit', outfitId);
    if (!(acc?.hides.contains('hair_front') ?? false)) base('hair_front', 'minimi_hair_front$style', 'hair');
    item('acc_ear', earringId);
    if (acc != null) item(acc.slot == 'face' ? 'acc_face' : 'acc_head', accessoryId);
    return out;
  }

  static String _sheetKey(String path, String? swap, int skin, int hair, int outfit) =>
      '$path|${switch (swap) {
        'skin' => skin,
        'hair' => hair,
        'outfit' => outfit,
        _ => '-',
      }}';

  /// 미니미 레이어 시트를 읽고 피부·머리·기본 옷 색을 바꿔 캐시한다.
  Future<void> preloadMinimi({
    required String? outfitId,
    required String? accessoryId,
    required int skin,
    required int hair,
    int outfit = 0,
    int hairStyle = 0,
    int eyes = 0,
    int mouth = 0,
    String? earringId,
  }) async {
    var changed = false;
    for (final f in [MinimiFacing.front, MinimiFacing.sideLeft]) {
      for (final (_, path, _, swap, usable) in _minimiPaths(
        outfitId,
        accessoryId,
        f,
        hairStyle,
        eyes,
        mouth,
        earringId,
      )) {
        if (!usable) continue;
        final key = _sheetKey(path, swap, skin, hair, outfit);
        if (_minimiCache.containsKey(key) || !_minimiTried.add(key)) continue;
        try {
          final data = await _bundleOf(this).load('${PixelManifest.assetRoot}$path');
          final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
          var img = (await codec.getNextFrame()).image;
          if (img.width != MinimiSheet.width || img.height != MinimiSheet.height) {
            problems[key] = '크기 ${img.width}×${img.height} ≠ ${MinimiSheet.width}×${MinimiSheet.height}';
            continue;
          }
          if (swap != null) {
            final table = switch (swap) {
              'skin' => PixelPalette.swapFor(skinIndex: skin, hairIndex: 0),
              'hair' => PixelPalette.swapFor(skinIndex: 0, hairIndex: hair),
              _ => PixelPalette.outfitSwap(outfit),
            };
            img = await paletteSwap(img, table);
          }
          _minimiCache[key] = img;
          changed = true;
        } catch (_) {
          problems[key] = '불러오기 실패: $path';
        }
      }
    }
    if (changed) _changed();
  }

  /// 그릴 레이어 목록 (그리는 순서). 하나라도 없으면 null → 미니미 전체를 기존 그림으로.
  List<MinimiLayer>? minimiLayers({
    required String? outfitId,
    required String? accessoryId,
    required int skin,
    required int hair,
    int outfit = 0,
    int hairStyle = 0,
    int eyes = 0,
    int mouth = 0,
    String? earringId,
    MinimiFacing facing = MinimiFacing.front,
  }) {
    final out = <MinimiLayer>[];
    for (final (name, path, mirrorable, swap, usable) in _minimiPaths(
      outfitId,
      accessoryId,
      facing,
      hairStyle,
      eyes,
      mouth,
      earringId,
    )) {
      if (!usable) return null;
      final img = _minimiCache[_sheetKey(path, swap, skin, hair, outfit)];
      if (img == null) return null;
      final isLeftSheet = path.contains('_left');
      out.add(MinimiLayer(name, img, mirror: facing == MinimiFacing.sideLeft && mirrorable && !isLeftSheet));
    }
    out.sort((a, b) => MinimiSheet.order.indexOf(a.name).compareTo(MinimiSheet.order.indexOf(b.name)));
    return out;
  }
}

/// 가구 그림에서 색을 바꿀 램프 번호 (PixelPalette.ramps). 없으면 -1.
/// 강조색이 20% 넘게 쓰였으면 그중 가장 많은 것(침대 이불), 아니면 가장 많이 쓰인 램프(원목 몸통).
/// 그것도 20%가 안 되면 바꿔도 티가 안 나서 색을 고르지 않는다.
int recolorRamp(Uint8List rgba) {
  final n = List.filled(PixelPalette.ramps.length, 0);
  var total = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i + 3] == 0) continue;
    final rgb = (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    if (PixelPalette.ink.contains(rgb)) continue;
    total++;
    final r = PixelPalette.ramps.indexWhere((l) => l.contains(rgb));
    if (r >= 0) n[r]++;
  }
  int top(int end) {
    var best = 0;
    for (var i = 1; i < end; i++) {
      if (n[i] > n[best]) best = i;
    }
    return best;
  }

  bool enough(int r) => total > 0 && n[r] * 5 >= total;
  final accent = top(ItemColor.values.length), any = top(n.length);
  return enough(accent) ? accent : (enough(any) ? any : -1);
}

/// 0번 램프 색과 정확히 같은 픽셀만 고른 램프 색으로 바꾼다 (01 §6).
Future<ui.Image> paletteSwap(ui.Image src, Map<int, int> table) async {
  if (table.isEmpty) return src;
  final bytes = (await src.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  final out = Uint8List.fromList(bytes);
  for (var i = 0; i < out.length; i += 4) {
    if (out[i + 3] == 0) continue;
    final rgb = (out[i] << 16) | (out[i + 1] << 8) | out[i + 2];
    final to = table[rgb];
    if (to == null) continue;
    out[i] = to >> 16;
    out[i + 1] = (to >> 8) & 255;
    out[i + 2] = to & 255;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, src.width, src.height, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// 위젯 트리에서 레지스트리를 꺼낸다. 로드가 끝나면 다시 그린다.
class RegistryScope extends InheritedNotifier<AssetRegistry> {
  const RegistryScope({super.key, required AssetRegistry registry, required super.child}) : super(notifier: registry);

  static AssetRegistry? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RegistryScope>()?.notifier;
}

AssetBundle _bundleOf(AssetRegistry r) => r._bundle;
