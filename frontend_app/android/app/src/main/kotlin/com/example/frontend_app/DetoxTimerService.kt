package com.example.frontend_app

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/**
 * DetoxTimerService — Multi-app foreground tracking.
 *
 * - Receives a LIST of tracked apps (name, package, limit).
 * - Polls every 5 s using UsageEvents to find which app is in the foreground.
 * - Only counts time for the CURRENTLY OPEN app; resets all others to 0.
 * - Fires ONE notification + brings app to front when any limit is hit.
 * - No daily-total data is ever used — purely session-based.
 */
class DetoxTimerService : Service() {

    companion object {
        const val ACTION_START  = "com.aiPlanner.detox.START"
        const val ACTION_CANCEL = "com.aiPlanner.detox.CANCEL"

        // Parallel-array extras (cleaner than serializing JSON in an Intent)
        const val EXTRA_APP_NAMES = "app_names"
        const val EXTRA_PKG_NAMES = "pkg_names"
        const val EXTRA_LIMITS    = "limits"

        const val CHANNEL_RUNNING  = "detox_running"
        const val CHANNEL_ALERT    = "detox_alert"
        const val NOTIF_ID_RUNNING = 7001
        const val NOTIF_ID_ALERT   = 7002

        @Volatile var isRunning = false
    }

    data class AppEntry(val name: String, val pkg: String, val limitMins: Int, var sessionMs: Long = 0L)

    private val handler = Handler(Looper.getMainLooper())
    private var pollRunnable: Runnable? = null
    private var apps = listOf<AppEntry>()
    private val POLL_MS = 5_000L

    // ─────────────────────────────────────────────────────────────────────────
    override fun onCreate() { super.onCreate(); createChannels() }
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val names  = intent.getStringArrayExtra(EXTRA_APP_NAMES) ?: arrayOf()
                val pkgs   = intent.getStringArrayExtra(EXTRA_PKG_NAMES) ?: arrayOf()
                val limits = intent.getIntArrayExtra(EXTRA_LIMITS)       ?: intArrayOf()
                val list   = names.indices.map { i ->
                    AppEntry(
                        name     = names.getOrNull(i) ?: "",
                        pkg      = pkgs.getOrNull(i)  ?: "",
                        limitMins = limits.getOrNull(i) ?: 15
                    )
                }.filter { it.pkg.isNotEmpty() }
                startMonitoring(list)
            }
            ACTION_CANCEL -> { stopMonitoring(); stopSelf() }
        }
        return START_STICKY
    }

    // ─────────────────────────────────────────────────────────────────────────
    private fun startMonitoring(appList: List<AppEntry>) {
        pollRunnable?.let { handler.removeCallbacks(it) }
        apps     = appList
        isRunning = true

        val summary = apps.joinToString(", ") { "${it.name}(${it.limitMins}m)" }
        startForeground(NOTIF_ID_RUNNING, buildRunningNotif("Watching: $summary", null, null))

        pollRunnable = object : Runnable {
            override fun run() {
                if (!isRunning) return

                val fgPkg = getForegroundPackage()

                // Find which tracked app (if any) is in foreground
                var activeEntry: AppEntry? = null
                for (app in apps) {
                    if (app.pkg == fgPkg) {
                        activeEntry = app
                    } else {
                        // Reset session for apps not in foreground
                        app.sessionMs = 0L
                    }
                }

                if (activeEntry != null) {
                    activeEntry.sessionMs += POLL_MS
                    val sessionMins = (activeEntry.sessionMs / 60_000L).toInt()

                    // Update notification
                    NotificationManagerCompat.from(this@DetoxTimerService)
                        .notify(NOTIF_ID_RUNNING, buildRunningNotif(
                            activeEntry.name, sessionMins, activeEntry.limitMins
                        ))

                    if (sessionMins >= activeEntry.limitMins) {
                        onLimitReached(activeEntry.name, activeEntry.limitMins)
                        return
                    }
                } else {
                    // No tracked app in foreground — show waiting state
                    NotificationManagerCompat.from(this@DetoxTimerService)
                        .notify(NOTIF_ID_RUNNING, buildRunningNotif(
                            apps.firstOrNull()?.name ?: "App", null, null
                        ))
                }

                handler.postDelayed(this, POLL_MS)
            }
        }
        handler.postDelayed(pollRunnable!!, POLL_MS)
    }

    private fun stopMonitoring() {
        isRunning = false
        apps.forEach { it.sessionMs = 0L }
        pollRunnable?.let { handler.removeCallbacks(it) }
        pollRunnable = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
        NotificationManagerCompat.from(this).cancel(NOTIF_ID_RUNNING)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Returns the package name of the app currently in the foreground,
    // or null if nothing relevant is open.
    // ─────────────────────────────────────────────────────────────────────────
    private fun getForegroundPackage(): String? {
        return try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0);      set(Calendar.MILLISECOND, 0)
            }
            val events  = usm.queryEvents(cal.timeInMillis, now)
            val event   = UsageEvents.Event()
            var lastPkg  = ""
            var lastTime = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND &&
                    event.timeStamp > lastTime) {
                    lastPkg  = event.packageName
                    lastTime = event.timeStamp
                }
            }
            lastPkg.ifEmpty { null }
        } catch (e: Exception) { null }
    }

    // ─────────────────────────────────────────────────────────────────────────
    private fun onLimitReached(name: String, limitMins: Int) {
        stopMonitoring()

        // Cancel the running-timer notification
        NotificationManagerCompat.from(this).cancel(NOTIF_ID_RUNNING)

        // ONE alert notification (no duplicates)
        NotificationManagerCompat.from(this).notify(NOTIF_ID_ALERT, buildAlertNotif(name, limitMins))

        // Bring the app to the foreground to show the overlay dialog
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("detox_alert_app", name)
            putExtra("detox_alert_mins", limitMins)
        }
        if (launch != null) startActivity(launch)

        MainActivity.pendingDetoxAlert = name to limitMins
        stopSelf()
    }

    // ─────────────────────────────────────────────────────────────────────────
    private fun buildRunningNotif(appName: String, usedMins: Int?, limitMins: Int?): Notification {
        val text = if (usedMins != null && limitMins != null) {
            val rem = (limitMins - usedMins).coerceAtLeast(0)
            "Using $appName · ${usedMins}min / ${limitMins}min · ${rem}min left"
        } else {
            "Monitoring $appName · Waiting for you to open it…"
        }
        val stopPi = PendingIntent.getService(
            this, 0,
            Intent(this, DetoxTimerService::class.java).apply { action = ACTION_CANCEL },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_RUNNING)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏱ Digital Detox Active")
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true).setSilent(true)
            .addAction(android.R.drawable.ic_delete, "Cancel", stopPi)
            .build()
    }

    private fun buildAlertNotif(appName: String, limitMins: Int): Notification {
        val pi = PendingIntent.getActivity(
            this, 7999,
            packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("detox_alert_app", appName)
                putExtra("detox_alert_mins", limitMins)
            } ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ALERT)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🚨 Time Limit Reached!")
            .setContentText("You've used $appName for $limitMins minutes. Time for a break!")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("You've been using $appName for $limitMins minutes continuously.\nYour limit is up — put it down and refocus! 💪"))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 600, 200, 600))
            .setAutoCancel(true)
            .setFullScreenIntent(pi, true)
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_RUNNING, "Detox Timer", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null); enableVibration(false)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ALERT, "Screen Time Alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 200, 600)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
    }
}
