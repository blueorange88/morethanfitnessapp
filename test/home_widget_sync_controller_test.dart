import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_widget_sync_controller.dart';

void main() {
  test('동시에 요청된 위젯 동기화를 순서대로 실행한다', () async {
    final controller = HomeWidgetSyncController();
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondCompleted = Completer<void>();

    controller.runNow(syncAction: () async {
      firstStarted.complete();
      await releaseFirst.future;
    });
    await firstStarted.future;

    controller.runNow(syncAction: () async {
      secondCompleted.complete();
    });
    await Future<void>.delayed(Duration.zero);

    expect(secondCompleted.isCompleted, isFalse);
    releaseFirst.complete();
    await secondCompleted.future;
    controller.dispose();
  });

  test('실패한 위젯 동기화 뒤에도 다음 요청을 실행한다', () async {
    final controller = HomeWidgetSyncController();
    final failedActionStarted = Completer<void>();
    final nextCompleted = Completer<void>();

    controller.runNow(syncAction: () async {
      failedActionStarted.complete();
      throw StateError('expected failure');
    });
    await failedActionStarted.future;
    await Future<void>.delayed(Duration.zero);

    controller.runNow(syncAction: () async {
      nextCompleted.complete();
    });
    await nextCompleted.future;
    controller.dispose();
  });
}
