package com.example.mtf_app

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.AppWidgetId
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
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
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import java.util.Calendar
import kotlin.math.ceil
import kotlin.math.max

import android.graphics.LinearGradient
import android.graphics.Shader

class MtfScheduleWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Exact

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = (id as? AppWidgetId)?.appWidgetId ?: 0
        provideContent {
            GlanceContent(context, currentState(), appWidgetId)
        }
    }

    @Composable
    private fun GlanceContent(
        context: Context,
        currentState: HomeWidgetGlanceState,
        appWidgetId: Int,
    ) {
        val prefs = currentState.preferences
        val widgetSize = LocalSize.current

        val activeOffset = prefs.getInt("mtf_widget_active_offset", 0).coerceIn(0, 1)
        val dayFilter = prefs.getString("mtf_widget_day_filter", "all") ?: "all"

        val themeMode = prefs.getString("mtf_widget_theme_mode", "light") ?: "light"

        val headerDrawable = when (themeMode) {
            "brandLight" -> R.drawable.widget_header_brand_light
            "dark" -> R.drawable.widget_header_dark
            "pinkperfume" -> R.drawable.widget_header_pinkperfume
            "brownHistory" -> R.drawable.widget_header_brown_history
            "ttobak" -> R.drawable.widget_header_ttobak
            else -> R.drawable.widget_header_bg
        }

        val headerStartColor = parseBitmapColor(
            prefs.getString("mtf_widget_header_start", "#4F46E5") ?: "#4F46E5"
        ) ?: 0xFF4F46E5.toInt()

        val headerEndColor = parseBitmapColor(
            prefs.getString("mtf_widget_header_end", "#9333EA") ?: "#9333EA"
        ) ?: 0xFF9333EA.toInt()

        val headerTextColor = parseBitmapColor(
            prefs.getString("mtf_widget_header_text", "#FFFFFF") ?: "#FFFFFF"
        )?.toLong() ?: 0xFFFFFFFF

        val iconColor = parseBitmapColor(
            prefs.getString("mtf_widget_icon_color", "#FFFFFF") ?: "#FFFFFF"
        )?.toLong() ?: 0xFFFFFFFF


        val title = if (activeOffset == 1) {
            prefs.getString("mtf_widget_title_1", "다음 주 스케줄")
        } else {
            prefs.getString("mtf_widget_title_0", "이번 주 스케줄")
        } ?: "이번 주 스케줄"

        val days = readDays(prefs, activeOffset).ifEmpty {
            when (dayFilter) {
                "weekday" -> listOf("월", "화", "수", "목", "금")
                "weekend" -> listOf("토", "일")
                else -> listOf("월", "화", "수", "목", "금", "토", "일")
            }
        }

        val todayDay = if (activeOffset == 0) getTodayDayLabel() else null
        val visibleRange = readVisibleHourRange(prefs)

        val savedRows = readPackedRows(prefs, activeOffset)

        val baseRows = if (savedRows.isNotEmpty()) {
            savedRows
        } else {
            buildDisplayRows(
                startHour = visibleRange.startHour,
                endHour = visibleRange.endHour,
                currentMarkerRatio = null,
            )
        }

        val rows = applyCurrentRowFromDeviceClock(
            rows = baseRows,
            prefs = prefs,
            activeOffset = activeOffset,
        )

        val blocks = readPackedBlocks(
            prefs = prefs,
            activeOffset = activeOffset,
            rowCount = rows.size,
        )

        val openAppIntent = MtfWidgetIntentFactory.openWeeklySchedule(context, appWidgetId)
        val widgetSettingsIntent = MtfWidgetIntentFactory.openWeeklySettings(
            context,
            appWidgetId,
        )

        val headerHorizontalPadding = 8.dp
        val headerVerticalPadding = 7.dp

        val settingsWidth = 34.dp
        val navButtonWidth = 34.dp
        val navGap = 2.dp

        val headerAreaHeight = 51.dp
        val availableHeaderWidth = widgetSize.width - (headerHorizontalPadding * 2)
        val rawTitleWidth =
            availableHeaderWidth - settingsWidth - (navButtonWidth * 2) - (navGap * 2)
        val titleWidth = if (rawTitleWidth.value < 1f) 1.dp else rawTitleWidth

        val titleStyle = TextStyle(
            color = widgetColor(headerTextColor),
            fontSize = 19.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        val gearStyle = TextStyle(
            color = widgetColor(iconColor),
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        val navStyle = TextStyle(
            color = widgetColor(iconColor),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        val bodyHeight = widgetSize.height - headerAreaHeight
        val safeBodyHeight = if (bodyHeight.value < 1f) 1.dp else bodyHeight

        val bitmapScale = 2.4f

        val bitmapWidth = (widgetSize.width.value * bitmapScale)
            .toInt()
            .coerceIn(900, 1400)

        val bitmapHeight = (safeBodyHeight.value * bitmapScale)
            .toInt()
            .coerceIn(900, 1500)

        val tableBitmap = renderScheduleBitmap(
            rows = rows,
            days = days,
            blocks = blocks,
            todayDay = todayDay,
            themeMode = themeMode,
            prefs = prefs,
            widthPx = bitmapWidth,
            heightPx = bitmapHeight,
        )

        val widgetBgColor = parseBitmapColor(
            prefs.getString("mtf_widget_body_bg", "#FFFFFF") ?: "#FFFFFF"
        )?.toLong() ?: 0xFFFFFFFF

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(widgetColor(widgetBgColor))
        ) {


            Column(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .background(ImageProvider(headerDrawable))
                    .padding(
                        horizontal = headerHorizontalPadding,
                        vertical = headerVerticalPadding,
                    )
            ) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = GlanceModifier
                            .width(settingsWidth)
                            .height(34.dp)
                            .clickable(onClick = actionStartActivity(widgetSettingsIntent)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "⚙",
                            style = gearStyle,
                        )
                    }

                    Text(
                        text = MtfWidgetIntentFactory.displayTitle(
                            context,
                            compactWeekTitle(title),
                        ),
                        style = titleStyle,
                        modifier = GlanceModifier.width(titleWidth)
                    )

                    Box(
                        modifier = GlanceModifier
                            .width(navButtonWidth)
                            .height(34.dp)
                            .clickable(onClick = actionRunCallback<PrevWeekAction>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "⪡",
                            style = navStyle,
                        )
                    }

                    Box(modifier = GlanceModifier.width(navGap)) {}

                    Box(
                        modifier = GlanceModifier
                            .width(navButtonWidth)
                            .height(34.dp)
                            .clickable(onClick = actionRunCallback<NextWeekAction>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "⪢",
                            style = navStyle,
                        )
                    }
                }
            }

            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(widgetColor(0x38FFFFFF))
            ) {}

            Image(
                provider = ImageProvider(tableBitmap),
                contentDescription = "스케줄표",
                contentScale = ContentScale.FillBounds,
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(safeBodyHeight)
                    .clickable(onClick = actionStartActivity(openAppIntent))
            )
        }
    }

    private fun renderScheduleBitmap(
        rows: List<WidgetRow>,
        days: List<String>,
        blocks: List<WidgetBlock>,
        todayDay: String?,
        themeMode: String,
        prefs: SharedPreferences,
        widthPx: Int,
        heightPx: Int,
    ): Bitmap {

        fun prefColor(key: String, fallback: String): Int {
            return parseBitmapColor(prefs.getString(key, fallback) ?: fallback)
                ?: parseBitmapColor(fallback)
                ?: 0xFF111827.toInt()
        }

        val isDarkTheme = prefs.getString("mtf_widget_is_dark", "false") == "true"
        val isTtobakTheme = prefs.getString("mtf_widget_is_ttobak", "false") == "true"

        val headerStartColor = prefColor("mtf_widget_header_start", "#4F46E5")
        val headerEndColor = prefColor("mtf_widget_header_end", "#9333EA")

        val canvasBgColor = prefColor("mtf_widget_body_bg", "#FFFFFF")
        val rowAltColor = prefColor("mtf_widget_row_even", "#EFF6FF")
        val rowOddColor = prefColor("mtf_widget_row_odd", "#FFFFFF")
        val lineColor = prefColor("mtf_widget_grid_line", "#E5E7EB")
        val strongLineColor = prefColor("mtf_widget_time_col_line", "#D1D5DB")
        val headerTextColor = prefColor("mtf_widget_day_text", "#111827")
        val timeTextColor = prefColor("mtf_widget_time_text", "#334155")
        val timeColumnBaseColor = prefColor("mtf_widget_time_col_bg", "#F8FAFC")
        val todayBodyColor = prefColor("mtf_widget_today_col", "#22FDE68A")
        val todayHeaderColor = prefColor("mtf_widget_today_header", "#FDE68A")
        val currentOutlineColor = prefColor("mtf_widget_today_border", "#E11D48")

        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = canvasBgColor
            style = Paint.Style.FILL
        }

        canvas.drawRect(0f, 0f, widthPx.toFloat(), heightPx.toFloat(), bgPaint)


        if (rows.isEmpty() || days.isEmpty()) {
            val emptyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFF111827.toInt()
                textSize = 34f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            canvas.drawText("등록된 스케줄이 없어요.", widthPx / 2f, heightPx / 2f, emptyPaint)
            return bitmap
        }

        val timeColWidth = when {
            days.size <= 2 -> widthPx * 0.15f
            days.size <= 5 -> widthPx * 0.12f
            else -> widthPx * 0.095f
        }.coerceAtLeast(98f)

        val dayHeaderHeight = 64f
        val bodyTop = dayHeaderHeight
        val bodyHeight = heightPx - dayHeaderHeight
        val rowHeight = bodyHeight / rows.size.toFloat()
        val dayColWidth = (widthPx - timeColWidth) / days.size.toFloat()

        val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = lineColor
            strokeWidth = if (isTtobakTheme) 1.8f else 2f
            style = Paint.Style.STROKE
        }

        val rowAltPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rowAltColor
            style = Paint.Style.FILL
        }

        val rowOddPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rowOddColor
            style = Paint.Style.FILL
        }

        val timeColumnPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = timeColumnBaseColor
            style = Paint.Style.FILL
        }

        val timeColumnShinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                bodyTop,
                0f,
                heightPx.toFloat(),
                intArrayOf(
                    withAlpha(0xFFFFFFFF.toInt(), if (isDarkTheme) 0x10 else 0x32),
                    withAlpha(headerStartColor, if (isDarkTheme) 0x08 else 0x06),
                    0x00000000,
                ),
                floatArrayOf(0f, 0.45f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }

        val timeColumnRightShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                timeColWidth - 18f,
                0f,
                timeColWidth,
                0f,
                intArrayOf(0x00000000, 0x11000000),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }

        val todayHeaderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = todayHeaderColor
            style = Paint.Style.FILL
        }

        val todayBodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = todayBodyColor
            style = Paint.Style.FILL
        }

        val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = headerTextColor
            textSize = 34f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        val timePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = timeTextColor
            textSize = 31f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        val timeColumnTintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                bodyTop,
                timeColWidth,
                heightPx.toFloat(),
                intArrayOf(
                    withAlpha(headerStartColor, if (isDarkTheme) 0x18 else 0x08),
                    withAlpha(headerEndColor, if (isDarkTheme) 0x10 else 0x05),
                ),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }



        val blockTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = when {
                days.size <= 2 -> 46f
                days.size <= 5 -> 40f
                else -> 31f
            }
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        val blockPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        // 요일 헤더 기본 배경
        val dayHeaderBasePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = timeColumnBaseColor
            style = Paint.Style.FILL
        }

        canvas.drawRect(
            0f,
            0f,
            widthPx.toFloat(),
            dayHeaderHeight,
            dayHeaderBasePaint,
        )

