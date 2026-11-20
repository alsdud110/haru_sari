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
/// [Reminders.sync] 의 doneToday: 오늘 이미 한 루틴 id. 그 루틴의 오늘 알림은 울리지 않는다.
abstract class Reminders {
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings, Set<String> doneToday = const {}});
  Future<void> clear();
  Future<bool> requestPermission();
}

class NoReminders implements Reminders {
  @override
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings, Set<String> doneToday = const {}}) async {}
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

/// [now] 다음의 [minute]분 (그날 0시부터) 시각. [weekday] 가 있으면 그 요일로.
tz.TZDateTime nextAt(int minute, tz.TZDateTime now, {int? weekday}) {
  var t = tz.TZDateTime(now.location, now.year, now.month, now.day, minute ~/ 60, minute % 60);
  while (!t.isAfter(now) || (weekday != null && t.weekday != weekday)) {
    t = t.add(const Duration(days: 1));
  }
  return t;
}

/// [weekday] 요일 [minute]분 루틴 알림을 언제, 매주 반복으로 걸지.
/// 오늘 이미 한 루틴([doneToday])은 오늘 알림을 건너뛴다. iOS 의 매주 반복 알림은 시작 날짜를 미룰 수 없어서
/// 다음 주 한 번만 건다. 체크하거나 앱을 켤 때마다 다시 걸리므로 그때 매주 반복으로 돌아온다.
/// shortcut: 앱을 일주일 넘게 안 열면 이 요일 알림이 그 뒤로 멈춘다, 문제가 되면 몇 주치를 미리 건다.
({tz.TZDateTime at, bool weekly}) routineSlot(int minute, int weekday, {required bool doneToday, required tz.TZDateTime now}) {
  final t = nextAt(minute, now, weekday: weekday);
  final today = t.year == now.year && t.month == now.month && t.day == now.day;
  if (!doneToday || !today) return (at: t, weekly: true);
  return (at: tz.TZDateTime(t.location, t.year, t.month, t.day + 7, t.hour, t.minute), weekly: false);
}

class LocalReminders implements Reminders {
  LocalReminders({this.iconAssetFor});

  /// 루틴의 이모지 → 알림 옆에 붙일 앱 그림(에셋 경로). 짝이 없으면 null → 그림 없이 글만 보낸다.
  final String? Function(String emoji)? iconAssetFor;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 알림 하나의 모양. [iconAsset]이 있으면 알림 옆에 그 그림을 붙인다
  /// (Android: 글 왼쪽, iOS: 오른쪽 첨부 그림 미리보기).
  Future<NotificationDetails> _details(int id, String? iconAsset, String body) async {
    final icon = iconAsset == null ? null : await _iconFile(id, iconAsset);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'routine',
        '루틴 알림',
        channelDescription: '정해 둔 루틴 시간과 하루 마감에 살며시 알려드려요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // Android에서 그림을 글 왼쪽에 두는 길은 대화 모양 알림뿐이다 (큰 아이콘은 늘 오른쪽).
        styleInformation: icon == null
            ? null
            : MessagingStyleInformation(
                Person(name: '하루살이', icon: BitmapFilePathAndroidIcon(icon)),
                messages: [Message(body, DateTime.now(), null)],
              ),
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
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        // iOS는 내용이 같은 그림을 한 장으로 합쳐 알림 하나에만 묶어 두고, 그 알림이 지워지면 나머지 알림의 그림도 사라진다.
        // 그래서 PNG 끝에 알림 번호를 덧붙여 알림마다 다른 파일로 만든다 (그림 뒤에 붙은 글자는 그릴 때 무시된다).
        await file.writeAsBytes(ios ? [...bytes, ...'$id'.codeUnits] : bytes, flush: true);
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

  @override
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings, Set<String> doneToday = const {}}) async {
    try {
      await _init();
      await _plugin.cancelAll();
      if (!settings.allOn) return;
      final now = tz.TZDateTime.now(tz.local);
      var id = 1;
      if (settings.routineStart) {
        for (final r in routines) {
          if (!r.active || !r.alarmOn || r.minuteOfDay == null) continue;
          for (final d in r.weekdays) {
            final nid = id++;
            final slot = routineSlot(r.minuteOfDay!, d, doneToday: doneToday.contains(r.id), now: now);
            await _plugin.zonedSchedule(
              id: nid,
              title: '하루살이',
              body: routineAlarmBody(r),
              scheduledDate: slot.at,
              notificationDetails: await _details(nid, iconAssetFor?.call(r.emoji), routineAlarmBody(r)),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: slot.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
            );
          }
        }
      }
      if (settings.dayEnd) {
        await _plugin.zonedSchedule(
          id: 0,
          title: dayEndTitle,
          body: dayEndBody,
          scheduledDate: nextAt(settings.dayEndMinute, now),
          notificationDetails: await _details(0, null, dayEndBody), // 마감 알림은 그림 없이 글 앞의 💌만
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
