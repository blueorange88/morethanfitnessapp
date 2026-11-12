import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/schedule/home_weekly_schedule_table.dart';

Future<void> _pump(WidgetTester tester, String colorHex) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: HomeWeeklyScheduleTable(
            dayFilter: 'weekend',
            weekOffset: 0,
            scheduleData: {
              'a': {
                'name': '홍길동',
                // 2026-08-08 은 토요일.
                'startAt': DateTime(2026, 8, 8, 9, 0),
                'endAt': DateTime(2026, 8, 8, 10, 0),
                'typeColorHex': colorHex,
              },
            },
            currentTime: DateTime(2026, 8, 8, 9, 30),
            timeSlots: const ['09:00', '10:00'],
            onCellTap: (_, __, ___) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('홈 시간표 레슨 블록 글씨 색', () {
    testWidgets('어두운 레슨 종류 색에서는 흰 글씨', (tester) async {
      await _pump(tester, '#4F46E5');
      expect(tester.widget<Text>(find.text('홍길동')).style!.color, Colors.white);
    });

    testWidgets('흰색 같은 밝은 레슨 종류 색에서는 짙은 글씨로 바뀐다', (tester) async {
      await _pump(tester, '#FFFFFF');
      expect(
        tester.widget<Text>(find.text('홍길동')).style!.color,
        const Color(0xFF1F2937),
      );
    });
  });
}
