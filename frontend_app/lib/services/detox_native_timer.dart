// Flutter-side wrapper for the native Android DetoxTimerService.
//
// How it works:
//   1. Flutter calls DetoxNativeTimer.start(appName, limitMinutes)
//      → tells the Kotlin foreground service to begin counting
//   2. The Kotlin service runs FULLY IN NATIVE CODE while the user is in
//      another app — no Flutter timer involved.
//   3. When the limit is reached, the service:
//      a. fires a system notification (loud, full-screen-intent)
//      b. brings MainActivity back to the front
//      c. calls the Flutter method "onDetoxAlert" on the MethodChannel
//   4. Flutter receives "onDetoxAlert" and shows the in-app dialog overlay.
//
// This approach is 100% reliable because it does NOT depend on Flutter's
// Dart isolate being alive.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback type: called when the native timer fires (limit reached).
typedef DetoxAlertCallback = void Function(String appName, int limitMins);

class DetoxNativeTimer {
  static const _channel = MethodChannel('com.aiPlanner.detoxTimer');

  static DetoxAlertCallback? _onAlert;

  /// Must be called once — e.g. inside main() or before the first use.
  static void initialize(DetoxAlertCallback onAlert) {
    _onAlert = onAlert;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDetoxAlert') {
      final appName   = call.arguments['app_name']   as String? ?? 'App';
      final limitMins = call.arguments['limit_mins'] as int?    ?? 0;
      _onAlert?.call(appName, limitMins);
    }
  }

  /// Start monitoring ALL tracked apps simultaneously.
  /// The native service detects which one is in the foreground and counts
  /// only that app's session, resetting others when they go to background.
  ///
  /// [apps] is a list of maps: {app_name, package_name, limit_minutes}
  static Future<bool> startAll(List<Map<String, dynamic>> apps) async {
    if (apps.isEmpty) {
      await cancel();
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('startTimer', {
        'app_names': apps.map((a) => a['app_name']     as String? ?? '').toList(),
        'pkg_names': apps.map((a) => a['package_name'] as String? ?? '').toList(),
        'limits':    apps.map((a) => (a['daily_limit_minutes'] as num? ?? 15).toInt()).toList(),
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  // Keep single-app start() as a convenience wrapper
  static Future<bool> start({
    required String appName,
    required String packageName,
    required int limitMinutes,
  }) => startAll([{
    'app_name':            appName,
    'package_name':        packageName,
    'daily_limit_minutes': limitMinutes,
  }]);

  /// Cancel the running timer (e.g. user leaves the tracked app voluntarily).
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancelTimer');
    } on PlatformException {
      // ignore
    }
  }

  /// Get current timer state from the native service.
  static Future<Map<String, dynamic>> getState() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getElapsed');
      if (raw == null) return {};
      return Map<String, dynamic>.from(raw);
    } on PlatformException {
      return {};
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay widget shown when the limit is reached
// ─────────────────────────────────────────────────────────────────────────────

/// Show a full-screen blocking overlay when a detox limit is reached.
/// The dialog is dismissible so the user can close it, but it forces them to
/// acknowledge the alert before continuing.
void showDetoxAlertDialog(
  BuildContext context, {
  required String appName,
  required int limitMins,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.85),
    pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: _DetoxAlertOverlay(appName: appName, limitMins: limitMins),
      );
    },
  );
}

class _DetoxAlertOverlay extends StatelessWidget {
  final String appName;
  final int    limitMins;

  const _DetoxAlertOverlay({
    required this.appName,
    required this.limitMins,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.5),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('🚨', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  const Text(
                    'Time Limit Reached!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ve been using $appName for $limitMins minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  _TipRow(emoji: '💪', text: 'You set this limit for a reason.'),
                  SizedBox(height: 10),
                  _TipRow(emoji: '🎯', text: 'Refocus on your goals & habits.'),
                  SizedBox(height: 10),
                  _TipRow(emoji: '🧘', text: 'Take a mindful break right now.'),
                ],
              ),
            ),

            // ── Actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7C4DFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Got it — I\'ll stop now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String emoji;
  final String text;
  const _TipRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
