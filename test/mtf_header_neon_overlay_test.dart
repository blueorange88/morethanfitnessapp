import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/mtf_header_neon_overlay.dart';

void main() {
  testWidgets('최초 진입 애니메이션은 끝난 뒤 ticker를 계속 돌리지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MtfHeaderNeonOverlay(
            isExpanded: false,
            child: SizedBox(key: Key('header'), height: 120),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('접기 전환 때만 다시 재생하고 완료 후 멈춘다', (tester) async {
    final expanded = ValueNotifier<bool>(false);
    addTearDown(expanded.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: expanded,
          builder: (_, value, __) => MtfHeaderNeonOverlay(
            isExpanded: value,
            child: const SizedBox(height: 120),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expanded.value = true;
    await tester.pumpAndSettle();
    expanded.value = false;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduce motion에서는 네온 애니메이션을 만들지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MtfHeaderNeonOverlay(
            isExpanded: false,
            child: SizedBox(key: Key('reduced_header'), height: 120),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('reduced_header')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MtfHeaderNeonOverlay),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
