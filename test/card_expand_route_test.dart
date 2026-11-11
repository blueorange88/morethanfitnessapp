import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/card_expand_route.dart';

class _CountingPage extends StatefulWidget {
  const _CountingPage({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(onPressed: () {}, child: const Text('등록 화면')),
      ),
    );
  }
}

void main() {
  testWidgets('카드가 떠올라 화면을 덮고 새 화면으로 바뀌며 뒤로 가면 카드로 돌아간다', (tester) async {
    var initCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      CardExpandRoute<void>(
                        originRect: const Rect.fromLTWH(20, 500, 320, 200),
                        originFace: const Center(child: Text('카드 얼굴')),
                        builder:
                            (_) => _CountingPage(onInit: () => initCount++),
                      ),
                    );
                  },
                  child: const Text('열기'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pump();

    // 전환 중에는 새 화면을 누를 수 없다.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    final guards = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.byType(_CountingPage),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(guards.any((guard) => guard.ignoring), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('등록 화면'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 전환이 끝나도 화면이 다시 만들어지지 않는다(입력 상태 유지).
    expect(initCount, 1);
    // 끝난 뒤에는 눌린다.
    await tester.tap(find.text('등록 화면'));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('등록 화면'), findsNothing);
    expect(find.text('열기'), findsOneWidget);
  });
}
