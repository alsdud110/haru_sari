import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneul_sari/data/models.dart';
import 'package:oneul_sari/room/iso.dart';
import 'package:oneul_sari/room/layout.dart';
import 'package:oneul_sari/room/manifest.dart';
import 'package:oneul_sari/room/registry.dart';
import 'package:oneul_sari/room/scene.dart';
import 'package:oneul_sari/ui/room/iso_room_painter.dart';
import 'package:oneul_sari/ui/room/room_painter.dart';

import 'manifest_test.dart' show fakeSprite, loadManifest;

/// 테스트용 번들: 지정한 경로만 바이트를 돌려주고 나머지는 없음
class FakeBundle extends CachingAssetBundle {
  FakeBundle(this.files);
  final Map<String, Uint8List> files;
  @override
  Future<ByteData> load(String key) async {
    final f = files[key];
    if (f == null) throw FlutterError('없음: $key');
    return ByteData.sublistView(f);
  }
}

RoomLayout referenceScene() => RoomLayout(
      floor: {
        'bed_single': const FloorPos(0, 1),
        'lamp_stand': const FloorPos(1, 1),
        'desk_wood': const FloorPos(5, 1),
        'chair_wood': const FloorPos(5, 2),
        'plant_small': const FloorPos(7, 3),
        'rug_round': const FloorPos(3, 2),
      },
      wall: {
        'window_curtain': const WallPos(left: true, u: 2, z: 40),
        'shelf_book': const WallPos(left: false, u: 5, z: 72),
      },
      minimi: (4, 4),
    );

void main() {
  final m = loadManifest();

  test('장면 순서: 러그 → 벽 장식 → 깊이 정렬된 물체·미니미', () {
    final s = RoomScene.build(referenceScene(), m);
    expect(s.entries.map((e) => e.id).toList(), [
      'rug_round',
      'window_curtain',
      'shelf_book',
      'bed_single',
      'lamp_stand',
      'desk_wood',
      'chair_wood',
      RoomScene.minimiId,
      'plant_small',
    ]);
  });

  test('미니미 발이 타일 중심에 놓인다', () {
    final b = RoomScene.minimiBox(4, 4);
    final c = IsoGrid.tileCenter(4, 4);
    expect(b.left + RoomScene.minimiFrame.ax, c.dx.round());
    expect(b.top + RoomScene.minimiFrame.ay, c.dy.round());
  });

  test('터치 판정: 앞의 물체가 먼저, 미니미는 고르지 않음, 빈 곳은 null', () {
    final s = RoomScene.build(referenceScene(), m);
    final chair = s.entries.firstWhere((e) => e.id == 'chair_wood');
    expect(s.hitTest(chair.box.rect.center), 'chair_wood');
    final bed = s.entries.firstWhere((e) => e.id == 'bed_single');
    expect(s.hitTest(Offset(bed.box.left + 20.0, bed.box.top + 60.0)), 'bed_single');
    expect(s.hitTest(IsoGrid.tileCenter(4, 6)), isNull);
    // 알파 마스크가 투명이라고 하면 뒤의 것으로 넘어간다
    expect(s.hitTest(chair.box.rect.center, opaque: (e, _, _) => e.id != 'chair_wood'), isNot('chair_wood'));
  });

  test('끌고 있는 가구는 override 위치로 장면이 다시 계산된다', () {
    final s = RoomScene.build(referenceScene(), m, override: {'chair_wood': const FloorPos(2, 6)});
    final chair = s.entries.firstWhere((e) => e.id == 'chair_wood');
    expect(chair.footprint, (2, 6, 1, 1));
  });

  group('레지스트리 (PNG 없음 → 대체 그림)', () {
    testWidgets('draft이거나 파일이 없으면 null, 출시 모드는 draft를 읽지 않는다', (tester) async {
      await tester.runAsync(() async {
        final reg = PixelRegistryTestHelper.make(m, files: {}, showDraft: false);
        await reg.preload(['bed_single']);
        expect(reg.sprite('bed_single', Rot.r0), isNull);
        expect(reg.problems, isEmpty, reason: '출시 모드는 draft 파일을 열어 보지도 않는다');

        final dev = PixelRegistryTestHelper.make(m, files: {}, showDraft: true);
        await dev.preload(['bed_single']);
        expect(dev.sprite('bed_single', Rot.r0), isNull);
        expect(dev.problems.keys, contains('bed_single#r0'));
      });
    });

    testWidgets('개발 모드: 크기가 맞는 PNG는 쓰고, 틀리면 거른다. 반전 허용이면 R1 = R0 반전', (tester) async {
      await tester.runAsync(() async {
        final good = await fakeSprite(96, 104, const [(10.0, 60.0), (80.0, 60.0), (60.0, 100.0)]);
        final bad = await fakeSprite(90, 90, const [(10.0, 10.0), (80.0, 10.0), (40.0, 80.0)]);
        final plant = await fakeSprite(64, 72, const [(20.0, 20.0), (44.0, 20.0), (32.0, 70.0)]);
        final reg = PixelRegistryTestHelper.make(m, showDraft: true, files: {
          'assets/pixel/furniture/beds/bed_single_r0.png': good,
          'assets/pixel/furniture/beds/bed_single_r1.png': bad,
          'assets/pixel/furniture/decorations/plant_small_r0.png': plant,
        });
        await reg.preload(['bed_single', 'plant_small']);
        expect(reg.sprite('bed_single', Rot.r0), isNotNull);
        expect(reg.sprite('bed_single', Rot.r1), isNull);
        expect(reg.problems['bed_single#r1'], contains('크기'));
        final mir = reg.sprite('plant_small', Rot.r1);
        expect(mir, isNotNull);
        expect(mir!.mirror, isTrue);
        // 알파 마스크: 칠한 곳은 불투명, 바깥은 투명
        final s = reg.sprite('bed_single', Rot.r0)!;
        expect(s.opaqueAt(50, 70), isTrue);
        expect(s.opaqueAt(2, 2), isFalse);
      });
    });
  });

  testWidgets('그리기: PNG 없이 기준 장면이 예외 없이 그려진다', (tester) async {
    final l = referenceScene();
    final painter = IsoRoomPainter(
      layout: l,
      scene: RoomScene.build(l, m),
      manifest: m,
      registry: null,
      drawMinimi: (c, r) => MinimiPainter(const Minimi()).paint(c, r.size),
      editing: true,
      selected: 'desk_wood',
      ghost: const DragGhost(id: 'chair_wood', ok: false),
    );
    await tester.pumpWidget(Center(child: RepaintBoundary(child: CustomPaint(size: const Size(512, 432), painter: painter))));
    expect(tester.takeException(), isNull);
  });
}

class PixelRegistryTestHelper {
  static AssetRegistry make(PixelManifest m, {required Map<String, Uint8List> files, required bool showDraft}) =>
      AssetRegistry(m, bundle: FakeBundle(files), showDraft: showDraft);
}
