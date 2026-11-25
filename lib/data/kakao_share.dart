import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

import '../config.dart';
import 'friends.dart';

/// 친구 초대를 주고받는 바깥 통로 (PLAN_FRIEND_SHARE_STEP1.md 5장).
/// 실제는 카카오톡 공유, 테스트는 가짜를 쓴다.
abstract class FriendInvites {
  /// 카카오톡으로 보낼 수 있는지 (카카오톡이 깔려 있는지).
  Future<bool> kakaoAvailable();

  /// 카카오톡 공유 카드를 보낸다. [name] 은 보내는 사람, [code] 는 8자 코드.
  Future<void> shareToKakao({required String name, required String code});

  /// 카드의 "구경하러 가기"로 앱이 열리면 [onCode] 에 코드를 넘긴다 (형식이 맞는 것만).
  /// 앱이 꺼져 있다가 링크로 켜진 경우도 플러그인이 모아 두었다가 넘겨준다.
  void listen(void Function(String code) onCode);

  /// Android: 공유 글의 Play 링크로 설치했으면 그 링크에 실린 코드 (Install Referrer). 그 밖에는 null.
  Future<String?> installReferrerCode();
}

/// 카카오 실행 링크에서 코드를 꺼낸다. `kakao{키}://kakaolink?code=K7QM3XPD`
String? inviteCodeFromKakaoUri(Uri uri) {
  if (!uri.scheme.startsWith('kakao') || uri.host != 'kakaolink') return null;
  return InviteCode.parse(uri.queryParameters['code']);
}

class KakaoInvites implements FriendInvites {
  KakaoInvites._();

  /// main 에서 한 번. 실패해도 앱은 켜지고, 카카오톡 버튼만 숨는다.
  static Future<KakaoInvites?> init() async {
    try {
      await KakaoSdk.init(nativeAppKey: KakaoConfig.nativeAppKey);
      return KakaoInvites._();
    } catch (e) {
      debugPrint('kakao init failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<bool> kakaoAvailable() async {
    try {
      return await ShareClient.instance.isKakaoTalkSharingAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> shareToKakao({required String name, required String code}) async {
    final link = Link(androidExecutionParams: {'code': code}, iosExecutionParams: {'code': code});
    await ShareClient.instance.shareDefault(
      template: FeedTemplate(
        content: Content(
          title: ShareCopy.kakaoTitle(name),
          description: ShareCopy.kakaoDescription(InviteCode.display(code)),
          imageUrl: Uri.parse(ShareCopy.cardImage),
          imageWidth: 800,
          imageHeight: 400,
          link: link,
        ),
        buttons: [Button(title: ShareCopy.kakaoButton, link: link)],
      ),
    );
  }

  @override
  Future<String?> installReferrerCode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final d = await PlayInstallReferrer.installReferrer;
      return InviteCode.fromReferrer(d.installReferrer);
    } catch (e) {
      // Play 스토어가 없거나 응답이 없으면 (10초) 그냥 넘어간다 → 코드 입력 안내로
      debugPrint('install referrer failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  void listen(void Function(String code) onCode) {
    receiveKakaoScheme((uri) {
      final code = inviteCodeFromKakaoUri(uri);
      if (code != null) onCode(code);
    });
  }
}
