import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_day_selector.dart';
import 'package:mtf_app/widgets/home/sections/home_recent_clients_section.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      darkTheme: theme,
      themeMode:
          theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
      home: Scaffold(
        body: HomeLessonDaySelector(
          allDays: const ['월', '화', '수', '목', '금'],
          selectedDays: const {'화'},
          activeColor: const Color(0xFF0B1B3A),
          onDayTapped: (_) {},
        ),
      ),
    ),
  );
}

Color _textColor(WidgetTester tester, String day) =>
    tester.widget<Text>(find.text(day)).style!.color!;

BoxDecoration _chip(WidgetTester tester, String day) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(day), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('다크모드: 선택·미선택 요일 글자가 배경과 충분히 대비된다', (tester) async {
    await _pump(tester, ThemeData.dark());
    final background = ThemeData.dark().scaffoldBackgroundColor;
    for (final day in ['월', '화']) {
      final chip = Color.alphaBlend(_chip(tester, day).color!, background);
      expect(
        _contrast(_textColor(tester, day), chip),
        greaterThanOrEqualTo(4.5),
        reason: '$day 글자 대비',
      );
    }
  });

  testWidgets('선택한 요일은 레슨계약서 칩과 같은 배경·테두리·글자색이다', (tester) async {
    // 라이트
    await _pump(tester, ThemeData.light());
    var selected = _chip(tester, '화');
    expect(selected.color, const Color(0xFFFFF1C2));
    expect((selected.border! as Border).top.color, const Color(0xFFEFCB62));
    expect(_textColor(tester, '화'), const Color(0xFF0B1E32));
    // 선택하지 않은 요일은 기존 회색 칩
    expect(_textColor(tester, '월'), Colors.black87);
    expect(_chip(tester, '월').color, Colors.grey.shade100);

    // 다크
    await _pump(tester, ThemeData.dark());
    await tester.pumpAndSettle();
    selected = _chip(tester, '화');
    expect(selected.color, const Color(0xFF4A401F));
    expect((selected.border! as Border).top.color, const Color(0xFFEFCB62));
    expect(_textColor(tester, '화'), const Color(0xFFFFF4CF));
  });

  testWidgets('요일을 누르면 콜백에 요일이 전달된다', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeLessonDaySelector(
            allDays: const ['월', '화'],
            selectedDays: const {},
            onDayTapped: (day) => tapped = day,
          ),
        ),
      ),
    );
    await tester.tap(find.text('화'));
    expect(tapped, '화');
  });

  group('홈 하단 최근 회원 머리말', () {
    Future<void> pumpHeader(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          darkTheme: theme,
          themeMode:
              theme.brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
          home: Scaffold(
            body: HomeRecentClientsHeader(
              primaryColor: const Color(0xFF0B1B3A),
              onOpenAllTap: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('다크모드에서 제목과 전체보기가 배경에 묻히지 않는다', (tester) async {
      await pumpHeader(tester, ThemeData.dark());
      final background = ThemeData.dark().scaffoldBackgroundColor;
      for (final label in ['최근 회원', '전체보기']) {
        final color = tester.widget<Text>(find.text(label)).style!.color!;
        expect(
          _contrast(color, background),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }
    });

    testWidgets('라이트모드는 전체보기가 기존 남색이다', (tester) async {
      await pumpHeader(tester, ThemeData.light());
      expect(
        tester.widget<Text>(find.text('전체보기')).style!.color,
        const Color(0xFF0B1B3A),
      );
    });

    testWidgets('전체보기를 누르면 콜백이 불린다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeRecentClientsHeader(
              primaryColor: const Color(0xFF0B1B3A),
              onOpenAllTap: () => tapped++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('전체보기'));
      expect(tapped, 1);
    });
  });
}
