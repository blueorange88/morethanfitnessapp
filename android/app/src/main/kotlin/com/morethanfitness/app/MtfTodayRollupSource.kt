package com.morethanfitness.app

import android.content.Context
import android.content.SharedPreferences
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import org.json.JSONObject

/**
 * 앱이 위젯 저장소에 넣어 둔 '오늘 레슨' 데이터를 읽고 검증한다.
 * 오늘 레슨 위젯과 지금·다음 위젯이 같은 규칙(소유자·환경·프로젝트·시간대·날짜 일치)을 쓰도록 한곳에 둔다.
 * 끝난 레슨도 함께 돌려주고, 끝남/진행 중 판단은 [RollupLesson]의 시각으로 각 위젯이 한다.
 */
internal object MtfTodayRollupSource {
    /** home_widget 플러그인이 위젯 데이터를 저장하는 SharedPreferences 이름. */
    const val HOME_WIDGET_PREFERENCES = "HomeWidgetPreferences"

    fun load(
        context: Context,
        prefs: SharedPreferences,
        nowMillis: Long = System.currentTimeMillis(),
    ): RollupRenderResult {
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
        return parse(
            encoded = encoded,
            currentOwnerUid = ownerUid,
            environment = environment,
            expectedEnvironment = expectedEnvironment,
            projectId = projectId,
            expectedProjectId = expectedProjectId,
            workspaceType = workspaceType,
            localDate = localDate,
            nowMillis = nowMillis,
        ).copy(
            ownerPresent = ownerUid.isNotBlank(),
            payloadPresent = encoded.isNotBlank() && encoded != "{}",
        )
    }

    fun parse(
        encoded: String,
        currentOwnerUid: String,
        environment: String,
        expectedEnvironment: String,
        projectId: String,
        expectedProjectId: String,
        workspaceType: String,
        localDate: String,
        nowMillis: Long,
    ): RollupRenderResult {
        if (currentOwnerUid.isBlank()) {
            return RollupRenderResult(result = "missing_owner")
        }
        val now = nowMillis
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
                    if (status in EXCLUDED_STATUSES) continue
                    val name = item.optString(nameKey).trim().ifEmpty { "미등록 일정" }
                    val type = item.optString("lessonType").trim()
                    add(
                        RollupLesson(
                            startAtMillis = start,
                            endAtMillis = end,
                            time = formatter.format(Instant.ofEpochMilli(start).atZone(SEOUL_ZONE)),
                            name = name,
                            type = type,
                            done = end <= now,
                            ongoing = start <= now && now < end,
                        ),
                    )
                }
            }.sortedBy { it.startAtMillis }
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

    private fun dateKey(millis: Long) = DATE_KEY_FORMATTER
        .format(Instant.ofEpochMilli(millis).atZone(SEOUL_ZONE))

    private fun normalizedStatus(value: String) = value.trim().lowercase(Locale.ROOT)
        .replace('_', '-').replace(' ', '-')

    private const val KEY_ROLLUP = "mtf_widget_today_rollup_items_v1"
    private const val KEY_OWNER_UID = "mtf_widget_personal_owner_uid"
    private const val KEY_ENVIRONMENT = "mtf_widget_personal_environment"
    private const val KEY_PROJECT_ID = "mtf_widget_personal_project_id"
    private const val KEY_WORKSPACE_TYPE = "mtf_widget_personal_workspace_type"
    private const val KEY_LOCAL_DATE = "mtf_widget_today_rollup_local_date"
    private const val TIMEZONE_SEOUL = "Asia/Seoul"
    private val SEOUL_ZONE = ZoneId.of(TIMEZONE_SEOUL)
    private val DATE_KEY_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.ROOT)
    private val EXCLUDED_STATUSES = setOf(
        "deleted", "archived", "voided", "tombstone", "pending-delete",
        "pendingdelete", "rollback", "failed", "temp", "example",
    )
}

internal data class RollupRenderResult(
    val lessons: List<RollupLesson> = emptyList(),
    val ownerMatched: Boolean = false,
    val ownerPresent: Boolean = false,
    val payloadPresent: Boolean = false,
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

internal data class RollupLesson(
    val startAtMillis: Long,
    val endAtMillis: Long,
    val time: String,
    val name: String,
    val type: String,
    val done: Boolean,
    val ongoing: Boolean,
)
