package com.example.risha

import android.content.Context
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class StoryAudioController(
    private val context: Context,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaPlayer: MediaPlayer? = null
    private var prepared = false
    private var completed = false
    private var durationMs = 0
    private var loadedAssetPath: String? = null

    fun load(assetPath: String, result: MethodChannel.Result) {
        if (assetPath.isBlank()) {
            result.error("invalid_asset", "Asset path is empty.", null)
            return
        }

        Thread {
            try {
                val localFile = ensureAssetCopied(assetPath)
                runOnMain {
                    preparePlayer(localFile, assetPath, result)
                }
            } catch (error: Exception) {
                runOnMain {
                    releasePlayer()
                    result.error(
                        "story_audio_load_failed",
                        error.message ?: "Failed to copy story audio asset.",
                        null,
                    )
                }
            }
        }.start()
    }

    fun play(result: MethodChannel.Result) {
        runOnMain {
            val player = mediaPlayer
            if (player == null || !prepared) {
                result.error("not_ready", "Story audio is not prepared yet.", null)
                return@runOnMain
            }

            try {
                if (completed) {
                    seekToInternal(player, 0)
                    completed = false
                }
                player.start()
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("play_failed", error.message ?: "Failed to start playback.", null)
            }
        }
    }

    fun pause(result: MethodChannel.Result) {
        runOnMain {
            val player = mediaPlayer
            if (player == null || !prepared) {
                result.success(stateMap())
                return@runOnMain
            }

            try {
                if (player.isPlaying) {
                    player.pause()
                }
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("pause_failed", error.message ?: "Failed to pause playback.", null)
            }
        }
    }

    fun seekTo(positionMs: Int, result: MethodChannel.Result) {
        runOnMain {
            val player = mediaPlayer
            if (player == null || !prepared) {
                result.error("not_ready", "Story audio is not prepared yet.", null)
                return@runOnMain
            }

            try {
                completed = false
                seekToInternal(player, positionMs.coerceAtLeast(0))
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("seek_failed", error.message ?: "Failed to seek playback.", null)
            }
        }
    }

    fun stop(result: MethodChannel.Result) {
        runOnMain {
            try {
                mediaPlayer?.let { player ->
                    if (prepared) {
                        if (player.isPlaying) {
                            player.pause()
                        }
                        seekToInternal(player, 0)
                    }
                }
                completed = false
                result.success(stateMap())
            } catch (error: Exception) {
                result.error("stop_failed", error.message ?: "Failed to stop playback.", null)
            }
        }
    }

    fun getState(result: MethodChannel.Result) {
        runOnMain {
            result.success(stateMap())
        }
    }

    fun dispose(result: MethodChannel.Result) {
        runOnMain {
            releasePlayer()
            result.success(null)
        }
    }

    fun disposeSilently() {
        runOnMain {
            releasePlayer()
        }
    }

    private fun preparePlayer(
        localFile: File,
        assetPath: String,
        result: MethodChannel.Result,
    ) {
        if (prepared && loadedAssetPath == assetPath && mediaPlayer != null) {
            result.success(stateMap())
            return
        }

        releasePlayer()

        val player = MediaPlayer()
        mediaPlayer = player
        loadedAssetPath = assetPath
        prepared = false
        completed = false
        durationMs = 0

        val hasReplied = AtomicBoolean(false)

        fun replySuccess() {
            if (hasReplied.compareAndSet(false, true)) {
                result.success(stateMap())
            }
        }

        fun replyError(code: String, message: String) {
            if (hasReplied.compareAndSet(false, true)) {
                releasePlayer()
                result.error(code, message, null)
            }
        }

        player.setOnPreparedListener {
            prepared = true
            completed = false
            durationMs = it.duration.coerceAtLeast(0)
            replySuccess()
        }

        player.setOnCompletionListener {
            completed = true
        }

        player.setOnErrorListener { _, what, extra ->
            prepared = false
            completed = false
            replyError(
                "media_player_error",
                "MediaPlayer error. what=$what extra=$extra",
            )
            true
        }

        try {
            player.setDataSource(localFile.absolutePath)
            player.prepareAsync()
        } catch (error: Exception) {
            replyError(
                "prepare_failed",
                error.message ?: "Failed to prepare story audio.",
            )
        }
    }

    private fun ensureAssetCopied(assetPath: String): File {
        val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        val extension = assetPath.substringAfterLast('.', "bin")
        val cacheFile = File(context.cacheDir, "story_audio_${assetPath.hashCode()}.$extension")
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

    private fun stateMap(): Map<String, Any> {
        val player = mediaPlayer
        val position = if (prepared && player != null) {
            try {
                player.currentPosition.coerceAtLeast(0)
            } catch (_: Exception) {
                0
            }
        } else {
            0
        }

        val isPlaying = if (prepared && player != null) {
            try {
                player.isPlaying
            } catch (_: Exception) {
                false
            }
        } else {
            false
        }

        return mapOf(
            "ready" to prepared,
            "playing" to isPlaying,
            "completed" to completed,
            "positionMs" to position,
            "durationMs" to durationMs.coerceAtLeast(0),
        )
    }

    private fun releasePlayer() {
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
            // Ignore release failures.
        }

        mediaPlayer = null
        prepared = false
        completed = false
        durationMs = 0
        loadedAssetPath = null
    }

    private fun seekToInternal(player: MediaPlayer, positionMs: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            player.seekTo(positionMs.toLong(), MediaPlayer.SEEK_CLOSEST_SYNC)
        } else {
            @Suppress("DEPRECATION")
            player.seekTo(positionMs)
        }
    }

    private fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
            return
        }
        mainHandler.post(action)
    }
}
