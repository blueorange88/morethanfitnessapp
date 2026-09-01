import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_account_service.dart';

void main() {
  const anonymous = AppAccountUser(
    uid: 'anonymous-uid',
    email: '',
    emailVerified: false,
    isAnonymous: true,
  );
  const linked = AppAccountUser(
    uid: 'anonymous-uid',
    email: 'trainer@example.com',
    emailVerified: false,
    isAnonymous: false,
  );

  test('user가 없으면 anonymous session을 한 번 생성한다', () async {
    final gateway = _FakeIdentityGateway(anonymousResult: anonymous);
    final result = await AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _FakeProfileGateway(),
    ).ensureAnonymousSession();

    expect(result, anonymous);
    expect(gateway.anonymousCalls, 1);
  });

  test('동시 anonymous session 요청은 같은 Future와 UID를 사용한다', () async {
    final completer = Completer<AppAccountUser>();
    final gateway = _FakeIdentityGateway(anonymousCompleter: completer);
    final service = AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _FakeProfileGateway(),
    );

    final first = service.ensureAnonymousSession();
    final second = service.ensureAnonymousSession();
    expect(identical(first, second), isTrue);
    completer.complete(anonymous);

    expect((await first).uid, anonymous.uid);
    expect((await second).uid, anonymous.uid);
    expect(gateway.anonymousCalls, 1);
  });

  test('기존 anonymous session은 새 인증 없이 재사용한다', () async {
    final gateway = _FakeIdentityGateway(currentUser: anonymous);
    final result = await AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _FakeProfileGateway(),
    ).ensureAnonymousSession();

    expect(result, anonymous);
    expect(gateway.anonymousCalls, 0);
  });

  test('기존 linked user도 변경하지 않고 반환한다', () async {
    final gateway = _FakeIdentityGateway(currentUser: linked);
    final result = await AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _FakeProfileGateway(),
    ).ensureAnonymousSession();

    expect(result, linked);
    expect(gateway.anonymousCalls, 0);
  });

  test('anonymous provider 비활성 오류를 구분한다', () async {
    final gateway = _FakeIdentityGateway(
      anonymousError: const AppAccountException(
        AppAccountErrorCode.anonymousProviderDisabled,
      ),
    );
    final service = AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _FakeProfileGateway(),
    );

    await expectLater(
      service.ensureAnonymousSession(),
      _failsWith(AppAccountErrorCode.anonymousProviderDisabled),
    );
  });

  test('anonymous profile bootstrap은 별도 server gateway만 호출한다', () async {
    final gateway = _FakeIdentityGateway(currentUser: anonymous);
    final profile = _FakeProfileGateway();
    await AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: profile,
    ).bootstrapAnonymousBeginnerProfile();

    expect(profile.bootstrapCalls, 1);
    expect(profile.transitionCalls, 0);
  });

  test('이메일 연결은 link, token refresh, profile 전환 순서로 UID를 유지한다', () async {
    final steps = <String>[];
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkedResult: linked,
      steps: steps,
    );
    final profile = _FakeProfileGateway(steps: steps);

    final result = await AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: profile,
    ).linkAnonymousWithEmail(
      email: ' trainer@example.com ',
      password: 'password-123',
    );

    expect(result.uid, anonymous.uid);
    expect(result.isAnonymous, isFalse);
    expect(gateway.linkedEmail, 'trainer@example.com');
    expect(steps, ['link', 'refresh', 'transition']);
  });

  test('인증 link 후 profile 전환이 실패해도 같은 UID에서 재시도를 재개한다', () async {
    final steps = <String>[];
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkedResult: linked,
      steps: steps,
    );
    final profile = _FakeProfileGateway(
      steps: steps,
      transitionErrors: [
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'network unavailable',
        ),
      ],
    );
    final service = AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: profile,
    );

    await expectLater(
      service.linkAnonymousWithEmail(
        email: 'trainer@example.com',
        password: 'password-123',
      ),
      _failsWith(AppAccountErrorCode.network),
    );
    expect(gateway.currentUser?.isAnonymous, isFalse);

    final resumed = await service.linkAnonymousWithEmail(
      email: 'trainer@example.com',
      password: 'password-123',
    );

    expect(resumed.uid, anonymous.uid);
    expect(steps, ['link', 'refresh', 'transition', 'refresh', 'transition']);
    expect(gateway.linkCalls, 1);
    expect(profile.transitionCalls, 2);
  });

  test('Functions unavailable은 재시도 가능한 네트워크 오류로 번역한다', () async {
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkedResult: linked,
    );
    final profile = _FakeProfileGateway(
      transitionErrors: [
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'network unavailable',
        ),
      ],
    );

    await expectLater(
      AppAccountService(
        gateway: gateway,
        anonymousGateway: gateway,
        profileGateway: profile,
      ).linkAnonymousWithEmail(
        email: 'trainer@example.com',
        password: 'password-123',
      ),
      _failsWith(AppAccountErrorCode.network),
    );
    expect(
      appAccountErrorMessage(
        const AppAccountException(AppAccountErrorCode.network),
      ),
      contains('이 화면에서 다시 시도'),
    );
  });

  test('Firebase Auth internal-error의 DNS 원인도 네트워크 오류로 번역한다', () async {
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkError: FirebaseAuthException(
        code: 'internal-error',
        message: 'UnknownHostException: Unable to resolve host',
      ),
    );

    await expectLater(
      AppAccountService(
        gateway: gateway,
        anonymousGateway: gateway,
        profileGateway: _FakeProfileGateway(),
      ).linkAnonymousWithEmail(
        email: 'trainer@example.com',
        password: 'password-123',
      ),
      _failsWith(AppAccountErrorCode.network),
    );
  });

  test('비활성 Email/Password provider는 일반 오류와 구분한다', () async {
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkError: FirebaseAuthException(code: 'operation-not-allowed'),
    );

    await expectLater(
      AppAccountService(
        gateway: gateway,
        anonymousGateway: gateway,
        profileGateway: _FakeProfileGateway(),
      ).linkAnonymousWithEmail(
        email: 'trainer@example.com',
        password: 'password-123',
      ),
      _failsWith(AppAccountErrorCode.emailPasswordProviderDisabled),
    );
    expect(
      appAccountErrorMessage(
        const AppAccountException(
          AppAccountErrorCode.emailPasswordProviderDisabled,
        ),
      ),
      contains('활성화되지 않았어요'),
    );
  });

  test('재시작 후 linked Auth는 link 재호출 없이 profile 전환만 마무리한다', () async {
    final steps = <String>[];
    final gateway = _FakeIdentityGateway(currentUser: linked, steps: steps);
    final profile = _FakeProfileGateway(steps: steps);

    final result = await AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: profile,
    ).completeCurrentEmailLink();

    expect(result.uid, anonymous.uid);
    expect(gateway.linkCalls, 0);
    expect(steps, ['refresh', 'transition']);
  });

  test('연결 결과 UID가 바뀌면 profile 전환 없이 실패한다', () async {
    const changed = AppAccountUser(
      uid: 'different-uid',
      email: 'trainer@example.com',
      emailVerified: false,
      isAnonymous: false,
    );
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkedResult: changed,
    );
    final profile = _FakeProfileGateway();

    await expectLater(
      AppAccountService(
        gateway: gateway,
        anonymousGateway: gateway,
        profileGateway: profile,
      ).linkAnonymousWithEmail(
        email: 'trainer@example.com',
        password: 'password-123',
      ),
      _failsWith(AppAccountErrorCode.uidChangedUnexpectedly),
    );
    expect(gateway.refreshCalls, 0);
    expect(profile.transitionCalls, 0);
  });

  test('기존 이메일 충돌은 자동 병합 없이 typed error를 유지한다', () async {
    final gateway = _FakeIdentityGateway(
      currentUser: anonymous,
      linkError: const AppAccountException(
        AppAccountErrorCode.credentialAlreadyInUse,
      ),
    );
    final profile = _FakeProfileGateway();

    await expectLater(
      AppAccountService(
        gateway: gateway,
        anonymousGateway: gateway,
        profileGateway: profile,
      ).linkAnonymousWithEmail(
        email: 'existing@example.com',
        password: 'password-123',
      ),
      _failsWith(AppAccountErrorCode.credentialAlreadyInUse),
    );
    expect(gateway.signOutCalls, 0);
    expect(profile.transitionCalls, 0);
  });
}

