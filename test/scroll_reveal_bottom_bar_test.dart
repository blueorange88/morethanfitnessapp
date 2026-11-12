import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/scroll_reveal_bottom_bar.dart';

Widget _host({bool forceVisible = false, VoidCallback? onBarTap}) {
  return MaterialApp(
    home: Scaffold(
      body: ScrollRevealBottomBar(
        forceVisible: forceVisible,
        bar: Container(
          key: const Key('bar'),
          height: 60,
          color: Colors.blue,
          child: TextButton(
            key: const Key('bar_button'),
            onPressed: onBarTap ?? () {},
            child: const Text('저장'),
          ),
        ),
        body: ListView(
          key: const Key('list'),
          children: [
            // 안쪽 가로 목록: 이 스크롤은 바에 영향을 주지 않는다.
            SizedBox(
              height: 80,
              child: ListView(
                key: const Key('horizontal'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 20; i++)
                    SizedBox(width: 120, child: Center(child: Text('h$i'))),
                ],
              ),
            ),
            for (var i = 0; i < 60; i++)
              SizedBox(height: 60, child: Text('row $i')),
          ],
        ),
      ),
    ),
  );
}

bool _barVisible(WidgetTester tester) {
  final slide = tester.widget<AnimatedSlide>(
    find.byKey(const Key('scroll_reveal_bottom_bar_slide')),
  );
  return slide.offset == Offset.zero;
}

void main() {
  testWidgets('처음에는 보이고, 내용을 아래로 내리면 숨고, 위로 올리면 다시 나타난다', (tester) async {
    await tester.pumpWidget(_host());
    expect(_barVisible(tester), isTrue);

    // 손가락을 위로 밀어 내용을 아래로 내린다.
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isFalse);

    // 계속 내려도 숨은 채다.
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isFalse);

    // 손가락을 아래로 밀어 내용을 위로 올리면 나타난다.
    await tester.drag(find.byKey(const Key('list')), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isTrue);
  });

  testWidgets('맨 아래 끝에 닿으면 숨겨졌더라도 다시 보인다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isFalse);

    // 끝까지 내린다.
    await tester.fling(
      find.byKey(const Key('list')),
      const Offset(0, -3000),
      4000,
    );
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isTrue);
  });

  testWidgets('맨 위로 돌아오면 보인다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isFalse);

    await tester.fling(
      find.byKey(const Key('list')),
      const Offset(0, 3000),
      4000,
    );
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isTrue);
  });

  testWidgets('안쪽 가로 목록을 밀어도 바는 그대로다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.drag(
      find.byKey(const Key('horizontal')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isTrue);
  });

  testWidgets('숨은 동안에는 바가 터치를 가로채지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(onBarTap: () => taps++));
    await tester.tap(find.byKey(const Key('bar_button')));
    expect(taps, 1);

    await tester.drag(find.byKey(const Key('list')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isFalse);
    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const Key('scroll_reveal_bottom_bar_slide')),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
  });

  testWidgets('키보드가 올라오면 숨고, forceVisible이면 항상 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    expect(_barVisible(tester), isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isFalse);

    // 키보드 중에도 저장 중이면(강제 표시) 보인다.
    await tester.pumpWidget(_host(forceVisible: true));
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isTrue);

    tester.view.resetViewInsets();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(_barVisible(tester), isTrue);
  });
}
