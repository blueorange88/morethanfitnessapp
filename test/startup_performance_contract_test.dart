import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('비필수 위젯 인터랙션 등록은 runApp 이후에 시작한다', () {
    final source = File('lib/main.dart').readAsStringSync();
    final runAppIndex = source.indexOf('\n  runApp(');
    final registrationIndex = source.indexOf(
      '_registerWidgetInteractivity()',
      runAppIndex,
    );

    expect(runAppIndex, greaterThanOrEqualTo(0));
    expect(registrationIndex, greaterThan(runAppIndex));
    expect(source, contains('WidgetsBinding.instance.addPostFrameCallback'));
  });

  test('Home의 위젯·알림 초기화는 첫 frame 이후에 시작한다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final initStateIndex = source.indexOf('void initState()');
    final postFrameIndex = source.indexOf(
      'WidgetsBinding.instance.addPostFrameCallback',
      initStateIndex,
    );
    final widgetSyncIndex = source.indexOf(
      "_queueHomeWidgetSync(source: 'appStart')",
      initStateIndex,
    );
    final notificationIndex = source.indexOf(
      'NotificationService.instance.initialize()',
      initStateIndex,
    );

    expect(postFrameIndex, greaterThan(initStateIndex));
    expect(widgetSyncIndex, greaterThan(postFrameIndex));
    expect(notificationIndex, greaterThan(postFrameIndex));
  });

  test('기존 익명 사용자는 profile을 먼저 읽고 누락 시에만 bootstrap한다', () {
    final source = File('lib/pages/account_gate.dart').readAsStringSync();
    final methodIndex = source.indexOf('_preparePersonalStart()');
    final firstReadIndex = source.indexOf(
      'PersonalStartStage.personalProfileRead',
      methodIndex,
    );
    final bootstrapIndex = source.indexOf(
      'PersonalStartStage.bootstrapAnonymousBeginnerProfile',
      methodIndex,
    );

    expect(firstReadIndex, greaterThan(methodIndex));
    expect(bootstrapIndex, greaterThan(firstReadIndex));
    expect(
      source,
      contains('PersonalProfileReadErrorCode.profileNotFound'),
    );
  });
}
