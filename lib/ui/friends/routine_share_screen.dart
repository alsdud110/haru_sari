import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../app.dart';
import '../../config.dart';
import '../../data/friends.dart';
import '../../data/routine_sharing.dart';
import '../../theme/tokens.dart';
import '../auth_screens.dart' show kakaoLabel, kakaoSymbolSvg, kakaoYellow;
import '../motion.dart';
import '../routine_icon.dart';
import '../widgets.dart';
import 'dev_kakao_preview.dart';
import 'invite_scope.dart';

/// 나의 루틴 공유 화면 (PLAN_FRIEND_SHARE_STEP1.md 2-1).
/// 공유할 루틴을 고르고, 초대 코드를 다른 앱(카카오 연동 뒤에는 카카오톡도)으로 보낸다.
class RoutineShareScreen extends StatefulWidget {
  const RoutineShareScreen({super.key});

  @override
  State<RoutineShareScreen> createState() => _RoutineShareScreenState();
}

class _RoutineShareScreenState extends State<RoutineShareScreen> {
  RoutineSharing? get _sharing => AppScope.read(context).sharing;

  /// 아직 공유 전일 때 고른 것 (공유 중이면 [RoutineSharing.ids] 를 쓴다)
  Set<String>? _draft;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  /// 카카오톡으로 보낼 수 있으면
  bool _kakao = false;

  Future<void> _refresh() async {
    final invites = InviteScope.maybeOf(context)?.invites;
    if (invites != null) {
      invites.kakaoAvailable().then((v) {
        if (mounted) setState(() => _kakao = v);
      });
    }
    final sh = _sharing;
    if (sh != null) {
      try {
        await sh.refresh();
      } catch (e) {
        // 오프라인: 기기에 적어 둔 상태로 그린다
        debugPrint('routine share refresh failed: ${e.runtimeType}');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Set<String> _picked(RoutineSharing sh) {
    if (sh.isOn) return sh.ids;
    return _draft ??= {
      for (final r in AppScope.read(context).routines)
        if (r.active) r.id,
    };
  }

  void _toggle(RoutineSharing sh, String id, bool on) {
    final next = {..._picked(sh)};
    if (on) {
      if (next.length >= RoutineSharing.maxRoutines) {
        showAppToast(context, '한 번에 ${RoutineSharing.maxRoutines}개까지 공유할 수 있어요');
        return;
      }
      next.add(id);
    } else {
      next.remove(id);
    }
    if (sh.isOn) {
      sh.setIds(next);
    } else {
      setState(() => _draft = next);
    }
  }

  /// 공유 전이면 서버에 공유를 만들고 코드를 받는다.
  Future<String?> _ensureCode(RoutineSharing sh) async {
    if (sh.code != null) {
      if (sh.dirty) await sh.flush();
      return sh.code;
    }
    setState(() => _busy = true);
    try {
      return await sh.share(_picked(sh));
    } catch (e) {
      debugPrint('routine share create failed: ${e.runtimeType}');
      if (mounted) showAppToast(context, '지금은 공유를 만들지 못했어요. 잠시 후 다시 해 주세요');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareToApps(RoutineSharing sh) async {
    final box = context.findRenderObject() as RenderBox?;
    final code = await _ensureCode(sh);
    if (code == null || !mounted) return;
    final name = _displayName();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: ShareCopy.otherApps(name, code),
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      debugPrint('routine share sheet failed: ${e.runtimeType}');
    }
  }

  Future<void> _shareToKakao(RoutineSharing sh) async {
    final invites = InviteScope.maybeOf(context)?.invites;
    if (invites == null) return;
    final code = await _ensureCode(sh);
    if (code == null || !mounted) return;
    try {
      await invites.shareToKakao(name: _displayName(), code: code);
      // 개발 빌드 + 카카오톡 없는 기기: 카톡에 카드가 온 모습을 그려 보여 준다
      if (invites is DevKakaoInvites && invites.lastWasMock && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DevKakaoChatScreen(name: _displayName(), code: code)),
        );
      }
    } catch (e) {
      debugPrint('kakao share failed: ${e.runtimeType}');
      if (mounted) showAppToast(context, '카카오톡을 열지 못했어요. 다른 앱으로 보내 주세요');
    }
  }

  String _displayName() {
    final n = AppScope.read(context).profile.name.trim();
    return n.isEmpty ? '친구' : n;
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: InviteCode.display(code)));
    if (mounted) showAppToast(context, '코드를 복사했어요');
  }

