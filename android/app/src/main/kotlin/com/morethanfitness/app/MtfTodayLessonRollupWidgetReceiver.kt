package com.morethanfitness.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MtfTodayLessonRollupWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<MtfTodayLessonRollupWidget>() {
    override val glanceAppWidget: MtfTodayLessonRollupWidget
        get() = MtfTodayLessonRollupWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // 앱이 오늘 일정을 동기화하면 이 수신기가 갱신 신호를 받는다. 같은 데이터를 쓰는
        // '지금·다음' 위젯(DEV 빌드에만 있음)에도 알려 준다. 받는 곳이 없으면 아무 일도 없다.
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            context.sendBroadcast(
                Intent(ACTION_NOW_NEXT_REFRESH).setPackage(context.packageName),
            )
        }
    }

    private companion object {
        const val ACTION_NOW_NEXT_REFRESH = "com.morethanfitness.app.action.NOW_NEXT_REFRESH"
    }
}
