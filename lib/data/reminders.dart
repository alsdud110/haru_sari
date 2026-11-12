import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// 알림 예약. 상태가 바뀔 때마다 전부 지우고 다시 건다.
abstract class Reminders {
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings});
  Future<void> clear();
  Future<bool> requestPermission();
}

class NoReminders implements Reminders {
  @override
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings}) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> requestPermission() async => true;
}

/// 다정한 문구만 쓴다. 미완료를 지적하지 않는다.
/// 아이콘은 글자 속 이모지 대신 알림 옆 그림으로 붙인다 ([LocalReminders.iconAssetFor]).
String routineAlarmBody(Routine r) => '${r.name}, 할 수 있을 때 해봐요.';

/// 글 앞의 💌는 폰 기본 이모지다 (알림 글에는 그림을 넣을 수 없다). 앱 그림은 알림 옆에 따로 붙는다.
const dayEndTitle = '💌 오늘 하루도 수고했어요';
const dayEndBody = '잠깐 오늘을 돌아볼까요? 한 개만 했어도 충분해요.';

class LocalReminders implements Reminders {
  LocalReminders({this.iconAssetFor});

  /// 루틴의 이모지 → 알림 옆에 붙일 앱 그림(에셋 경로). 짝이 없으면 null → 그림 없이 글만 보낸다.
  final String? Function(String emoji)? iconAssetFor;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 알림 하나의 모양. [iconAsset]이 있으면 알림 옆에 그 그림을 붙인다
  /// (Android: 오른쪽 큰 아이콘, iOS: 첨부 그림 미리보기).
  Future<NotificationDetails> _details(int id, String? iconAsset) async {
    final icon = iconAsset == null ? null : await _iconFile(id, iconAsset);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'routine',
        '루틴 알림',
        channelDescription: '정해 둔 루틴 시간과 하루 마감에 살며시 알려드려요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        largeIcon: icon == null ? null : FilePathAndroidBitmap(icon),
      ),
      iOS: DarwinNotificationDetails(attachments: icon == null ? null : [DarwinNotificationAttachment(icon)]),
    );
  }

  /// 알림은 에셋을 직접 못 읽어서 그림을 기기 파일로 꺼내 둔다. 실패하면 null (그림 없이 보낸다).
  /// iOS는 첨부한 파일을 가져가 버리므로 알림마다 따로 한 장씩 만든다. Android는 그림마다 한 장을 같이 쓴다.
  Future<String?> _iconFile(int id, String asset) async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/notif_icons');
      final name = asset.split('/').last;
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      final file = File('${dir.path}/${ios ? '${id}_$name' : name}');
      if (ios || !file.existsSync()) {
        await dir.create(recursive: true);
        final data = await rootBundle.load(asset);
        await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      return file.path;
    } catch (e) {
      debugPrint('reminder icon failed: $e');
      return null;
    }
  }

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('timezone fallback: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return true;
  }

  @override
  Future<void> clear() async {
    await _init();
    await _plugin.cancelAll();
  }

  /// 다음 [weekday] [minute] 시각 (지금 이후).
  static tz.TZDateTime _next(int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, minute ~/ 60, minute % 60);
    while (!t.isAfter(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  @override
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings}) async {
    try {
      await _init();
      await _plugin.cancelAll();
      if (!settings.allOn) return;
      var id = 1;
      if (settings.routineStart) {
        for (final r in routines) {
          if (!r.active || !r.alarmOn || r.minuteOfDay == null) continue;
          for (final d in r.weekdays) {
            final nid = id++;
            await _plugin.zonedSchedule(
              id: nid,
              title: '하루살이',
              body: routineAlarmBody(r),
              scheduledDate: _next(r.minuteOfDay!, weekday: d),
              notificationDetails: await _details(nid, iconAssetFor?.call(r.emoji)),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
          }
        }
      }
      if (settings.dayEnd) {
        await _plugin.zonedSchedule(
          id: 0,
          title: dayEndTitle,
          body: dayEndBody,
          scheduledDate: _next(settings.dayEndMinute),
          notificationDetails: await _details(0, null), // 마감 알림은 그림 없이 글 앞의 💌만
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      // 알림 실패가 기록을 막지 않게 한다.
      debugPrint('reminder sync failed: $e');
    }
  }
}
