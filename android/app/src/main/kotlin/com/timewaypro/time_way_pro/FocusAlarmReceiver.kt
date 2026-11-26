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
 * 所有迟到广播都先校验 Flutter 持久化状态；停止后没有状态直接忽略，
 * 新阶段尚未到点时只恢复倒计时，不能按旧广播提前响铃。
 */
class FocusAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            FocusAlarmScheduler.ACTION_FIRE,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> restoreState(context)
        }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(
        "FlutterSharedPreferences",
        Context.MODE_PRIVATE,
    )

    private fun restoreState(context: Context) {
        try {
            val p = prefs(context)
            val raw = p.getString("flutter.focus_timer_state", null) ?: return
            val data = JSONObject(raw)
            val phase = data.optInt("phase", 0)
            val isPaused = data.optBoolean("isPaused", false)
            val mode = p.getString("flutter.focus_alarm_mode", "sound") ?: "sound"
            val rounds = data.optInt("completedRounds", 0) + 1
            val isFocus = phase == 1 || phase == 2
            val now = System.currentTimeMillis()

            if (phase == 2 || phase == 4) {
                val alarmAt = parseIsoLocalMillis(data.optString("alarmAt", "")) ?: return
                // 与原生服务 10 分钟自动停铃保持一致，防止下次开 App 或系统广播重放。
                if (now >= alarmAt + 10 * 60 * 1000L) return
                startAlarm(context, mode, isFocus)
                return
            }

            if (phase != 1 && phase != 3) return
            if (isPaused) {
                FocusAlarmService.pause(
                    context,
                    data.optInt("pausedRemaining", 0),
                    isFocus,
                )
                return
            }
            val endMillis = parseIsoLocalMillis(data.optString("phaseEndTime", "")) ?: return
            if (endMillis <= now) {
                startAlarm(context, mode, isFocus)
            } else {
                FocusAlarmService.countdown(context, endMillis, isFocus, rounds)
            }
        } catch (_: Exception) {
        }
    }

    private fun startAlarm(context: Context, mode: String, isFocus: Boolean) {
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
