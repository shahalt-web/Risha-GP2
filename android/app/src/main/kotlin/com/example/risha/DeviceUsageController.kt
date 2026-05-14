package com.example.risha

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import java.util.Calendar

object DeviceUsageController {
    fun isUsageAccessGranted(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            }

        if (mode == AppOpsManager.MODE_ALLOWED) {
            return true
        }

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - 60_000L
        val usageStats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            start,
            end,
        )
        return usageStats.isNotEmpty()
    }

    fun openUsageAccessSettings(context: Context) {
        val intent =
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        context.startActivity(intent)
    }

    fun getTodayUsageMillis(context: Context): Long {
        return getActiveUsageMillisSince(context, startOfDayMillis())
    }

    fun getActiveUsageMillisSince(context: Context, startEpochMs: Long): Long {
        if (!isUsageAccessGranted(context)) {
            return 0L
        }

        val usageStatsManager =
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = startEpochMs.coerceAtMost(end)
        val events = usageStatsManager.queryEvents(startOfDayMillis(), end)
        val event = UsageEvents.Event()
        val timelineEvents = mutableListOf<UsageTimelineCalculator.Event>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val type = timelineEventType(event.eventType) ?: continue
            timelineEvents.add(
                UsageTimelineCalculator.Event(
                    timestampMs = event.timeStamp,
                    packageName = event.packageName,
                    type = type,
                ),
            )
        }

        return UsageTimelineCalculator.calculateActiveMillis(
            events = timelineEvents.asSequence(),
            startEpochMs = start,
            endEpochMs = end,
        ) { segmentStart, segmentEnd ->
            activeMillisOutsideRest(context, segmentStart, segmentEnd)
        }
    }

    private fun timelineEventType(eventType: Int): UsageTimelineCalculator.Type? {
        return when (eventType) {
            foregroundEventType() -> UsageTimelineCalculator.Type.Foreground
            backgroundEventType() -> UsageTimelineCalculator.Type.Background
            screenInteractiveEventType() -> UsageTimelineCalculator.Type.ScreenInteractive
            screenNonInteractiveEventType() -> UsageTimelineCalculator.Type.ScreenNonInteractive
            else -> null
        }
    }

    fun activeUsageMillisForRestMonitor(context: Context, startEpochMs: Long): Long {
        return getActiveUsageMillisSince(context, startEpochMs)
    }

    fun startOfTodayMillis(): Long {
        return startOfDayMillis()
    }

    fun todayKey(now: Calendar = Calendar.getInstance()): String {
        return "%04d-%02d-%02d".format(
            now.get(Calendar.YEAR),
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH),
        )
    }

    private fun activeMillisOutsideRest(context: Context, start: Long, end: Long): Long {
        if (end <= start) {
            return 0L
        }

        val restWindow = UsageRestStorage.lastRestWindow(context)
        if (restWindow == null) {
            return end - start
        }

        val (restStart, restEnd) = restWindow
        val overlapStart = maxOf(start, restStart)
        val overlapEnd = minOf(end, restEnd)
        val overlap = (overlapEnd - overlapStart).coerceAtLeast(0L)
        return (end - start - overlap).coerceAtLeast(0L)
    }

    private fun foregroundEventType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.ACTIVITY_RESUMED
        } else {
            @Suppress("DEPRECATION")
            UsageEvents.Event.MOVE_TO_FOREGROUND
        }
    }

    private fun backgroundEventType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.ACTIVITY_PAUSED
        } else {
            @Suppress("DEPRECATION")
            UsageEvents.Event.MOVE_TO_BACKGROUND
        }
    }

    private fun screenInteractiveEventType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.SCREEN_INTERACTIVE
        } else {
            @Suppress("DEPRECATION")
            UsageEvents.Event.SCREEN_INTERACTIVE
        }
    }

    private fun screenNonInteractiveEventType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            UsageEvents.Event.SCREEN_NON_INTERACTIVE
        } else {
            @Suppress("DEPRECATION")
            UsageEvents.Event.SCREEN_NON_INTERACTIVE
        }
    }

    private fun startOfDayMillis(now: Calendar = Calendar.getInstance()): Long {
        val start = now.clone() as Calendar
        start.set(Calendar.HOUR_OF_DAY, 0)
        start.set(Calendar.MINUTE, 0)
        start.set(Calendar.SECOND, 0)
        start.set(Calendar.MILLISECOND, 0)
        return start.timeInMillis
    }
}
