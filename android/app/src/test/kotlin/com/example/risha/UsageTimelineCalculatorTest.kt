package com.example.risha

import kotlin.test.Test
import kotlin.test.assertEquals

class UsageTimelineCalculatorTest {
    @Test
    fun countsUsageWhenForegroundStartedBeforeCycleStart() {
        val usageMillis = UsageTimelineCalculator.calculateActiveMillis(
            events = sequenceOf(
                UsageTimelineCalculator.Event(
                    timestampMs = 1_000L,
                    packageName = "com.video.app",
                    type = UsageTimelineCalculator.Type.Foreground,
                ),
            ),
            startEpochMs = 5_000L,
            endEpochMs = 15_000L,
        )

        assertEquals(10_000L, usageMillis)
    }

    @Test
    fun excludesRestWindowFromActiveUsage() {
        val usageMillis = UsageTimelineCalculator.calculateActiveMillis(
            events = sequenceOf(
                UsageTimelineCalculator.Event(
                    timestampMs = 1_000L,
                    packageName = "com.video.app",
                    type = UsageTimelineCalculator.Type.Foreground,
                ),
            ),
            startEpochMs = 5_000L,
            endEpochMs = 20_000L,
            subtractRestMillis = { start, end ->
                val overlapStart = maxOf(start, 10_000L)
                val overlapEnd = minOf(end, 13_000L)
                end - start - (overlapEnd - overlapStart).coerceAtLeast(0L)
            },
        )

        assertEquals(12_000L, usageMillis)
    }
}
