package com.morethanfitness.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.ZoneId

/**
 * 지금·다음 위젯: 손 계수기(탤리 카운터)처럼 전 / 지금 / 다음 세 줄을 칸마다 보여 준다.
 *
 * - 시각 숫자 4칸과 이름 글자 칸(5자 + '…')이 한 줄. 바뀐 칸만 그 칸 안에서 위로 굴러 올라간다.
 * - 위쪽 줄을 탭하면 이전 레슨, 아래쪽 줄을 탭하면 이후 레슨으로 훑어보고 6초 뒤 지금으로 돌아온다.
 *   가운데 줄을 탭하면 앱의 오늘 일정이 열린다.
 * - 칸 크기와 글자 크기는 실제 위젯 크기와 이름 길이에서 계산한다(API 31 이상, 그보다 낮으면 기본 크기).
 * - 색은 앱의 위젯 테마(mtf_widget_theme_mode)를 따른다.
 *
 * 굴러가는 방식: 칸마다 ViewFlipper의 글자 A/B 중 '들어오는 쪽'의 글자만 바꾸고 그쪽으로 전환한다.
 * 나가는 쪽은 건드리지 않아 사라지는 동안 글자가 바뀌어 보이지 않는다. 부분 갱신(showNext)은
 * 삼성 런처에서 화면이 바뀌지 않아 매번 전체 갱신(setDisplayedChild)으로 보낸다.
 */
class MtfNowNextWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, appWidgetManager, appWidgetIds, 0)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        // 위젯 크기가 바뀌면 칸 크기를 다시 계산한다(훑어보던 위치는 유지).
        render(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            statePrefs(context).getInt(KEY_PEEK, 0),
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PEEK_UP -> peek(context, -1)
            ACTION_PEEK_DOWN -> peek(context, 1)
            ACTION_PEEK_RESET -> {
                if (intent.getLongExtra(EXTRA_TOKEN, -1L) ==
                    statePrefs(context).getLong(KEY_TOKEN, 0L)
                ) {
                    refresh(context, 0)
                }
            }
            ACTION_TICK,
            ACTION_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> refresh(context, 0)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(tickIntent(context))
        alarmManager.cancel(resetIntent(context, 0L))
        statePrefs(context).edit().clear().apply()
    }

    private fun peek(context: Context, delta: Int) {
        val prefs = statePrefs(context)
        refresh(context, prefs.getInt(KEY_PEEK, 0) + delta)
        // 훑어보는 중이면 마지막 탭 6초 뒤에 지금으로 돌아온다. 탭할 때마다 처음부터 다시 센다.
        val token = prefs.getLong(KEY_TOKEN, 0L) + 1
        prefs.edit().putLong(KEY_TOKEN, token).apply()
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (prefs.getInt(KEY_PEEK, 0) != 0) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + PEEK_RETURN_MILLIS,
                resetIntent(context, token),
            )
        } else {
            alarmManager.cancel(resetIntent(context, token))
        }
    }

    private fun refresh(context: Context, requestedPeek: Int) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, MtfNowNextWidget::class.java))
        if (ids.isEmpty()) return
        render(context, manager, ids, requestedPeek)
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        requestedPeek: Int,
    ) {
        val now = System.currentTimeMillis()
        val prefs = statePrefs(context)
        val homePrefs = context.getSharedPreferences(
            MtfTodayRollupSource.HOME_WIDGET_PREFERENCES,
            Context.MODE_PRIVATE,
        )
        val loaded = MtfTodayRollupSource.load(context, homePrefs, now)
        val lessons = loaded.lessons.map {
            DrumLesson(it.startAtMillis, it.endAtMillis, it.time, it.name)
        }
        val ready = loaded.result == "ready" || loaded.result == "empty"
        val view = if (ready) {
            NowNextDrum.compute(lessons, now, requestedPeek)
        } else {
            DrumView(null, DrumLine("", "", NOT_READY_LABEL), null, 0, false, false)
        }
        val theme = NowNextThemes.forMode(homePrefs.getString(KEY_THEME_MODE, null))

        // 칸마다 이전 글자와 비교해 바뀐 칸만 굴린다. 이전 상태가 없으면(처음) 굴리지 않는다.
        val cells = cellTexts(view)
        val prevCells = decode(prefs.getString(KEY_CELLS, null))
        val prevChildren = prefs.getString(KEY_CHILDREN, null)?.takeIf { it.length == CELL_COUNT }
        val hadState = prevCells != null && prevChildren != null
        val children = IntArray(CELL_COUNT)
        var rolledCells = 0
        for (i in 0 until CELL_COUNT) {
            val previousChild = if (hadState) prevChildren!![i] - '0' else 0
            val previous = if (hadState) prevCells!![i] else ""
            val roll = hadState && previous.isNotEmpty() && cells[i].isNotEmpty() &&
                previous != cells[i]
            children[i] = if (roll) 1 - previousChild else previousChild
            if (roll) rolledCells++
        }
        prefs.edit()
            .putString(KEY_CELLS, cells.joinToString(SEP))
            .putString(KEY_CHILDREN, children.joinToString("") { it.toString() })
            .putInt(KEY_PEEK, view.peek)
            .apply()

        ids.forEach { id ->
            manager.updateAppWidget(
                id,
                buildViews(context, id, view, cells, children, theme, metricsFor(manager, id)),
            )
        }
        scheduleTick(context, lessons, now)

        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.d(
                TAG,
                "result=${loaded.result} lessons=${lessons.size} peek=${view.peek} " +
                    "rolledCells=$rolledCells theme=${homePrefs.getString(KEY_THEME_MODE, null)} " +
                    "rows=${view.fullSignature}",
            )
        }
    }

    private fun buildViews(
        context: Context,
        appWidgetId: Int,
        view: DrumView,
        cells: List<String>,
        children: IntArray,
        theme: NowNextTheme,
        metrics: Metrics,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_now_next)
        views.setInt(NowNextIds.ROOT, "setBackgroundResource", theme.bodyRes)
        views.setInt(NowNextIds.WINDOW, "setBackgroundResource", theme.windowRes)
        arrayOf(view.top, view.center, view.bottom).forEachIndexed { index, line ->
            bindRow(views, index, line, cells, children, theme, metrics)
        }
        views.setOnClickPendingIntent(
            NowNextIds.ROWS[0].row,
            broadcast(context, appWidgetId * 8 + 1, ACTION_PEEK_UP),
        )
        views.setOnClickPendingIntent(
            NowNextIds.ROWS[1].row,
            PendingIntent.getActivity(
                context,
                appWidgetId * 8 + 2,
                MtfWidgetIntentFactory.openToday(context, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        views.setOnClickPendingIntent(
            NowNextIds.ROWS[2].row,
            broadcast(context, appWidgetId * 8 + 3, ACTION_PEEK_DOWN),
        )
        return views
    }

    /**
     * 한 줄을 채운다. 시각 'HH:mm'은 숫자 칸 네 칸, 이름은 글자 칸(5자를 넘으면 5자 + '…').
     * 시각이 없는 줄('오늘 끝' 등)은 칸 없이 글자만. 가운데 줄은 지금 진행 중이면 강조색.
     */
    private fun bindRow(
        views: RemoteViews,
        rowIndex: Int,
        line: DrumLine?,
        cells: List<String>,
        children: IntArray,
        theme: NowNextTheme,
        metrics: Metrics,
    ) {
        val ids = NowNextIds.ROWS[rowIndex]
        val base = rowIndex * CELLS_PER_ROW
        val digits = line?.time?.filter { it.isDigit() } ?: ""
        val hasTime = line != null && digits.length == DIGIT_CELLS
        val labelOnly = line != null && !hasTime
        val color = rowColor(theme, rowIndex, line)

        views.setViewVisibility(ids.digitsBox, if (hasTime) View.VISIBLE else View.GONE)
        views.setViewVisibility(ids.namesBox, if (hasTime) View.VISIBLE else View.GONE)
        views.setViewVisibility(ids.label, if (labelOnly) View.VISIBLE else View.GONE)
        if (labelOnly && line != null) {
            views.setTextViewText(ids.label, line.name)
            views.setTextColor(ids.label, color)
        }
        if (!hasTime) return

        val nameCount = (DIGIT_CELLS until CELLS_PER_ROW).count { cells[base + it].isNotEmpty() }
        val sizing = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            sizingFor(rowIndex, nameCount, metrics)
        } else {
            null
        }
        ids.digits.forEachIndexed { index, cell ->
            bindCell(
                views, cell, cells[base + index], children[base + index],
                color, theme, sizing, sizing?.digitSp,
            )
        }
        views.setTextColor(ids.colon, color)
        if (sizing != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(ids.colon, sizing.colonW, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(ids.colon, sizing.cellH, TypedValue.COMPLEX_UNIT_DIP)
            views.setTextViewTextSize(ids.colon, TypedValue.COMPLEX_UNIT_SP, sizing.digitSp)
        }
        ids.names.forEachIndexed { index, cell ->
            val at = base + DIGIT_CELLS + index
            if (cells[at].isEmpty()) {
                views.setViewVisibility(cell.flipper, View.GONE)
            } else {
                bindCell(
                    views, cell, cells[at], children[at],
                    color, theme, sizing, sizing?.nameSp,
                )
            }
        }
    }

    private fun bindCell(
        views: RemoteViews,
        cell: CellIds,
        text: String,
        child: Int,
        color: Int,
        theme: NowNextTheme,
        sizing: Sizing?,
        textSp: Float?,
    ) {
        views.setViewVisibility(cell.flipper, View.VISIBLE)
        views.setInt(cell.flipper, "setBackgroundResource", theme.cellRes)
        // 들어오는 쪽에만 새 글자를 쓰고, 나가는 쪽은 그대로 둔다.
        views.setTextViewText(if (child == 0) cell.a else cell.b, text)
        views.setTextColor(cell.a, color)
        views.setTextColor(cell.b, color)
        views.setDisplayedChild(cell.flipper, child)
        if (sizing != null && textSp != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(cell.flipper, sizing.cellW, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(cell.flipper, sizing.cellH, TypedValue.COMPLEX_UNIT_DIP)
            views.setTextViewTextSize(cell.a, TypedValue.COMPLEX_UNIT_SP, textSp)
            views.setTextViewTextSize(cell.b, TypedValue.COMPLEX_UNIT_SP, textSp)
        }
    }

    private fun rowColor(theme: NowNextTheme, rowIndex: Int, line: DrumLine?): Int =
        when (rowIndex) {
            1 -> if (line?.tag == NowNextDrum.TAG_NOW) theme.highlight else theme.text
            0 -> withAlpha(theme.text, 0.68f)
            else -> withAlpha(theme.text, 0.52f)
        }

    private fun withAlpha(argb: Int, factor: Float): Int {
        val alpha = ((argb ushr 24) and 0xFF) * factor
        return (alpha.toInt().coerceIn(0, 255) shl 24) or (argb and 0x00FFFFFF)
    }

    /** 세 줄의 칸 글자(줄마다 숫자 4칸 + 이름 6칸). 안 쓰는 칸은 빈 글자. */
    private fun cellTexts(view: DrumView): List<String> = buildList {
        arrayOf(view.top, view.center, view.bottom).forEach { line ->
            val digits = line?.time?.filter { it.isDigit() } ?: ""
            val hasTime = line != null && digits.length == DIGIT_CELLS
            repeat(DIGIT_CELLS) { add(if (hasTime) digits[it].toString() else "") }
            val glyphs = if (hasTime && line != null) nameGlyphs(line.name) else emptyList()
            repeat(NAME_CELLS) { add(glyphs.getOrNull(it) ?: "") }
        }
    }

    /** 이름을 글자 칸에 넣을 조각으로 나눈다: 5자를 넘으면 앞 5자 + '…'(이모지 같은 두 칸짜리 문자도 안전하게). */
    private fun nameGlyphs(name: String): List<String> {
        val points = name.codePoints().toArray()
        val shown = points.take(NAME_MAX_CHARS).map { String(intArrayOf(it), 0, 1) }
        return if (points.size > NAME_MAX_CHARS) shown + "…" else shown
    }

    /** 위젯의 실제 크기(dp)에서 줄 높이와 안쪽 폭을 구한다. 알 수 없으면 2×2 기본값. */
    private fun metricsFor(manager: AppWidgetManager, appWidgetId: Int): Metrics {
        val options = manager.getAppWidgetOptions(appWidgetId)
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, DEFAULT_WIDTH_DP)
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, DEFAULT_HEIGHT_DP)
        return Metrics(
            innerWidthDp = (widthDp - WINDOW_SIDE_DP).toFloat().coerceAtLeast(80f),
            rowHeightDp = ((heightDp - WINDOW_VERTICAL_DP) / 3f).coerceAtLeast(24f),
        )
    }

    /** 이름이 짧아 칸이 남으면 남은 폭만큼 칸과 글자를 키운다. */
    private fun sizingFor(rowIndex: Int, nameCount: Int, metrics: Metrics): Sizing {
        val center = rowIndex == 1
        val units = DIGIT_CELLS + COLON_UNITS + nameCount
        val pitch = ((metrics.innerWidthDp - NAME_GAP_DP) / units).coerceAtLeast(10f)
        val cellW = (pitch - CELL_GAP_DP).coerceIn(9f, if (center) 24f else 20f)
        val cellH = minOf(
            metrics.rowHeightDp * (if (center) 0.78f else 0.58f),
            cellW * (if (center) 2.8f else 2.4f),
        ).coerceAtLeast(18f)
        return Sizing(
            cellW = cellW,
            cellH = cellH,
            digitSp = minOf(cellW * 1.45f, cellH * 0.62f),
            nameSp = minOf(cellW * 0.9f, cellH * 0.5f),
            colonW = cellW * COLON_UNITS,
        )
    }

    private fun decode(value: String?): List<String>? =
        value?.split(SEP)?.takeIf { it.size == CELL_COUNT }

    /** 다음 레슨 시작·종료 시각(없으면 자정 직후)에, 늦어도 30분 안에는 다시 그린다. */
    private fun scheduleTick(context: Context, lessons: List<DrumLesson>, now: Long) {
        val eventAt = NowNextDrum.nextEventAt(lessons, now)
        val midnight = LocalDate.now(SEOUL).plusDays(1).atStartOfDay(SEOUL)
            .toInstant().toEpochMilli() + 30_000L
        val at = minOf((eventAt?.plus(1_500L)) ?: midnight, now + MAX_TICK_MILLIS)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, tickIntent(context))
    }

    private fun tickIntent(context: Context): PendingIntent =
        broadcast(context, REQUEST_TICK, ACTION_TICK)

    private fun resetIntent(context: Context, token: Long): PendingIntent {
        val intent = Intent(context, MtfNowNextWidget::class.java).apply {
            action = ACTION_PEEK_RESET
            putExtra(EXTRA_TOKEN, token)
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_RESET,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun broadcast(context: Context, requestCode: Int, action: String): PendingIntent {
        val intent = Intent(context, MtfNowNextWidget::class.java).apply { this.action = action }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun statePrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private class Metrics(val innerWidthDp: Float, val rowHeightDp: Float)

    private class Sizing(
        val cellW: Float,
        val cellH: Float,
        val digitSp: Float,
        val nameSp: Float,
        val colonW: Float,
    )

    companion object {
        const val ACTION_REFRESH = "com.morethanfitness.app.action.NOW_NEXT_REFRESH"
        private const val ACTION_TICK = "com.morethanfitness.app.action.NOW_NEXT_TICK"
        private const val ACTION_PEEK_UP = "com.morethanfitness.app.action.NOW_NEXT_PEEK_UP"
        private const val ACTION_PEEK_DOWN = "com.morethanfitness.app.action.NOW_NEXT_PEEK_DOWN"
        private const val ACTION_PEEK_RESET = "com.morethanfitness.app.action.NOW_NEXT_PEEK_RESET"
        private const val EXTRA_TOKEN = "token"

        private const val PREFS = "mtf_now_next"
        private const val KEY_PEEK = "peek"
        private const val KEY_CELLS = "cells"
        private const val KEY_CHILDREN = "children"
        private const val KEY_TOKEN = "token"
        private const val KEY_THEME_MODE = "mtf_widget_theme_mode"
        private const val SEP = "\u0001"

        private const val REQUEST_TICK = 880501
        private const val REQUEST_RESET = 880502

        /** 훑어보다가 마지막 탭 뒤 이만큼 지나면 지금으로 돌아온다. */
        private const val PEEK_RETURN_MILLIS = 6_000L
        private const val MAX_TICK_MILLIS = 30 * 60_000L
        private const val NOT_READY_LABEL = "앱을 열어 일정을 불러와 주세요"

        private const val NAME_MAX_CHARS = 5
        private const val DIGIT_CELLS = 4
        private const val NAME_CELLS = 6
        private const val CELLS_PER_ROW = DIGIT_CELLS + NAME_CELLS
        private const val CELL_COUNT = CELLS_PER_ROW * 3

        // 레이아웃(gen_tally_layout.cjs)의 여백과 맞춘 값(dp).
        private const val DEFAULT_WIDTH_DP = 196
        private const val DEFAULT_HEIGHT_DP = 217
        private const val WINDOW_SIDE_DP = 37 // 창 좌우 여백 8+17, 안쪽 여백 6+6
        private const val WINDOW_VERTICAL_DP = 44 // 창 위아래 여백 18+18, 안쪽 여백 4+4
        private const val NAME_GAP_DP = 5f
        private const val CELL_GAP_DP = 1f // 칸 양쪽 0.5dp 여백
        private const val COLON_UNITS = 0.45f

        private const val TAG = "MTF_NOW_NEXT"
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
