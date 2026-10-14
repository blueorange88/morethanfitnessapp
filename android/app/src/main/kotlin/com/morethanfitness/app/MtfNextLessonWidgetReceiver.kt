package com.morethanfitness.app

import androidx.glance.appwidget.GlanceAppWidget
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MtfNextLessonWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<MtfNextLessonWidget>() {

    override val glanceAppWidget: MtfNextLessonWidget  // GlanceAppWidget → MtfNextLessonWidget
        get() = MtfNextLessonWidget()
}