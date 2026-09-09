import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/aifc_interaction.dart';

void main() {
  testWidgets('AIFC toast는 keyboard viewInsets 위로 이동한다', (tester) async {
    final keyboardInset = ValueNotifier<double>(0);
    addTearDown(() {
      AifcInteraction.hideToast();
      keyboardInset.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(384, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: keyboardInset,
          builder: (context, inset, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: EdgeInsets.only(bottom: inset),
            ),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AifcInteraction.toast(
      context: hostContext,
      message: '저장 결과',
      duration: const Duration(minutes: 1),
    );
    await tester.pump();
    expect(_toastPosition(tester).bottom, 76);

    keyboardInset.value = 280;
    await tester.pumpAndSettle();
    expect(_toastPosition(tester).bottom, 296);
    expect(tester.takeException(), isNull);
    AifcInteraction.hideToast();
    await tester.pump();
  });

  testWidgets('공통 feedback SnackBar는 keyboard 위에 표시된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    AifcInteraction.feedbackSnack(
      context: hostContext,
      message: '일정을 저장했어요.',
      duration: const Duration(minutes: 1),
    );
    await tester.pumpAndSettle();

    final snackBottom = tester.getBottomRight(find.byType(SnackBar)).dy;
    expect(snackBottom, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });
}

AnimatedPositioned _toastPosition(WidgetTester tester) {
  return tester.widget<AnimatedPositioned>(
    find.byWidgetPredicate(
      (widget) => widget is AnimatedPositioned && widget.left == 24,
    ),
  );
}