// 요일 헤더 테마 틴트
        val dayHeaderTintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                widthPx.toFloat(),
                dayHeaderHeight,
                intArrayOf(
                    withAlpha(headerStartColor, if (isDarkTheme) 0x40 else 0x1C),
                    withAlpha(headerEndColor, if (isDarkTheme) 0x32 else 0x14),
                ),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }

        canvas.drawRect(
            0f,
            0f,
            widthPx.toFloat(),
            dayHeaderHeight,
            dayHeaderTintPaint,
        )

// 오늘 요일 헤더 배경은 shine 전에 먼저 그림
        val todayIndexForHeader = todayDay?.let { days.indexOf(it) } ?: -1
        if (todayIndexForHeader >= 0) {
            val left = timeColWidth + todayIndexForHeader * dayColWidth
            val right = left + dayColWidth
            canvas.drawRect(left, 0f, right, dayHeaderHeight, todayHeaderPaint)
        }

// 헤더 상단 shine
        val headerShinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                0f,
                dayHeaderHeight,
                intArrayOf(0x44FFFFFF, 0x00FFFFFF),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }

        canvas.drawRect(
            0f,
            0f,
            widthPx.toFloat(),
            dayHeaderHeight,
            headerShinePaint,
        )

// 헤더 하단 어두운 레이어
        val headerBottomPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                dayHeaderHeight * 0.65f,
                0f,
                dayHeaderHeight,
                intArrayOf(
                    0x00000000,
                    if (isDarkTheme) 0x44000000 else 0x22000000,
                ),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
            style = Paint.Style.FILL
        }

        canvas.drawRect(
            0f,
            dayHeaderHeight * 0.65f,
            widthPx.toFloat(),
            dayHeaderHeight,
            headerBottomPaint,
        )

