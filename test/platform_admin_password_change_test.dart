import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/account_gate.dart';
import 'package:mtf_app/pages/password_change_page.dart';
import 'package:mtf_app/services/account_claims_service.dart';
import 'package:mtf_app/services/account_password_service.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/linked_account_access_service.dart';
import 'package:mtf_app/services/personal_profile_start_reader.dart';

void main() {
  test('새 비밀번호 확인이 다르면 인증 호출 전에 거부한다', () async {
    final gateway = _FakePasswordGateway();
    final service = AccountPasswordService(gateway: gateway);

    await expectLater(
      service.changePassword(
        currentPassword: _secret(1),
        newPassword: _secret(2),
        confirmation: _secret(3),
      ),
      _passwordFailure(AccountPasswordErrorCode.confirmationMismatch),
    );
    expect(gateway.reauthenticateCalls, 0);
  });

  test('현재 비밀번호 오류를 구분하고 update를 실행하지 않는다', () async {
    final gateway = _FakePasswordGateway(
      reauthenticateError: const AccountPasswordException(
        AccountPasswordErrorCode.invalidCurrentPassword,
      ),
    );
    final service = AccountPasswordService(gateway: gateway);

    await expectLater(
      service.changePassword(
        currentPassword: _secret(1),
        newPassword: _secret(2),
        confirmation: _secret(2),
      ),
      _passwordFailure(AccountPasswordErrorCode.invalidCurrentPassword),
    );
    expect(gateway.updateCalls, 0);
  });

  test('비밀번호 변경 후 token refresh와 finalize를 순서대로 실행한다', () async {
    final gateway = _FakePasswordGateway();
    await AccountPasswordService(gateway: gateway).changePassword(
      currentPassword: _secret(1),
      newPassword: _secret(2),
      confirmation: _secret(2),
    );

    expect(gateway.steps, ['reauthenticate', 'update', 'refresh', 'finalize']);
  });

  test('updatePassword 실패 시 token refresh와 finalize를 실행하지 않는다', () async {
    final gateway = _FakePasswordGateway(
      updateError: const AccountPasswordException(
        AccountPasswordErrorCode.weakPassword,
      ),
    );

    await expectLater(
      AccountPasswordService(gateway: gateway).changePassword(
        currentPassword: _secret(1),
        newPassword: _secret(2),
        confirmation: _secret(2),
      ),
      _passwordFailure(AccountPasswordErrorCode.weakPassword),
    );
    expect(gateway.steps, ['reauthenticate', 'update']);
  });

  test('finalize 실패를 완료로 오인하지 않는다', () async {
    final gateway = _FakePasswordGateway(finalizeError: StateError('failed'));

    await expectLater(
      AccountPasswordService(gateway: gateway).changePassword(
        currentPassword: _secret(1),
        newPassword: _secret(2),
        confirmation: _secret(2),
      ),
      throwsA(
        isA<AccountPasswordException>()
            .having(
              (error) => error.code,
              'code',
              AccountPasswordErrorCode.finalizeFailed,
            )
            .having(
              (error) => error.passwordWasUpdated,
              'passwordWasUpdated',
              isTrue,
            ),
      ),
    );
  });

  testWidgets('강제 변경 성공 시 민감 입력을 지우고 완료 callback을 실행한다', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordChangePage(
          forced: true,
          passwordService: AccountPasswordService(
            gateway: _FakePasswordGateway(),
          ),
          accountService: AppAccountService(gateway: _FakeAccountGateway()),
          onCompleted: () => completed = true,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('current_password_field')),
      _secret(1),
    );
    await tester.enterText(
      find.byKey(const Key('new_password_field')),
      _secret(2),
    );
    await tester.enterText(
      find.byKey(const Key('confirm_password_field')),
      _secret(2),
    );
    await tester.tap(find.byKey(const Key('change_password_button')));
    await tester.pump();

    expect(completed, isTrue);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('current_password_field')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('new_password_field')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  for (final width in <double>[320, 360, 412]) {
    for (final scale in <double>[1, 1.3, 1.8]) {
      testWidgets('비밀번호 화면 ${width.toInt()}dp / $scale 배율 overflow 없음',
          (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 760),
                textScaler: TextScaler.linear(scale),
              ),
              child: PasswordChangePage(
                passwordService: AccountPasswordService(
                  gateway: _FakePasswordGateway(),
                ),
                accountService: AppAccountService(
                  gateway: _FakeAccountGateway(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('password_change_page')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('일반 비밀번호 화면은 뒤로가기 가능하고 forced는 차단한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordChangePage(
          passwordService: AccountPasswordService(
            gateway: _FakePasswordGateway(),
          ),
          accountService: AppAccountService(gateway: _FakeAccountGateway()),
        ),
      ),
    );
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: PasswordChangePage(
          forced: true,
          passwordService: AccountPasswordService(
            gateway: _FakePasswordGateway(),
          ),
          accountService: AppAccountService(gateway: _FakeAccountGateway()),
        ),
      ),
    );
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  testWidgets('mustChangePassword gate는 workspace보다 먼저 표시된다', (tester) async {
    await _pumpGate(
      tester,
      status: LinkedAccountAccessStatus.passwordChangeRequired,
      claims: const PlatformAccountClaims(
        platformAdmin: true,
        legacyDataAccessApproved: true,
      ),
    );

    expect(find.byKey(const Key('password_change_page')), findsOneWidget);
    expect(find.text('personal workspace'), findsNothing);
    expect(find.text('legacy workspace'), findsNothing);
  });

  testWidgets('platformAdmin claim 계정만 workspace 선택을 본다', (tester) async {
    await _pumpGate(
      tester,
      status: LinkedAccountAccessStatus.personalWorkspaceReady,
      claims: const PlatformAccountClaims(platformAdmin: true),
    );

    expect(
        find.byKey(const Key('platform_admin_workspace_page')), findsOneWidget);
    expect(find.byKey(const Key('open_personal_workspace')), findsOneWidget);
    expect(find.byKey(const Key('open_legacy_workspace')), findsNothing);
  });

  testWidgets('legacy 승인 claim이 있을 때만 기존 개발 데이터 버튼을 표시한다', (tester) async {
    await _pumpGate(
      tester,
      status: LinkedAccountAccessStatus.personalWorkspaceReady,
      claims: const PlatformAccountClaims(
        platformAdmin: true,
        legacyDataAccessApproved: true,
      ),
    );

    expect(find.byKey(const Key('open_legacy_workspace')), findsOneWidget);
  });

  testWidgets('일반 계정에는 관리자 선택을 표시하지 않는다', (tester) async {
    await _pumpGate(
      tester,
      status: LinkedAccountAccessStatus.personalWorkspaceReady,
      claims: const PlatformAccountClaims(),
    );

    expect(find.text('personal workspace'), findsOneWidget);
    expect(
        find.byKey(const Key('platform_admin_workspace_page')), findsNothing);
  });

  testWidgets('관리자 작업공간 선택 후 로그아웃하면 관리자 화면 잔상이 없다', (tester) async {
    final user = AppAccountUser(
      uid: 'uid-${DateTime.now().microsecondsSinceEpoch}',
      email: 'linked@example.com',
      emailVerified: true,
      isAnonymous: false,
    );
    final gateway = _FakeAccountGateway(currentUser: user);
    final service = AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _FakeAnonymousProfileGateway(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: service,
          accessGateway: const _FakeLinkedAccessGateway(
            LinkedAccountAccessStatus.personalWorkspaceReady,
          ),
          claimsGateway: const _FakeClaimsGateway(
            PlatformAccountClaims(platformAdmin: true),
          ),
          profileReader: const _FakePersonalProfileStartReader(),
          personalWorkspaceBuilder: (account) =>
              Text('personal ${account.uid}'),
          linkedChild: const Text('legacy workspace'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('open_personal_workspace')));
    await tester.pump();
    expect(find.text('personal ${user.uid}'), findsOneWidget);

    await service.signOut();
    await tester.pumpAndSettle();
    expect(find.text('personal ${user.uid}'), findsNothing);
    expect(
        find.byKey(const Key('platform_admin_workspace_page')), findsNothing);
    expect(find.text('personal signed-out-anonymous'), findsOneWidget);
  });

  testWidgets('두 claim으로 연 legacy workspace는 표시와 개인 전환을 제공한다', (tester) async {
    await _pumpGate(
      tester,
      status: LinkedAccountAccessStatus.personalWorkspaceReady,
      claims: const PlatformAccountClaims(
        platformAdmin: true,
        legacyDataAccessApproved: true,
      ),
    );

    await tester.tap(find.byKey(const Key('open_legacy_workspace')));
    await tester.pump();
    expect(
        find.byKey(const Key('legacy_admin_workspace_shell')), findsOneWidget);
    expect(find.text('기존 개발 데이터'), findsOneWidget);

    await tester.tap(find.byKey(const Key('switch_to_personal_workspace')));
    await tester.pump();
    expect(find.text('personal workspace'), findsOneWidget);
    expect(find.text('legacy workspace'), findsNothing);
  });

  testWidgets('legacy profile 상태만으로는 기존 데이터에 진입하지 않는다', (tester) async {
    await _pumpGate(
      tester,
      status: LinkedAccountAccessStatus.legacyAccessReady,
      claims: const PlatformAccountClaims(),
    );

    expect(find.text('legacy workspace'), findsNothing);
    expect(find.byKey(const Key('legacy_admin_workspace_shell')), findsNothing);
  });
}

Future<void> _pumpGate(
  WidgetTester tester, {
  required LinkedAccountAccessStatus status,
  required PlatformAccountClaims claims,
}) async {
  final user = AppAccountUser(
    uid: 'uid-${DateTime.now().microsecondsSinceEpoch}',
    email: 'linked@example.com',
    emailVerified: true,
    isAnonymous: false,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: AppAccountGate(
        service: AppAccountService(
          gateway: _FakeAccountGateway(currentUser: user),
        ),
        accessGateway: _FakeLinkedAccessGateway(status),
        claimsGateway: _FakeClaimsGateway(claims),
        profileReader: const _FakePersonalProfileStartReader(),
        personalWorkspaceChild: const Text('personal workspace'),
        linkedChild: const Text('legacy workspace'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _secret(int seed) =>
    List<String>.filled(10, String.fromCharCode(64 + seed)).join();

Matcher _passwordFailure(AccountPasswordErrorCode code) => throwsA(
      isA<AccountPasswordException>().having(
        (error) => error.code,
        'code',
        code,
      ),
    );

class _FakePasswordGateway implements AccountPasswordGateway {
  _FakePasswordGateway({
    this.reauthenticateError,
    this.updateError,
    this.finalizeError,
  });

  final Object? reauthenticateError;
  final Object? updateError;
  final Object? finalizeError;
  final List<String> steps = [];
  int reauthenticateCalls = 0;
  int updateCalls = 0;

  @override
  String? get currentEmail => 'linked@example.com';

  @override
  bool get isAnonymous => false;

  @override
  Future<void> reauthenticate(String currentPassword) async {
    reauthenticateCalls += 1;
    steps.add('reauthenticate');
    if (reauthenticateError != null) throw reauthenticateError!;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updateCalls += 1;
    steps.add('update');
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> forceRefreshIdToken() async => steps.add('refresh');

  @override
  Future<void> completeInitialPasswordChange() async {
    steps.add('finalize');
    if (finalizeError != null) throw finalizeError!;
  }

  @override
  Future<void> sendPasswordResetEmail() async {}
}

class _FakeClaimsGateway implements AccountClaimsGateway {
  const _FakeClaimsGateway(this.claims);

  final PlatformAccountClaims claims;

  @override
  Future<PlatformAccountClaims> read({bool forceRefresh = false}) async =>
      claims;
}

class _FakeLinkedAccessGateway implements LinkedAccountAccessGateway {
  const _FakeLinkedAccessGateway(this.status);

  final LinkedAccountAccessStatus status;

  @override
  Future<LinkedAccountAccessStatus> check(AppAccountUser user) async => status;
}

class _FakeAccountGateway
    implements AppAccountAuthGateway, AppAnonymousIdentityGateway {
  _FakeAccountGateway({this.currentUser});

  final StreamController<AppAccountUser?> _controller =
      StreamController<AppAccountUser?>.broadcast();

  @override
  AppAccountUser? currentUser;

  @override
  Stream<AppAccountUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppAccountUser> createUserWithEmailAndPassword({
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
  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AppAccountUser> signInAnonymously() async {
    currentUser = const AppAccountUser(
      uid: 'signed-out-anonymous',
      email: '',
      emailVerified: false,
      isAnonymous: true,
    );
    _controller.add(currentUser);
    return currentUser!;
  }

  @override
  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forceRefreshIdToken() async {}
}

class _FakeAnonymousProfileGateway implements AnonymousProfileGateway {
  @override
  Future<void> bootstrapAnonymousBeginnerProfile() async {}

  @override
  Future<void> transitionAnonymousProfileToLinked() async {}

  @override
  Future<Map<String, dynamic>> reconcilePersonalTier() async => const {
        'tier': 'Beginner',
        'amateurConditionCount': 0,
        'amateurConditionTotal': 2,
        'eligible': false,
        'changed': false,
      };
}

class _FakePersonalProfileStartReader implements PersonalProfileStartReader {
  const _FakePersonalProfileStartReader();

  @override
  Future<PersonalProfileStartResult> read(AppAccountUser user) async =>
      const PersonalProfileStartResult.onboardingCompleted(nickname: '테스트');
}
