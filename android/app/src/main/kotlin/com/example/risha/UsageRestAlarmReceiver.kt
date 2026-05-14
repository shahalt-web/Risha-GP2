package com.example.risha

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class UsageRestAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        UsageRestController.evaluateMonitor(context)
        UsageRestController.syncServiceState(context)
    }
}
