package com.example.risha

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object UsageRestController {
    private const val alarmRequestCode = 4318
    private const val monitorAlarmRequestCode = 4316
    private const val alarmAction = "com.example.risha.action.USAGE_REST_SYNC"
    private const val monitorAlarmAction = "com.example.risha.action.USAGE_REST_MONITOR"
    private const val monitorIntervalMillis = 60_000L

    fun startRest(
        context: Context,
        endsAtEpochMs: Long,
        childName: String?,
    ): Boolean {
        val now = System.currentTimeMillis()
        if (endsAtEpochMs <= now || !SleepLockController.isOverlayPermissionGranted(context)) {
            return false
        }

        UsageRestStorage.writeActive(
            context = context,
            startedAtEpochMs = now,
            endsAtEpochMs = endsAtEpochMs,
            childName = childName,
        )
        syncServiceState(context)
        return true
    }

    fun configureMonitor(
        context: Context,
        enabled: Boolean,
        cycleStartedAtEpochMs: Long,
        cycleDate: String?,
        cycleCount: Int,
        thresholdMillis: Long,
        restDurationMillis: Long,
        maxCyclesPerDay: Int,
        childName: String?,
    ) {
        val config = UsageRestMonitorConfig(
            enabled = enabled,
            cycleStartedAtEpochMs = cycleStartedAtEpochMs,
            cycleDate = cycleDate,
            cycleCount = cycleCount.coerceAtLeast(0),
            thresholdMillis = thresholdMillis,
            restDurationMillis = restDurationMillis,
            maxCyclesPerDay = maxCyclesPerDay,
            childName = childName,
        )
        UsageRestStorage.writeMonitor(context, config)
        if (config.isUsable()) {
            evaluateMonitor(context)
            scheduleMonitorSync(context)
        } else {
            cancelMonitorSync(context)
        }
    }

    fun syncServiceState(context: Context) {
        val state = UsageRestStorage.read(context)
        if (!state.isActiveAt() || !SleepLockController.isOverlayPermissionGranted(context)) {
            cancelScheduledStateSync(context)
            UsageRestStorage.clearActive(context)
            UsageRestOverlayService.stop(context)
            return
        }

        scheduleEndSync(context, state.endsAtEpochMs)
        UsageRestOverlayService.start(context)
    }

    fun evaluateMonitor(context: Context) {
        val state = UsageRestStorage.read(context)
        if (state.isActiveAt()) {
            scheduleMonitorSync(context)
            return
        }

        val config = normalizedMonitorConfig(context)
        if (!config.isUsable()) {
            cancelMonitorSync(context)
            return
        }

        if (config.cycleCount >= config.maxCyclesPerDay) {
            cancelMonitorSync(context)
            return
        }

        if (!SleepLockController.isOverlayPermissionGranted(context) ||
            !DeviceUsageController.isUsageAccessGranted(context)
        ) {
            scheduleMonitorSync(context)
            return
        }

        val activeMillis = DeviceUsageController.activeUsageMillisForRestMonitor(
            context,
            config.cycleStartedAtEpochMs,
        )
        if (activeMillis < config.thresholdMillis) {
            scheduleMonitorSync(context)
            return
        }

        // Start the native prompt overlay service
        UsageRestPromptOverlayService.start(context)
        
        // Keep syncing every 60 seconds until Flutter handles the prompt and updates the config
        scheduleMonitorSync(context)
    }

    fun getState(context: Context): Map<String, Any?> {
        val state = UsageRestStorage.read(context)
        val active = state.isActiveAt()
        if (!active && state.active) {
            syncServiceState(context)
        }
        return mapOf(
            "active" to active,
            "startedAtEpochMs" to state.startedAtEpochMs,
            "endsAtEpochMs" to state.endsAtEpochMs,
            "childName" to state.childName,
        )
    }

    fun stopIfExpired(context: Context): Boolean {
        val wasActive = UsageRestStorage.read(context).active
        syncServiceState(context)
        return wasActive && !UsageRestStorage.read(context).isActiveAt()
    }

    private fun normalizedMonitorConfig(context: Context): UsageRestMonitorConfig {
        val config = UsageRestStorage.readMonitor(context)
        if (!config.enabled) {
            return config
        }

        val todayKey = DeviceUsageController.todayKey()
        if (config.cycleDate == todayKey) {
            return config
        }

        val reset = config.copy(
            cycleStartedAtEpochMs = maxOf(DeviceUsageController.startOfTodayMillis(), System.currentTimeMillis()),
            cycleDate = todayKey,
            cycleCount = 0,
        )
        UsageRestStorage.writeMonitor(context, reset)
        return reset
    }

    private fun scheduleEndSync(context: Context, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildAlarmPendingIntent(context)
        alarmManager.cancel(pendingIntent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
                return
            } catch (_: SecurityException) {
                // Fall back to inexact scheduling if exact alarms are blocked.
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

    private fun scheduleMonitorSync(context: Context) {
        val config = UsageRestStorage.readMonitor(context)
        if (!config.isUsable()) {
            cancelMonitorSync(context)
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildMonitorAlarmPendingIntent(context)
        alarmManager.cancel(pendingIntent)
        val triggerAtMillis = System.currentTimeMillis() + monitorIntervalMillis

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

    private fun cancelMonitorSync(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildMonitorAlarmPendingIntent(context))
    }

    private fun buildAlarmPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, UsageRestAlarmReceiver::class.java).apply {
            action = alarmAction
        }
        return PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildMonitorAlarmPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, UsageRestAlarmReceiver::class.java).apply {
            action = monitorAlarmAction
        }
        return PendingIntent.getBroadcast(
            context,
            monitorAlarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
