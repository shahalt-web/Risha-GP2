package com.example.risha

import android.content.Context
import android.content.SharedPreferences
import android.os.Build

object UsageRestStorage {
    private const val prefsName = "risha_usage_rest_native_prefs"
    private const val keyActive = "active"
    private const val keyStartedAt = "started_at_epoch_ms"
    private const val keyEndsAt = "ends_at_epoch_ms"
    private const val keyLastStartedAt = "last_started_at_epoch_ms"
    private const val keyLastEndsAt = "last_ends_at_epoch_ms"
    private const val keyChildName = "child_name"
    private const val keyMonitorEnabled = "monitor_enabled"
    private const val keyMonitorCycleStartedAt = "monitor_cycle_started_at_epoch_ms"
    private const val keyMonitorCycleDate = "monitor_cycle_date"
    private const val keyMonitorCycleCount = "monitor_cycle_count"
    private const val keyMonitorThresholdMillis = "monitor_threshold_millis"
    private const val keyMonitorRestDurationMillis = "monitor_rest_duration_millis"
    private const val keyMonitorMaxCyclesPerDay = "monitor_max_cycles_per_day"

    private fun storageContext(context: Context): Context {
        val appContext = context.applicationContext
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            appContext.createDeviceProtectedStorageContext()
        } else {
            appContext
        }
    }

    private fun prefs(context: Context): SharedPreferences {
        return storageContext(context).getSharedPreferences(prefsName, Context.MODE_PRIVATE)
    }

    fun read(context: Context): UsageRestState {
        val prefs = prefs(context)
        return UsageRestState(
            active = prefs.getBoolean(keyActive, false),
            startedAtEpochMs = prefs.getLong(keyStartedAt, 0L),
            endsAtEpochMs = prefs.getLong(keyEndsAt, 0L),
            childName = prefs.getString(keyChildName, null)?.trim()?.takeIf { it.isNotEmpty() },
        )
    }

    fun writeActive(
        context: Context,
        startedAtEpochMs: Long,
        endsAtEpochMs: Long,
        childName: String?,
    ) {
        prefs(context)
            .edit()
            .putBoolean(keyActive, true)
            .putLong(keyStartedAt, startedAtEpochMs)
            .putLong(keyEndsAt, endsAtEpochMs)
            .putLong(keyLastStartedAt, startedAtEpochMs)
            .putLong(keyLastEndsAt, endsAtEpochMs)
            .putString(keyChildName, childName?.trim()?.takeIf { it.isNotEmpty() })
            .apply()
    }

    fun clearActive(context: Context) {
        prefs(context)
            .edit()
            .putBoolean(keyActive, false)
            .remove(keyStartedAt)
            .remove(keyEndsAt)
            .remove(keyChildName)
            .apply()
    }

    fun lastRestWindow(context: Context): Pair<Long, Long>? {
        val prefs = prefs(context)
        val startedAt = prefs.getLong(keyLastStartedAt, 0L)
        val endsAt = prefs.getLong(keyLastEndsAt, 0L)
        if (startedAt <= 0L || endsAt <= startedAt) {
            return null
        }
        return Pair(startedAt, endsAt)
    }

    fun writeMonitor(context: Context, config: UsageRestMonitorConfig) {
        prefs(context)
            .edit()
            .putBoolean(keyMonitorEnabled, config.enabled)
            .putLong(keyMonitorCycleStartedAt, config.cycleStartedAtEpochMs)
            .putString(keyMonitorCycleDate, config.cycleDate)
            .putInt(keyMonitorCycleCount, config.cycleCount)
            .putLong(keyMonitorThresholdMillis, config.thresholdMillis)
            .putLong(keyMonitorRestDurationMillis, config.restDurationMillis)
            .putInt(keyMonitorMaxCyclesPerDay, config.maxCyclesPerDay)
            .putString(keyChildName, config.childName?.trim()?.takeIf { it.isNotEmpty() })
            .apply()
    }

    fun readMonitor(context: Context): UsageRestMonitorConfig {
        val prefs = prefs(context)
        return UsageRestMonitorConfig(
            enabled = prefs.getBoolean(keyMonitorEnabled, false),
            cycleStartedAtEpochMs = prefs.getLong(keyMonitorCycleStartedAt, 0L),
            cycleDate = prefs.getString(keyMonitorCycleDate, null)?.trim()?.takeIf { it.isNotEmpty() },
            cycleCount = prefs.getInt(keyMonitorCycleCount, 0),
            thresholdMillis = prefs.getLong(keyMonitorThresholdMillis, 0L),
            restDurationMillis = prefs.getLong(keyMonitorRestDurationMillis, 0L),
            maxCyclesPerDay = prefs.getInt(keyMonitorMaxCyclesPerDay, 0),
            childName = prefs.getString(keyChildName, null)?.trim()?.takeIf { it.isNotEmpty() },
        )
    }

    fun clearMonitor(context: Context) {
        prefs(context)
            .edit()
            .putBoolean(keyMonitorEnabled, false)
            .remove(keyMonitorCycleStartedAt)
            .remove(keyMonitorCycleDate)
            .remove(keyMonitorCycleCount)
            .remove(keyMonitorThresholdMillis)
            .remove(keyMonitorRestDurationMillis)
            .remove(keyMonitorMaxCyclesPerDay)
            .apply()
    }
}

data class UsageRestMonitorConfig(
    val enabled: Boolean,
    val cycleStartedAtEpochMs: Long,
    val cycleDate: String?,
    val cycleCount: Int,
    val thresholdMillis: Long,
    val restDurationMillis: Long,
    val maxCyclesPerDay: Int,
    val childName: String?,
) {
    fun isUsable(): Boolean {
        return enabled &&
            cycleStartedAtEpochMs > 0L &&
            !cycleDate.isNullOrBlank() &&
            thresholdMillis > 0L &&
            restDurationMillis > 0L &&
            maxCyclesPerDay > 0
    }
}
