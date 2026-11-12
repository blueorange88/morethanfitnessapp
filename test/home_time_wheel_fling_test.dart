import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('시간 휠은 선택이 바뀔 때 휠을 다시 애니메이션하지 않아 빠른 스와이프 관성을 유지한다', () {
    final source =
        File(
          'lib/widgets/home/lesson_editor/home_single_lesson_time_dialog.dart',
        ).readAsStringSync();

    expect(
      source,
      contains('void syncInputsFromPickedTime({bool animateWheels = true})'),
    );
    expect(source, contains('if (!useKeyboard && animateWheels) {'));
    expect(
      RegExp(
        r'tempHour = idx;\s*syncInputsFromPickedTime\(\s*animateWheels: false,?\s*\);',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'tempMinute = validMinutes\[idx\];\s*'
        r'syncInputsFromPickedTime\(\s*animateWheels: false,?\s*\);',
      ).hasMatch(source),
      isTrue,
    );
  });
}
