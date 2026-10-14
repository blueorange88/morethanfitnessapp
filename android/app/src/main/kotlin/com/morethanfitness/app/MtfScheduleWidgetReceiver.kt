package com.morethanfitness.app

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class MtfScheduleWidgetReceiver :
    HomeWidgetGlanceWidgetReceiver<MtfScheduleWidget>() {

    override val glanceAppWidget: MtfScheduleWidget
        get() = MtfScheduleWidget()
}