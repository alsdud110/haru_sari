import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;

import '../../app.dart';
import '../../config.dart';
import '../../data/friends.dart';
import '../../data/kakao_share.dart';
import '../../theme/tokens.dart';
import 'friend_widgets.dart';
import 'invite_scope.dart';

/// 개발 빌드 전용: 카카오톡이 없는 기기(에뮬레이터)에서도 카톡 공유 흐름을 볼 수 있게 한다.
/// 보내기를 누르면 카톡 채팅방에 카드가 온 모습을 그려 보여 주고, 카드 버튼은 실제 카톡 링크와 같은
/// 수신 경로(PendingInvite.receive)를 탄다. main.dart 가 kDebugMode 일 때만 씌운다.
class DevKakaoInvites implements FriendInvites {
  DevKakaoInvites(this.real);

  /// 진짜 카카오 (초기화에 실패했으면 null)
  final FriendInvites? real;

  /// 마지막 보내기가 흉내였는지 (화면이 흉내 채팅방을 띄울지 정한다)
  bool lastWasMock = false;

  @override
  Future<bool> kakaoAvailable() async => true;

  @override
  Future<void> shareToKakao({required String name, required String code}) async {
    final r = real;
    if (r != null && await r.kakaoAvailable()) {
      lastWasMock = false;
      return r.shareToKakao(name: name, code: code);
    }
    lastWasMock = true;
  }

  @override
  void listen(void Function(String code) onCode) => real?.listen(onCode);

  @override
  Future<String?> installReferrerCode() async => await real?.installReferrerCode();
}

/// 카톡 채팅방에 공유 카드가 도착한 모습 (개발용 그림).
class DevKakaoChatScreen extends StatelessWidget {
  const DevKakaoChatScreen({super.key, required this.name, required this.code});
  final String name;
  final String code;

  static const _chatBg = Color(0xFFB2C7D9);

  void _open(BuildContext context) {
    // 실제 카드 버튼과 같은 길: 링크로 들어온 코드처럼 넘긴다 → 홈에서 구경 화면이 열린다
    InviteScope.maybeOf(context)?.pending.receive(code);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode);
    final t = Theme.of(context).textTheme;
    final look = SharedLook.fromProfile(AppScope.of(context).profile);
    return Scaffold(
      backgroundColor: _chatBg,
      appBar: AppBar(title: const Text('카카오톡 미리보기 (개발용)')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(Radii.md)),
            child: Text(
              '실제 카카오톡이 아니에요. 카카오톡이 없는 기기에서 카드 모양과 받는 흐름을 확인하는 개발용 화면이에요.',
              style: t.bodySmall,
            ),
          ),
          const SizedBox(height: Space.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.grey)),
              const SizedBox(width: Space.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: t.bodySmall),
                  const SizedBox(height: 4),
                  Container(
                    width: 260,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.md)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 카드 그림 (docs/share/card.png 와 같은 구성: 크림 바탕에 미니미)
                        AspectRatio(
                          aspectRatio: 2,
                          child: ColoredBox(
                            color: AppColors.background,
                            child: Center(child: FriendMinimi(look, width: 64)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ShareCopy.kakaoTitle(name), style: t.titleMedium),
                              const SizedBox(height: 2),
                              Text(ShareCopy.kakaoDescription(InviteCode.display(code)), style: t.bodySmall),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        TextButton(onPressed: () => _open(context), child: const Text(ShareCopy.kakaoButton)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
