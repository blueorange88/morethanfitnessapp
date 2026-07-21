package com.example.mtf_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.glance.appwidget.updateAll
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.util.Calendar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MtfWidgetWeekRolloverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            ACTION_WIDGET_TIME_REFRESH -> {
                scheduleNextTimeRefresh(context)
                refreshWidgets(context)
            }

            ACTION_WEEK_ROLLOVER -> {
                // 다음 주 월요일 00:01 알람도 다시 예약
                scheduleNext(context)

                // 위젯 현재 시간선 stale 방지를 위한 주기 refresh도 같이 유지
                scheduleNextTimeRefresh(context)

                // Flutter background callback으로 위젯 캐시 롤오버 요청
                HomeWidgetBackgroundIntent
                    .getBroadcast(context, Uri.parse("mtfwidget://week/rollover"))
                    .send()

                refreshWidgets(context)
            }

            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                scheduleNext(context)
                scheduleNextTimeRefresh(context)
                refreshWidgets(context)
            }

            else -> {
                scheduleNext(context)
                scheduleNextTimeRefresh(context)
                refreshWidgets(context)
            }
        }
    }

    private fun refreshWidgets(context: Context) {
        val pendingResult = goAsync()

        CoroutineScope(Dispatchers.Default).launch {
            try {
                MtfScheduleWidget().updateAll(context)
                MtfNextLessonWidget().updateAll(context)
                MtfTodayLessonRollupWidget().updateAll(context)
            } finally {
                pendingResult.finish()
            }
        }
    }

    companion object {
        private const val ACTION_WEEK_ROLLOVER =
            "com.example.mtf_app.action.WEEK_ROLLOVER"

        private const val ACTION_WIDGET_TIME_REFRESH =
            "com.example.mtf_app.action.WIDGET_TIME_REFRESH"

        private const val REQUEST_CODE_WEEK_ROLLOVER = 880401
        private const val REQUEST_CODE_TIME_REFRESH = 880402

        fun scheduleNext(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val intent = Intent(context, MtfWidgetWeekRolloverReceiver::class.java).apply {
                action = ACTION_WEEK_ROLLOVER
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_WEEK_ROLLOVER,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val next = Calendar.getInstance().apply {
                timeInMillis = System.currentTimeMillis()

                set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)

                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.WEEK_OF_YEAR, 1)
                }
            }

            alarmManager.cancel(pendingIntent)
            scheduleAlarm(alarmManager, next.timeInMillis, pendingIntent)
        }

        fun scheduleNextTimeRefresh(context: Context) {
            val alarmManager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val intent = Intent(context, MtfWidgetWeekRolloverReceiver::class.java).apply {
                action = ACTION_WIDGET_TIME_REFRESH
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE_TIME_REFRESH,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val nowMillis = System.currentTimeMillis()

            // 현재 시각에 30분을 더한 뒤 다시 반올림하면
            // 22:05 -> 23:00처럼 갱신이 최대 55분 늦어질 수 있습니다.
            // 현재 시각 기준의 '바로 다음 00분/30분 경계'를 예약합니다.
            // 23:30 이후에는 다음 예약이 정확히 00:00이 되어
            // 오늘 요일 강조가 전날에 남지 않습니다.
            val next = Calendar.getInstance().apply {
                timeInMillis = nowMillis
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)

                if (get(Calendar.MINUTE) < 30) {
                    set(Calendar.MINUTE, 30)
                } else {
                    add(Calendar.HOUR_OF_DAY, 1)
                    set(Calendar.MINUTE, 0)
                }

                if (timeInMillis <= nowMillis) {
                    add(Calendar.MINUTE, 30)
                }
            }

            alarmManager.cancel(pendingIntent)
            scheduleAlarm(alarmManager, next.timeInMillis, pendingIntent)
        }

        private fun scheduleAlarm(
            alarmManager: AlarmManager,
            triggerAtMillis: Long,
            pendingIntent: PendingIntent,
        ) {
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } catch (_: SecurityException) {
                // 정확 알람 권한이 없는 기기에서는 기존 절전 허용 알람으로 fallback
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }
        }
    }
}
