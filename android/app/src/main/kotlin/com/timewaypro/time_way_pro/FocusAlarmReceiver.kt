package com.timewaypro.time_way_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 系统闹钟到点广播：通知前台闹铃服务切换响铃。
 *
 * 正常情况下服务在倒计时阶段一直存活，这里只是到点触发器；
 * 若进程已被回收，则重新拉起服务。闹铃模式与阶段文案从 Flutter
 * 持久化的 SharedPreferences 读取，无需 Flutter 引擎存活。
 * 开机后也会根据持久化状态恢复倒计时 / 闹铃。
 */
class FocusAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            FocusAlarmScheduler.ACTION_FIRE -> fireAlarm(context)
            Intent.ACTION_BOOT_COMPLETED -> restoreAfterBoot(context)
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(
        "FlutterSharedPreferences",
        Context.MODE_PRIVATE,
    )

    private fun fireAlarm(context: Context) {
        val p = prefs(context)
        val mode = p.getString("flutter.focus_alarm_mode", "sound") ?: "sound"
        var finishedFocus = true
        try {
            val raw = p.getString("flutter.focus_timer_state", null)
            if (raw != null) {
                val phase = JSONObject(raw).optInt("phase", 1)
                finishedFocus = phase != 3 && phase != 4
            }
        } catch (_: Exception) {
        }
        FocusAlarmService.alarm(
            context,
            mode,
            if (finishedFocus) "⏰ 45 分钟专注时间到" else "🔔 5 分钟休息结束",
            if (finishedFocus) {
                "请放下手头工作，点击关闭闹铃并休息 5 分钟"
            } else {
                "休息结束，点击关闭闹铃并开始下一轮 45 分钟专注"
            },
        )
    }

    private fun restoreAfterBoot(context: Context) {
        try {
            val p = prefs(context)
            val raw = p.getString("flutter.focus_timer_state", null) ?: return
            val data = JSONObject(raw)
            val phase = data.optInt("phase", 0)
            val isPaused = data.optBoolean("isPaused", false)
            val mode = p.getString("flutter.focus_alarm_mode", "sound") ?: "sound"
            val rounds = data.optInt("completedRounds", 0) + 1
            val isFocus = phase == 1 || phase == 2

            when {
                // 关机前正在闹铃：开机立即补响
                phase == 2 || phase == 4 -> FocusAlarmService.alarm(
                    context,
                    mode,
                    if (isFocus) "⏰ 45 分钟专注时间到" else "🔔 5 分钟休息结束",
                    if (isFocus) {
                        "请放下手头工作，点击关闭闹铃并休息 5 分钟"
                    } else {
                        "休息结束，点击关闭闹铃并开始下一轮 45 分钟专注"
                    },
                )
                phase == 1 || phase == 3 -> {
                    if (isPaused) {
                        FocusAlarmService.pause(
                            context,
                            data.optInt("pausedRemaining", 0),
                            isFocus,
                        )
                        return
                    }
                    val endIso = data.optString("phaseEndTime", "")
                    if (endIso.isEmpty()) return
                    val endMillis = parseIsoLocalMillis(endIso) ?: return
                    if (endMillis <= System.currentTimeMillis()) {
                        FocusAlarmService.alarm(
                            context,
                            mode,
                            if (isFocus) "⏰ 45 分钟专注时间到" else "🔔 5 分钟休息结束",
                            if (isFocus) {
                                "请放下手头工作，点击关闭闹铃并休息 5 分钟"
                            } else {
                                "休息结束，点击关闭闹铃并开始下一轮 45 分钟专注"
                            },
                        )
                    } else {
                        FocusAlarmService.countdown(context, endMillis, isFocus, rounds)
                    }
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun parseIsoLocalMillis(iso: String): Long? {
        return try {
            LocalDateTime.parse(iso)
                .atZone(ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli()
        } catch (_: Exception) {
            null
        }
    }
}