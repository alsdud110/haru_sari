import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/catalog.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../settings.dart';
import '../motion.dart';
import '../widgets.dart';
import 'iso_room_view.dart';
import 'room_painter.dart';

/// 내 방: 방 그림 · 미니미 상태 · 방 꾸밈 현황 · 보유 아이템 요약
class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.profile;
    final t = Theme.of(context).textTheme;
    final placed = s.placedFurniture;
    final outfit = itemById(p.outfitId);
    final acc = itemById(p.accessoryId);
    final storedFurniture = s.storedItems.where((i) => i.isFurniture).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 120),
          children: [
            Row(
              children: [
                Expanded(
                  child: Reveal(index: 0, child: Text('${p.name.isEmpty ? '나' : p.name}의 방', style: t.headlineMedium)),
                ),
                const LevelChip(),
                const SizedBox(width: Space.sm),
                const CoinChip(),
              ],
            ),
            const SizedBox(height: Space.lg),
            FullBleed(
              height: FullBleed.heightFor(context),
              child: RoomViewport(builder: (context, fit) => IsoRoomView(fit: fit)),
            ),
            const SizedBox(height: Space.sm),
            Text(
              placed.isEmpty ? '아직 텅 빈 방이에요. 하루를 살아낼 때마다 조금씩 채워져요.' : '지금까지 살아낸 하루들이 이 방을 만들었어요.',
              style: t.bodySmall,
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('가구 상점'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageScreen())),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('보관함'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text('미니미 상태', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            Panel(
              child: Row(
                children: [
                  MinimiView(profile: p, width: 64),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv(t, '입은 옷', outfit?.name ?? '기본 티셔츠'),
                        const SizedBox(height: Space.xs),
                        _kv(t, '액세서리', acc?.name ?? '없음'),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShopScreen(initial: ShopCategory.outfit)),
                    ),
                    child: const Text('옷 고르기'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            Text('방 꾸밈 현황', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            if (placed.isEmpty)
              Text('아직 놓인 가구가 없어요.', style: t.bodySmall)
            else
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: placed.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                  itemBuilder: (context, i) => SizedBox(
                    width: 92,
                    child: _MiniItem(
                      item: placed[i],
                      caption: placed[i].typeLabel,
                      onTap: () => showItemSheet(context, placed[i]),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: Space.xl),
            Text('보유 아이템', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            Panel(
              child: Row(
                children: [
                  _Stat(label: '보관함 아이템', value: '${s.storedItems.length}개'),
                  _Stat(label: '미배치 가구', value: '$storedFurniture개'),
                  _Stat(
                    label: '받은 배지',
                    value: '${p.badges.length}개',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(TextTheme t, String k, String v) => Row(
    children: [
      SizedBox(width: 64, child: Text(k, style: t.bodySmall)),
      Expanded(
        child: Text(v, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              Text(value, style: t.titleLarge),
              const SizedBox(height: 2),
              Text(label, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniItem extends StatelessWidget {
  const _MiniItem({required this.item, required this.caption, required this.onTap});
  final ShopItem item;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppScope.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            children: [
              Expanded(child: ItemThumb(item, size: 56, minimi: s.profile.minimi)),
              Text(
                item.name,
                style: t.bodySmall?.copyWith(color: AppColors.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(caption, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// 방 그림 + 숨 쉬는 미니미
class RoomView extends StatefulWidget {
  const RoomView({super.key, required this.placed});
  final Map<RoomSlot, ShopItem> placed;
  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final mw = c.maxWidth * 0.2;
            return Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: Motion.normal,
                    child: CustomPaint(
                      key: ValueKey(widget.placed.values.map((e) => e.id).join(',')),
                      painter: RoomPainter(widget.placed),
                      size: Size.infinite,
                    ),
                  ),
                ),
                Positioned(
                  left: c.maxWidth * 0.5 - mw / 2,
                  top: h * 0.60,
                  width: mw,
                  height: mw * 1.25,
                  child: Semantics(
                    label: '내 미니미',
                    child: AnimatedBuilder(
                      animation: _breath,
                      builder: (_, child) =>
                          Transform.translate(offset: Offset(0, reduceMotion ? 0 : -2 * _breath.value), child: child),
                      child: MinimiView(profile: s.profile, width: mw),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────── 상점 ─────────

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initial = ShopCategory.all});
  final ShopCategory initial;
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late ShopCategory _cat = widget.initial;
  bool _affordableOnly = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    var items = shopCatalog.where((i) => _cat == ShopCategory.all || i.category == _cat).toList()
      ..sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.price.compareTo(b.price));
    if (_affordableOnly) items = items.where((i) => s.canBuy(i) == BuyResult.ok).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('가구 상점'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: Space.gutter),
            child: CoinChip(),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryBar(
            value: _cat,
            onChanged: (c) => setState(() => _cat = c),
            trailing: FilterChip(
              label: const Text('살 수 있는 것'),
              selected: _affordableOnly,
              onSelected: (v) => setState(() => _affordableOnly = v),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primarySoft,
              side: const BorderSide(color: AppColors.line),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyHint(emoji: '🪙', title: '지금 살 수 있는 게 없어요', body: '하루를 살아내면 코인이 쌓여요.')
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: Space.sm,
                      crossAxisSpacing: Space.sm,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _ShopCard(item: items[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
              child: Text('레벨이 오르면 새 아이템이 열려요', style: t.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.value, required this.onChanged, this.trailing});
  final ShopCategory value;
  final ValueChanged<ShopCategory> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xs),
      children: [
        for (final c in ShopCategory.values) ...[
          ChoiceChip(
            label: Text(c.label),
            selected: c == value,
            onSelected: (_) => onChanged(c),
            showCheckmark: false,
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primarySoft,
            side: const BorderSide(color: AppColors.line),
          ),
          const SizedBox(width: Space.sm),
        ],
        ?trailing,
      ],
    ),
  );
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.item});
  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final status = s.canBuy(item);
    final owned = status == BuyResult.alreadyOwned;
    final locked = status == BuyResult.levelTooLow;

    final (String label, Color color) = switch (status) {
      BuyResult.alreadyOwned => ('보유 중', AppColors.sage),
      BuyResult.levelTooLow => ('Lv.${item.level}부터', AppColors.textMuted),
      BuyResult.notEnoughCoins => ('${item.price} 코인', AppColors.textMuted),
      BuyResult.ok || BuyResult.okStored => ('${item.price} 코인', AppColors.text),
    };

    return Semantics(
      button: true,
      label: '${item.name}, $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => showItemSheet(context, item),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Opacity(
                      opacity: locked ? 0.35 : 1,
                      child: ItemThumb(item, size: 88, minimi: s.profile.minimi),
                    ),
                  ),
                ),
                Text(item.name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.typeLabel, style: t.bodySmall),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    if (locked) const Icon(Icons.lock_rounded, size: 13, color: AppColors.textMuted),
                    if (!owned && !locked) const Icon(Icons.circle, size: 10, color: AppColors.coin),
                    if (owned) const Icon(Icons.check_rounded, size: 14, color: AppColors.sage),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: t.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── 보관함 ─────────

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  ShopCategory _cat = ShopCategory.all;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final items = s.storedItems.where((i) => _cat == ShopCategory.all || i.category == _cat).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('보관함')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs),
            child: Text('아직 방에 두지 않았거나 입지 않은 아이템이에요', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          ),
          _CategoryBar(value: _cat, onChanged: (c) => setState(() => _cat = c)),
          Expanded(
            child: items.isEmpty
                ? EmptyHint(
                    emoji: '📦',
                    title: '보관함이 비어 있어요',
                    body: s.profile.owned.isEmpty ? '상점에서 첫 아이템을 들여볼까요?' : '가진 아이템을 모두 쓰고 있어요.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: Space.sm,
                      crossAxisSpacing: Space.sm,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _MiniItem(
                      item: items[i],
                      caption: items[i].typeLabel,
                      onTap: () => showItemSheet(context, items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────── 아이템 상세 (구매 확인 / 배치 / 입기) ─────────

Future<void> showItemSheet(BuildContext context, ShopItem item) {
  return showAppSheet<void>(
    context,
    builder: (ctx) {
      final s = AppScope.of(ctx);
      final p = s.profile;
      final t = Theme.of(ctx).textTheme;
      final status = s.canBuy(item);
      final owned = status == BuyResult.alreadyOwned;
      final inUse = owned && s.isInUse(item);
      final current = switch (item.kind) {
        ItemKind.furniture => itemById(p.placed[item.slot!.name]),
        ItemKind.outfit => itemById(p.outfitId),
        ItemKind.accessory => itemById(p.accessoryId),
      };
      final useVerb = item.isFurniture ? '방에 놓기' : '입기';
      final awayVerb = item.isFurniture ? '보관함에 넣기' : '벗기';
      final replaceHint = current != null && current.id != item.id
          ? '지금 ${item.isFurniture ? '놓인' : '쓰고 있는'} ${current.name}은(는) 보관함으로 가요.'
          : null;

      final rows = <(String, String)>[];
      String? hint;
      Widget action;
      if (owned) {
        rows.add(('상태', inUse ? (item.isFurniture ? '방에 놓여 있음' : '착용 중') : '보관 중'));
        if (p.acquired[item.id] case final d?) rows.add(('들인 날', d.replaceAll('-', '.')));
        if (!inUse) hint = replaceHint;
        action = inUse
            ? OutlinedButton(
                onPressed: () {
                  s.putAway(item);
                  Navigator.pop(ctx);
                },
                child: Text(awayVerb),
              )
            : FilledButton(
                onPressed: () {
                  final ok = s.use(item);
                  Navigator.pop(ctx);
                  if (!ok) showAppToast(context, '방에 빈 자리가 없어요. 다른 가구를 보관함에 넣어 주세요');
                },
                child: Text(useVerb),
              );
      } else {
        rows.addAll([('가격', '${item.price} 코인'), ('보유 코인', '${p.coins}')]);
        switch (status) {
          case BuyResult.levelTooLow:
            hint = '레벨 ${item.level}이 되면 살 수 있어요. 지금은 레벨 ${p.level}이에요.';
            action = const FilledButton(onPressed: null, child: Text('아직 잠겨 있어요'));
          case BuyResult.notEnoughCoins:
            hint = '${item.price - p.coins}코인이 더 필요해요. 하루를 살아내면 코인이 쌓여요.';
            action = const FilledButton(onPressed: null, child: Text('코인이 조금 모자라요'));
          default:
            rows.add(('구매 후', '${p.coins - item.price} 코인'));
            hint = replaceHint;
            action = FilledButton(
              onPressed: () {
                final result = s.buy(item);
                if (result == BuyResult.ok || result == BuyResult.okStored) {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  final badges = s.takePendingBadges();
                  showAppToast(
                    context,
                    result == BuyResult.okStored
                        ? '방에 빈 자리가 없어 ${item.name}을(를) 보관함에 넣었어요'
                        : item.isFurniture
                        ? '${item.name}을(를) 방에 들였어요'
                        : '${item.name}을(를) 입었어요',
                  );
                  if (badges.isNotEmpty) showNewBadges(context, badges);
                }
              },
              child: Text('${item.price}코인으로 사서 ${item.isFurniture ? '놓기' : '입기'}'),
            );
        }
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: Space.lg),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.lg)),
                  child: Center(child: ItemThumb(item, size: 140, minimi: p.minimi)),
                ),
                const SizedBox(height: Space.lg),
                Text(item.name, style: t.titleLarge),
                const SizedBox(height: 2),
                Text('${item.typeLabel} · Lv.${item.level}', style: t.bodySmall),
                const SizedBox(height: Space.md),
                for (final (k, v) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(k, style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                        const Spacer(),
                        Text(v, style: t.labelLarge),
                      ],
                    ),
                  ),
                if (hint != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    hint,
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: Space.lg),
                SizedBox(width: double.infinity, child: action),
              ],
            ),
          ),
        ),
      );
    },
  );
}
