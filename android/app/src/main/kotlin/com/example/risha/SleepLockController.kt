package com.example.risha

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import java.util.Calendar
import java.util.Locale

object SleepLockController {
    private const val alarmRequestCode = 4208
    private const val alarmAction = "com.example.risha.action.SLEEP_LOCK_SYNC"

    fun isOverlayPermissionGranted(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)
    }

    fun shouldLockNow(
        config: SleepLockConfig,
        now: Calendar = Calendar.getInstance(),
    ): Boolean {
        if (!config.isActiveConfig) {
            return false
        }

        if (config.sleepMinutes == SleepLockConfig.MORNING_UNLOCK_MINUTES) {
            return false
        }

        val currentMinutes = (now.get(Calendar.HOUR_OF_DAY) * 60) + now.get(Calendar.MINUTE)
        return if (config.sleepMinutes < SleepLockConfig.MORNING_UNLOCK_MINUTES) {
            currentMinutes in config.sleepMinutes until SleepLockConfig.MORNING_UNLOCK_MINUTES
        } else {
            currentMinutes >= config.sleepMinutes ||
                currentMinutes < SleepLockConfig.MORNING_UNLOCK_MINUTES
        }
    }

    fun syncServiceState(context: Context) {
        val config = SleepLockStorage.read(context)
        if (
            !config.isActiveConfig ||
            config.sleepMinutes == SleepLockConfig.MORNING_UNLOCK_MINUTES ||
            !isOverlayPermissionGranted(context)
        ) {
            cancelScheduledStateSync(context)
            SleepLockOverlayService.stop(context)
            return
        }

        scheduleNextStateSync(context, config)
        if (shouldLockNow(config)) {
            SleepLockOverlayService.start(context)
        } else {
            SleepLockOverlayService.stop(context)
        }
    }

    fun openOverlayPermissionSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${context.packageName}"),
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun startForegroundServiceCompat(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, intent)
        } else {
            context.startService(intent)
        }
    }

    fun formatTime(hour: Int, minute: Int): String {
        return String.format(Locale.US, "%02d:%02d", hour, minute)
    }

    private fun scheduleNextStateSync(
        context: Context,
        config: SleepLockConfig,
        now: Calendar = Calendar.getInstance(),
    ) {
        val triggerAt =
            if (shouldLockNow(config, now)) {
                nextOccurrence(now, SleepLockConfig.MORNING_UNLOCK_MINUTES)
            } else {
                nextOccurrence(now, config.sleepMinutes)
            }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildAlarmPendingIntent(context)
        alarmManager.cancel(pendingIntent)

        val triggerAtMillis = triggerAt.timeInMillis
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
                return
            } catch (_: SecurityException) {
                // Fall back to inexact scheduling if the device blocks exact alarms.
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
                return
            } catch (_: SecurityException) {
                // Fall through to a best-effort alarm below.
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun cancelScheduledStateSync(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildAlarmPendingIntent(context))
    }

    private fun buildAlarmPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, SleepLockAlarmReceiver::class.java).apply {
            action = alarmAction
        }
        return PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextOccurrence(now: Calendar, minutesOfDay: Int): Calendar {
        return (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, minutesOfDay / 60)
            set(Calendar.MINUTE, minutesOfDay % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(now)) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
    }
}
