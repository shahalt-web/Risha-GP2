package com.example.risha

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val quranAudioController = OptimizedAudioController(this)
        val storyAudioController = OptimizedAudioController(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceSleepLockChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncSleepLockConfig" -> {
                    val config = SleepLockConfig(
                        enabled = readBoolean(call, "enabled"),
                        configured = readBoolean(call, "configured"),
                        sleepHour = readInt(call, "sleepHour"),
                        sleepMinute = readInt(call, "sleepMinute"),
                        childId = readString(call, "childId"),
                        childName = readString(call, "childName"),
                    )
                    SleepLockStorage.write(this, config)
                    SleepLockController.syncServiceState(this)
                    result.success(null)
                }

                "clearSleepLockConfig" -> {
                    SleepLockStorage.clear(this)
                    SleepLockController.syncServiceState(this)
                    result.success(null)
                }

                "isOverlayPermissionGranted" -> {
                    result.success(SleepLockController.isOverlayPermissionGranted(this))
                }

                "openOverlayPermissionSettings" -> {
                    SleepLockController.openOverlayPermissionSettings(this)
                    result.success(true)
                }

                "refreshSleepLock" -> {
                    SleepLockController.syncServiceState(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceUsageChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isUsageAccessGranted" -> {
                    result.success(DeviceUsageController.isUsageAccessGranted(this))
                }

                "openUsageAccessSettings" -> {
                    DeviceUsageController.openUsageAccessSettings(this)
                    result.success(true)
                }

                "getTodayUsageMillis" -> {
                    result.success(DeviceUsageController.getTodayUsageMillis(this))
                }

                "getActiveUsageMillisSince" -> {
                    val startEpochMs = readLong(call, "startEpochMs")
                    result.success(DeviceUsageController.getActiveUsageMillisSince(this, startEpochMs))
                }

                "startUsageRest" -> {
                    val endsAtEpochMs = readLong(call, "endsAtEpochMs")
                    val childName = readString(call, "childName")
                    result.success(UsageRestController.startRest(this, endsAtEpochMs, childName))
                }

                "getUsageRestState" -> {
                    result.success(UsageRestController.getState(this))
                }

                "stopUsageRestIfExpired" -> {
                    result.success(UsageRestController.stopIfExpired(this))
                }

                "configureUsageRestMonitor" -> {
                    UsageRestController.configureMonitor(
                        context = this,
                        enabled = readBoolean(call, "enabled"),
                        cycleStartedAtEpochMs = readLong(call, "cycleStartedAtEpochMs"),
                        cycleDate = readString(call, "cycleDate"),
                        cycleCount = readInt(call, "cycleCount"),
                        thresholdMillis = readLong(call, "thresholdMillis"),
                        restDurationMillis = readLong(call, "restDurationMillis"),
                        maxCyclesPerDay = readInt(call, "maxCyclesPerDay"),
                        childName = readString(call, "childName"),
                    )
                    result.success(null)
                }

                "triggerUsageRestPrompt" -> {
                    UsageRestPromptOverlayService.start(this)
                    result.success(null)
                }

                "getUsageRestMonitorConfig" -> {
                    val config = UsageRestStorage.readMonitor(this)
                    result.success(
                        mapOf(
                            "enabled" to config.enabled,
                            "cycleStartedAtEpochMs" to config.cycleStartedAtEpochMs,
                            "cycleDate" to config.cycleDate,
                            "cycleCount" to config.cycleCount,
                            "thresholdMillis" to config.thresholdMillis,
                            "restDurationMillis" to config.restDurationMillis,
                            "maxCyclesPerDay" to config.maxCyclesPerDay,
                            "childName" to config.childName,
                        ),
                    )
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            storyAudioChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadStoryAudio" -> {
                    val assetPath = call.argument<String>("assetPath")?.trim()
                    if (assetPath.isNullOrEmpty()) {
                        result.error("invalid_asset", "Story audio asset path is empty.", null)
                    } else {
                        storyAudioController.load(assetPath, result)
                    }
                }

                "playStoryAudio" -> storyAudioController.play(result)
                "pauseStoryAudio" -> storyAudioController.pause(result)
                "seekStoryAudio" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    storyAudioController.seekTo(positionMs, result)
                }

                "stopStoryAudio" -> storyAudioController.stop(result)
                "getStoryAudioState" -> storyAudioController.getState(result)
                "disposeStoryAudio" -> storyAudioController.dispose(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            quranAudioChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadQuranAudio" -> {
                    val assetPath = call.argument<String>("assetPath")?.trim()
                    if (assetPath.isNullOrEmpty()) {
                        result.error("invalid_asset", "Quran audio asset path is empty.", null)
                    } else {
                        quranAudioController.load(assetPath, result)
                    }
                }

                "playQuranAudio" -> quranAudioController.play(result)
                "pauseQuranAudio" -> quranAudioController.pause(result)
                "seekQuranAudio" -> {
                    val positionMs = call.argument<Int>("positionMs") ?: 0
                    quranAudioController.seekTo(positionMs, result)
                }

                "stopQuranAudio" -> quranAudioController.stop(result)
                "getQuranAudioState" -> quranAudioController.getState(result)
                "disposeQuranAudio" -> quranAudioController.dispose(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        SleepLockController.syncServiceState(this)
        UsageRestController.evaluateMonitor(this)
        UsageRestController.syncServiceState(this)
    }

    private fun readBoolean(call: MethodCall, key: String): Boolean {
        return call.argument<Boolean>(key) ?: false
    }

    private fun readInt(call: MethodCall, key: String): Int {
        return call.argument<Int>(key) ?: 0
    }

    private fun readLong(call: MethodCall, key: String): Long {
        return when (val value = call.argument<Any>(key)) {
            is Long -> value
            is Int -> value.toLong()
            is Number -> value.toLong()
            is String -> value.trim().toLongOrNull() ?: 0L
            else -> 0L
        }
    }

    private fun readString(call: MethodCall, key: String): String? {
        return call.argument<String>(key)?.trim()?.takeIf { it.isNotEmpty() }
    }

    companion object {
        private const val deviceSleepLockChannel = "risha_v01/device_sleep_lock"
        private const val deviceUsageChannel = "risha_v01/device_usage"
        private const val storyAudioChannel = "risha_v01/story_audio"
        private const val quranAudioChannel = "risha_v01/quran_audio"
    }
}
