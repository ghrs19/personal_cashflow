import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders: a daily "record your expenses" nudge and one-off
/// reminders the day before a debt falls due. Everything is scheduled
/// on-device; nothing leaves the phone.
///
/// Implementation note: times are converted to UTC and matched with
/// [DateTimeComponents.time] so no device-timezone plugin is needed —
/// Indonesia has no DST, so a fixed offset stays correct.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _dailyId = 1001;
  static const _channelId = 'reminders';

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Pengingat',
          channelDescription: 'Pengingat pencatatan dan jatuh tempo',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Converts a local wall-clock time to the TZDateTime (UTC zone) that
  /// fires at that local time on [day] (or today when omitted).
  static tz.TZDateTime _toUtcTz(DateTime day, int hour, int minute) {
    final local = DateTime(day.year, day.month, day.day, hour, minute);
    final utc = local.toUtc();
    return tz.TZDateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  /// (Re)schedules the daily reminder at [hour]:[minute] local time.
  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.cancel(id: _dailyId);
    var first = _toUtcTz(DateTime.now(), hour, minute);
    if (first.isBefore(tz.TZDateTime.now(tz.UTC))) {
      first = first.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: title,
      body: body,
      scheduledDate: first,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDaily() async {
    await init();
    await _plugin.cancel(id: _dailyId);
  }

  /// One-off reminder at 09:00 local on the day before [dueDate].
  /// Uses a stable id derived from the debt id so re-saves reschedule.
  static Future<void> scheduleDebtReminder({
    required int debtId,
    required DateTime dueDate,
    required String title,
    required String body,
  }) async {
    await init();
    final id = 2000 + debtId;
    await _plugin.cancel(id: id);
    final day = dueDate.subtract(const Duration(days: 1));
    final when = _toUtcTz(day, 9, 0);
    if (when.isBefore(tz.TZDateTime.now(tz.UTC))) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelDebtReminder(int debtId) async {
    await init();
    await _plugin.cancel(id: 2000 + debtId);
  }
}
