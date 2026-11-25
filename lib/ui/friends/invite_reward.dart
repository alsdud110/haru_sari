import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/friends.dart';
import '../../data/sync.dart';
import '../../theme/tokens.dart';
import '../motion.dart';

/// 초대 보상 (3단계, PLAN_FRIEND_SHARE.md "앱이 없는 친구").

/// 가입 직후 한 번: "친구에게 초대받았나요?" 코드를 넣으면 보상을 받는다.
/// 받았으면 그 결과를, 건너뛰거나 받을 수 없으면 null 을 돌려준다.
Future<({String code, InviteClaim claim})?> askInviteCode(BuildContext context, {String? prefill}) =>
    showAppDialog<({String code, InviteClaim claim})>(
      context,
      dismissible: false,
      builder: (_) => _InviteCodeDialog(prefill: prefill),
    );

/// 보상을 받았다는 창. [친구 루틴 구경하기]를 누르면 true.
Future<bool> showInviteRewardDone(BuildContext context, int gained) async {
  final view = await showAppDialog<bool>(
    context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('친구 링크로 와서 $gained코인 받았어요!'),
      content: const Text('초대한 친구도 코인을 받았어요.\n친구가 공유한 루틴을 구경해 볼까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그냥 시작하기')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('친구 루틴 구경하기')),
      ],
    ),
  );
  return view == true;
}

class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog({this.prefill});
  final String? prefill;

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  late final _c = TextEditingController(text: widget.prefill == null ? '' : InviteCode.display(widget.prefill!));
  late String? _code = widget.prefill;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final code = InviteCode.find(d?.text);
    if (code == null) {
      setState(() => _error = '복사한 글에서 코드를 찾지 못했어요');
      return;
    }
    _c.text = InviteCode.display(code);
    setState(() {
      _code = code;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final code = _code;
    final remote = AppScope.read(context).sync?.remote;
    if (code == null || remote == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await remote.claimInvite(code);
      if (!mounted) return;
      switch (r.result) {
        case ClaimResult.ok:
          Navigator.pop(context, (code: code, claim: r));
        case ClaimResult.notFound:
          setState(() => _error = '코드가 맞지 않거나 공유가 끝났어요');
        case ClaimResult.self:
          setState(() => _error = '내 코드는 넣을 수 없어요');
        case ClaimResult.claimed || ClaimResult.notNew:
          showAppToast(context, '초대 보상은 가입하고 이틀 안에 한 번만 받을 수 있어요');
          Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('invite claim failed: ${e.runtimeType}');
      if (mounted) setState(() => _error = '지금은 확인하지 못했어요. 잠시 후 다시 해 주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('친구에게 초대받았나요?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('받은 코드를 넣으면 나도 친구도 ${InviteRules.newFriendCoins}코인을 받아요.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Space.sm),
        TextField(
          controller: _c,
          maxLength: 20,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'HARU-XXXX-XXXX',
            counterText: '',
            errorText: _error,
            suffixIcon: IconButton(tooltip: '붙여넣기', onPressed: _paste, icon: const Icon(Icons.content_paste_rounded)),
          ),
          onChanged: (v) => setState(() {
            _code = InviteCode.parse(v);
            _error = null;
          }),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('건너뛰기')),
      TextButton(
        onPressed: _code == null || _busy ? null : _submit,
        child: Text(_busy ? '확인 중…' : '${InviteRules.newFriendCoins}코인 받기'),
      ),
    ],
  );
}
