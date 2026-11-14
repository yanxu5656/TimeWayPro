package com.timewaypro.time_way_pro

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ALARM_CHANNEL = "com.timewaypro.time_way_pro/alarm"
    }

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    startAlarm()
                    result.success(true)
                }
                "stopAlarm" -> {
                    stopAlarm()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
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

    private fun startAlarm() {
        stopAlarm()

        // 短时唤醒锁保证振动与铃声触发不被立刻休眠打断
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = pm?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "TimeWayPro::FocusAlarmWakeLock",
            )?.apply {
                setReferenceCounted(false)
                acquire(10 * 60 * 1000L)
            }
        } catch (_: Exception) {
        }

        // 持续周期振动（0ms 延迟，振动 650ms、间隔 350ms，循环索引 0）
        try {
            val vibrator = getVibrator()
            if (vibrator != null && vibrator.hasVibrator()) {
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

        // 循环播放系统默认闹铃音（按闹钟音量通道）
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

    private fun stopAlarm() {
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
        stopAlarm()
        super.onDestroy()
    }
}
