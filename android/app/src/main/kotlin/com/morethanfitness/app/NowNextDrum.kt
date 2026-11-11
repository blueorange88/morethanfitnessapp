package com.morethanfitness.app

/** 지금·다음 위젯이 쓰는 레슨 한 건(오늘 레슨 데이터에서 시각과 표시 글자만 뽑은 것). */
internal data class DrumLesson(
    val startAtMillis: Long,
    val endAtMillis: Long,
    val time: String,
    val name: String,
)

/** 세 줄 중 한 줄. [tag]가 비어 있으면 이름표 없음. */
internal data class DrumLine(val tag: String, val time: String, val name: String)

internal data class DrumView(
    val top: DrumLine?,
    val center: DrumLine,
    val bottom: DrumLine?,
    /** 지금 시각 기준 가운데 줄을 몇 칸 옮겨 보고 있는지(0이면 지금). */
    val peek: Int,
    val canPeekUp: Boolean,
    val canPeekDown: Boolean,
) {
    /** 줄의 내용(이름표 제외)이 같으면 같은 모양이라 굴러가지 않는다. */
    val rowsSignature: String
        get() = listOf(top, center, bottom).joinToString("|") { line ->
            line?.let { "${it.time}/${it.name}" } ?: "-"
        }

    /** 이름표까지 같아야 화면을 다시 쓸 필요가 없다. */
    val fullSignature: String
        get() = listOf(top, center, bottom).joinToString("|") { line ->
            line?.let { "${it.tag}/${it.time}/${it.name}" } ?: "-"
        }
}

/**
 * 전 / 지금 / 다음 세 줄을 계산한다. 안드로이드에 의존하지 않는 순수 코드라 JVM에서 바로 점검할 수 있다.
 *
 * 가운데 줄은 '아직 끝나지 않은 첫 레슨'(진행 중이거나 다음 레슨)이고, 그 위가 직전 레슨, 아래가 그다음 레슨이다.
 * [peek]만큼 가운데를 옮겨 앞뒤를 훑어볼 수 있으며, 범위를 넘으면 끝에서 멈춘다.
 * 모두 끝났으면 가운데는 '오늘 끝' 칸이다.
 */
internal object NowNextDrum {
    const val END_LABEL = "오늘 끝"
    const val EMPTY_LABEL = "오늘 레슨 없음"
    const val TAG_PAST = "전"
    const val TAG_NOW = "지금"
    const val TAG_NEXT = "다음"
    const val TAG_LATER = "이후"

    fun compute(lessons: List<DrumLesson>, nowMillis: Long, peek: Int): DrumView {
        val sorted = lessons.sortedBy { it.startAtMillis }
        val size = sorted.size
        val anchor = sorted.indexOfFirst { it.endAtMillis > nowMillis }.let { if (it < 0) size else it }
        val centerIndex = (anchor + peek).coerceIn(0, size)
        val nextIndex = sorted.indexOfFirst { it.startAtMillis > nowMillis }

        fun tagOf(index: Int): String = when {
            sorted[index].endAtMillis <= nowMillis -> TAG_PAST
            sorted[index].startAtMillis <= nowMillis -> TAG_NOW
            index == nextIndex -> TAG_NEXT
            else -> TAG_LATER
        }

        fun lineAt(index: Int): DrumLine? = when {
            index < 0 -> null
            index < size -> DrumLine(tagOf(index), sorted[index].time, sorted[index].name)
            index == size -> DrumLine("", "", if (size == 0) EMPTY_LABEL else END_LABEL)
            else -> null
        }

        return DrumView(
            top = lineAt(centerIndex - 1),
            center = lineAt(centerIndex)!!,
            bottom = lineAt(centerIndex + 1),
            peek = centerIndex - anchor,
            canPeekUp = centerIndex > 0,
            canPeekDown = centerIndex < size,
        )
    }

    /** 지금 이후 가장 가까운 레슨 시작·종료 시각. 그때 위젯을 다시 그린다. */
    fun nextEventAt(lessons: List<DrumLesson>, nowMillis: Long): Long? =
        lessons.flatMap { listOf(it.startAtMillis, it.endAtMillis) }
            .filter { it > nowMillis }
            .minOrNull()
}
