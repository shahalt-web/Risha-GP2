package com.example.risha

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class UsageRestBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            -> {
                UsageRestController.evaluateMonitor(context)
                UsageRestController.syncServiceState(context)
            }
        }
    }
}
