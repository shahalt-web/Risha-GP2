package com.example.risha

object UsageTimelineCalculator {
    data class Event(
        val timestampMs: Long,
        val packageName: String?,
        val type: Type,
    )

    enum class Type {
        Foreground,
        Background,
        ScreenInteractive,
        ScreenNonInteractive,
    }

    fun calculateActiveMillis(
        events: Sequence<Event>,
        startEpochMs: Long,
        endEpochMs: Long,
        subtractRestMillis: (Long, Long) -> Long = { start, end -> end - start },
    ): Long {
        if (endEpochMs <= startEpochMs) {
            return 0L
        }

        val activePackages = mutableSetOf<String>()
        var screenInteractive = true
        var lastTimestamp = startEpochMs
        var totalMillis = 0L

        events.sortedBy { it.timestampMs }.forEach { event ->
            val rawEventTime = event.timestampMs
            if (rawEventTime < startEpochMs) {
                updateUsageState(event, activePackages) { interactive ->
                    screenInteractive = interactive
                }
                return@forEach
            }
            if (rawEventTime > endEpochMs) {
                return@forEach
            }

            val eventTime = rawEventTime.coerceIn(startEpochMs, endEpochMs)
            if (eventTime > lastTimestamp && screenInteractive && activePackages.isNotEmpty()) {
                totalMillis += subtractRestMillis(lastTimestamp, eventTime).coerceAtLeast(0L)
            }
            updateUsageState(event, activePackages) { interactive ->
                screenInteractive = interactive
            }
            lastTimestamp = eventTime
        }

        if (endEpochMs > lastTimestamp && screenInteractive && activePackages.isNotEmpty()) {
            totalMillis += subtractRestMillis(lastTimestamp, endEpochMs).coerceAtLeast(0L)
        }
        return totalMillis
    }

    private fun updateUsageState(
        event: Event,
        activePackages: MutableSet<String>,
        setScreenInteractive: (Boolean) -> Unit,
    ) {
        when (event.type) {
            Type.Foreground -> {
                event.packageName?.takeIf { it.isNotBlank() }?.let {
                    activePackages.clear()
                    activePackages.add(it)
                }
            }

            Type.Background -> {
                event.packageName?.takeIf { it.isNotBlank() }?.let {
                    activePackages.remove(it)
                }
            }

            Type.ScreenInteractive -> setScreenInteractive(true)
            Type.ScreenNonInteractive -> setScreenInteractive(false)
        }
    }
}
