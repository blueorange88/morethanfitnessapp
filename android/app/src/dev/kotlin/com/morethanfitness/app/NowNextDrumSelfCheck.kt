package com.morethanfitness.app

/**
 * DEV 점검용: 앱 안에서는 쓰이지 않는다. 컴파일된 클래스를 PC의 JVM에서 직접 실행해
 * [NowNextDrum] 계산을 확인한다(테스트 라이브러리를 새로 넣지 않기 위한 방법).
 */
fun main() {
    val minute = 60_000L
    fun at(h: Int, m: Int) = (h * 60L + m) * minute
    fun lesson(h: Int, m: Int, name: String) = DrumLesson(
        startAtMillis = at(h, m),
        endAtMillis = at(h, m) + 50 * minute,
        time = "%02d:%02d".format(h, m),
        name = name,
    )

    val l0 = lesson(10, 0, "가")
    val l1 = lesson(11, 0, "나")
    val l2 = lesson(13, 0, "다")
    val day = listOf(l2, l0, l1) // 일부러 순서를 섞어 넣는다.

    var failures = 0
    fun expect(label: String, actual: Any?, expected: Any?) {
        if (actual != expected) {
            failures++
            println("FAIL  $label\n   기대: $expected\n   실제: $actual")
        } else {
            println("ok    $label")
        }
    }

    // 1) 첫 레슨 전: 위 없음, 가운데 '다음'
    var v = NowNextDrum.compute(day, at(9, 0), 0)
    expect("시작 전 위", v.top, null)
    expect("시작 전 가운데", v.center, DrumLine("다음", "10:00", "가"))
    expect("시작 전 아래", v.bottom, DrumLine("이후", "11:00", "나"))

    // 2) 첫 레슨 진행 중
    v = NowNextDrum.compute(day, at(10, 20), 0)
    expect("진행 중 가운데", v.center, DrumLine("지금", "10:00", "가"))
    expect("진행 중 아래", v.bottom, DrumLine("다음", "11:00", "나"))

    // 3) 레슨 사이 시간: 끝난 레슨이 위로, 다음 레슨이 가운데
    v = NowNextDrum.compute(day, at(10, 55), 0)
    expect("사이 위", v.top, DrumLine("전", "10:00", "가"))
    expect("사이 가운데", v.center, DrumLine("다음", "11:00", "나"))
    expect("사이 아래", v.bottom, DrumLine("이후", "13:00", "다"))
    val gap = v

    // 4) 두 번째 레슨 시작: 줄 내용은 같고 이름표만 바뀐다(굴러가지 않음)
    v = NowNextDrum.compute(day, at(11, 10), 0)
    expect("시작 후 가운데", v.center, DrumLine("지금", "11:00", "나"))
    expect("이름표만 바뀌면 같은 모양", v.rowsSignature, gap.rowsSignature)
    expect("이름표는 다름", v.fullSignature == gap.fullSignature, false)

    // 5) 레슨이 끝나면 한 칸 굴러간다(줄 내용이 바뀐다)
    val before = NowNextDrum.compute(day, at(11, 40), 0)
    val after = NowNextDrum.compute(day, at(11, 55), 0)
    expect("끝나면 모양이 바뀜", before.rowsSignature == after.rowsSignature, false)

    // 6) 모두 끝남
    v = NowNextDrum.compute(day, at(14, 0), 0)
    expect("끝 가운데", v.center, DrumLine("", "", "오늘 끝"))
    expect("끝 위", v.top, DrumLine("전", "13:00", "다"))
    expect("끝 아래", v.bottom, null)
    expect("끝에서 아래로 훑기 불가", v.canPeekDown, false)

    // 7) 훑어보기: 앞으로/뒤로, 범위를 넘으면 멈춤
    v = NowNextDrum.compute(day, at(11, 10), -1)
    expect("뒤로 한 칸 가운데", v.center, DrumLine("전", "10:00", "가"))
    expect("뒤로 한 칸 peek", v.peek, -1)
    expect("맨 앞에서 위로 훑기 불가", v.canPeekUp, false)
    v = NowNextDrum.compute(day, at(11, 10), -9)
    expect("뒤로 범위 넘김", v.peek, -1)
    v = NowNextDrum.compute(day, at(11, 10), 1)
    expect("앞으로 한 칸 가운데", v.center, DrumLine("다음", "13:00", "다"))
    expect("앞으로 한 칸 아래", v.bottom, DrumLine("", "", "오늘 끝"))
    v = NowNextDrum.compute(day, at(11, 10), 9)
    expect("앞으로 범위 넘김", v.peek, 2)

    // 8) 레슨이 없는 날
    v = NowNextDrum.compute(emptyList(), at(11, 10), 0)
    expect("없는 날 가운데", v.center, DrumLine("", "", "오늘 레슨 없음"))
    expect("없는 날 위", v.top, null)
    expect("없는 날 훑기", listOf(v.canPeekUp, v.canPeekDown), listOf(false, false))

    // 9) 다음 갱신 시각(레슨 시작·종료 중 가장 가까운 때)
    expect("진행 중 → 종료 시각", NowNextDrum.nextEventAt(day, at(10, 20)), at(10, 50))
    expect("사이 → 시작 시각", NowNextDrum.nextEventAt(day, at(10, 55)), at(11, 0))
    expect("모두 끝 → 없음", NowNextDrum.nextEventAt(day, at(14, 0)), null)

    // 10) 겹치는 레슨: 먼저 끝나지 않은 레슨이 가운데
    val overlap = listOf(
        DrumLesson(at(10, 0), at(11, 30), "10:00", "긴"),
        DrumLesson(at(10, 30), at(11, 0), "10:30", "짧은"),
    )
    v = NowNextDrum.compute(overlap, at(10, 40), 0)
    expect("겹침 가운데", v.center, DrumLine("지금", "10:00", "긴"))
    expect("겹침 아래", v.bottom, DrumLine("지금", "10:30", "짧은"))

    println(if (failures == 0) "\n모두 통과" else "\n실패 $failures 건")
    if (failures != 0) kotlin.system.exitProcess(1)
}
