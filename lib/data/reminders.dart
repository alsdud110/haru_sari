import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
String routineAlarmBody(Routine r) => '${r.emoji} ${r.name}, 할 수 있을 때 해봐요.';
const dayEndTitle = '오늘 하루도 수고했어요';
const dayEndBody = '잠깐 오늘을 돌아볼까요? 한 개만 했어도 충분해요.';

class LocalReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'routine',
      '루틴 알림',
      channelDescription: '정해 둔 루틴 시간과 하루 마감에 살며시 알려드려요',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

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
            await _plugin.zonedSchedule(
              id: id++,
              title: '오늘살이',
              body: routineAlarmBody(r),
              scheduledDate: _next(r.minuteOfDay!, weekday: d),
              notificationDetails: _details,
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
          notificationDetails: _details,
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
