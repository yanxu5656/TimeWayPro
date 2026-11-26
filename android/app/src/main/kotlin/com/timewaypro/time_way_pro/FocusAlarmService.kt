package com.timewaypro.time_way_pro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 专注计时前台服务：整个 45/5 循环期间常驻。
 *
 * 倒计时阶段挂一条系统 chronometer 倒计时通知（由系统渲染剩余时间，
 * 服务本身不耗电），并预约 [FocusAlarmScheduler] 的系统闹钟作为唤醒备份；
 * 到点后切换为持续振动 +（可选）闹铃铃声。
 *
 * 前台服务让进程在锁屏、切后台、最近任务清理后依然存活，
 * 避免国产 ROM 查杀后台导致闹钟被取消、到点不响。
 */
class FocusAlarmService : Service() {
    companion object {
        const val CHANNEL_COUNTDOWN = "focus_channel"
        const val CHANNEL_ALARM = "focus_alarm_channel"
        const val ID_COUNTDOWN = 1002
        const val ID_ALARM = 1003
        const val MODE_VIBRATE_ONLY = "vibrate"
        private const val TIMEOUT_MS = 10 * 60 * 1000L

        private const val ACTION_COUNTDOWN = "com.timewaypro.time_way_pro.action.COUNTDOWN"
        private const val ACTION_PAUSE = "com.timewaypro.time_way_pro.action.PAUSE"
        private const val ACTION_ALARM = "com.timewaypro.time_way_pro.action.ALARM"
        private const val ACTION_STOP_ALARM = "com.timewaypro.time_way_pro.action.STOP_ALARM"

        fun countdown(context: Context, endMillis: Long, isFocus: Boolean, rounds: Int) {
            startCompat(
                Intent(context, FocusAlarmService::class.java)
                    .setAction(ACTION_COUNTDOWN)
                    .putExtra("endMillis", endMillis)
                    .putExtra("isFocus", isFocus)
                    .putExtra("rounds", rounds),
                context,
            )
        }

        fun pause(context: Context, remainingSeconds: Int, isFocus: Boolean) {
            startCompat(
                Intent(context, FocusAlarmService::class.java)
                    .setAction(ACTION_PAUSE)
                    .putExtra("remainingSeconds", remainingSeconds)
                    .putExtra("isFocus", isFocus),
                context,
            )
        }

        fun alarm(context: Context, mode: String, title: String, body: String) {
            startCompat(
                Intent(context, FocusAlarmService::class.java)
                    .setAction(ACTION_ALARM)
                    .putExtra("mode", mode)
                    .putExtra("title", title)
                    .putExtra("body", body),
                context,
            )
        }

        fun stopAlarmOnly(context: Context) {
            startCompat(
                Intent(context, FocusAlarmService::class.java).setAction(ACTION_STOP_ALARM),
                context,
            )
        }

        fun stopAll(context: Context) {
            FocusAlarmScheduler.cancel(context)
            try {
                val nm =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                nm?.cancel(ID_COUNTDOWN)
                nm?.cancel(ID_ALARM)
            } catch (_: Exception) {
            }
            try {
                context.stopService(Intent(context, FocusAlarmService::class.java))
            } catch (_: Exception) {
            }
        }

        private fun startCompat(intent: Intent, context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        expirePersistedAlarm()
        stopSelf()
    }

    private var alarming = false
    private var paused = false
    private var endMillis = 0L
    private var isFocus = true
    private var rounds = 1
    private var pausedRemaining = 0
    private var mode = "sound"
    private var alarmTitle = "⏰ 45 分钟专注时间到"
    private var alarmBody = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_COUNTDOWN -> {
                alarming = false
                paused = false
                endMillis = intent.getLongExtra("endMillis", 0L)
                isFocus = intent.getBooleanExtra("isFocus", true)
                rounds = intent.getIntExtra("rounds", 1)
                enterCountdown()
            }
            ACTION_PAUSE -> {
                paused = true
                pausedRemaining = intent.getIntExtra("remainingSeconds", 0)
                isFocus = intent.getBooleanExtra("isFocus", true)
                enterPaused()
            }
            ACTION_ALARM -> {
                val newMode = intent.getStringExtra("mode") ?: "sound"
                alarmTitle = intent.getStringExtra("title") ?: alarmTitle
                alarmBody = intent.getStringExtra("body") ?: alarmBody
                // 响铃阶段不再保留旧截止时间，否则停止试听/闹铃后会重新
                // 调度一个已经过期的闹钟，造成停止后再次响起。
                endMillis = 0L
                // 已在按同一模式响铃时忽略重复触发（Dart 与系统闹钟可能先后到达）
                if (alarming && newMode == mode && mediaPlayer != null) {
                    return START_STICKY
                }
                if (alarming && newMode == mode && mode == MODE_VIBRATE_ONLY) {
                    return START_STICKY
                }
                mode = newMode
                enterAlarm()
            }
            ACTION_STOP_ALARM -> {
                if (!alarming) {
                    // 无闹铃在响：若也没有倒计时状态则直接退出
                    if (endMillis <= 0 && !paused) {
                        stopSelf()
                        return START_NOT_STICKY
                    }
                    return START_STICKY
                }
                alarming = false
                stopPlayback()
                handler.removeCallbacks(timeoutRunnable)
                releaseWakeLock()
                notificationManager()?.cancel(ID_ALARM)
                when {
                    paused -> enterPaused()
                    endMillis > 0 -> enterCountdown()
                    else -> {
                        try {
                            stopForeground(STOP_FOREGROUND_REMOVE)
                        } catch (_: Exception) {
                        }
                        stopSelf()
                        return START_NOT_STICKY
                    }
                }
            }
            null -> {
                // 服务被系统回收后 sticky 重启：按最后状态恢复
                when {
                    alarming -> enterAlarm()
                    paused -> enterPaused()
                    endMillis > 0 -> enterCountdown()
                    else -> {
                        stopSelf()
                        return START_NOT_STICKY
                    }
                }
            }
            else -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    private fun enterCountdown() {
        stopPlayback()
        handler.removeCallbacks(timeoutRunnable)
        releaseWakeLock()
        FocusAlarmScheduler.schedule(this, endMillis)
        notificationManager()?.cancel(ID_ALARM)
        ensureChannel(CHANNEL_COUNTDOWN, "专注计时通知", false)
        startForegroundCompat(ID_COUNTDOWN, buildCountdownNotification())
    }

    private fun enterPaused() {
        stopPlayback()
        handler.removeCallbacks(timeoutRunnable)
        releaseWakeLock()
        FocusAlarmScheduler.cancel(this)
        notificationManager()?.cancel(ID_ALARM)
        ensureChannel(CHANNEL_COUNTDOWN, "专注计时通知", false)
        startForegroundCompat(ID_COUNTDOWN, buildPausedNotification())
    }

    private fun enterAlarm() {
        alarming = true
        paused = false
        FocusAlarmScheduler.cancel(this)
        handler.removeCallbacks(timeoutRunnable)
        notificationManager()?.cancel(ID_COUNTDOWN)
        ensureChannel(CHANNEL_ALARM, "专注闹铃提醒", true)
        startForegroundCompat(ID_ALARM, buildAlarmNotification())

        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = pm?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "TimeWayPro::FocusAlarmWakeLock",
            )?.apply {
                setReferenceCounted(false)
                acquire(TIMEOUT_MS)
            }
        } catch (_: Exception) {
        }

