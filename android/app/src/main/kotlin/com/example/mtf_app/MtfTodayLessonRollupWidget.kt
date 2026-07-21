package com.example.mtf_app

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import org.json.JSONObject

class MtfTodayLessonRollupWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact
    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Content(context, currentState()) }
    }

    @Composable
    private fun Content(context: Context, state: HomeWidgetGlanceState) {
        val prefs = state.preferences
        val ownerUid = prefs.getString(KEY_OWNER_UID, "") ?: ""
        val encoded = prefs.getString(KEY_ROLLUP, "{}") ?: "{}"
        val lessons = parseVisibleLessons(encoded, ownerUid)
        val remainingCapacity = when {
            LocalSize.current.height.value >= 310f -> 4
            LocalSize.current.height.value >= 270f -> 3
            else -> 2
        }
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(MainActivity.EXTRA_WIDGET_ACTION, MainActivity.WIDGET_ACTION_TODAY)
        }

        Column(
            modifier = GlanceModifier.fillMaxSize()
                .background(color(0xFFFFFFFF))
                .clickable(actionStartActivity(openAppIntent))
                .padding(12.dp),
        ) {
            Header(lessons.size)
            Box(GlanceModifier.height(8.dp)) {}
            if (lessons.isEmpty()) {
                EmptyState()
                return@Column
            }
            FeaturedLesson("다음 레슨", lessons[0])
            if (lessons.size >= 2) {
                Box(GlanceModifier.height(6.dp)) {}
                FeaturedLesson("다다음 레슨", lessons[1])
            }
            val remaining = lessons.drop(2)
            if (remaining.isNotEmpty()) {
                Box(GlanceModifier.height(8.dp)) {}
                Text(
                    "오늘 남은 일정",
                    style = TextStyle(
                        color = color(0xFF6B7280),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                remaining.take(remainingCapacity).forEach { CompactLesson(it) }
                val hidden = remaining.size - remainingCapacity
                if (hidden > 0) {
                    Text(
                        "외 ${hidden}개",
                        modifier = GlanceModifier.fillMaxWidth(),
                        style = TextStyle(
                            color = color(0xFF6B7280),
                            fontSize = 11.sp,
                            textAlign = TextAlign.End,
                        ),
                    )
                }
            }
        }
    }

    @Composable
    private fun Header(count: Int) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    todayLabel(),
                    style = TextStyle(
                        color = color(0xFF312E81),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Text(
                    "오늘 레슨",
                    style = TextStyle(color = color(0xFF6B7280), fontSize = 11.sp),
                )
            }
            Text(
                "남은 레슨 ${count}개",
                style = TextStyle(
                    color = color(0xFF4F46E5),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
    }

    @Composable
    private fun FeaturedLesson(label: String, lesson: RollupLesson) {
        Column(
            modifier = GlanceModifier.fillMaxWidth()
                .background(color(0xFFF5F3FF))
                .padding(horizontal = 9.dp, vertical = 7.dp),
        ) {
            Text(
                if (lesson.ongoing) "진행 중" else label,
                style = TextStyle(
                    color = color(if (lesson.ongoing) 0xFFDC2626 else 0xFF6D28D9),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    lesson.time,
                    modifier = GlanceModifier.width(50.dp),
                    style = TextStyle(
                        color = color(0xFF111827),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Text(
                    lesson.title,
                    modifier = GlanceModifier.defaultWeight(),
                    maxLines = 1,
                    style = TextStyle(color = color(0xFF312E81), fontSize = 13.sp),
                )
                if (lesson.remainingSessions != null) {
                    Text(
                        "${lesson.remainingSessions}회 남음",
                        style = TextStyle(color = color(0xFF6B7280), fontSize = 10.sp),
                    )
                }
            }
        }
    }

    @Composable
    private fun CompactLesson(lesson: RollupLesson) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                lesson.time,
                modifier = GlanceModifier.width(48.dp),
                style = TextStyle(
                    color = color(0xFF374151),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                lesson.title,
                modifier = GlanceModifier.defaultWeight(),
                maxLines = 1,
                style = TextStyle(color = color(0xFF4B5563), fontSize = 11.sp),
            )
        }
    }

    @Composable
    private fun EmptyState() {
        Box(
            modifier = GlanceModifier.fillMaxWidth().height(78.dp)
                .background(color(0xFFF9FAFB)).padding(10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "오늘 남은 레슨이 없어요.",
                style = TextStyle(
                    color = color(0xFF6B7280),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                ),
            )
        }
    }

    private fun parseVisibleLessons(encoded: String, currentOwnerUid: String): List<RollupLesson> {
        if (currentOwnerUid.isBlank()) return emptyList()
        val now = System.currentTimeMillis()
        val today = dateKey(now)
        val formatter = SimpleDateFormat("HH:mm", Locale.KOREAN)
        return try {
            val root = JSONObject(encoded)
            if (root.optString("ownerUid") != currentOwnerUid ||
                root.optString("workspaceType") != "personal" ||
                root.optString("generatedDate") != today
            ) return emptyList()
            val array = root.optJSONArray("items") ?: return emptyList()
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val start = item.optLong("startAtMillis", -1L)
                    val end = item.optLong("endAtMillis", -1L)
                    val status = item.optString("status").lowercase(Locale.ROOT)
                    if (dateKey(start) != today || end <= now || end <= start ||
                        status in EXCLUDED_STATUSES
                    ) continue
                    val name = item.optString("memberName").trim()
                    val type = item.optString("lessonType").trim()
                    val title = listOf(name, type).filter { it.isNotEmpty() }
                        .joinToString(" · ").ifEmpty { "미등록 일정" }
                    add(
                        RollupLesson(
                            startAtMillis = start,
                            time = formatter.format(Date(start)),
                            title = title,
                            remainingSessions = if (item.has("remainingSessions"))
                                item.optInt("remainingSessions") else null,
                            ongoing = start <= now && now < end,
                        ),
                    )
                }
            }.sortedWith(compareByDescending<RollupLesson> { it.ongoing }
                .thenBy { it.startAtMillis })
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun todayLabel() = SimpleDateFormat("M월 d일 EEEE", Locale.KOREAN).format(Date())
    private fun dateKey(millis: Long) = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(Date(millis))
    private fun color(hex: Long) = ColorProvider(Color(hex), Color(hex))

    companion object {
        private const val KEY_ROLLUP = "mtf_widget_today_rollup_items_v1"
        private const val KEY_OWNER_UID = "mtf_widget_personal_owner_uid"
        private val EXCLUDED_STATUSES = setOf("deleted", "archived", "voided", "tombstone")
    }
}

private data class RollupLesson(
    val startAtMillis: Long,
    val time: String,
    val title: String,
    val remainingSessions: Int?,
    val ongoing: Boolean,
)
