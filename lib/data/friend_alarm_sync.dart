import 'package:flutter/foundation.dart';

import 'friends.dart';
import 'store.dart';
import 'sync.dart';

/// 친구 루틴 알림을 서버 친구 목록에 맞춘다 (2단계).
/// 친구가 루틴 시간을 바꾸거나 공유를 멈추면, 내가 다음에 앱을 열 때 알림도 따라 바뀐다.

/// 이미 받아 온 친구 목록으로 맞춘다 (친구 화면).
void applyFriendAlarms(AppState s, List<FriendShare> friends) => s.setFriendAlarms([for (final f in friends) ...f.alarms]);

/// 켜 둔 친구 알림이 있을 때만 서버에 묻는다 (앱을 켤 때·돌아올 때). 실패하면 기기에 적어 둔 대로 둔다.
Future<void> refreshFriendAlarms(AppState s, Remote remote) async {
  if (s.friendAlarms.isEmpty) return;
  try {
    applyFriendAlarms(s, await remote.friendRoutines());
  } catch (e) {
    debugPrint('friend alarm refresh failed: ${e.runtimeType}');
  }
}
