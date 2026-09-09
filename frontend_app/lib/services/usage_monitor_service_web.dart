// Web stub — all methods are no-ops.
// This file is conditionally selected when the app runs on web/desktop.

class UsageMonitorService {
  static Future<void> initialize() async {}
  static Future<void> cancel() async {}
  static Future<bool> hasUsagePermission() async => false;
  static Future<void> storeToken(String token) async {}
  static Future<void> triggerCheckNow() async {}
  static void startInAppPolling() {}
  static void stopInAppPolling() {}
  static Future<void> scheduleDetoxAlarms() async {}
  static Future<void> cancelAllDetoxAlarms() async {}
  static Future<void> cancelAlarmsForPackage(String pkg) async {}
  static Future<void> resetNotifiedFlagForPackage(String pkg) async {}
}
