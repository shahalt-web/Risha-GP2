package com.example.risha

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class OptimizedAudioController(private val context: Context) {
    companion object {
        private const val PREPARE_TIMEOUT_MS = 6000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val isDisposed = AtomicBoolean(false)
    private val isLoading = AtomicBoolean(false)

    private var exoPlayer: ExoPlayer? = null
    private var playerListener: Player.Listener? = null
    private var prepareTimeoutRunnable: Runnable? = null

    private var pendingLoadResult: MethodChannel.Result? = null
    private var pendingLoadHandled = false

    private var prepared = false
    private var completed = false
    private var durationMs = 0L
    private var loadedAssetPath: String? = null

    fun load(assetPath: String, result: MethodChannel.Result) {
        val normalizedAssetPath = assetPath.trim()
        if (normalizedAssetPath.isEmpty()) {
            result.error("invalid_asset", "Audio asset path is empty.", null)
            return
        }
        if (isDisposed.get()) {
            result.error("disposed", "Audio controller disposed.", null)
            return
        }
        if (!isLoading.compareAndSet(false, true)) {
            result.error("loading", "Audio is already loading.", null)
            return
        }

        ioScope.launch {
            try {
                val localFile = ensureAssetCopied(normalizedAssetPath)
                runOnMain {
                    if (isDisposed.get()) {
                        isLoading.set(false)
                        result.error("disposed", "Audio controller disposed.", null)
                        return@runOnMain
                    }
                    if (prepared && loadedAssetPath == normalizedAssetPath && exoPlayer != null) {
                        isLoading.set(false)
                        updateStateFromPlayer(exoPlayer)
                        result.success(stateMap())
                        return@runOnMain
                    }

                    beginPendingLoad(result)
                    preparePlayer(localFile, normalizedAssetPath)
                }
            } catch (error: Exception) {
                runOnMain {
                    isLoading.set(false)
                    releasePlayer()
                    if (isDisposed.get()) {
                        result.error("disposed", "Audio controller disposed.", null)
                    } else {
                        result.error(
                            "audio_load_failed",
                            error.message ?: "Failed to copy audio asset.",
                            null,
                        )
                    }
                }
            }
        }
    }

    fun play(result: MethodChannel.Result) {
        runOnMain {
            if (isDisposed.get()) {
                result.error("disposed", "Audio controller disposed.", null)
                return@runOnMain
            }
            val player = exoPlayer
            if (player == null || !prepared) {
                result.error("not_ready", "Audio is not prepared yet.", null)
                return@runOnMain
            }

            try {
                if (completed) {
                    player.seekTo(0L)
                    completed = false
                }
                player.playWhenReady = true
                player.play()
                updateStateFromPlayer(player)
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("play_failed", error.message ?: "Failed to start playback.", null)
            }
        }
    }

    fun pause(result: MethodChannel.Result) {
        runOnMain {
            if (isDisposed.get()) {
                result.error("disposed", "Audio controller disposed.", null)
                return@runOnMain
            }
            val player = exoPlayer
            if (player == null || !prepared) {
                result.success(stateMap())
                return@runOnMain
            }

            try {
                if (player.isPlaying) {
                    player.pause()
                }
                updateStateFromPlayer(player)
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("pause_failed", error.message ?: "Failed to pause playback.", null)
            }
        }
    }

    fun seekTo(positionMs: Int, result: MethodChannel.Result) {
        runOnMain {
            if (isDisposed.get()) {
                result.error("disposed", "Audio controller disposed.", null)
                return@runOnMain
            }
            val player = exoPlayer
            if (player == null || !prepared) {
                result.error("not_ready", "Audio is not prepared yet.", null)
                return@runOnMain
            }

            try {
                completed = false
                player.seekTo(positionMs.coerceAtLeast(0).toLong())
                updateStateFromPlayer(player)
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("seek_failed", error.message ?: "Failed to seek playback.", null)
            }
        }
    }

    fun stop(result: MethodChannel.Result) {
        runOnMain {
            if (isDisposed.get()) {
                result.success(stateMap())
                return@runOnMain
            }
            val player = exoPlayer
            if (player == null || !prepared) {
                result.success(stateMap())
                return@runOnMain
            }

            try {
                player.pause()
                player.seekTo(0L)
                completed = false
                updateStateFromPlayer(player)
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("stop_failed", error.message ?: "Failed to stop playback.", null)
            }
        }
    }

    fun getState(result: MethodChannel.Result) {
        runOnMain {
            updateStateFromPlayer(exoPlayer)
            result.success(stateMap())
        }
    }

    fun dispose(result: MethodChannel.Result? = null) {
        runOnMain {
            if (isDisposed.getAndSet(true)) {
                result?.success(null)
                return@runOnMain
            }

            ioScope.cancel()
            failPendingLoadIfAny("disposed", "Audio controller disposed.")
            releasePlayer()
            result?.success(null)
        }
    }

    private fun preparePlayer(localFile: File, assetPath: String) {
        releasePlayer()

        val player = ExoPlayer.Builder(context).build()
        exoPlayer = player
        prepared = false
        completed = false
        durationMs = 0L
        loadedAssetPath = assetPath

        val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                updateStateFromPlayer(player)
                if (playbackState == Player.STATE_READY) {
                    prepared = true
                    completed = false
                    durationMs = safeDuration(player)
                    completePendingLoadSuccess()
                } else if (playbackState == Player.STATE_ENDED) {
                    completed = true
                }
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                updateStateFromPlayer(player)
            }

            override fun onPlayerError(error: PlaybackException) {
                releasePlayer()
                completePendingLoadError(
                    "player_error",
                    error.message ?: "Audio player failed to prepare.",
                )
            }
        }
        playerListener = listener
        player.addListener(listener)

        val timeout = Runnable {
            releasePlayer()
            completePendingLoadError("prepare_timeout", "Timed out while preparing audio.")
        }
        prepareTimeoutRunnable = timeout
        mainHandler.postDelayed(timeout, PREPARE_TIMEOUT_MS)

        try {
            player.setMediaItem(MediaItem.fromUri(Uri.fromFile(localFile)))
            player.prepare()
        } catch (error: Exception) {
            releasePlayer()
            completePendingLoadError(
                "prepare_failed",
                error.message ?: "Failed to prepare audio player.",
            )
        }
    }

    private fun beginPendingLoad(result: MethodChannel.Result) {
        pendingLoadResult = result
        pendingLoadHandled = false
    }

    private fun completePendingLoadSuccess() {
        if (pendingLoadHandled) {
            return
        }
        pendingLoadHandled = true
        cancelPrepareTimeout()
        isLoading.set(false)
        pendingLoadResult?.success(stateMap())
        pendingLoadResult = null
    }

    private fun completePendingLoadError(code: String, message: String) {
        if (pendingLoadHandled) {
            return
        }
        pendingLoadHandled = true
        cancelPrepareTimeout()
        isLoading.set(false)
        pendingLoadResult?.error(code, message, null)
        pendingLoadResult = null
    }

    private fun failPendingLoadIfAny(code: String, message: String) {
        if (pendingLoadResult == null || pendingLoadHandled) {
            cancelPrepareTimeout()
            isLoading.set(false)
            return
        }
        completePendingLoadError(code, message)
    }

    private fun releasePlayer() {
        cancelPrepareTimeout()
        try {
            val listener = playerListener
            val player = exoPlayer
            if (listener != null && player != null) {
                player.removeListener(listener)
            }
            player?.release()
        } catch (_: Exception) {
            // Ignore release failures.
        }
        playerListener = null
        exoPlayer = null
        prepared = false
        completed = false
        durationMs = 0L
        loadedAssetPath = null
    }

    private fun updateStateFromPlayer(player: ExoPlayer?) {
        if (player == null) {
            prepared = false
            completed = false
            durationMs = 0L
            return
        }
        val resolvedDuration = safeDuration(player)
        if (resolvedDuration > 0L) {
            durationMs = resolvedDuration
        }
        if (player.playbackState == Player.STATE_ENDED) {
            completed = true
        }
    }

    private fun stateMap(): Map<String, Any> {
        val player = exoPlayer
        val position = if (prepared && player != null) {
            safePosition(player)
        } else {
            0L
        }
        val isPlaying = if (prepared && player != null) {
            safeIsPlaying(player)
        } else {
            false
        }
        val resolvedDuration = if (durationMs > 0L) {
            durationMs
        } else if (prepared && player != null) {
            safeDuration(player)
        } else {
            0L
        }

        return mapOf(
            "ready" to prepared,
            "playing" to isPlaying,
            "completed" to completed,
            "positionMs" to position,
            "durationMs" to resolvedDuration.coerceAtLeast(0L),
        )
    }

    private fun safeDuration(player: ExoPlayer): Long {
        return try {
            player.duration.takeIf { it > 0L } ?: 0L
        } catch (_: Exception) {
            0L
        }
    }

    private fun safePosition(player: ExoPlayer): Long {
        return try {
            player.currentPosition.coerceAtLeast(0L)
        } catch (_: Exception) {
            0L
        }
    }

    private fun safeIsPlaying(player: ExoPlayer): Boolean {
        return try {
            player.isPlaying
        } catch (_: Exception) {
            false
        }
    }

    private fun cancelPrepareTimeout() {
        prepareTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        prepareTimeoutRunnable = null
    }

    private fun ensureAssetCopied(assetPath: String): File {
        val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        val extension = assetPath.substringAfterLast('.', "bin")
        val cacheFile = File(context.cacheDir, "optimized_audio_${assetPath.hashCode()}.$extension")

        if (cacheFile.exists() && cacheFile.length() > 0L) {
            return cacheFile
        }

        context.assets.open(lookupKey).use { input ->
            FileOutputStream(cacheFile).use { output ->
                input.copyTo(output)
            }
        }
        return cacheFile
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
            return
        }
        mainHandler.post(action)
    }
}