Matcher _failsWith(AppAccountErrorCode code) => throwsA(
      isA<AppAccountException>().having((error) => error.code, 'code', code),
    );

class _FakeIdentityGateway
    implements AppAccountAuthGateway, AppAnonymousIdentityGateway {
  _FakeIdentityGateway({
    this.currentUser,
    this.anonymousResult,
    this.anonymousCompleter,
    this.anonymousError,
    this.linkedResult,
    this.linkError,
    this.steps,
  });

  @override
  AppAccountUser? currentUser;
  final AppAccountUser? anonymousResult;
  final Completer<AppAccountUser>? anonymousCompleter;
  final Object? anonymousError;
  final AppAccountUser? linkedResult;
  final Object? linkError;
  final List<String>? steps;
  int anonymousCalls = 0;
  int refreshCalls = 0;
  int linkCalls = 0;
  int signOutCalls = 0;
  String? linkedEmail;

  @override
  Stream<AppAccountUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AppAccountUser> signInAnonymously() async {
    anonymousCalls += 1;
    if (anonymousError != null) throw anonymousError!;
    final result = anonymousCompleter == null
        ? anonymousResult!
        : await anonymousCompleter!.future;
    currentUser = result;
    return result;
  }

  @override
  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  }) async {
    linkCalls += 1;
    steps?.add('link');
    linkedEmail = email;
    if (linkError != null) throw linkError!;
    final result = linkedResult!;
    currentUser = result;
    return result;
  }

  @override
  Future<void> forceRefreshIdToken() async {
    refreshCalls += 1;
    steps?.add('refresh');
  }

  @override
  Future<AppAccountUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    currentUser = null;
  }
}

class _FakeProfileGateway implements AnonymousProfileGateway {
  _FakeProfileGateway({this.steps, List<Object>? transitionErrors})
      : transitionErrors = transitionErrors ?? <Object>[];

  final List<String>? steps;
  final List<Object> transitionErrors;
  int bootstrapCalls = 0;
  int transitionCalls = 0;

  @override
  Future<void> bootstrapAnonymousBeginnerProfile() async {
    bootstrapCalls += 1;
  }

  @override
  Future<void> transitionAnonymousProfileToLinked() async {
    transitionCalls += 1;
    steps?.add('transition');
    if (transitionErrors.isNotEmpty) throw transitionErrors.removeAt(0);
  }

  @override
  Future<Map<String, dynamic>> reconcilePersonalTier() async => const {
        'tier': 'Beginner',
        'amateurConditionCount': 0,
        'amateurConditionTotal': 2,
        'eligible': false,
        'changed': false,
      };
}