// 시간 / 요일 텍스트
        canvas.drawText(
            "시간",
            timeColWidth / 2f,
            dayHeaderHeight / 2f + 9f,
            headerPaint,
        )

        days.forEachIndexed { index, day ->
            val left = timeColWidth + index * dayColWidth

            canvas.drawText(
                day,
                left + dayColWidth / 2f,
                dayHeaderHeight / 2f + 9f,
                headerPaint,
            )
        }

// 헤더 하단 구분선
        val headerBottomLinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = strongLineColor
            strokeWidth = 2.2f
            style = Paint.Style.STROKE
        }

        canvas.drawLine(
            0f,
            dayHeaderHeight,
            widthPx.toFloat(),
            dayHeaderHeight,
            headerBottomLinePaint,
        )






        val todayIndex = todayDay?.let { days.indexOf(it) } ?: -1
        if (todayIndex >= 0) {
            val left = timeColWidth + todayIndex * dayColWidth
            val right = left + dayColWidth
            canvas.drawRect(left, bodyTop, right, heightPx.toFloat(), todayBodyPaint)
        }

        canvas.drawRect(
            0f,
            bodyTop,
            timeColWidth,
            heightPx.toFloat(),
            timeColumnPaint,
        )

        canvas.drawRect(
            0f,
            bodyTop,
            timeColWidth,
            heightPx.toFloat(),
            timeColumnTintPaint,
        )

        canvas.drawRect(
            0f,
            bodyTop,
            timeColWidth,
            heightPx.toFloat(),
            timeColumnShinePaint,
        )

        canvas.drawRect(
            timeColWidth - 22f,
            bodyTop,
            timeColWidth,
            heightPx.toFloat(),
            timeColumnRightShadowPaint,
        )

        rows.forEachIndexed { rowIndex, row ->
            val top = bodyTop + rowIndex * rowHeight
            val bottom = top + rowHeight

            if (rowIndex % 2 == 0) {
                canvas.drawRect(timeColWidth, top, widthPx.toFloat(), bottom, rowAltPaint)
            } else {
                canvas.drawRect(timeColWidth, top, widthPx.toFloat(), bottom, rowOddPaint)
            }

            canvas.drawText(
                row.time,
                timeColWidth / 2f,
                top + rowHeight / 2f + 10f,
                timePaint,
            )
        }

        // 일반 세로선
        for (i in 1..days.size) {
            val x = timeColWidth + i * dayColWidth
            canvas.drawLine(x, 0f, x, heightPx.toFloat(), linePaint)
        }

