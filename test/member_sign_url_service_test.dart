import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_environment.dart';
import 'package:mtf_app/services/member_sign_url_service.dart';

void main() {
  test('DEV 서명 링크는 DEV Hosting만 사용한다', () {
    final uri = MemberSignUrlService.buildForEnvironment(
      token: 'dev-token',
      environment: AppEnvironment.dev,
    );

    expect(uri.host, 'more-than-fitness-dev-mft.web.app');
    expect(uri.path, '/sign');
    expect(uri.queryParameters['t'], 'dev-token');
    expect(uri.toString(), isNot(contains('more-than-fitness-f6adb')));
  });

  test('PROD 서명 링크는 기존 PROD Hosting을 유지한다', () {
    final uri = MemberSignUrlService.buildForEnvironment(
      token: 'prod-token',
      environment: AppEnvironment.prod,
    );

    expect(uri.host, 'more-than-fitness-f6adb.web.app');
    expect(uri.queryParameters['t'], 'prod-token');
  });

  test('빈 token 링크는 생성하지 않는다', () {
    expect(
      () => MemberSignUrlService.buildForEnvironment(
        token: ' ',
        environment: AppEnvironment.dev,
      ),
      throwsArgumentError,
    );
  });

  test('웹 서명 실패 로그는 예외 원문을 출력하지 않는다', () {
    final source = File(
      'lib/pages/member_signature_web_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("실패: \$e")));
  });
}
