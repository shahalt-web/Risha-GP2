package com.example.risha

data class UsageRestState(
    val active: Boolean = false,
    val startedAtEpochMs: Long = 0L,
    val endsAtEpochMs: Long = 0L,
    val childName: String? = null,
) {
    fun isActiveAt(nowEpochMs: Long = System.currentTimeMillis()): Boolean {
        return active && endsAtEpochMs > nowEpochMs
    }
}
