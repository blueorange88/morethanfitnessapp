import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/home/schedule/home_weekly_schedule_table.dart';
import 'package:mtf_app/widgets/home/sections/home_recent_clients_section.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> _pumpTable(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: HomeWeeklyScheduleTable(
            dayFilter: 'weekend',
            weekOffset: 0,
            scheduleData: const {},
            // 2026-08-08 은 토요일이라 `토` 칸이 오늘 칸이다.
            currentTime: DateTime(2026, 8, 8, 9, 30),
            timeSlots: const ['09:00', '10:00'],
            onCellTap: (_, __, ___) {},
          ),
        ),
      ),
    ),
  );
}

Color? _headerBackground(WidgetTester tester, String day) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(day), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  group('홈 시간표 요일 줄의 오늘 칸', () {
    testWidgets('다크모드: 밝은 금색 배경 + 남색 글자로 어두운 헤더와 구분된다', (tester) async {
      await _pumpTable(tester, darkTheme());
      final background = _headerBackground(tester, '토')!;
      final text = tester.widget<Text>(find.text('토')).style!.color!;
      expect(background, AppColors.warmYellow);
      expect(text, AppColors.deepNavy);
      expect(_contrast(text, background), greaterThanOrEqualTo(4.5));
      // 오늘이 아닌 칸은 기존 헤더색 위의 밝은 글자
      expect(_headerBackground(tester, '일'), AppColors.deepNavy);
      expect(
        tester.widget<Text>(find.text('일')).style!.color,
        AppColors.darkTextPrimary,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('라이트모드는 기존 연한 노란색 + 남색 글자 그대로', (tester) async {
      await _pumpTable(tester, lightTheme());
      expect(_headerBackground(tester, '토'), const Color(0xFFFFF1C2));
      expect(
        tester.widget<Text>(find.text('토')).style!.color,
        AppColors.deepNavy,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('최근 회원 아바타', () {
    Future<void> pumpAvatars(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Row(
              children: [
                for (var i = 0; i < 4; i++) HomeRecentClientAvatar(index: i),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('이름 약자 대신 사람 모양 아이콘만 들어간다', (tester) async {
      await pumpAvatars(tester, lightTheme());
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(4));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('다크모드: 어두운 배경 위에 밝은 아이콘(대비 3 이상)', (tester) async {
      await pumpAvatars(tester, darkTheme());
      final icons = tester.widgetList<Icon>(find.byIcon(Icons.person_rounded));
      final containers =
          tester
              .widgetList<Container>(
                find.descendant(
                  of: find.byType(HomeRecentClientAvatar),
                  matching: find.byType(Container),
                ),
              )
              .toList();
      expect(containers, hasLength(4));
      for (var i = 0; i < 4; i++) {
        final bg = (containers[i].decoration! as BoxDecoration).color!;
        expect(bg.computeLuminance(), lessThan(0.15), reason: '배경 $i 어두움');
        expect(
          _contrast(icons.elementAt(i).color!, bg),
          greaterThanOrEqualTo(3),
          reason: '아이콘 $i 대비',
        );
      }
    });

    testWidgets('라이트모드는 연한 파스텔 배경 + 진한 아이콘 그대로', (tester) async {
      await pumpAvatars(tester, lightTheme());
      final first = tester.widget<Container>(
        find.descendant(
          of: find.byType(HomeRecentClientAvatar).first,
          matching: find.byType(Container),
        ),
      );
      expect(
        (first.decoration! as BoxDecoration).color,
        const Color(0xFFEEF2FF),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.person_rounded).first).color,
        const Color(0xFF4338CA),
      );
    });
  });
}