// 시간 열과 월요일 사이 강조선
        val timeDividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = strongLineColor
            strokeWidth = 2.4f
            style = Paint.Style.STROKE
        }

        canvas.drawLine(
            timeColWidth,
            0f,
            timeColWidth,
            heightPx.toFloat(),
            timeDividerPaint,
        )
        // 블럭
        blocks.forEach { block ->
            val dayIndex = days.indexOf(block.day)
            if (dayIndex < 0) return@forEach

            val safeTopRatio = block.topRatio.coerceIn(0f, 1f)
            val safeHeightRatio = block.heightRatio.coerceAtLeast(0.003f)

            val left = timeColWidth + dayIndex * dayColWidth + 5f
            val top = bodyTop + (safeTopRatio * bodyHeight) + 4f
            val right = timeColWidth + (dayIndex + 1) * dayColWidth - 5f
            val rawBottom =
                bodyTop + ((safeTopRatio + safeHeightRatio).coerceAtMost(1f) * bodyHeight) - 4f

            val minBlockHeight = 18f
            val bottom = if (rawBottom - top < minBlockHeight) {
                top + minBlockHeight
            } else {
                rawBottom
            }

            val rawColor = parseBitmapColor(block.colorHex) ?: 0xFF4F46E5.toInt()
            val blockRect = RectF(left, top, right, bottom)

// 블럭 그림자
            val blockShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = if (isDarkTheme) 0x66000000 else 0x26000000
                style = Paint.Style.FILL
            }

            canvas.drawRoundRect(
                RectF(
                    blockRect.left + 1.5f,
                    blockRect.top + 2.5f,
                    blockRect.right + 1.5f,
                    blockRect.bottom + 2.5f,
                ),
                10f,
                10f,
                blockShadowPaint,
            )

