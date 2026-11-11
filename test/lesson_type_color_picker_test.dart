import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_type_editor_panel.dart';
import 'package:mtf_app/widgets/lesson_type_color_picker.dart';

void main() {
  group('LessonTypeColorDialog', () {
    Future<Color?> open(
      WidgetTester tester,
      Future<void> Function() act,
    ) async {
      Color? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<Color>(
                      context: context,
                      builder:
                          (_) => const LessonTypeColorDialog(
                            title: '색 직접 고르기',
                            initial: Color(0xFF4F46E5),
                          ),
                    );
                  },
                  child: const Text('열기'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await act();
      return result;
    }

    testWidgets('색 코드를 넣고 적용하면 그 색이 돌아온다', (tester) async {
      final result = await open(tester, () async {
        await tester.enterText(
          find.byKey(const ValueKey('lesson_type_color_hex')),
          '#12AB34',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('lesson_type_color_apply')));
        await tester.pumpAndSettle();
      });
      expect(result, const Color(0xFF12AB34));
    });

    testWidgets('색 코드가 잘못되면 적용할 수 없다', (tester) async {
      await open(tester, () async {
        await tester.enterText(
          find.byKey(const ValueKey('lesson_type_color_hex')),
          'ZZZ',
        );
        await tester.pump();
        final apply = tester.widget<FilledButton>(
          find.byKey(const ValueKey('lesson_type_color_apply')),
        );
        expect(apply.onPressed, isNull);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
      });
    });
  });

  group('HomeLessonTypeEditorPanel', () {
    Widget panel({
      required String selected,
      VoidCallback? onCustom,
      ValueChanged<String>? onSelect,
    }) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeLessonTypeEditorPanel(
            isEditMode: false,
            nameController: TextEditingController(),
            selectedColorHex: selected,
            paletteColorHexes: [
              for (final c in kLessonTypePalette) lessonTypeColorToHex(c),
            ],
            onColorSelected: onSelect ?? (_) {},
            onCustomColorTap: onCustom,
            onClose: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    testWidgets('+ 버튼이 있고, 누르면 직접 고르기를 연다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        panel(selected: '#4F46E5', onCustom: () => taps++),
      );
      await tester.tap(find.byKey(const ValueKey('lesson_type_color_custom')));
      expect(taps, 1);
    });

    testWidgets('onCustomColorTap이 없으면 + 버튼이 없다', (tester) async {
      await tester.pumpWidget(panel(selected: '#4F46E5'));
      expect(
        find.byKey(const ValueKey('lesson_type_color_custom')),
        findsNothing,
      );
    });

    testWidgets('팔레트에 없는 색을 고른 상태면 선택된 원으로 따로 보인다', (tester) async {
      await tester.pumpWidget(panel(selected: '#123456'));
      expect(
        find.byKey(const ValueKey('lesson_type_color_#123456')),
        findsOneWidget,
      );
    });

    testWidgets('팔레트의 색을 누르면 그 색이 선택된다', (tester) async {
      String? picked;
      await tester.pumpWidget(
        panel(selected: '#4F46E5', onSelect: (v) => picked = v),
      );
      await tester.tap(find.byKey(const ValueKey('lesson_type_color_#D64545')));
      expect(picked, '#D64545');
    });
  });
}
