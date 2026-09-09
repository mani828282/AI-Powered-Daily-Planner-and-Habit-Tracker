package com.example.frontend_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val BATTERY_CHANNEL = "android_battery_channel"
    private val DETOX_CHANNEL   = "com.aiPlanner.detoxTimer"

    private var detoxChannel: MethodChannel? = null

    companion object {
        // Set by DetoxTimerService when the limit is reached while the app is
        // in the background. MainActivity picks this up in onResume/onNewIntent
        // and forwards it to Flutter.
        @Volatile var pendingDetoxAlert: Pair<String, Int>? = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Battery optimisation channel (existing) ───────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } else {
                            result.success(true)
                        }
                    }
                    "openBatterySettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                )
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Detox timer channel (new) ──────────────────────────────────────
        detoxChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, DETOX_CHANNEL
        )
        detoxChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {

                // Flutter → start monitoring a list of tracked apps
                "startTimer" -> {
                    val names  = call.argument<List<String>>("app_names")  ?: emptyList()
                    val pkgs   = call.argument<List<String>>("pkg_names")  ?: emptyList()
                    val limits = call.argument<List<Int>>("limits")        ?: emptyList()

                    val intent = Intent(this, DetoxTimerService::class.java).apply {
                        action = DetoxTimerService.ACTION_START
                        putExtra(DetoxTimerService.EXTRA_APP_NAMES, names.toTypedArray())
                        putExtra(DetoxTimerService.EXTRA_PKG_NAMES, pkgs.toTypedArray())
                        putExtra(DetoxTimerService.EXTRA_LIMITS,    limits.toIntArray())
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }

                // Flutter → cancel the running timer
                "cancelTimer" -> {
                    val intent = Intent(this, DetoxTimerService::class.java).apply {
                        action = DetoxTimerService.ACTION_CANCEL
                    }
                    startService(intent)
                    result.success(true)
                }

                // Flutter → query session state
                "getElapsed" -> {
                    result.success(
                        mapOf(
                            "is_running" to DetoxTimerService.isRunning
                        )
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Handle alert when app is brought to foreground after limit is reached
    // ─────────────────────────────────────────────────────────────────────────
    override fun onResume() {
        super.onResume()
        deliverPendingAlert()
        handleAlertIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlertIntent(intent)
    }

    private fun handleAlertIntent(intent: Intent?) {
        val appName  = intent?.getStringExtra("detox_alert_app")  ?: return
        val limitMin = intent.getIntExtra("detox_alert_mins", 0)
        sendDetoxAlertToFlutter(appName, limitMin)
        // Clear the extras so it doesn't fire again on next resume
        intent.removeExtra("detox_alert_app")
        intent.removeExtra("detox_alert_mins")
    }

    private fun deliverPendingAlert() {
        val alert = pendingDetoxAlert ?: return
        pendingDetoxAlert = null
        sendDetoxAlertToFlutter(alert.first, alert.second)
    }

    /** Calls the Flutter method "onDetoxAlert" on the detox channel. */
    fun sendDetoxAlertToFlutter(appName: String, limitMins: Int) {
        runOnUiThread {
            detoxChannel?.invokeMethod(
                "onDetoxAlert",
                mapOf("app_name" to appName, "limit_mins" to limitMins)
            )
        }
    }
}
