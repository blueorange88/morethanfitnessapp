package com.example.mtf_app

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.AppWidgetId
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle

import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

class MtfNextLessonWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = (id as? AppWidgetId)?.appWidgetId ?: 0
        provideContent {
            Content(context, currentState(), appWidgetId)
        }
    }

    @Composable
    private fun Content(
        context: Context,
        currentState: HomeWidgetGlanceState,
        appWidgetId: Int,
    ) {
        val prefs = currentState.preferences

        val next = LessonWidgetItem(
            time = prefs.getString("mtf_widget_next_lesson_time", "") ?: "",
            name = prefs.getString("mtf_widget_next_lesson_name", "") ?: "",
            type = prefs.getString("mtf_widget_next_lesson_type", "") ?: "",
            memo = prefs.getString("mtf_widget_next_lesson_memo", "") ?: "",
        )

        val second = LessonWidgetItem(
            time = prefs.getString("mtf_widget_second_lesson_time", "") ?: "",
            name = prefs.getString("mtf_widget_second_lesson_name", "") ?: "",
            type = prefs.getString("mtf_widget_second_lesson_type", "") ?: "",
            memo = prefs.getString("mtf_widget_second_lesson_memo", "") ?: "",
        )

        val openAppIntent = MtfWidgetIntentFactory.openNextLesson(context, appWidgetId)

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(widgetColor(0xFFFFFFFF))
                .clickable(onClick = actionStartActivity(openAppIntent))
                .padding(10.dp)
        ) {
            Text(
                text = MtfWidgetIntentFactory.displayTitle(context, "다음 레슨"),
                style = TextStyle(
                    color = widgetColor(0xFF4F46E5),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Start,
                ),
                modifier = GlanceModifier.fillMaxWidth()
            )

            Box(modifier = GlanceModifier.height(8.dp)) {}

            if (next.name.isBlank()) {
                EmptyLessonCard()
            } else {
                LessonCard(
                    item = next,
                    isPrimary = true,
                    showMemo = true,
                )
            }

            Box(modifier = GlanceModifier.height(8.dp)) {}

            Text(
                text = "다다음",
                style = TextStyle(
                    color = widgetColor(0xFF6B7280),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Start,
                ),
                modifier = GlanceModifier.fillMaxWidth()
            )

            Box(modifier = GlanceModifier.height(4.dp)) {}

            if (second.name.isBlank()) {
                Text(
                    text = "예정된 다음 레슨이 없어요.",
                    style = TextStyle(
                        color = widgetColor(0xFF9CA3AF),
                        fontSize = 11.sp,
                        textAlign = TextAlign.Start,
                    ),
                    modifier = GlanceModifier.fillMaxWidth()
                )
            } else {
                LessonCard(
                    item = second,
                    isPrimary = false,
                    showMemo = false,
                )
            }
        }
    }

    @Composable
    private fun LessonCard(
        item: LessonWidgetItem,
        isPrimary: Boolean,
        showMemo: Boolean,
    ) {
        val bgColor = if (isPrimary) 0xFFF5F3FF else 0xFFF9FAFB
        val titleColor = if (isPrimary) 0xFF312E81 else 0xFF111827
        val timeWidth = if (isPrimary) 62.dp else 54.dp
        val timeFontSize = if (isPrimary) 18.sp else 14.sp
        val titleFontSize = if (isPrimary) 15.sp else 13.sp

        Column(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(widgetColor(bgColor))
                .padding(9.dp)
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = item.time.ifBlank { "--:--" },
                    style = TextStyle(
                        color = widgetColor(0xFF111827),
                        fontSize = timeFontSize,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Start,
                    ),
                    modifier = GlanceModifier.width(timeWidth)
                )

                Text(
                    text = buildLessonTitle(item),
                    maxLines = 1,
                    style = TextStyle(
                        color = widgetColor(titleColor),
                        fontSize = titleFontSize,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Start,
                    ),
                    modifier = GlanceModifier.fillMaxWidth()
                )
            }

            if (showMemo && item.memo.isNotBlank()) {
                Box(modifier = GlanceModifier.height(6.dp)) {}

                Text(
                    text = "메모: ${item.memo}",
                    maxLines = 2,
                    style = TextStyle(
                        color = widgetColor(0xFF4B5563),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Start,
                    ),
                    modifier = GlanceModifier.fillMaxWidth()
                )
            }
        }
    }

    @Composable
    private fun EmptyLessonCard() {
        Box(
            modifier = GlanceModifier
                .fillMaxWidth()
                .height(72.dp)
                .background(widgetColor(0xFFF9FAFB))
                .padding(10.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "예정된 레슨이 없어요.",
                style = TextStyle(
                    color = widgetColor(0xFF6B7280),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                )
            )
        }
    }

    private fun buildLessonTitle(item: LessonWidgetItem): String {
        val name = item.name.trim()
        val type = item.type.trim()

        return when {
            name.isNotBlank() && type.isNotBlank() -> "$name $type"
            name.isNotBlank() -> name
            type.isNotBlank() -> type
            else -> "-"
        }
    }

    private fun widgetColor(hex: Long) =
        ColorProvider(
            day = Color(hex),
            night = Color(hex)
        )
}

data class LessonWidgetItem(
    val time: String,
    val name: String,
    val type: String,
    val memo: String,
)
