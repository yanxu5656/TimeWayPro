package com.timewaypro.time_way_pro

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val ALARM_CHANNEL = "com.timewaypro.time_way_pro/alarm"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCountdown" -> {
                    val end = call.argument<Number>("endMillis")?.toLong()
                    if (end != null) {
                        FocusAlarmService.countdown(
                            this,
                            end,
                            call.argument<Boolean>("isFocus") ?: true,
                            call.argument<Number>("rounds")?.toInt() ?: 1,
                        )
                    }
                    result.success(true)
                }
                "pauseCountdown" -> {
                    FocusAlarmService.pause(
                        this,
                        call.argument<Number>("remainingSeconds")?.toInt() ?: 0,
                        call.argument<Boolean>("isFocus") ?: true,
                    )
                    result.success(true)
                }
                "startAlarm" -> {
                    FocusAlarmService.alarm(
                        this,
                        call.argument<String>("mode") ?: "sound",
                        call.argument<String>("title") ?: "⏰ 专注时间到",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(true)
                }
                "stopAlarm" -> {
                    // 仅停止闹铃播放；进行中的倒计时会自动恢复
                    FocusAlarmService.stopAlarmOnly(this)
                    result.success(true)
                }
                "stopAll" -> {
                    FocusAlarmService.stopAll(this)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as? PowerManager
                    result.success(pm?.isIgnoringBatteryOptimizations(packageName) ?: true)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    result.success(requestIgnoreBatteryOptimizations())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}