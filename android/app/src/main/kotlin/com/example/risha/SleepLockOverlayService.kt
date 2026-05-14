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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.roundToInt

class SleepLockOverlayService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val refreshRunnable = object : Runnable {
        override fun run() {
            if (refreshOverlayState()) {
                handler.postDelayed(this, refreshIntervalMillis)
            }
        }
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var titleView: TextView? = null
    private var messageView: TextView? = null
    private var footerView: TextView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val config = SleepLockStorage.read(this)
        if (!config.isActiveConfig || !SleepLockController.isOverlayPermissionGranted(this)) {
            SleepLockController.syncServiceState(this)
            return START_NOT_STICKY
        }

        if (!SleepLockController.shouldLockNow(config)) {
            removeOverlay()
            SleepLockController.syncServiceState(this)
            return START_NOT_STICKY
        }

        startForeground(
            notificationId,
            buildNotification(
                config = config,
                activeNow = SleepLockController.shouldLockNow(config),
            ),
        )
        handler.removeCallbacks(refreshRunnable)
        return if (refreshOverlayState()) {
            handler.postDelayed(refreshRunnable, refreshIntervalMillis)
            START_STICKY
        } else {
            START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshRunnable)
        removeOverlay()
        super.onDestroy()
    }

    private fun refreshOverlayState(): Boolean {
        val config = SleepLockStorage.read(this)
        if (!config.isActiveConfig || !SleepLockController.isOverlayPermissionGranted(this)) {
            SleepLockController.syncServiceState(this)
            return false
        }

        val shouldLockNow = SleepLockController.shouldLockNow(config)
        if (!shouldLockNow) {
            removeOverlay()
            SleepLockController.syncServiceState(this)
            return false
        }

        updateNotification(config, activeNow = true)
        showOrUpdateOverlay(config)
        return true
    }

    private fun showOrUpdateOverlay(config: SleepLockConfig) {
        if (overlayView == null) {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val createdView = buildOverlayView()
            try {
                windowManager?.addView(createdView, buildLayoutParams())
                overlayView = createdView
            } catch (_: Exception) {
                return
            }
        }

        val childLabel = config.childName?.takeIf { it.isNotBlank() }
        titleView?.text = if (childLabel == null) {
            "حان وقت النوم الآن"
        } else {
            "حان وقت نوم $childLabel"
        }
        messageView?.text =
            "تم إيقاف استخدام الهاتف الآن حتى موعد الاستيقاظ.\n" 
            
        footerView?.text = "سيبقى الهاتف محجوبًا حتى 06:00 صباحًا."
    }

    private fun buildOverlayView(): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#E617110E"))
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setOnTouchListener { _, _ -> true }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            background = GradientDrawable().apply {
                cornerRadius = 28f.toPx(this@SleepLockOverlayService)
                setColor(Color.parseColor("#FFF7F1E2"))
            }
            setPadding(24.dp, 28.dp, 24.dp, 24.dp)
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }

        val mascot = ImageView(this).apply {
            val bitmap = loadFlutterAssetBitmap("assets/risha/risha_sleep.png")
            if (bitmap != null) {
                setImageBitmap(bitmap)
            } else {
                setImageResource(R.mipmap.ic_launcher)
            }
            scaleType = ImageView.ScaleType.FIT_CENTER
        }

        val title = TextView(this).apply {
            textSize = 24f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor("#D6A23C"))
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            textDirection = View.TEXT_DIRECTION_RTL
        }
        titleView = title

        val message = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.parseColor("#6B584D"))
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            textDirection = View.TEXT_DIRECTION_RTL
            setLineSpacing(0f, 1.25f)
        }
        messageView = message

        val footer = TextView(this).apply {
            textSize = 14f
            setTextColor(Color.parseColor("#9F7F67"))
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            textDirection = View.TEXT_DIRECTION_RTL
            setTypeface(typeface, Typeface.BOLD)
        }
        footerView = footer

        card.addView(
            mascot,
            LinearLayout.LayoutParams(190.dp, 190.dp).apply {
                bottomMargin = 12.dp
            },
        )
        card.addView(
            title,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = 10.dp
            },
        )
        card.addView(
            message,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = 12.dp
            },
        )
        card.addView(
            footer,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ).apply {
                leftMargin = 24.dp
                rightMargin = 24.dp
            },
        )

        return root
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
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    private fun removeOverlay() {
        val currentView = overlayView ?: return
        try {
            windowManager?.removeView(currentView)
        } catch (_: Exception) {
            // Ignore if Android already detached the overlay.
        } finally {
            overlayView = null
            titleView = null
            messageView = null
            footerView = null
        }
    }

    private fun stopServiceInternal() {
        handler.removeCallbacks(refreshRunnable)
        removeOverlay()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun buildNotification(
        config: SleepLockConfig,
        activeNow: Boolean,
    ): Notification {
        createNotificationChannelIfNeeded()
        val launchIntent =
            packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            3001,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (activeNow) {
            "حان وقت النوم"
        } else {
            "حماية وقت النوم مفعلة"
        }
        val body = if (activeNow) {
            "الهاتف محجوب الآن حتى 06:00 صباحًا."
        } else {
            "سيُقفل الهاتف عند ${SleepLockController.formatTime(config.sleepHour, config.sleepMinute)}."
        }
        return NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(config: SleepLockConfig, activeNow: Boolean) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, buildNotification(config, activeNow))
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            notificationChannelId,
            "حماية وقت النوم",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "إبقاء قفل وقت النوم مفعّلًا على مستوى الهاتف."
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_SECRET
        }
        manager.createNotificationChannel(channel)
    }

    private fun loadFlutterAssetBitmap(assetPath: String) = try {
        assets.open("flutter_assets/$assetPath").use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    } catch (_: Exception) {
        null
    }

    private val Int.dp: Int
        get() = (this * resources.displayMetrics.density).roundToInt()

    private fun Float.toPx(context: Context): Float {
        return this * context.resources.displayMetrics.density
    }

    companion object {
        private const val notificationChannelId = "risha_sleep_lock_channel"
        private const val notificationId = 4207
        private const val refreshIntervalMillis = 30_000L
        private const val actionRefresh = "com.example.risha.action.SLEEP_LOCK_REFRESH"

        fun start(context: Context) {
            val intent = Intent(context, SleepLockOverlayService::class.java).apply {
                action = actionRefresh
            }
            SleepLockController.startForegroundServiceCompat(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SleepLockOverlayService::class.java))
        }
    }
}
