import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/account_gate.dart';
import 'package:mtf_app/pages/guest_start_page.dart';
import 'package:mtf_app/services/account_claims_service.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/app_environment.dart';
import 'package:mtf_app/services/app_workspace_mode.dart';
import 'package:mtf_app/services/linked_account_access_service.dart';
import 'package:mtf_app/services/personal_profile_start_reader.dart';

void main() {
  testWidgets('PROD Debug identity에서는 callback이 있어도 개발 버튼을 숨긴다',
      (tester) async {
    AppEnvironmentConfig.select(AppEnvironment.prod);
    await tester.pumpWidget(
      MaterialApp(
        home: GuestStartPage(
          service: AppAccountService(gateway: _GuestAccountGateway()),
          onOpenDebugLegacyWorkspace: () {},
        ),
      ),
    );

    expect(
      find.byKey(const Key('open_debug_legacy_workspace')),
      findsNothing,
    );
  });

  testWidgets('callback이 없는 보존 sample 화면에는 우회 버튼이 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GuestStartPage(
          service: AppAccountService(gateway: _GuestAccountGateway()),
        ),
      ),
    );

    expect(
      find.byKey(const Key('open_debug_legacy_workspace')),
      findsNothing,
    );
  });

  testWidgets('PROD Debug AccountGate는 legacy shell과 개발 아이콘을 만들지 않는다',
      (tester) async {
    AppEnvironmentConfig.select(AppEnvironment.prod);
    final accessGateway = _UnexpectedAccessGateway();
    final claimsGateway = _UnexpectedClaimsGateway();
    AppWorkspaceMode? openedMode;

    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: _anonymousService(_GuestAccountGateway()),
          accessGateway: accessGateway,
          claimsGateway: claimsGateway,
          profileReader: const _DebugPersonalProfileStartReader(),
          linkedChild: Builder(
            builder: (context) {
              openedMode = AppWorkspaceScope.of(context);
              return const Text('legacy home');
            },
          ),
          personalWorkspaceChild: const Text('personal home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedMode, isNull);
    expect(find.text('legacy home'), findsNothing);
    expect(find.text('personal home'), findsOneWidget);
    expect(find.byKey(const Key('open_debug_legacy_workspace')), findsNothing);
    expect(find.byKey(const Key('debug_legacy_workspace_shell')), findsNothing);
    expect(accessGateway.calls, 0);
    expect(claimsGateway.calls, 0);
  });

  test('정확한 DEV Debug identity만 legacy developer 진입 조건을 만족한다', () {
    expect(
      AppEnvironmentConfig.canOpenDebugLegacyWorkspaceForIdentity(
        debugBuild: true,
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.developmentFirebaseProjectId,
        packageName: AppEnvironmentConfig.developmentPackageName,
      ),
      isTrue,
    );
  });
}

AppAccountService _anonymousService(_GuestAccountGateway gateway) =>
    AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: _DebugProfileGateway(),
    );

class _GuestAccountGateway
    implements AppAccountAuthGateway, AppAnonymousIdentityGateway {
  final StreamController<AppAccountUser?> _controller =
      StreamController<AppAccountUser?>.broadcast();
  AppAccountUser? _user;

  @override
  AppAccountUser? get currentUser => _user;

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
  Future<void> signOut() async {}

  @override
  Future<AppAccountUser> signInAnonymously() async {
    _user = const AppAccountUser(
      uid: 'debug-anonymous',
      email: '',
      emailVerified: false,
      isAnonymous: true,
    );
    _controller.add(_user);
    return _user!;
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

class _DebugProfileGateway implements AnonymousProfileGateway {
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

class _DebugPersonalProfileStartReader implements PersonalProfileStartReader {
  const _DebugPersonalProfileStartReader();

  @override
  Future<PersonalProfileStartResult> read(AppAccountUser user) async =>
      const PersonalProfileStartResult.onboardingCompleted(nickname: '테스트');
}

class _UnexpectedAccessGateway implements LinkedAccountAccessGateway {
  int calls = 0;

  @override
  Future<LinkedAccountAccessStatus> check(AppAccountUser user) async {
    calls += 1;
    throw StateError('Debug legacy 진입에서 profile bootstrap을 호출하면 안 됩니다.');
  }
}

class _UnexpectedClaimsGateway implements AccountClaimsGateway {
  int calls = 0;

  @override
  Future<PlatformAccountClaims> read({bool forceRefresh = false}) async {
    calls += 1;
    throw StateError('Debug legacy 진입에서 claim을 조회하면 안 됩니다.');
  }
}
