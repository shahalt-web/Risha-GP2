package com.example.risha

data class SleepLockConfig(
    val enabled: Boolean = false,
    val configured: Boolean = false,
    val sleepHour: Int = 0,
    val sleepMinute: Int = 0,
    val childId: String? = null,
    val childName: String? = null,
) {
    val hasValidTime: Boolean
        get() = sleepHour in 0..23 && sleepMinute in 0..59

    val isActiveConfig: Boolean
        get() = enabled && configured && hasValidTime

    val sleepMinutes: Int
        get() = (sleepHour * 60) + sleepMinute

    companion object {
        const val MORNING_UNLOCK_MINUTES: Int = 6 * 60
    }
}