        startVibration()
        if (mode != MODE_VIBRATE_ONLY) {
            startRingtone()
        }
        handler.postDelayed(timeoutRunnable, TIMEOUT_MS)
    }

    private fun expirePersistedAlarm() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.focus_timer_state", null) ?: return
            val data = JSONObject(raw)
            if (data.optInt("phase", 0) != 2 && data.optInt("phase", 0) != 4) return
            data.put("alarmAt", LocalDateTime.now(ZoneId.systemDefault()).minusMinutes(10).toString())
            prefs.edit().putString("flutter.focus_timer_state", data.toString()).apply()
        } catch (_: Exception) {
        }
    }

    private fun notificationManager(): NotificationManager? =
        getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

    private fun startForegroundCompat(id: Int, notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(id, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(id, notification)
            }
        } catch (_: Exception) {
        }
    }

    private fun contentIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        4507,
        packageManager.getLaunchIntentForPackage(packageName) ?: Intent(),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun countdownTitle(): String =
        if (isFocus) "🎯 45 分钟专注 · 第 $rounds 轮" else "☕ 5 分钟休息"

    private fun buildCountdownNotification(): Notification {
        val builder = baseBuilder(CHANNEL_COUNTDOWN)
        return builder
            .setContentTitle(countdownTitle())
            .setContentText(if (isFocus) "专注中" else "休息中")
            // 系统渲染的倒计时，熄屏后无需任何 CPU 唤醒即可持续走秒
            .setWhen(endMillis)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(contentIntent())
            .build()
    }

    private fun buildPausedNotification(): Notification {
        val minutes = pausedRemaining / 60
        val seconds = pausedRemaining % 60
        val clock = "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
        return baseBuilder(CHANNEL_COUNTDOWN)
            .setContentTitle(countdownTitle())
            .setContentText("已暂停 · 剩余 $clock")
            .setShowWhen(false)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(contentIntent())
            .build()
    }

    private fun buildAlarmNotification(): Notification {
        return baseBuilder(CHANNEL_ALARM)
            .setContentTitle(alarmTitle)
            .setContentText(alarmBody)
            .setStyle(Notification.BigTextStyle().bigText(alarmBody))
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            // 声音与振动由服务按闹铃模式自行播放，通知本身保持静默，
            // 避免渠道音与 MediaPlayer 叠加响两遍
            .setSound(null)
            .setVibrate(null)
            .setContentIntent(contentIntent())
            .build()
    }

    private fun baseBuilder(channelId: String): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setPriority(
                    if (channelId == CHANNEL_ALARM) Notification.PRIORITY_MAX
                    else Notification.PRIORITY_LOW,
                )
        }
        return builder
            .setSmallIcon(applicationInfo.icon)
            .setSound(null)
            .setVibrate(null)
    }

    private fun ensureChannel(channelId: String, name: String, alarm: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = notificationManager() ?: return
        if (nm.getNotificationChannel(channelId) != null) return
        val channel = NotificationChannel(
            channelId,
            name,
            if (alarm) NotificationManager.IMPORTANCE_HIGH
            else NotificationManager.IMPORTANCE_LOW,
        ).apply {
            if (alarm) {
                description = "每 45 分钟专注结束或 5 分钟休息结束时的闹铃提醒"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 650, 350)
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                if (uri != null) {
                    setSound(
                        uri,
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                }
            } else {
                description = "显示 45/5 专注与休息倒计时"
                enableVibration(false)
                setSound(null, null)
            }
        }
        nm.createNotificationChannel(channel)
    }

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun startVibration() {
        try {
            val vibrator = getVibrator()
            if (vibrator != null && vibrator.hasVibrator()) {
                // 0ms 延迟，振动 650ms、间隔 350ms，循环索引 0
                val pattern = longArrayOf(0, 650, 350)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val effect = VibrationEffect.createWaveform(pattern, 0)
                    val attrs = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(effect, attrs)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, 0)
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun startRingtone() {
        try {
            val alarmUri =
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            if (alarmUri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    setDataSource(applicationContext, alarmUri)
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (_: Exception) {
            mediaPlayer?.release()
            mediaPlayer = null
        }
    }

    private fun stopPlayback() {
        try {
            getVibrator()?.cancel()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.let { player ->
                if (player.isPlaying) {
                    player.stop()
                }
                player.release()
            }
        } catch (_: Exception) {
        } finally {
            mediaPlayer = null
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let { lock ->
                if (lock.isHeld) {
                    lock.release()
                }
            }
        } catch (_: Exception) {
        } finally {
            wakeLock = null
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeoutRunnable)
        stopPlayback()
        releaseWakeLock()
        // 注意：不在此处取消系统闹钟调度——服务被系统回收时
        // 闹钟仍应到点通过广播重新拉起服务；只有 stopAll 才显式取消。
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}