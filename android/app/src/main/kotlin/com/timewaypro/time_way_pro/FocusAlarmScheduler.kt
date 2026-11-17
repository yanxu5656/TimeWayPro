package com.timewaypro.time_way_pro

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * 系统级专注闹铃调度器。
 *
 * 使用 [AlarmManager.setAlarmClock]：不受 Doze / 省电模式限制，
 * 也不需要 SCHEDULE_EXACT_ALARM 权限，App 进程被杀后依然准时触发。
 */
object FocusAlarmScheduler {
    const val ACTION_FIRE = "com.timewaypro.time_way_pro.action.FOCUS_ALARM"
    private const val REQUEST_FIRE = 4505
    private const val REQUEST_SHOW = 4506

    fun schedule(context: Context, triggerAtMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val at = if (triggerAtMillis <= System.currentTimeMillis()) {
            System.currentTimeMillis() + 1000
        } else {
            triggerAtMillis
        }
        val operation = firePendingIntent(context)
        val show = PendingIntent.getActivity(
            context,
            REQUEST_SHOW,
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), operation)
        } catch (_: Exception) {
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
            } catch (_: Exception) {
                am.set(AlarmManager.RTC_WAKEUP, at, operation)
            }
        }
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val operation = firePendingIntent(context)
        try {
            am.cancel(operation)
        } catch (_: Exception) {
        }
        operation.cancel()
    }

    private fun firePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, FocusAlarmReceiver::class.java).setAction(ACTION_FIRE)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_FIRE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}