package com.morethanfitness.app

/** gen_tally_layout.cjs가 레이아웃(widget_now_next.xml)과 함께 만든다. 손으로 고치지 않는다. */
internal class CellIds(val flipper: Int, val a: Int, val b: Int)

internal class RowIds(
    val row: Int,
    val digitsBox: Int,
    /** 시각의 숫자 네 칸(시 두 칸, 분 두 칸). */
    val digits: Array<CellIds>,
    val colon: Int,
    val namesBox: Int,
    /** 이름 글자 칸(5자 + '…'). */
    val names: Array<CellIds>,
    /** 시각이 없는 줄('오늘 끝' 등)에 쓰는 글자. */
    val label: Int,
)

internal object NowNextIds {
    val ROOT = R.id.now_next_root
    val WINDOW = R.id.now_next_window

    /** 위 줄(전), 가운데 줄(지금), 아래 줄(다음) 순서. */
    val ROWS = arrayOf(
        RowIds(
            row = R.id.r_top,
            digitsBox = R.id.r_top_digits,
            digits = arrayOf(
                CellIds(R.id.r_top_d1, R.id.r_top_d1_a, R.id.r_top_d1_b),
                CellIds(R.id.r_top_d2, R.id.r_top_d2_a, R.id.r_top_d2_b),
                CellIds(R.id.r_top_d3, R.id.r_top_d3_a, R.id.r_top_d3_b),
                CellIds(R.id.r_top_d4, R.id.r_top_d4_a, R.id.r_top_d4_b),
            ),
            colon = R.id.r_top_colon,
            namesBox = R.id.r_top_names,
            names = arrayOf(
                CellIds(R.id.r_top_n1, R.id.r_top_n1_a, R.id.r_top_n1_b),
                CellIds(R.id.r_top_n2, R.id.r_top_n2_a, R.id.r_top_n2_b),
                CellIds(R.id.r_top_n3, R.id.r_top_n3_a, R.id.r_top_n3_b),
                CellIds(R.id.r_top_n4, R.id.r_top_n4_a, R.id.r_top_n4_b),
                CellIds(R.id.r_top_n5, R.id.r_top_n5_a, R.id.r_top_n5_b),
                CellIds(R.id.r_top_n6, R.id.r_top_n6_a, R.id.r_top_n6_b),
            ),
            label = R.id.r_top_label,
        ),
        RowIds(
            row = R.id.r_center,
            digitsBox = R.id.r_center_digits,
            digits = arrayOf(
                CellIds(R.id.r_center_d1, R.id.r_center_d1_a, R.id.r_center_d1_b),
                CellIds(R.id.r_center_d2, R.id.r_center_d2_a, R.id.r_center_d2_b),
                CellIds(R.id.r_center_d3, R.id.r_center_d3_a, R.id.r_center_d3_b),
                CellIds(R.id.r_center_d4, R.id.r_center_d4_a, R.id.r_center_d4_b),
            ),
            colon = R.id.r_center_colon,
            namesBox = R.id.r_center_names,
            names = arrayOf(
                CellIds(R.id.r_center_n1, R.id.r_center_n1_a, R.id.r_center_n1_b),
                CellIds(R.id.r_center_n2, R.id.r_center_n2_a, R.id.r_center_n2_b),
                CellIds(R.id.r_center_n3, R.id.r_center_n3_a, R.id.r_center_n3_b),
                CellIds(R.id.r_center_n4, R.id.r_center_n4_a, R.id.r_center_n4_b),
                CellIds(R.id.r_center_n5, R.id.r_center_n5_a, R.id.r_center_n5_b),
                CellIds(R.id.r_center_n6, R.id.r_center_n6_a, R.id.r_center_n6_b),
            ),
            label = R.id.r_center_label,
        ),
        RowIds(
            row = R.id.r_bottom,
            digitsBox = R.id.r_bottom_digits,
            digits = arrayOf(
                CellIds(R.id.r_bottom_d1, R.id.r_bottom_d1_a, R.id.r_bottom_d1_b),
                CellIds(R.id.r_bottom_d2, R.id.r_bottom_d2_a, R.id.r_bottom_d2_b),
                CellIds(R.id.r_bottom_d3, R.id.r_bottom_d3_a, R.id.r_bottom_d3_b),
                CellIds(R.id.r_bottom_d4, R.id.r_bottom_d4_a, R.id.r_bottom_d4_b),
            ),
            colon = R.id.r_bottom_colon,
            namesBox = R.id.r_bottom_names,
            names = arrayOf(
                CellIds(R.id.r_bottom_n1, R.id.r_bottom_n1_a, R.id.r_bottom_n1_b),
                CellIds(R.id.r_bottom_n2, R.id.r_bottom_n2_a, R.id.r_bottom_n2_b),
                CellIds(R.id.r_bottom_n3, R.id.r_bottom_n3_a, R.id.r_bottom_n3_b),
                CellIds(R.id.r_bottom_n4, R.id.r_bottom_n4_a, R.id.r_bottom_n4_b),
                CellIds(R.id.r_bottom_n5, R.id.r_bottom_n5_a, R.id.r_bottom_n5_b),
                CellIds(R.id.r_bottom_n6, R.id.r_bottom_n6_a, R.id.r_bottom_n6_b),
            ),
            label = R.id.r_bottom_label,
        ),
    )
}
