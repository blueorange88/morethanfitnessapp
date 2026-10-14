package com.morethanfitness.app

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MtfTodayLessonRollupWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<MtfTodayLessonRollupWidget>() {
    override val glanceAppWidget: MtfTodayLessonRollupWidget
        get() = MtfTodayLessonRollupWidget()
}
