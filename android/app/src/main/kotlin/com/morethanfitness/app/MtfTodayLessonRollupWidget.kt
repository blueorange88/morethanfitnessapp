package com.morethanfitness.app

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.AppWidgetId
import androidx.glance.appwidget.cornerRadius
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
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextDecoration
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

class MtfTodayLessonRollupWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact
    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = (id as? AppWidgetId)?.appWidgetId ?: 0
        provideContent { Content(context, currentState(), appWidgetId) }
    }

    @Composable
    private fun Content(
        context: Context,
        state: HomeWidgetGlanceState,
        appWidgetId: Int,
    ) {
        val prefs = state.preferences
        val renderResult = MtfTodayRollupSource.load(context, prefs)
        val lessons = renderResult.lessons
        val palette = readPalette(prefs)
        val size = LocalSize.current
        val isDevWidget = MtfWidgetIntentFactory.isDevWidget(context)
        val showType = size.width.value >= WIDE_WIDTH_DP
        val reservedHeight = HEADER_RESERVED_DP + CONTENT_PADDING_DP * 2 +
            NOW_LINE_HEIGHT_DP * 2 + (if (isDevWidget) DEV_BANNER_RESERVED_DP else 0f)
        val capacity = maxOf(
            MIN_ROWS,
            ((size.height.value - reservedHeight) / ROW_HEIGHT_DP).toInt(),
        )
        val window = pickWindow(lessons, capacity)
        val doneCount = lessons.count { it.done }
        val openCount = lessons.size - doneCount
        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.d(
                TAG_PARSE,
                "appWidgetId=$appWidgetId payloadRevision=${renderResult.payloadRevision} " +
                    "schemaVersion=${renderResult.schemaVersion} rawItemCount=${renderResult.payloadCount} " +
                    "validDateCount=${renderResult.validDateCount} " +
                    "validTimeCount=${renderResult.validTimeCount} " +
                    "todayCount=${renderResult.parsedItemCount} " +
                    "invalidDateCount=${renderResult.invalidDateCount} " +
                    "invalidTimeCount=${renderResult.invalidTimeCount} " +
                    "localDateMatched=${renderResult.localDateMatched} " +
                    "ownerMatched=${renderResult.ownerMatched} result=${renderResult.result}",
            )
            Log.d(
                TAG_TAP,
                "appWidgetIdPresent=${appWidgetId > 0} pendingIntentType=activity " +
                    "explicitComponent=true requestCode=glanceViewId uniqueData=true " +
                    "actionPresent=true dataPresent=true",
            )
            Log.d(
                TAG_RENDER,
                "appWidgetId=$appWidgetId payloadRevision=${renderResult.payloadRevision} " +
                    "ownerPresent=${renderResult.ownerPresent} ownerMatched=${renderResult.ownerMatched} " +
                    "payloadPresent=${renderResult.payloadPresent} " +
                    "payloadCount=${renderResult.payloadCount} todayCount=${lessons.size} " +
                    "done=$doneCount open=$openCount capacity=$capacity " +
                    "windowStart=${window.start} windowEnd=${window.end} " +
                    "hiddenAfter=${window.hiddenAfter} " +
                    "renderState=${if (lessons.isEmpty()) "empty" else "ready"}",
            )
        }
        val openAppIntent = MtfWidgetIntentFactory.openToday(context, appWidgetId)

        Column(
            modifier = GlanceModifier.fillMaxSize()
                .background(color(palette.background))
                .clickable(actionStartActivity(openAppIntent))
                .padding(CONTENT_PADDING_DP.dp),
        ) {
            if (isDevWidget) {
                DevBanner(context)
                Box(GlanceModifier.height(6.dp)) {}
            }
            Header(
                palette = palette,
                showCounts = lessons.isNotEmpty(),
                doneCount = doneCount,
                openCount = openCount,
            )
            Box(GlanceModifier.height(6.dp)) {}
            if (lessons.isEmpty()) {
                EmptyState(palette)
                return@Column
            }
            // Glance는 한 컨테이너에 자식을 10개까지만 허용하므로 줄을 묶음(Column)으로 나눠 담는다.
            buildEntries(lessons, window).chunked(MAX_CHILDREN_PER_COLUMN).forEach { chunk ->
                Column(modifier = GlanceModifier.fillMaxWidth()) {
                    chunk.forEach { entry ->
                        when (entry) {
                            is ListEntry.Lesson -> LessonRow(palette, entry.lesson, showType)
                            is ListEntry.NowLine -> NowLine(palette, entry.label)
                            is ListEntry.More -> MoreLabel(palette, entry.count)
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun MoreLabel(palette: RollupPalette, count: Int) {
        Text(
            "+${count}개 더",
            modifier = GlanceModifier.fillMaxWidth().padding(start = 18.dp),
            style = TextStyle(color = color(palette.muted), fontSize = 11.sp),
        )
    }

    @Composable
    private fun DevBanner(context: Context) {
        Text(
            context.getString(R.string.mtf_widget_dev_banner),
            modifier = GlanceModifier.fillMaxWidth()
                .background(color(0xFF6D28D9))
                .padding(horizontal = 8.dp, vertical = 5.dp),
            style = TextStyle(
                color = color(0xFFFFFFFF),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            ),
        )
    }

    @Composable
    private fun Header(
        palette: RollupPalette,
        showCounts: Boolean,
        doneCount: Int,
        openCount: Int,
    ) {
        Column(modifier = GlanceModifier.fillMaxWidth()) {
            Text(
                todayLabel(),
                maxLines = 1,
                style = TextStyle(
                    color = color(palette.title),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            if (showCounts) {
                Text(
                    "완료 $doneCount · 남음 $openCount",
                    maxLines = 1,
                    style = TextStyle(color = color(palette.muted), fontSize = 11.sp),
                )
            }
        }
    }

    @Composable
    private fun LessonRow(palette: RollupPalette, lesson: RollupLesson, showType: Boolean) {
        // 끝남=흐리게, 진행 중=강조색, 예정=본문색. 색은 앱의 위젯 테마(라이트·다크 등)를 따른다.
        val dotColor = when {
            lesson.done -> palette.muted
            lesson.ongoing -> palette.accent
            else -> palette.text
        }
        val timeColor = when {
            lesson.done -> palette.muted
            lesson.ongoing -> palette.accent
            else -> palette.text
        }
        val nameColor = timeColor
        val label = if (showType && lesson.type.isNotEmpty()) {
            "${lesson.name} · ${lesson.type}"
        } else {
            lesson.name
        }
        val rowModifier = GlanceModifier.fillMaxWidth().height(ROW_HEIGHT_DP.dp).let {
            if (lesson.ongoing) {
                it.background(color(withAlpha(palette.accent, 0.16f))).cornerRadius(6.dp)
            } else {
                it
            }
        }
        Row(
            modifier = rowModifier,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(GlanceModifier.width(4.dp)) {}
            Box(
                modifier = GlanceModifier.size(8.dp)
                    .background(color(dotColor))
                    .cornerRadius(4.dp),
            ) {}
            Box(GlanceModifier.width(6.dp)) {}
            Text(
                lesson.time,
                modifier = GlanceModifier.width(40.dp),
                maxLines = 1,
                style = TextStyle(
                    color = color(timeColor),
                    fontSize = 12.sp,
                    fontWeight = if (lesson.done) FontWeight.Normal else FontWeight.Bold,
                    textDecoration = if (lesson.done) TextDecoration.LineThrough else null,
                ),
            )
            Text(
                label,
                modifier = GlanceModifier.defaultWeight(),
                maxLines = 1,
                style = TextStyle(
                    color = color(nameColor),
                    fontSize = 12.sp,
                    fontWeight = if (lesson.ongoing) FontWeight.Bold else FontWeight.Normal,
                ),
            )
        }
    }

    @Composable
    private fun NowLine(palette: RollupPalette, label: String) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().height(NOW_LINE_HEIGHT_DP.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(GlanceModifier.width(8.dp).height(1.dp).background(color(palette.accent))) {}
            if (label.isNotEmpty()) {
                Text(
                    " $label ",
                    maxLines = 1,
                    style = TextStyle(
                        color = color(palette.accent),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
            Box(
                GlanceModifier.defaultWeight().height(1.dp).background(color(palette.accent)),
            ) {}
        }
    }

    @Composable
    private fun EmptyState(palette: RollupPalette) {
        Box(
            modifier = GlanceModifier.fillMaxWidth().height(78.dp)
                .background(color(palette.panel)).padding(10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "오늘 레슨이 없어요.",
                style = TextStyle(
                    color = color(palette.muted),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                ),
            )
        }
    }

    /** 화면에 그릴 줄(레슨·'지금' 선·'+N개 더')을 순서대로 만든다. */
    private fun buildEntries(lessons: List<RollupLesson>, window: LessonWindow): List<ListEntry> {
        val firstOpenIndex = lessons.indexOfFirst { !it.done }
        val anyOngoing = lessons.any { it.ongoing }
        return buildList {
            for (index in window.start until window.end) {
                val lesson = lessons[index]
                val startsOngoingRun =
                    lesson.ongoing && (index == window.start || !lessons[index - 1].ongoing)
                when {
                    // 진행 중인 레슨(들)은 '지금' 선으로 열고
                    startsOngoingRun -> add(ListEntry.NowLine("지금"))
                    // 진행 중인 레슨이 없을 때는 다음 레슨 위에 '다음' 선 하나만 긋는다.
                    !anyOngoing && index == firstOpenIndex -> add(ListEntry.NowLine("다음"))
                }
                add(ListEntry.Lesson(lesson))
                val endsOngoingRun =
                    lesson.ongoing && (index + 1 >= lessons.size || !lessons[index + 1].ongoing)
                if (endsOngoingRun) {
                    // 닫는 선은 이어지는 레슨이 있으면 '다음' 이름표, 마지막 레슨이면 이름표 없는 선.
                    add(ListEntry.NowLine(if (index + 1 < lessons.size) "다음" else ""))
                }
            }
            if (firstOpenIndex < 0 && window.end == lessons.size) {
                add(ListEntry.NowLine("오늘 레슨 끝"))
            }
            if (window.hiddenAfter > 0) add(ListEntry.More(window.hiddenAfter))
        }
    }

    /**
     * 화면에 들어가는 줄 수([capacity])만큼 레슨 구간을 고른다. 끝난 레슨 하나 뒤부터 보이도록
     * 현재(진행 중·다음) 레슨 주변을 잡고, 아래가 잘리면 마지막 줄을 '+N개 더'에 비워 둔다.
     */
    private fun pickWindow(lessons: List<RollupLesson>, capacity: Int): LessonWindow {
        if (lessons.isEmpty()) return LessonWindow(0, 0, 0)
        val firstOpen = lessons.indexOfFirst { !it.done }.let { if (it < 0) lessons.size else it }
        val start = maxOf(0, minOf(firstOpen - 1, lessons.size - capacity))
        var end = minOf(lessons.size, start + capacity)
        if (end < lessons.size) end -= 1
        return LessonWindow(start, end, lessons.size - end)
    }

    /** 앱의 위젯 테마(주간 위젯과 같은 저장값)에서 색을 읽는다. 값이 없으면 라이트 기본색. */
    private fun readPalette(prefs: SharedPreferences): RollupPalette {
        fun themed(key: String, fallback: Long): Long {
            val raw = prefs.getString(key, null)?.trim()?.removePrefix("#")?.removePrefix("0x")
                ?: return fallback
            val parsed = raw.toLongOrNull(16) ?: return fallback
            return when (raw.length) {
                6 -> 0xFF000000L or parsed
                8 -> parsed
                else -> fallback
            }
        }
        val text = themed("mtf_widget_time_text", 0xFF334155L)
        return RollupPalette(
            background = themed("mtf_widget_body_bg", 0xFFFFFFFFL),
            panel = themed("mtf_widget_row_even", 0xFFEFF6FFL),
            title = themed("mtf_widget_day_text", 0xFF111827L),
            text = text,
            muted = withAlpha(text, 0.55f),
            accent = themed("mtf_widget_today_border", 0xFFE11D48L),
        )
    }

    private fun withAlpha(argb: Long, factor: Float): Long {
        val alpha = (((argb ushr 24) and 0xFF) * factor).toInt().coerceIn(0, 255)
        return (alpha.toLong() shl 24) or (argb and 0x00FFFFFFL)
    }

    private fun todayLabel() = DateTimeFormatter.ofPattern("M월 d일 E", Locale.KOREAN)
        .format(Instant.now().atZone(SEOUL_ZONE))
    private fun color(hex: Long) = ColorProvider(Color(hex), Color(hex))

    companion object {
        private const val ROW_HEIGHT_DP = 22f
        private const val NOW_LINE_HEIGHT_DP = 14f
        private const val HEADER_RESERVED_DP = 40f
        private const val CONTENT_PADDING_DP = 10f
        private const val DEV_BANNER_RESERVED_DP = 31f
        private const val MIN_ROWS = 2

        /** Glance 컨테이너 하나가 가질 수 있는 자식 수(10) 아래로 묶는다. */
        private const val MAX_CHILDREN_PER_COLUMN = 8
        private const val WIDE_WIDTH_DP = 200f
        private const val TAG_RENDER = "MTF_DAILY_WIDGET_RENDER"
        private const val TAG_PARSE = "MTF_DAILY_WIDGET_PARSE"
        private const val TAG_TAP = "MTF_DAILY_WIDGET_TAP"
        private val SEOUL_ZONE = ZoneId.of("Asia/Seoul")
    }
}

private data class RollupPalette(
    val background: Long,
    val panel: Long,
    val title: Long,
    val text: Long,
    val muted: Long,
    val accent: Long,
)

private data class LessonWindow(val start: Int, val end: Int, val hiddenAfter: Int)

private sealed interface ListEntry {
    data class Lesson(val lesson: RollupLesson) : ListEntry
    data class NowLine(val label: String) : ListEntry
    data class More(val count: Int) : ListEntry
}
