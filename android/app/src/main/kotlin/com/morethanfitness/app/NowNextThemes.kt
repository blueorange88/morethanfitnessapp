package com.morethanfitness.app

/** gen_tally_layout.cjs가 만든다. 앱의 위젯 테마(mtf_widget_theme_mode)별 드로어블과 글자색. */
internal class NowNextTheme(
    val bodyRes: Int,
    val windowRes: Int,
    val cellRes: Int,
    val text: Int,
    val highlight: Int,
)

internal object NowNextThemes {
    fun forMode(mode: String?): NowNextTheme = when (mode) {
        "dark" -> DARK
        "brandLight" -> BRAND_LIGHT
        "light" -> LIGHT
        "pinkperfume" -> PINKPERFUME
        "brownHistory" -> BROWN_HISTORY
        "ttobak" -> TTOBAK
        else -> DARK
    }

    private val DARK = NowNextTheme(
        bodyRes = R.drawable.now_next_bg_dark,
        windowRes = R.drawable.now_next_window_dark,
        cellRes = R.drawable.now_next_cell_dark,
        text = 0xFFFFFFFF.toInt(),
        highlight = 0xFFE8C97A.toInt(),
    )

    private val BRAND_LIGHT = NowNextTheme(
        bodyRes = R.drawable.now_next_bg_brand_light,
        windowRes = R.drawable.now_next_window_brand_light,
        cellRes = R.drawable.now_next_cell_brand_light,
        text = 0xFFF7F5EF.toInt(),
        highlight = 0xFFEFCB62.toInt(),
    )

    private val LIGHT = NowNextTheme(
        bodyRes = R.drawable.now_next_bg_light,
        windowRes = R.drawable.now_next_window_light,
        cellRes = R.drawable.now_next_cell_light,
        text = 0xFFFFFFFF.toInt(),
        highlight = 0xFFFDE68A.toInt(),
    )

    private val PINKPERFUME = NowNextTheme(
        bodyRes = R.drawable.now_next_bg_pinkperfume,
        windowRes = R.drawable.now_next_window_pinkperfume,
        cellRes = R.drawable.now_next_cell_pinkperfume,
        text = 0xFFFFF7FB.toInt(),
        highlight = 0xFFFFD6EA.toInt(),
    )

    private val BROWN_HISTORY = NowNextTheme(
        bodyRes = R.drawable.now_next_bg_brown_history,
        windowRes = R.drawable.now_next_window_brown_history,
        cellRes = R.drawable.now_next_cell_brown_history,
        text = 0xFFFFF5E0.toInt(),
        highlight = 0xFFE0B878.toInt(),
    )

    private val TTOBAK = NowNextTheme(
        bodyRes = R.drawable.now_next_bg_ttobak,
        windowRes = R.drawable.now_next_window_ttobak,
        cellRes = R.drawable.now_next_cell_ttobak,
        text = 0xFF111827.toInt(),
        highlight = 0xFFC2410C.toInt(),
    )
}
