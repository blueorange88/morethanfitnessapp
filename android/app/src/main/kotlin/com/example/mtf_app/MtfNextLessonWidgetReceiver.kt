package com.example.mtf_app

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MtfNextLessonWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<MtfNextLessonWidget>() {
    override val glanceAppWidget = MtfNextLessonWidget()
}