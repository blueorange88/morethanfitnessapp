import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('마이페이지 저장은 등급 재계산을 기다리지 않고 뒤에서 처리한다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();

    // 저장 흐름(프로필 저장 호출 ~ 저장 확인 읽기) 안에서는 재계산을 기다리지 않는다.
    final saveStart = source.indexOf("activeSaveStep = 'profile';");
    final saveEnd = source.indexOf("activeSaveStep = 'none';", saveStart);
    expect(saveStart, greaterThan(0));
    expect(saveEnd, greaterThan(saveStart));
    final saveFlow = source.substring(saveStart, saveEnd);
    expect(saveFlow, contains('unawaited(_reconcileTierThenRefresh(uid));'));
    expect(saveFlow, isNot(contains('reconcilePersonalTier()')));
    expect(saveFlow, isNot(contains('await _loadTierStatus()')));

    // 뒤에서 하는 일: 재계산 → (실패해도) 등급 상태 갱신, 화면이 닫혔으면 갱신하지 않는다.
    final helperStart = source.indexOf(
      'Future<void> _reconcileTierThenRefresh(',
    );
    final helperEnd = source.indexOf(
      'Future<void> _loadTierStatus()',
      helperStart,
    );
    final helper = source.substring(helperStart, helperEnd);
    expect(helper, contains('reconcilePersonalTier()'));
    expect(helper, contains('catch (error)'));
    expect(helper, contains('if (!mounted) return;'));
    expect(
      helper.indexOf('reconcilePersonalTier()'),
      lessThan(helper.indexOf('await _loadTierStatus()')),
    );

    // 저장된 값 확인 읽기(서버 기준)는 그대로 저장 흐름 안에 있다.
    expect(saveFlow, contains('Source.server'));
    expect(
      saveFlow,
      contains("throw StateError('personal_profile_refresh_failed')"),
    );
  });
}