  Future<void> _stop(RoutineSharing sh) async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('루틴 공유를 멈출까요?'),
        content: const Text('지금 코드는 더는 쓸 수 없고,\n나를 추가한 친구 목록에서도 빠져요.\n다시 공유하면 새 코드가 만들어져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그대로 둘게요')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('멈추기', style: TextStyle(color: AppColors.primaryInk)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await sh.stop();
      _draft = null;
      if (mounted) showAppToast(context, '루틴 공유를 멈췄어요');
    } catch (e) {
      debugPrint('routine share stop failed: ${e.runtimeType}');
      if (mounted) showAppToast(context, '지금은 멈추지 못했어요. 잠시 후 다시 해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final sh = s.sharing;
    final t = Theme.of(context).textTheme;

    if (sh == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('루틴 공유')),
        body: const Center(
          child: EmptyHint(emoji: '🏠', title: '로그인하면 쓸 수 있어요', body: '루틴 공유는 계정이 있어야 해요'),
        ),
      );
    }

    return ListenableBuilder(
      listenable: sh,
      builder: (context, _) {
        final routines = s.sortedRoutines;
        final picked = _picked(sh);
        final code = sh.code;
        return Scaffold(
          appBar: AppBar(title: const Text('루틴 공유')),
          body: _loading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : routines.isEmpty
              ? const Center(
                  child: EmptyHint(emoji: '🌱', title: '공유할 루틴이 없어요', body: '루틴을 먼저 만들어 주세요'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
                  children: [
                    Text('친구에게 보여 줄 루틴을 골라요', style: t.titleMedium),
                    const SizedBox(height: Space.md),
                    Panel(
                      padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      child: Column(
                        children: [
                          for (final r in routines)
                            CheckboxListTile.adaptive(
                              value: picked.contains(r.id),
                              onChanged: _busy ? null : (v) => _toggle(sh, r.id, v ?? false),
                              activeColor: AppColors.primary,
                              secondary: RoutineIcon(r.emoji),
                              title: Text(r.name, style: t.titleMedium),
                              subtitle: Text(
                                '${weekdaySummary(r.weekdays)} ${formatMinute(r.minuteOfDay)}${r.active ? '' : ' · 쉬는 중'}',
                                style: t.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    if (code != null) ...[
                      Panel(
                        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, Space.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('내 코드', style: t.bodySmall),
                                  Text(InviteCode.display(code), style: t.titleLarge),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _copy(code),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('복사'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                    // 공유하는 사람에게: 초대 보상 한 줄
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Row(
                        children: [
                          const RoutineIcon('🪙', size: 20),
                          const SizedBox(width: Space.xs),
                          Expanded(child: Text(ShareCopy.inviterReward(), style: t.bodySmall)),
                        ],
                      ),
                    ),
                    if (_kakao) ...[
                      FilledButton.icon(
                        onPressed: _busy || picked.isEmpty ? null : () => _shareToKakao(sh),
                        style: FilledButton.styleFrom(backgroundColor: kakaoYellow, foregroundColor: kakaoLabel),
                        // 로그인 화면과 같은 카카오 공식 말풍선 심볼
                        icon: SvgPicture.string(kakaoSymbolSvg, width: 20, height: 20),
                        label: const Text('카카오톡으로 보내기'),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    if (_kakao)
                      OutlinedButton.icon(
                        onPressed: _busy || picked.isEmpty ? null : () => _shareToApps(sh),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('다른 앱으로 보내기'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _busy || picked.isEmpty ? null : () => _shareToApps(sh),
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(code == null ? '공유하고 보내기' : '다른 앱으로 보내기'),
                      ),
                    if (picked.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Text('루틴을 하나 이상 골라 주세요', style: t.bodySmall, textAlign: TextAlign.center),
                      ),
                    if (code != null) ...[
                      const SizedBox(height: Space.sm),
                      TextButton(
                        onPressed: _busy ? null : () => _stop(sh),
                        child: const Text('공유 멈추기', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
