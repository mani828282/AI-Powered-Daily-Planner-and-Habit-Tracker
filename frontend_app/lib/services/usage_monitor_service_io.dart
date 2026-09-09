// Android-only implementation — selected when dart.library.io is available.
//
// THREE-LAYER ARCHITECTURE:
//
// Layer 1 — WorkManager ONE-TIME task (primary)
//   • Registered with initialDelay = remainingMinutes
//   • Fires our Dart code → checks REAL usage → sends notification only if truly exceeded
//   • Runs even when app is killed; more reliable than zonedSchedule on Chinese OEM phones
//
// Layer 2 — WorkManager PERIODIC task (backup safety net)
//   • Runs every 15 minutes as a fallback
//   • Same logic: checks real usage, fires notification if limit exceeded
//
// Layer 3 — In-app timer (when app is open)
//   • Fires every 60 seconds while app is in foreground
//   • Provides near-instant notifications while user has the app open

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'bad_habit_service.dart';

const String _kPeriodicTask = 'com.aiPlanner.usageMonitorPeriodic';
const String _kOneTimeTask  = 'com.aiPlanner.usageCheckOnce';
const String _kPeriodicId   = 'usageMonitorPeriodic';

// ─────────────────────────────────────────────────────────────────────────────
// WorkManager callback — top-level, runs even when app is killed
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _kPeriodicTask || taskName.startsWith(_kOneTimeTask)) {
      await _runUsageCheckAndNotify();
    }
    return Future.value(true);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Core check — checks REAL usage and fires notification if limit is exceeded
// Called by WorkManager tasks AND in-app timer
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runUsageCheckAndNotify() async {
  // Legacy method — natively handled by DetoxTimerService now.
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule alarms — uses a per-app "tracking start" baseline so that
// pre-existing daily usage does NOT trigger an immediate notification.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _scheduleAllLayers() async {
  // Legacy method — natively handled by DetoxTimerService now.
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule exact alarms via AlarmManager
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _scheduleExactAlarms({
  required String appName,
  required int usedMin,
  required int limitMin,
  required DateTime fireAt,
  required int baseId,
}) async {
  // Legacy method — natively handled by DetoxTimerService now.
}

// ─────────────────────────────────────────────────────────────────────────────
// Send urgent persistent notifications
// ─────────────────────────────────────────────────────────────────────────────
final _plugin = FlutterLocalNotificationsPlugin();
bool _pluginReady = false;

Future<void> _ensurePlugin() async {
  if (_pluginReady) return;
  tz_data.initializeTimeZones();
  await _plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  _pluginReady = true;
}

Future<void> _sendNotifications({
  required String appName,
  required int sessionUsed,
  required int limitMin,
  required int baseId,
}) async {
  // Legacy method — natively handled by DetoxTimerService now.
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────
class UsageMonitorService {
  static Timer? _timer;

  /// Initialize once at app startup.
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await _ensurePlugin();

    // Cancel all old WorkManager tasks — the native Kotlin foreground service
    // (DetoxTimerService) now handles all detox monitoring. WorkManager was
    // causing duplicate notifications based on stale daily-total usage data.
    await Workmanager().cancelAll();
    await _plugin.cancelAll();
  }

  /// Call every time the Detox screen opens, or after adding/editing an app.
  /// Reads current usage, fires immediately if exceeded, or registers a
  /// one-time WorkManager task to check at the predicted time.
  static Future<void> scheduleDetoxAlarms() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    await _scheduleAllLayers();
  }

  /// Start the in-app 60-second loop (active only while Flutter is running).
  static void startInAppPolling() {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    if (_timer != null && _timer!.isActive) return;

    _runUsageCheckAndNotify(); // immediate check
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _runUsageCheckAndNotify();
    });
  }

  /// Stop the in-app loop.
  static void stopInAppPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// Manual refresh — triggered by the refresh button.
  static Future<void> triggerCheckNow() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    await _runUsageCheckAndNotify();
    await _scheduleAllLayers();
  }

  /// Cancel all scheduled WorkManager tasks and notification alarms.
  static Future<void> cancelAllDetoxAlarms() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    await Workmanager().cancelAll();
    await _ensurePlugin();
    await _plugin.cancelAll();
  }

  /// Cancel alarms for a specific package (when app is removed from tracking).
  static Future<void> cancelAlarmsForPackage(String packageName) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().cancelByUniqueName('${_kOneTimeTask}_$packageName');
    } catch (_) {}
    await _ensurePlugin();
    final baseId = packageName.hashCode.abs() % 100000;
    await _plugin.cancel(baseId);
    await _plugin.cancel(baseId + 1);
    await _plugin.cancel(baseId + 2);
  }

  /// Clear today's "already notified" flag so a new limit edit gets a fresh alarm.
  static Future<void> resetNotifiedFlagForPackage(String packageName) async {
    final prefs  = await SharedPreferences.getInstance();
    final now    = DateTime.now();
    final dayKey = '${now.year}${now.month}${now.day}';
    await prefs.remove('notified_${packageName}_$dayKey');
    await prefs.remove('baseline_${packageName}_$dayKey');
    await prefs.remove('inactive_${packageName}_$dayKey');
    // Reset tracking-start so the new limit counts from current usage forward
    await prefs.remove('tracking_start_$packageName');
  }

  static Future<void> cancel() async {
    stopInAppPolling();
  }

  static Future<bool> hasUsagePermission() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    try {
      final now   = DateTime.now();
      final start = now.subtract(const Duration(minutes: 1));
      await AppUsage().getAppUsage(start, now);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
