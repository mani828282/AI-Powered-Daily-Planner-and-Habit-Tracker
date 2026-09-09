import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/task.dart';
import '../models/habit.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database (needed for tz.UTC reference)
    tz.initializeTimeZones();

    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions immediately on initialization
    await requestPermissions();

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
  }

  Future<bool> requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS permissions
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Convert a LOCAL DateTime to a TZDateTime in UTC.
  /// This is the KEY fix — Dart's DateTime.toUtc() uses the device's
  /// real system timezone offset, so this always produces the correct
  /// absolute moment in time without needing any external timezone package.
  tz.TZDateTime _toTZDateTime(DateTime localDateTime) {
    final utc = localDateTime.toUtc();
    return tz.TZDateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  Future<void> scheduleTaskNotification(Task task,
      {int minutesBefore = 60}) async {
    if (!_initialized) await initialize();
    if (task.dueDate == null) return;

    final dueDateTime = _combineDateAndTime(task.dueDate!, task.dueTime);
    if (dueDateTime == null) return;

    final notificationTime =
        dueDateTime.subtract(Duration(minutes: minutesBefore));

    // Don't schedule if time is more than 30 seconds in the past
    if (notificationTime.isBefore(
        DateTime.now().subtract(const Duration(seconds: 30)))) {
      debugPrint(
          '⚠️ Task notification skipped — time in the past: $notificationTime');
      return;
    }

    debugPrint(
        '✅ Scheduling task notification: "${task.title}" at $notificationTime (${minutesBefore}min before due)');

    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Notifications for upcoming tasks',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF1744),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      task.taskId.hashCode,
      'Task Reminder: ${task.title}',
      minutesBefore > 0 ? 'Due in $minutesBefore minutes' : 'Due now!',
      _toTZDateTime(notificationTime),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleHabitReminder(Habit habit, DateTime reminderTime,
      {List<String>? customDays}) async {
    if (!_initialized) await initialize();
    final now = DateTime.now();

    debugPrint(
        '✅ Scheduling habit reminder: "${habit.name}" at ${reminderTime.hour}:${reminderTime.minute.toString().padLeft(2, "0")}');

    const androidDetails = AndroidNotificationDetails(
      'habit_reminders',
      'Habit Reminders',
      channelDescription: 'Daily reminders for your habits',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF66BB6A),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (customDays == null || customDays.isEmpty) {
      // -----------------------------------------------------------------------
      //  Schedule DAILY reminder
      // -----------------------------------------------------------------------
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        habit.habitId.hashCode,
        'Habit Reminder: ${habit.name}',
        'Time to complete your daily habit!',
        _toTZDateTime(scheduledTime),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );
    } else {
      // -----------------------------------------------------------------------
      //  Schedule CUSTOM WEEKLY reminders for specific days
      // -----------------------------------------------------------------------
      const dayMapping = {
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      };

      for (int i = 0; i < customDays.length; i++) {
        final dayName = customDays[i].toLowerCase();
        if (!dayMapping.containsKey(dayName)) continue;

        final targetWeekday = dayMapping[dayName]!;

        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          reminderTime.hour,
          reminderTime.minute,
        );

        while (scheduledTime.weekday != targetWeekday ||
            scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        final uniqueId = habit.habitId.hashCode + targetWeekday;

        await _notifications.zonedSchedule(
          uniqueId,
          'Habit Reminder: ${habit.name}',
          'Time to complete your habit!',
          _toTZDateTime(scheduledTime),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
        );
      }
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Test notification — call this to instantly verify notifications work
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      'Test Notification ✅',
      'If you see and hear this, notifications are working!',
      details,
    );
  }

  DateTime? _combineDateAndTime(DateTime date, String? timeString) {
    if (timeString == null) {
      return DateTime(date.year, date.month, date.day, 23, 59);
    }

    try {
      // Parse time string (format: "HH:MM:SS" or "HH:MM")
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
  }
}
