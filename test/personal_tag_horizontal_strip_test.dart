import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/personal_tag_horizontal_strip.dart';

Widget _testApp({
  required double width,
  required int tagCount,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? lightTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: PersonalTagHorizontalStrip(
            height: 32,
            fixedLeading: PersonalTagManagementButton(
              dimension: 32,
              onPressed: () {},
            ),
            children: [
              for (var index = 0; index < tagCount; index++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(label: Text('태그 $index')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in <double>[320, 360, 384, 411]) {
    for (final count in <int>[1, 5, 10, 20]) {
      testWidgets('${width.toInt()}dp 태그 $count개에서도 관리 버튼은 고정된다',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_testApp(width: width, tagCount: count));

        final settings = find.byKey(
          const ValueKey('personal_tag_management_button'),
        );
        final scroll = find.byKey(
          const ValueKey('personal_tag_horizontal_scroll'),
        );
        expect(settings, findsOneWidget);
        expect(scroll, findsOneWidget);
        final before = tester.getTopLeft(settings);
        expect(
            tester.getSize(find.byType(PersonalTagHorizontalStrip)).height, 32);

        if (count > 5) {
          await tester.drag(scroll, const Offset(-600, 0));
          await tester.pumpAndSettle();
        }

        expect(tester.getTopLeft(settings), before);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('관리 버튼은 태그 관리 semantics와 tooltip을 제공한다', (tester) async {
    await tester.pumpWidget(_testApp(width: 320, tagCount: 20));
    expect(find.byTooltip('태그 관리'), findsOneWidget);
    expect(find.bySemanticsLabel('태그 관리'), findsOneWidget);
  });

  for (final theme in <MapEntry<String, ThemeData>>[
    MapEntry('light', lightTheme()),
    MapEntry('dark', darkTheme()),
    MapEntry('lululala', lululalaTheme()),
  ]) {
    testWidgets('${theme.key} 테마에서 20개 태그 한 줄 strip이 overflow 없이 표시된다',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _testApp(width: 320, tagCount: 20, theme: theme.value),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
