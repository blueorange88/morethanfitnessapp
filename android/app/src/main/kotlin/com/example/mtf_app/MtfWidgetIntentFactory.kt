package com.example.mtf_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri

internal object MtfWidgetIntentFactory {
    fun openToday(context: Context, appWidgetId: Int): Intent =
        openApp(context, "today", appWidgetId).apply {
            action = MainActivity.openTodayScheduleAction(context.packageName)
            putExtra(MainActivity.EXTRA_WIDGET_ACTION, MainActivity.WIDGET_ACTION_TODAY)
        }

    fun openNextLesson(context: Context, appWidgetId: Int): Intent =
        openApp(context, "next", appWidgetId)

    fun openWeeklySchedule(context: Context, appWidgetId: Int): Intent =
        openApp(context, "weekly", appWidgetId)

    fun openWeeklySettings(context: Context, appWidgetId: Int): Intent =
        openApp(context, "weekly-settings", appWidgetId).apply {
            putExtra("mtf_route", "/widget-settings")
        }

    fun displayTitle(context: Context, title: String): String {
        if (!isDevWidget(context)) {
            return title
        }
        return "${context.getString(R.string.mtf_widget_dev_badge)} · $title"
    }

    fun isDevWidget(context: Context): Boolean =
        context.resources.getBoolean(R.bool.mtf_widget_show_dev_badge)

    private fun openApp(context: Context, kind: String, appWidgetId: Int): Intent {
        val component = ComponentName(
            context.packageName,
            MainActivity::class.java.name,
        )
        val data = Uri.Builder()
            .scheme(context.getString(R.string.mtf_widget_intent_scheme))
            .authority("widget")
            .appendPath(kind)
            .appendQueryParameter("instance", appWidgetId.toString())
            .build()
        return Intent().apply {
            this.component = component
            setPackage(context.packageName)
            this.data = data
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }
    }
}
