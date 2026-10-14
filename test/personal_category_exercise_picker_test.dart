import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_category_page.dart';

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openLowerBody(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 2600));
  await tester.pumpWidget(
    const MaterialApp(
      home: PersonalTrainingLogCategoryPage(
        initialName: '테스트 회원',
        autoOpenPreCheck: false,
      ),
    ),
  );
  await _show(tester, find.text('웨이트 트레이닝'));
  await tester.tap(find.text('웨이트 트레이닝'));
  await tester.pumpAndSettle();
  await _show(tester, find.text('하체'));
  await tester.tap(find.text('하체'));
  await tester.pumpAndSettle();
  await _show(tester, find.byKey(const Key('category_exercise_search')));
}

void main() {
  testWidgets('운동 목록은 가나다순으로 보이고 검색으로 걸러진다', (tester) async {
    await _openLowerBody(tester);

    final names =
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const Key('category_exercise_list')),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data)
            .toList();
    expect(names, ['레그익스텐션', '레그컬', '브릿지', '스쿼트']);

    await tester.enterText(
      find.byKey(const Key('category_exercise_search')),
      '레그',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category_exercise_row_브릿지')), findsNothing);
    expect(find.byKey(const Key('category_exercise_row_레그컬')), findsOneWidget);
    expect(find.byKey(const Key('category_exercise_add_row')), findsOneWidget);
  });

  testWidgets('목록에서 운동을 고르면 선택된 운동 구성에 들어간다', (tester) async {
    await _openLowerBody(tester);

    await tester.tap(find.byKey(const Key('category_exercise_row_스쿼트')));
    await tester.pumpAndSettle();

    expect(find.text('4) 선택된 운동 구성'), findsOneWidget);
  });

  testWidgets('없는 운동을 입력하면 추가 행이 나오고 긴 이름도 저장·선택된다', (tester) async {
    await _openLowerBody(tester);
    const longName = '아쿠아백 로테이션 불가리안 스플릿 스쿼트';

    await tester.enterText(
      find.byKey(const Key('category_exercise_search')),
      longName,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_exercise_add_row')));
    await tester.pumpAndSettle();

    expect(find.text('4) 선택된 운동 구성'), findsOneWidget);
    expect(
      find.byKey(const Key('category_exercise_row_$longName')),
      findsOneWidget,
    );
    expect(find.text('추가'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이미 있는 운동은 추가 행을 보여주지 않는다', (tester) async {
    await _openLowerBody(tester);

    await tester.enterText(
      find.byKey(const Key('category_exercise_search')),
      '스쿼트',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category_exercise_add_row')), findsNothing);
  });
}
