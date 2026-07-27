package com.example.mtf_app

import android.content.Context
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
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import org.json.JSONObject

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
        val ownerUid = prefs.getString(KEY_OWNER_UID, "") ?: ""
        val encoded = prefs.getString(KEY_ROLLUP, "{}") ?: "{}"
        val environment = prefs.getString(KEY_ENVIRONMENT, "") ?: ""
        val projectId = prefs.getString(KEY_PROJECT_ID, "") ?: ""
        val workspaceType = prefs.getString(KEY_WORKSPACE_TYPE, "") ?: ""
        val localDate = prefs.getString(KEY_LOCAL_DATE, "") ?: ""
        val expectedEnvironment = if (context.packageName.endsWith(".dev")) "dev" else "prod"
        val projectResourceId = context.resources.getIdentifier(
            "project_id",
            "string",
            context.packageName,
        )
        val expectedProjectId = if (projectResourceId == 0) "" else
            context.getString(projectResourceId)
        val renderResult = parseVisibleLessons(
            encoded = encoded,
            currentOwnerUid = ownerUid,
            environment = environment,
            expectedEnvironment = expectedEnvironment,
            projectId = projectId,
            expectedProjectId = expectedProjectId,
            workspaceType = workspaceType,
            localDate = localDate,
        )
        val lessons = renderResult.lessons
        val sizeRemainingCapacity = when {
            LocalSize.current.height.value >= 310f -> 4
            LocalSize.current.height.value >= 270f -> 3
            else -> 2
        }
        val remainingCapacity = if (lessons.size in 3..6) {
            minOf(sizeRemainingCapacity, 3)
        } else {
            sizeRemainingCapacity
        }
        val topCardCount = minOf(lessons.size, TOP_CARD_LIMIT)
        val remaining = lessons.drop(topCardCount)
        val visibleRemainingCount = minOf(remaining.size, remainingCapacity)
        val hiddenCount = maxOf(0, remaining.size - visibleRemainingCount)
        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.d(
                TAG_PARSE,
                "appWidgetId=$appWidgetId payloadRevision=${renderResult.payloadRevision} " +
                    "schemaVersion=${renderResult.schemaVersion} rawItemCount=${renderResult.payloadCount} " +
                    "validDateCount=${renderResult.validDateCount} " +
                    "validTimeCount=${renderResult.validTimeCount} " +
                    "upcomingCount=${renderResult.parsedItemCount} " +
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
                    "ownerPresent=${ownerUid.isNotBlank()} ownerMatched=${renderResult.ownerMatched} " +
                    "payloadPresent=${encoded.isNotBlank() && encoded != "{}"} " +
                    "payloadCount=${renderResult.payloadCount} upcomingCount=${lessons.size} " +
                    "topCardCount=$topCardCount " +
                    "visibleRemainingCount=$visibleRemainingCount hiddenCount=$hiddenCount " +
                    "hiddenLabelVisible=${hiddenCount > 0} " +
                    "renderState=${if (lessons.isEmpty()) "empty" else "ready"}",
            )
        }
        val openAppIntent = MtfWidgetIntentFactory.openToday(context, appWidgetId)

        val isDevWidget = MtfWidgetIntentFactory.isDevWidget(context)
        Column(
            modifier = GlanceModifier.fillMaxSize()
                .background(color(if (isDevWidget) 0xFFFAF5FF else 0xFFFFFFFF))
                .clickable(actionStartActivity(openAppIntent))
                .padding(12.dp),
        ) {
            if (isDevWidget) {
                DevBanner(context)
                Box(GlanceModifier.height(6.dp)) {}
            }
            Header(context, lessons.size)
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
            if (remaining.isNotEmpty()) {
                Box(GlanceModifier.height(8.dp)) {}
                Row(modifier = GlanceModifier.fillMaxWidth()) {
                    Text(
                        "오늘 남은 일정",
                        modifier = GlanceModifier.defaultWeight(),
                        style = TextStyle(
                            color = color(0xFF6B7280),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    if (hiddenCount > 0) {
                        Text(
                            "외 ${hiddenCount}개",
                            style = TextStyle(
                                color = color(0xFF6B7280),
                                fontSize = 11.sp,
                                textAlign = TextAlign.End,
                            ),
                        )
                    }
                }
                Column(modifier = GlanceModifier.fillMaxWidth()) {
                    remaining.take(visibleRemainingCount).forEach { CompactLesson(it) }
                }
            }
        }
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
    private fun Header(context: Context, count: Int) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text(
                    MtfWidgetIntentFactory.displayTitle(context, todayLabel()),
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

    private fun parseVisibleLessons(
        encoded: String,
        currentOwnerUid: String,
        environment: String,
        expectedEnvironment: String,
        projectId: String,
        expectedProjectId: String,
        workspaceType: String,
        localDate: String,
    ): RollupRenderResult {
        if (currentOwnerUid.isBlank()) {
            return RollupRenderResult(result = "missing_owner")
        }
        val now = System.currentTimeMillis()
        val today = dateKey(now)
        val formatter = DateTimeFormatter.ofPattern("HH:mm", Locale.KOREAN)
        return try {
            val root = JSONObject(encoded)
            val schemaVersion = root.optInt("schemaVersion", 1)
            val payloadRevision = root.optLong("payloadRevision", 0L)
            if (schemaVersion !in 1..2) {
                return RollupRenderResult(
                    payloadRevision = payloadRevision,
                    schemaVersion = schemaVersion,
                    result = "invalid_schema",
                )
            }
            val ownerMatched = root.optString("ownerUid") == currentOwnerUid
            val array = root.optJSONArray("items")
            val payloadCount = array?.length() ?: 0
            if (!ownerMatched) {
                return RollupRenderResult(
                    payloadCount = payloadCount,
                    payloadRevision = payloadRevision,
                    schemaVersion = schemaVersion,
                    result = "owner_mismatch",
                )
            }
            val payloadLocalDate = if (schemaVersion >= 2) {
                root.optString("localDate")
            } else {
                root.optString("generatedDate")
            }
            val identityMatches = root.optString("workspaceType") == "personal" &&
                workspaceType == "personal" &&
                root.optString("environment") == environment &&
                environment == expectedEnvironment &&
                root.optString("projectId") == projectId &&
                projectId.isNotBlank() &&
                projectId == expectedProjectId &&
                (schemaVersion < 2 || root.optString("timezone") == TIMEZONE_SEOUL) &&
                payloadLocalDate == today &&
                localDate == today
            if (!identityMatches) {
                return RollupRenderResult(
                    ownerMatched = true,
                    payloadCount = payloadCount,
                    payloadRevision = payloadRevision,
                    schemaVersion = schemaVersion,
                    localDateMatched = payloadLocalDate == today && localDate == today,
                    result = "stale",
                )
            }
            if (array == null) {
                return RollupRenderResult(
                    ownerMatched = true,
                    payloadRevision = payloadRevision,
                    schemaVersion = schemaVersion,
                    localDateMatched = true,
                    result = "invalid_payload",
                )
            }
            var validDateCount = 0
            var validTimeCount = 0
            var invalidDateCount = 0
            var invalidTimeCount = 0
            val lessons = buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val startKey = if (schemaVersion >= 2) "startAtEpochMs" else "startAtMillis"
                    val endKey = if (schemaVersion >= 2) "endAtEpochMs" else "endAtMillis"
                    val nameKey = if (schemaVersion >= 2) "displayName" else "memberName"
                    val start = item.optLong(startKey, -1L)
                    val end = item.optLong(endKey, -1L)
                    val status = normalizedStatus(item.optString("status"))
                    if (start < 0L || end <= start) {
                        invalidTimeCount++
                        continue
                    }
                    if (dateKey(start) != today) {
                        invalidDateCount++
                        continue
                    }
                    validDateCount++
                    validTimeCount++
                    if (end <= now || status in EXCLUDED_STATUSES) continue
                    val name = item.optString(nameKey).trim()
                    val type = item.optString("lessonType").trim()
                    val title = listOf(name, type).filter { it.isNotEmpty() }
                        .joinToString(" · ").ifEmpty { "미등록 일정" }
                    add(
                        RollupLesson(
                            startAtMillis = start,
                            time = formatter.format(Instant.ofEpochMilli(start).atZone(SEOUL_ZONE)),
                            title = title,
                            remainingSessions = if (item.has("remainingSessions"))
                                item.optInt("remainingSessions") else null,
                            ongoing = start <= now && now < end,
                        ),
                    )
                }
            }.sortedWith(
                compareByDescending<RollupLesson> { it.ongoing }
                    .thenBy { it.startAtMillis },
            )
            RollupRenderResult(
                lessons = lessons,
                ownerMatched = true,
                payloadCount = payloadCount,
                parsedItemCount = lessons.size,
                validDateCount = validDateCount,
                validTimeCount = validTimeCount,
                invalidDateCount = invalidDateCount,
                invalidTimeCount = invalidTimeCount,
                payloadRevision = payloadRevision,
                schemaVersion = schemaVersion,
                localDateMatched = true,
                result = if (lessons.isEmpty()) "empty" else "ready",
            )
        } catch (_: Exception) {
            RollupRenderResult(result = "invalid_payload")
        }
    }

    private fun todayLabel() = DateTimeFormatter.ofPattern("M월 d일 EEEE", Locale.KOREAN)
        .format(Instant.now().atZone(SEOUL_ZONE))
    private fun dateKey(millis: Long) = DATE_KEY_FORMATTER
        .format(Instant.ofEpochMilli(millis).atZone(SEOUL_ZONE))
    private fun normalizedStatus(value: String) = value.trim().lowercase(Locale.ROOT)
        .replace('_', '-').replace(' ', '-')
    private fun color(hex: Long) = ColorProvider(Color(hex), Color(hex))

    companion object {
        private const val TOP_CARD_LIMIT = 2
        private const val KEY_ROLLUP = "mtf_widget_today_rollup_items_v1"
        private const val KEY_OWNER_UID = "mtf_widget_personal_owner_uid"
        private const val KEY_ENVIRONMENT = "mtf_widget_personal_environment"
        private const val KEY_PROJECT_ID = "mtf_widget_personal_project_id"
        private const val KEY_WORKSPACE_TYPE = "mtf_widget_personal_workspace_type"
        private const val KEY_LOCAL_DATE = "mtf_widget_today_rollup_local_date"
        private const val TAG_RENDER = "MTF_DAILY_WIDGET_RENDER"
        private const val TAG_PARSE = "MTF_DAILY_WIDGET_PARSE"
        private const val TAG_TAP = "MTF_DAILY_WIDGET_TAP"
        private const val TIMEZONE_SEOUL = "Asia/Seoul"
        private val SEOUL_ZONE = ZoneId.of(TIMEZONE_SEOUL)
        private val DATE_KEY_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.ROOT)
        private val EXCLUDED_STATUSES = setOf(
            "deleted", "archived", "voided", "tombstone", "pending-delete",
            "pendingdelete", "rollback", "failed", "temp", "example",
        )
    }
}

private data class RollupRenderResult(
    val lessons: List<RollupLesson> = emptyList(),
    val ownerMatched: Boolean = false,
    val payloadCount: Int = 0,
    val parsedItemCount: Int = 0,
    val validDateCount: Int = 0,
    val validTimeCount: Int = 0,
    val invalidDateCount: Int = 0,
    val invalidTimeCount: Int = 0,
    val payloadRevision: Long = 0L,
    val schemaVersion: Int = 1,
    val localDateMatched: Boolean = false,
    val result: String,
)

private data class RollupLesson(
    val startAtMillis: Long,
    val time: String,
    val title: String,
    val remainingSessions: Int?,
    val ongoing: Boolean,
)
