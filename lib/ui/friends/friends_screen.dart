import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/friend_alarm_sync.dart';
import '../../data/friends.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import '../widgets.dart';
import 'friend_preview_screen.dart';
import 'friend_routines_screen.dart';
import 'friend_widgets.dart';

/// 친구 목록 (PLAN_FRIEND_SHARE_STEP1.md 2-2). 화면을 열 때마다 서버에서 받는다.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<FriendShare>? _friends;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final remote = AppScope.read(context).sync?.remote;
    try {
      if (remote == null) throw StateError('no remote');
      final list = await remote.friendRoutines();
      // 친구가 시간을 바꿨거나 공유를 멈췄으면 알림도 맞춘다
      if (mounted) applyFriendAlarms(AppScope.read(context), list);
      if (mounted) {
        setState(() {
          _friends = list;
          _failed = false;
        });
      }
    } catch (e) {
      debugPrint('friend routines failed: ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _enterCode() async {
    final code = await askFriendCode(context);
    if (code == null || !mounted) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FriendPreviewScreen(code: code)),
    );
    if (added == true) _load();
  }

  Future<void> _open(FriendShare f) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FriendRoutinesScreen(friend: f)),
    );
    // 친구를 끊었거나 알림을 바꿨을 수 있으니 다시 받는다
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final friends = _friends;
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 루틴'),
        actions: [
          TextButton.icon(
            onPressed: _enterCode,
            icon: const Icon(Icons.person_add_alt_rounded, size: 20),
            label: const Text('코드로 추가'),
          ),
        ],
      ),
      body: _failed && friends == null
          ? Center(
              child: EmptyHint(
                emoji: '💬',
                title: '불러오지 못했어요',
                body: friendLoadError,
                action: OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
              ),
            )
          : friends == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : RefreshIndicator.adaptive(
              onRefresh: _load,
              child: friends.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: Space.xl),
                        Center(
                          child: EmptyHint(
                            emoji: '🌱',
                            title: '아직 친구가 없어요',
                            body: '친구에게 받은 코드를 넣어 보세요',
                            action: OutlinedButton(onPressed: _enterCode, child: const Text('코드로 추가')),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
                      itemCount: friends.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                      itemBuilder: (context, i) {
                        if (i == friends.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: Space.sm),
                            child: Text('친구 ${friends.length} / $maxFriends명', style: t.bodySmall, textAlign: TextAlign.center),
                          );
                        }
                        final f = friends[i];
                        return Panel(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            onTap: () => _open(f),
                            leading: FriendMinimi(f.look, width: 44),
                            title: Text(f.displayName, style: t.titleMedium),
                            subtitle: Text('루틴 ${f.routines.length}개', style: t.bodySmall),
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// 코드 입력 창을 띄우고, 형식이 맞는 8자 코드를 돌려준다 (취소면 null). 구경 화면의 "다른 코드 넣기"도 쓴다.
Future<String?> askFriendCode(BuildContext context) => showAppDialog<String>(context, builder: (_) => const _CodeDialog());

/// 코드 입력 창. 형식이 맞을 때만 확인이 켜진다. 정규화된 8자를 돌려준다.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _c = TextEditingController();
  String? _code;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    // 공유 글 전체를 붙여 넣어도 코드만 찾는다
    final code = InviteCode.find(d?.text);
    if (code == null) return;
    _c.text = InviteCode.display(code);
    setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('코드로 친구 추가'),
    content: TextField(
      controller: _c,
      autofocus: true,
      maxLength: 20,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        hintText: 'HARU-XXXX-XXXX',
        counterText: '',
        suffixIcon: IconButton(tooltip: '붙여넣기', onPressed: _paste, icon: const Icon(Icons.content_paste_rounded)),
      ),
      onChanged: (v) => setState(() => _code = InviteCode.parse(v)),
      onSubmitted: (_) {
        if (_code != null) Navigator.pop(context, _code);
      },
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      TextButton(onPressed: _code == null ? null : () => Navigator.pop(context, _code), child: const Text('확인')),
    ],
  );
}
