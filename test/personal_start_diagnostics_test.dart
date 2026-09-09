import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/personal_start_diagnostics.dart';

void main() {
  test('Functions 실패는 코드만 기록하고 원문 메시지의 개인정보는 남기지 않는다', () async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    final functionsError = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'email=private@example.com uid=secret-uid',
    );

    await expectLater(
      PersonalStartDiagnostics.run<void>(
        PersonalStartStage.bootstrapAnonymousBeginnerProfile,
        () async => throw AppAccountException(
          AppAccountErrorCode.unknown,
          cause: functionsError,
        ),
      ),
      throwsA(isA<PersonalStartException>()),
    );

    final failure = logs.singleWhere((line) => line.contains(' failure '));
    expect(failure, contains('runtimeType=FirebaseFunctionsException'));
    expect(failure, contains('firebaseCode=unavailable'));
    expect(failure, contains('functionsCode=unavailable'));
    expect(failure, contains('message=Firebase Functions request failed'));
    expect(failure, isNot(contains('private@example.com')));
    expect(failure, isNot(contains('secret-uid')));
  });

  test('시작 실패 종류를 사용자 안내 단계로 구분한다', () {
    expect(
      PersonalStartDiagnostics.failureKind(
        const PersonalStartException(
          stage: PersonalStartStage.ensureAnonymousSession,
          cause: AppAccountException(AppAccountErrorCode.network),
        ),
      ),
      PersonalStartFailureKind.anonymousAccount,
    );
    expect(
      PersonalStartDiagnostics.failureKind(
        const PersonalStartException(
          stage: PersonalStartStage.personalProfileRead,
          cause: AppAccountException(AppAccountErrorCode.network),
        ),
      ),
      PersonalStartFailureKind.firestore,
    );
  });
}
