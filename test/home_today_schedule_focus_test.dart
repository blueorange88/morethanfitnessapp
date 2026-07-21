import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/home_today_schedule_focus.dart';

void main() {
  test('오늘 남은 다음 레슨 시간을 선택한다', () {
    final now = DateTime(2026, 7, 21, 13, 20);
    expect(
      resolveHomeTodayTargetHour(
        now: now,
        lessonStartTimes: [
          DateTime(2026, 7, 21, 12),
          DateTime(2026, 7, 21, 16),
          DateTime(2026, 7, 22, 14),
        ],
        startHour: 6,
        endHourExclusive: 23,
      ),
      16,
    );
  });

  test('남은 레슨이 없으면 현재 시간을 사용하고 범위 밖이면 clamp한다', () {
    expect(
      resolveHomeTodayTargetHour(
        now: DateTime(2026, 7, 21, 3),
        lessonStartTimes: const [],
        startHour: 6,
        endHourExclusive: 23,
      ),
      6,
    );
    expect(
      resolveHomeTodayTargetHour(
        now: DateTime(2026, 7, 21, 23, 30),
        lessonStartTimes: const [],
        startHour: 6,
        endHourExclusive: 23,
      ),
      22,
    );
  });
}