// 블럭 본체
            blockPaint.color = withAlpha(rawColor, 0xE6)

            canvas.drawRoundRect(
                blockRect,
                10f,
                10f,
                blockPaint,
            )

            val shinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = 0x26FFFFFF
                style = Paint.Style.FILL
            }

            canvas.drawRoundRect(
                RectF(
                    blockRect.left,
                    blockRect.top,
                    blockRect.right,
                    blockRect.top + (blockRect.height() * 0.42f),
                ),
                10f,
                10f,
                shinePaint,
            )

            val label = compactBlockLabel(block.label, days.size)
            val blockHeight = bottom - top

            if (label.isNotBlank() && blockHeight >= 24f) {
                val centerY = (top + bottom) / 2f
                val metrics = blockTextPaint.fontMetrics
                val textY = centerY - ((metrics.ascent + metrics.descent) / 2f)

                val shadowPaint = Paint(blockTextPaint).apply {
                    this.color = 0x66000000
                }

                canvas.drawText(
                    label,
                    (left + right) / 2f + 1.2f,
                    textY + 1.2f,
                    shadowPaint,
                )

                canvas.drawText(
                    label,
                    (left + right) / 2f,
                    textY,
                    blockTextPaint,
                )
            }
        }

// 현재 요일 + 현재 시간 칸 강조
        val currentRowIndex = rows.indexOfFirst { it.isCurrent }

        if (todayIndex >= 0 && currentRowIndex >= 0) {
            val cellLeft = timeColWidth + todayIndex * dayColWidth + 5f
            val cellTop = bodyTop + currentRowIndex * rowHeight + 4f
            val cellRight = timeColWidth + (todayIndex + 1) * dayColWidth - 5f
            val cellBottom = bodyTop + (currentRowIndex + 1) * rowHeight - 4f

            val currentFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = withAlpha(currentOutlineColor, 0x18)
                style = Paint.Style.FILL
            }

            val currentOutlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = currentOutlineColor
                style = Paint.Style.STROKE
                strokeWidth = 4.2f
            }

            val rect = RectF(cellLeft, cellTop, cellRight, cellBottom)

            canvas.drawRoundRect(
                rect,
                10f,
                10f,
                currentFillPaint,
            )

            canvas.drawRoundRect(
                rect,
                10f,
                10f,
                currentOutlinePaint,
            )
        }

        return bitmap
    }

    private fun buildDisplayRows(
        startHour: Int,
        endHour: Int,
        currentMarkerRatio: Float?,
    ): List<WidgetRow> {
        val safeStartHour = startHour.coerceIn(0, 23)
        val safeEndHour = endHour.coerceIn(safeStartHour + 1, 24)

        val rowCount = (safeEndHour - safeStartHour).coerceAtLeast(1)

        val currentRowIndex = currentMarkerRatio?.let {
            (it * rowCount).toInt().coerceIn(0, rowCount - 1)
        }

        return List(rowCount) { index ->
            val hour = safeStartHour + index
            val label = hour.toString().padStart(2, '0') + ":00"

            WidgetRow(
                time = label,
                hour = hour,
                minute = 0,
                slotIndex = index,
                isCurrent = currentRowIndex == index,
                cells = emptyList(),
            )
        }
    }

    private fun parseRow(raw: String): WidgetRow {
        val parts = raw.split("|")
        val time = parts.getOrNull(0)?.trim().orEmpty()
        val isCurrent = (parts.getOrNull(1) ?: "0").trim() == "1"

        return WidgetRow(
            time = time,
            hour = time.substringBefore(":").toIntOrNull() ?: 0,
            minute = time.substringAfter(":", "0").toIntOrNull() ?: 0,
            slotIndex = 0,
            isCurrent = isCurrent,
            cells = emptyList(),
        )
    }

    private fun readPackedRows(
        prefs: SharedPreferences,
        activeOffset: Int,
    ): List<WidgetRow> {
        val key = if (activeOffset == 1) "mtf_widget_rows_1" else "mtf_widget_rows_0"
        val packed = prefs.getString(key, "") ?: ""
        if (packed.isBlank()) return emptyList()

        return packed
            .split("§§ROW§§")
            .filter { it.isNotBlank() }
            .map { parseRow(it) }
    }

    private fun readDays(
        prefs: SharedPreferences,
        activeOffset: Int,
    ): List<String> {
        val key = if (activeOffset == 1) "mtf_widget_days_1" else "mtf_widget_days_0"
        val raw = prefs.getString(key, "") ?: ""
        if (raw.isBlank()) return emptyList()

        return raw
            .split("|")
            .map { it.trim() }
            .filter { it.isNotBlank() }
    }

    private fun parseBlock(raw: String, rowCount: Int): WidgetBlock? {
        val parts = raw.split("|")
        if (parts.size < 7) return null

        val day = parts[0].trim()
        val topRatio = parts[1].toFloatOrNull() ?: return null
        val heightRatio = parts[2].toFloatOrNull() ?: return null
        val columnIndex = parts[3].toIntOrNull() ?: 0
        val totalColumns = parts[4].toIntOrNull()?.coerceAtLeast(1) ?: 1
        val label = parts[5].trim()
        val type = parts[6].trim()
        val colorHex = parts.getOrNull(7)?.trim().orEmpty()

        val safeRowCount = rowCount.coerceAtLeast(1)
        val safeTopRatio = topRatio.coerceIn(0f, 1f)
        val safeHeightRatio = heightRatio.coerceAtLeast(0f)

        val startRow = (safeTopRatio * safeRowCount)
            .toInt()
            .coerceIn(0, safeRowCount - 1)

        val endRowExclusive = ceil((safeTopRatio + safeHeightRatio) * safeRowCount)
            .toInt()
            .coerceIn(startRow + 1, safeRowCount)

        return WidgetBlock(
            day = day,
            topRatio = safeTopRatio,
            heightRatio = safeHeightRatio,
            columnIndex = columnIndex.coerceIn(0, totalColumns - 1),
            totalColumns = totalColumns,
            label = label,
            type = type,
            colorHex = colorHex,
            startRow = startRow,
            endRowExclusive = endRowExclusive,
        )
    }

    private fun readPackedBlocks(
        prefs: SharedPreferences,
        activeOffset: Int,
        rowCount: Int,
    ): List<WidgetBlock> {
        val key = if (activeOffset == 1) {
            "mtf_widget_blocks_1"
        } else {
            "mtf_widget_blocks_0"
        }

        val packed = prefs.getString(key, "") ?: ""
        if (packed.isBlank()) return emptyList()

        val safeRowCount = rowCount.coerceAtLeast(1)

        return packed
            .split("§§ROW§§")
            .filter { it.isNotBlank() }
            .mapNotNull { parseBlock(it, safeRowCount) }
    }

    private fun applyCurrentRowFromDeviceClock(
        rows: List<WidgetRow>,
        prefs: SharedPreferences,
        activeOffset: Int,
    ): List<WidgetRow> {
        if (rows.isEmpty()) return rows

        // 현재 시간 강조는 이번 주 화면에서만 표시합니다.
        // 다음 주/다른 offset에서는 저장된 isCurrent도 모두 제거합니다.
        if (activeOffset != 0) {
            return rows.map { it.copy(isCurrent = false) }
        }

        val visibleRange = readVisibleHourRange(prefs)

        val now = Calendar.getInstance()
        val nowMinutes =
            now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

        val rangeStartMinutes = visibleRange.startHour * 60
        val rangeEndMinutes = visibleRange.endHour * 60

        if (nowMinutes < rangeStartMinutes || nowMinutes >= rangeEndMinutes) {
            return rows.map { it.copy(isCurrent = false) }
        }

        return rows.mapIndexed { index, row ->
            val rowStartMinutes = row.hour * 60 + row.minute

            val nextRowStartMinutes = rows.getOrNull(index + 1)?.let {
                it.hour * 60 + it.minute
            } ?: rangeEndMinutes

            row.copy(
                isCurrent = nowMinutes >= rowStartMinutes &&
                        nowMinutes < nextRowStartMinutes,
            )
        }
    }

    private fun readCurrentMarkerRatio(
        prefs: SharedPreferences,
        activeOffset: Int,
    ): Float? {
        val key = if (activeOffset == 1) {
            "mtf_widget_current_marker_ratio_1"
        } else {
            "mtf_widget_current_marker_ratio_0"
        }

        val raw = prefs.getString(key, null) ?: return null
        val value = raw.toFloatOrNull() ?: return null

        return if (value < 0f) null else value
    }

    private fun readVisibleHourRange(prefs: SharedPreferences): WidgetHourRange {
        var startHour = prefs.getInt("mtf_widget_start_hour", 6)
        var endHour = prefs.getInt("mtf_widget_end_hour", 22)

        startHour = startHour.coerceIn(0, 23)
        endHour = endHour.coerceIn(startHour + 1, 24)

        return WidgetHourRange(
            startHour = startHour,
            endHour = endHour,
        )
    }

    private fun compactWeekTitle(title: String): String {
        return when {
            title.contains("다음") -> "다음 주 스케줄"
            title.contains("이번") -> "이번 주 스케줄"
            else -> title
        }
    }

    private fun compactBlockLabel(
        label: String,
        dayCount: Int,
    ): String {
        val cleaned = label
            .replace("\n", " ")
            .replace(" ", "")
            .trim()

        if (cleaned.isBlank()) return ""

        return when {
            dayCount <= 2 -> {
                if (cleaned.length <= 8) cleaned else cleaned.take(7) + "…"
            }
            dayCount <= 5 -> {
                if (cleaned.length <= 6) cleaned else cleaned.take(5) + "…"
            }
            else -> {
                if (cleaned.length <= 4) cleaned else cleaned.take(3) + "…"
            }
        }
    }

    private fun getTodayDayLabel(): String {
        return when (Calendar.getInstance().get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> "월"
            Calendar.TUESDAY -> "화"
            Calendar.WEDNESDAY -> "수"
            Calendar.THURSDAY -> "목"
            Calendar.FRIDAY -> "금"
            Calendar.SATURDAY -> "토"
            Calendar.SUNDAY -> "일"
            else -> "월"
        }
    }

    private fun parseBitmapColor(raw: String): Int? {
        val cleaned = raw
            .trim()
            .removePrefix("#")
            .removePrefix("0x")
            .removePrefix("0X")

        if (cleaned.isBlank()) return null

        val value = when (cleaned.length) {
            6 -> "FF$cleaned"
            8 -> cleaned
            else -> return null
        }

        return value.toLongOrNull(16)?.toInt()
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)
    }

    private fun widgetColor(hex: Long) =
        ColorProvider(
            day = Color(hex),
            night = Color(hex)
        )
}

data class WidgetRow(
    val time: String,
    val hour: Int,
    val minute: Int,
    val slotIndex: Int,
    val isCurrent: Boolean,
    val cells: List<String>,
)

data class WidgetHourRange(
    val startHour: Int,
    val endHour: Int,
)

data class WidgetBlock(
    val day: String,
    val topRatio: Float,
    val heightRatio: Float,
    val columnIndex: Int,
    val totalColumns: Int,
    val label: String,
    val type: String,
    val colorHex: String,
    val startRow: Int,
    val endRowExclusive: Int,
)

class PrevWeekAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        HomeWidgetBackgroundIntent
            .getBroadcast(context, Uri.parse("mtfwidget://week/prev"))
            .send()
    }
}

class NextWeekAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        HomeWidgetBackgroundIntent
            .getBroadcast(context, Uri.parse("mtfwidget://week/next"))
            .send()
    }
}
