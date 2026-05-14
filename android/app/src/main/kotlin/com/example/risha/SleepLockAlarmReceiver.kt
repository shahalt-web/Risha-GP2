package com.example.risha

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SleepLockAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        SleepLockController.syncServiceState(context)
    }
}
