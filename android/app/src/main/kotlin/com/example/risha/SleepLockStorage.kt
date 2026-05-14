package com.example.risha

import android.content.Context
import android.content.SharedPreferences
import android.os.Build

object SleepLockStorage {
    private const val prefsName = "risha_sleep_lock_prefs"
    private const val keyEnabled = "enabled"
    private const val keyConfigured = "configured"
    private const val keySleepHour = "sleep_hour"
    private const val keySleepMinute = "sleep_minute"
    private const val keyChildId = "child_id"
    private const val keyChildName = "child_name"

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

    fun read(context: Context): SleepLockConfig {
        val prefs = prefs(context)
        return SleepLockConfig(
            enabled = prefs.getBoolean(keyEnabled, false),
            configured = prefs.getBoolean(keyConfigured, false),
            sleepHour = prefs.getInt(keySleepHour, 0),
            sleepMinute = prefs.getInt(keySleepMinute, 0),
            childId = prefs.getString(keyChildId, null)?.trim()?.takeIf { it.isNotEmpty() },
            childName = prefs.getString(keyChildName, null)?.trim()?.takeIf { it.isNotEmpty() },
        )
    }

    fun write(context: Context, config: SleepLockConfig) {
        prefs(context)
            .edit()
            .putBoolean(keyEnabled, config.enabled)
            .putBoolean(keyConfigured, config.configured)
            .putInt(keySleepHour, config.sleepHour)
            .putInt(keySleepMinute, config.sleepMinute)
            .putString(keyChildId, config.childId)
            .putString(keyChildName, config.childName)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }
}
