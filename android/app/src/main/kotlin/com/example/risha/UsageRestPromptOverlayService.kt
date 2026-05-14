package com.example.risha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

class UsageRestPromptOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val monitorConfig = UsageRestStorage.readMonitor(this)
        if (!monitorConfig.enabled || !SleepLockController.isOverlayPermissionGranted(this)) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        startForeground(notificationId, buildNotification())
        showOverlay(monitorConfig)
        return START_STICKY
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    private fun showOverlay(config: UsageRestMonitorConfig) {
        if (overlayView != null) return

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = buildOverlayView(config)
        try {
            windowManager?.addView(view, buildLayoutParams())
            overlayView = view
        } catch (e: Exception) {
            stopSelf()
        }
    }

    private fun buildOverlayView(config: UsageRestMonitorConfig): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#B80F0C09"))
            isClickable = true
            isFocusable = true
            setOnTouchListener { _, _ -> true }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = 28f.toPx(this@UsageRestPromptOverlayService)
                setColor(Color.parseColor("#FFF8EFD9"))
            }
            setPadding(20.dp, 18.dp, 20.dp, 16.dp)
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }

        val mascot = ImageView(this).apply {
            val bitmap = loadFlutterAssetBitmap("assets/risha/risha_tired.png")
            if (bitmap != null) {
                setImageBitmap(bitmap)
            } else {
                setImageResource(R.mipmap.ic_launcher)
            }
            scaleType = ImageView.ScaleType.FIT_CENTER
        }

        val message = TextView(this).apply {
            text = "ريشة تعب ويريد بعض الراحة\nهل تريد أن تمنح ريشة نصف ساعة راحة؟"
            textSize = 20f
            setTypeface(null, Typeface.BOLD)
            setTextColor(Color.parseColor("#3D3025"))
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setLineSpacing(0f, 1.35f)
        }

        val buttonsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 18.dp
            }
        }

        val approveButton = TextView(this).apply {
            text = "موافقة"
            setTextColor(Color.WHITE)
            textSize = 18f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(12.dp, 12.dp, 12.dp, 12.dp)
            background = GradientDrawable().apply {
                cornerRadius = 16f.toPx(this@UsageRestPromptOverlayService)
                setColor(Color.parseColor("#FF2D8B52"))
            }
            isClickable = true
            isFocusable = true
            setOnClickListener {
                handleDecision(true)
            }
        }

        val declineButton = TextView(this).apply {
            text = "رفض"
            setTextColor(Color.WHITE)
            textSize = 18f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(12.dp, 12.dp, 12.dp, 12.dp)
            background = GradientDrawable().apply {
                cornerRadius = 16f.toPx(this@UsageRestPromptOverlayService)
                setColor(Color.parseColor("#FFC69C6D"))
            }
            isClickable = true
            isFocusable = true
            setOnClickListener {
                handleDecision(false)
            }
        }

        val buttonParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        
        buttonsLayout.addView(approveButton, buttonParams)
        val spacer = View(this).apply { layoutParams = LinearLayout.LayoutParams(10.dp, 1.dp) }
        buttonsLayout.addView(spacer)
        buttonsLayout.addView(declineButton, buttonParams)

        card.addView(mascot, LinearLayout.LayoutParams(170.dp, 170.dp).apply { bottomMargin = 10.dp })
        card.addView(message, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        card.addView(buttonsLayout)

        root.addView(card, FrameLayout.LayoutParams(330.dp, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        
        return root
    }

    private fun handleDecision(accepted: Boolean) {
        val now = System.currentTimeMillis()
        val config = UsageRestStorage.readMonitor(this)
        
        // Update monitor config (increment cycle count, reset cycle start)
        val updatedConfig = config.copy(
            cycleCount = (config.cycleCount + 1).coerceAtMost(config.maxCyclesPerDay),
            cycleStartedAtEpochMs = now
        )
        UsageRestStorage.writeMonitor(this, updatedConfig)

        if (accepted) {
            val endsAt = now + config.restDurationMillis
            UsageRestController.startRest(this, endsAt, config.childName)
        }
        
        stopSelf()
    }

    private fun buildLayoutParams(): WindowManager.LayoutParams {
        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )
    }

    private fun removeOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
    }

    private fun buildNotification(): Notification {
        createNotificationChannel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            4320,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("استراحة ريشة")
            .setContentText("ريشة متعب ويريد الراحة.")
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Break Prompt", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun loadFlutterAssetBitmap(assetPath: String) = try {
        assets.open("flutter_assets/$assetPath").use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    } catch (_: Exception) {
        null
    }

    private val Int.dp: Int get() = (this * resources.displayMetrics.density).roundToInt()
    private fun Float.toPx(context: Context) = this * context.resources.displayMetrics.density

    companion object {
        private const val channelId = "risha_break_prompt_channel"
        private const val notificationId = 4320
        
        fun start(context: Context) {
            val intent = Intent(context, UsageRestPromptOverlayService::class.java)
            SleepLockController.startForegroundServiceCompat(context, intent)
        }
        
        fun stop(context: Context) {
            context.stopService(Intent(context, UsageRestPromptOverlayService::class.java))
        }
    }
}
