import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/account_gate.dart';
import 'package:mtf_app/pages/home_page.dart';
import 'package:mtf_app/pages/my_page.dart';
import 'package:mtf_app/pages/onboarding_page.dart';
import 'package:mtf_app/services/account_claims_service.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/linked_account_access_service.dart';
import 'package:mtf_app/services/personal_profile_start_reader.dart';
import 'package:mtf_app/aifc/core/aifc_avatar.dart';

void main() {
  const linkedUser = AppAccountUser(
    uid: 'firebase-uid-1',
    email: 'trainer@example.com',
    emailVerified: false,
    isAnonymous: false,
  );

  test('일반 personal canonical 목적지는 owner UID가 주입된 기존 HomePage다', () {
    final destination = buildCanonicalPersonalHome(
      'personal-owner',
      initialPersonalProfileData: const <String, dynamic>{
        'nickname': '라디오',
        'onboardingCompleted': true,
        'tier': 'Beginner',
      },
    );
    expect(destination, isA<HomePage>());
    expect((destination as HomePage).personalOwnerUid, 'personal-owner');
    expect(destination.initialPersonalProfileData?['nickname'], '라디오');

    final myPage = buildHomeMyPageDestination(
      personalOwnerUid: 'personal-owner',
    );
    expect(myPage, isA<MyPage>());
    expect((myPage as MyPage).personalOwnerUid, 'personal-owner');
  });

  testWidgets('신규 anonymous 사용자는 nickname 온보딩 저장 후 같은 UID 홈에 진입한다',
      (tester) async {
    final gateway = _FakeAccountGateway();
    final nicknameGateway = _FakeNicknameGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: _FakeAnonymousProfileGateway(),
          ),
          profileReader: const _FakePersonalProfileStartReader(
            result: PersonalProfileStartResult(
              nickname: '',
              onboardingCompleted: false,
            ),
          ),
          nicknameGateway: nicknameGateway,
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('만나서 반가워요.'), findsOneWidget);
    expect(find.textContaining('personal anonymous'), findsNothing);
    await tester.tap(find.byKey(const Key('onboarding_intro_continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding_nickname')),
      '레온쌤',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(nicknameGateway.uid, 'anonymous-uid-1');
    expect(nicknameGateway.nickname, '레온쌤');
    expect(find.text('personal anonymous-uid-1'), findsOneWidget);
  });

  testWidgets('nickname 저장 실패는 입력값과 온보딩을 유지한다', (tester) async {
    final gateway = _FakeAccountGateway();
    final nicknameGateway = _FakeNicknameGateway(error: StateError('offline'));
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: _FakeAnonymousProfileGateway(),
          ),
          profileReader: const _FakePersonalProfileStartReader(
            result: PersonalProfileStartResult(
              nickname: '',
              onboardingCompleted: false,
            ),
          ),
          nicknameGateway: nicknameGateway,
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_intro_continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding_nickname')),
      '입력 유지',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('입력 유지'), findsOneWidget);
    expect(find.textContaining('personal anonymous'), findsNothing);
    expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
  });

  testWidgets('nickname 입력은 화면에서도 6자로 제한한다', (tester) async {
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: _FakeAnonymousProfileGateway(),
          ),
          profileReader: const _FakePersonalProfileStartReader(
            result: PersonalProfileStartResult(
              nickname: '',
              onboardingCompleted: false,
            ),
          ),
          nicknameGateway: _FakeNicknameGateway(),
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_intro_continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding_nickname')),
      '일이삼사오육칠',
    );

    expect(find.text('일이삼사오육'), findsOneWidget);
    final nicknameField = tester.widget<TextField>(
      find.byKey(const Key('onboarding_nickname')),
    );
    expect(nicknameField.controller?.text, '일이삼사오육');
  });

  testWidgets('linked personal 계정도 nickname이 없으면 온보딩을 한 번 표시한다',
      (tester) async {
    final gateway = _FakeAccountGateway(currentUser: linkedUser);
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(gateway: gateway),
          accessGateway: _FakeLinkedAccessGateway(
            status: LinkedAccountAccessStatus.personalWorkspaceReady,
          ),
          profileReader: const _FakePersonalProfileStartReader(
            result: PersonalProfileStartResult(
              nickname: '',
              onboardingCompleted: false,
            ),
          ),
          nicknameGateway: _FakeNicknameGateway(),
          personalWorkspaceChild: const Text('linked personal'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('만나서 반가워요.'), findsOneWidget);
    expect(find.text('linked personal'), findsNothing);
  });

  testWidgets('신규 설치는 anonymous UID와 profile을 준비한 뒤 실제 personal 홈으로 진입한다',
      (tester) async {
    final gateway = _FakeAccountGateway();
    final profile = _FakeAnonymousProfileGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: profile,
          ),
          accessGateway: _FakeLinkedAccessGateway(),
          profileReader: const _FakePersonalProfileStartReader(),
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    expect(find.byKey(const Key('personal_start_progress')), findsOneWidget);
    expect(find.text('가입 없이 둘러보기'), findsNothing);
    await tester.pumpAndSettle();

    expect(find.text('personal anonymous-uid-1'), findsOneWidget);
    expect(gateway.anonymousCalls, 1);
    expect(profile.bootstrapCalls, 1);
  });

  testWidgets('personal 준비 화면은 Onboarding 배경과 기존 AI FC 로딩을 재사용한다',
      (tester) async {
    final gateway = _FakeAccountGateway();
    final delayedReader = _DelayedPersonalProfileStartReader();
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: _FakeAnonymousProfileGateway(),
          ),
          profileReader: delayedReader,
          personalWorkspaceChild: const Text('personal home'),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('personal_start_progress')),
    );
    expect(scaffold.backgroundColor, kOnboardingBg);
    expect(find.byKey(const Key('personal_start_brand_name')), findsOneWidget);
    expect(find.text('모어댄'), findsOneWidget);
    expect(
        find.byKey(const Key('personal_start_brand_english')), findsOneWidget);
    expect(find.text('MORE THAN'), findsOneWidget);
    expect(find.byKey(const Key('personal_start_aifc_avatar')), findsOneWidget);
    final avatar = tester.widget<AifcAvatar>(
      find.byKey(const Key('personal_start_aifc_avatar')),
    );
    expect(avatar.size, inInclusiveRange(64, 72));
    expect(find.byKey(const Key('personal_start_typing_dots')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('선생님'), findsNothing);
    expect(find.textContaining('강사님'), findsNothing);
    expect(find.text('조금만 기다려주세요'), findsNothing);

    final messageFinder = find.descendant(
      of: find.byType(AnimatedSwitcher),
      matching: find.byType(Text),
    );
    final firstMessage = tester.widget<Text>(messageFinder).data;
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.widget<Text>(messageFinder).data, firstMessage);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Text>(messageFinder).data, isNot(firstMessage));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('기존 anonymous user는 같은 UID로 멱등 bootstrap 후 진입한다', (tester) async {
    final gateway = _FakeAccountGateway(
      currentUser: const AppAccountUser(
        uid: 'saved-anonymous-uid',
        email: '',
        emailVerified: false,
        isAnonymous: true,
      ),
    );
    final profile = _FakeAnonymousProfileGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: profile,
          ),
          profileReader: const _FakePersonalProfileStartReader(),
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('personal saved-anonymous-uid'), findsOneWidget);
    expect(gateway.anonymousCalls, 0);
    expect(profile.bootstrapCalls, 1);
  });

  testWidgets('bootstrap 실패는 가짜 홈 대신 재시도 화면을 유지하고 재시도할 수 있다', (tester) async {
    final gateway = _FakeAccountGateway();
    final profile = _FakeAnonymousProfileGateway(
      error: const AppAccountException(AppAccountErrorCode.network),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: profile,
          ),
          profileReader: const _FakePersonalProfileStartReader(),
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personal_start_error')), findsOneWidget);
    expect(find.textContaining('personal anonymous'), findsNothing);
    profile.error = null;
    await tester.tap(find.byKey(const Key('retry_personal_start')));
    await tester.pumpAndSettle();

    expect(find.text('personal anonymous-uid-1'), findsOneWidget);
    expect(profile.bootstrapCalls, 2);
  });

  testWidgets('프로필 서버 조회 실패는 Firestore 준비 실패로 구분한다', (tester) async {
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(
            gateway: gateway,
            anonymousGateway: gateway,
            profileGateway: _FakeAnonymousProfileGateway(),
          ),
          profileReader: _FakePersonalProfileStartReader(
            error: StateError('offline'),
          ),
          personalWorkspaceBuilder: (user) => Text('personal ${user.uid}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personal_start_error')), findsOneWidget);
    expect(find.text('Firestore 준비 실패'), findsOneWidget);
    expect(find.textContaining('personal anonymous'), findsNothing);
  });

  testWidgets('로그인 사용자는 기존 앱 흐름으로 진입한다', (tester) async {
    final gateway = _FakeAccountGateway(currentUser: linkedUser);
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(gateway: gateway),
          accessGateway: _FakeLinkedAccessGateway(
            status: LinkedAccountAccessStatus.legacyAccessReady,
          ),
          claimsGateway: const _FakeClaimsGateway(
            PlatformAccountClaims(
              platformAdmin: true,
              legacyDataAccessApproved: true,
            ),
          ),
          linkedChild: const Text('기존 앱 흐름'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('기존 앱 흐름'), findsOneWidget);
    expect(find.text('가입 없이 둘러보기'), findsNothing);
  });

  testWidgets('승인되지 않은 신규 계정에는 기존 운영 데이터를 자동 연결하지 않는다', (tester) async {
    final gateway = _FakeAccountGateway(currentUser: linkedUser);
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(gateway: gateway),
          accessGateway: _FakeLinkedAccessGateway(
            status: LinkedAccountAccessStatus.profileMissing,
          ),
          linkedChild: const Text('기존 앱 흐름'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('기존 앱 흐름'), findsNothing);
    expect(find.textContaining('자동으로 연결하지 않습니다'), findsOneWidget);
  });

  test('이메일 형식 오류는 Firebase 호출 전에 거부한다', () async {
    final gateway = _FakeAccountGateway();
    final service = AppAccountService(gateway: gateway);

    await expectLater(
      service.registerWithEmail(email: 'invalid', password: '123456'),
      _failsWith(AppAccountErrorCode.invalidEmail),
    );
    expect(gateway.createCalls, 0);
  });

  test('짧은 비밀번호는 Firebase 호출 전에 거부한다', () async {
    final gateway = _FakeAccountGateway();
    final service = AppAccountService(gateway: gateway);

    await expectLater(
      service.registerWithEmail(
        email: 'trainer@example.com',
        password: '12345',
      ),
      _failsWith(AppAccountErrorCode.weakPassword),
    );
    expect(gateway.createCalls, 0);
  });

  test('이메일 가입 성공은 linked 상태이며 인증 메일 결과를 분리한다', () async {
    final gateway = _FakeAccountGateway(createUser: linkedUser);
    final result = await AppAccountService(gateway: gateway).registerWithEmail(
      email: 'trainer@example.com',
      password: '123456',
    );

    expect(result.snapshot.state, AppAccountState.linked);
    expect(result.snapshot.tier, AppTier.beginner);
    expect(result.verificationEmailSent, isTrue);
    expect(gateway.verificationCalls, 1);
  });

  test('이메일 로그인 성공은 Firebase user 상태를 반환한다', () async {
    final gateway = _FakeAccountGateway(loginUser: linkedUser);
    final result = await AppAccountService(gateway: gateway).signInWithEmail(
      email: 'trainer@example.com',
      password: '123456',
    );

    expect(result.state, AppAccountState.linked);
    expect(result.user?.uid, 'firebase-uid-1');
  });

  test('잘못된 비밀번호 오류를 사용자 계정 오류로 유지한다', () async {
    final gateway = _FakeAccountGateway(
      loginError: const AppAccountException(
        AppAccountErrorCode.invalidCredential,
      ),
    );

    await expectLater(
      AppAccountService(gateway: gateway).signInWithEmail(
        email: 'trainer@example.com',
        password: 'wrong-password',
      ),
      _failsWith(AppAccountErrorCode.invalidCredential),
    );
  });

  test('비밀번호 재설정은 입력 이메일만 Auth gateway로 전달한다', () async {
    final gateway = _FakeAccountGateway();
    await AppAccountService(gateway: gateway).sendPasswordReset(
      ' trainer@example.com ',
    );

    expect(gateway.resetCalls, 1);
    expect(gateway.lastResetEmail, 'trainer@example.com');
  });

  test('인증 요청 연속 실행은 첫 요청만 허용한다', () async {
    final completer = Completer<AppAccountUser>();
    final gateway = _FakeAccountGateway(createCompleter: completer);
    final service = AppAccountService(gateway: gateway);

    final first = service.registerWithEmail(
      email: 'trainer@example.com',
      password: '123456',
    );
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      service.registerWithEmail(
        email: 'trainer@example.com',
        password: '123456',
      ),
      _failsWith(AppAccountErrorCode.requestInProgress),
    );
    completer.complete(linkedUser);
    await first;
    expect(gateway.createCalls, 1);
  });

  testWidgets('linked 로그아웃 후 새 anonymous UID의 personal 홈으로 진입한다',
      (tester) async {
    final gateway = _FakeAccountGateway(currentUser: linkedUser);
    final profile = _FakeAnonymousProfileGateway();
    final workspaceEvents = <String>[];
    final service = AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: profile,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: service,
          accessGateway: _FakeLinkedAccessGateway(
            status: LinkedAccountAccessStatus.personalWorkspaceReady,
          ),
          profileReader: const _FakePersonalProfileStartReader(),
          personalWorkspaceBuilder: (user) => _WorkspaceProbe(
            uid: user.uid,
            events: workspaceEvents,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('personal firebase-uid-1'), findsOneWidget);

    await service.signOut();
    await tester.pumpAndSettle();

    expect(find.text('personal firebase-uid-1'), findsNothing);
    expect(find.text('personal anonymous-uid-1'), findsOneWidget);
    expect(profile.bootstrapCalls, 1);
    expect(workspaceEvents, contains('dispose:firebase-uid-1'));
  });

  test('계정 상태와 앱 등급은 서로 독립된 값이다', () {
    const snapshot = AppAccountSnapshot(
      state: AppAccountState.organizationMember,
      tier: AppTier.master,
      user: linkedUser,
    );

    expect(snapshot.state, AppAccountState.organizationMember);
    expect(snapshot.tier, AppTier.master);
  });

  test('익명 Firebase user는 최종 계정이나 문자열 me owner로 사용하지 않는다', () {
    const anonymous = AppAccountUser(
      uid: 'me',
      email: '',
      emailVerified: false,
      isAnonymous: true,
    );

    final snapshot = AppAccountSnapshot.fromUser(anonymous);
    expect(snapshot.state, AppAccountState.guest);
    expect(snapshot.user, isNull);
  });

  test('계정 연결은 trainer_profile me 또는 운영 데이터 gateway를 호출하지 않는다', () async {
    final gateway = _FakeAccountGateway(createUser: linkedUser);
    await AppAccountService(gateway: gateway).registerWithEmail(
      email: 'trainer@example.com',
      password: '123456',
    );

    expect(gateway.profileCalls, 0);
    expect(gateway.operationalDataCalls, 0);
  });

  test('Google 설정 미완료를 인증 성공으로 반환하지 않는다', () async {
    final gateway = _FakeAccountGateway();
    await expectLater(
      AppAccountService(gateway: gateway).signInWithGoogle(),
      _failsWith(AppAccountErrorCode.googleSetupRequired),
    );
    expect(gateway.currentUser, isNull);
  });

  test('linked personal 재진입은 서버 tier가 Amateur 이상이어도 허용한다', () {
    for (final tier in ['Beginner', 'Amateur', 'Semi-Pro', 'Pro']) {
      expect(
        isCanonicalPersonalProfile({
          'trainerId': 'firebase-uid-1',
          'accountState': 'linked',
          'workspaceType': 'personal',
          'workspaceStatus': 'active',
          'role': 'personal',
          'tier': tier,
        }, uid: 'firebase-uid-1'),
        isTrue,
        reason: tier,
      );
    }
  });
  testWidgets('신규 personal profile은 승인 없이 빈 작업공간으로 진입한다', (tester) async {
    final gateway = _FakeAccountGateway(currentUser: linkedUser);
    await tester.pumpWidget(
      MaterialApp(
        home: AppAccountGate(
          service: AppAccountService(gateway: gateway),
          accessGateway: _FakeLinkedAccessGateway(
            status: LinkedAccountAccessStatus.personalWorkspaceReady,
          ),
          profileReader: const _FakePersonalProfileStartReader(),
          linkedChild: const Text('legacy app'),
          personalWorkspaceChild: const Text('personal workspace'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('personal workspace'), findsOneWidget);
    expect(find.text('legacy app'), findsNothing);
  });
}

class _FakeLinkedAccessGateway implements LinkedAccountAccessGateway {
  _FakeLinkedAccessGateway({
    this.status = LinkedAccountAccessStatus.profileMissing,
  });

  final LinkedAccountAccessStatus status;
  int calls = 0;

  @override
  Future<LinkedAccountAccessStatus> check(AppAccountUser user) async {
    calls++;
    return status;
  }
}

class _FakeClaimsGateway implements AccountClaimsGateway {
  const _FakeClaimsGateway(this.claims);

  final PlatformAccountClaims claims;

  @override
  Future<PlatformAccountClaims> read({bool forceRefresh = false}) async =>
      claims;
}

Matcher _failsWith(AppAccountErrorCode code) => throwsA(
      isA<AppAccountException>().having(
        (error) => error.code,
        'code',
        code,
      ),
    );

class _FakeAccountGateway
    implements AppAccountAuthGateway, AppAnonymousIdentityGateway {
  _FakeAccountGateway({
    AppAccountUser? currentUser,
    this.createUser,
    this.loginUser,
    this.loginError,
    this.createCompleter,
  }) : _currentUser = currentUser;

  final StreamController<AppAccountUser?> _controller =
      StreamController<AppAccountUser?>.broadcast();
  AppAccountUser? _currentUser;
  final AppAccountUser? createUser;
  final AppAccountUser? loginUser;
  final Object? loginError;
  final Completer<AppAccountUser>? createCompleter;

  int createCalls = 0;
  int loginCalls = 0;
  int verificationCalls = 0;
  int resetCalls = 0;
  int signOutCalls = 0;
  int profileCalls = 0;
  int operationalDataCalls = 0;
  int anonymousCalls = 0;
  int refreshCalls = 0;
  String? lastResetEmail;

  @override
  AppAccountUser? get currentUser => _currentUser;

  @override
  Stream<AppAccountUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppAccountUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createCalls++;
    final user = createCompleter == null
        ? (createUser ??
            AppAccountUser(
              uid: 'created-uid',
              email: email,
              emailVerified: false,
              isAnonymous: false,
            ))
        : await createCompleter!.future;
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    final user = loginUser ??
        AppAccountUser(
          uid: 'login-uid',
          email: email,
          emailVerified: false,
          isAnonymous: false,
        );
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationCalls++;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls++;
    lastResetEmail = email;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<AppAccountUser> signInAnonymously() async {
    anonymousCalls++;
    final user = AppAccountUser(
      uid: 'anonymous-uid-$anonymousCalls',
      email: '',
      emailVerified: false,
      isAnonymous: true,
    );
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> forceRefreshIdToken() async => refreshCalls++;
}

class _FakeAnonymousProfileGateway implements AnonymousProfileGateway {
  _FakeAnonymousProfileGateway({this.error});

  Object? error;
  int bootstrapCalls = 0;

  @override
  Future<void> bootstrapAnonymousBeginnerProfile() async {
    bootstrapCalls++;
    if (error case final value?) throw value;
  }

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
  const _FakePersonalProfileStartReader({
    this.error,
    this.result = const PersonalProfileStartResult.onboardingCompleted(
      nickname: '테스트',
    ),
  });

  final Object? error;
  final PersonalProfileStartResult result;

  @override
  Future<PersonalProfileStartResult> read(AppAccountUser user) async {
    if (error case final value?) throw value;
    return result;
  }
}

class _DelayedPersonalProfileStartReader implements PersonalProfileStartReader {
  final _completer = Completer<PersonalProfileStartResult>();

  @override
  Future<PersonalProfileStartResult> read(AppAccountUser user) =>
      _completer.future;
}

class _FakeNicknameGateway implements PersonalNicknameOnboardingGateway {
  _FakeNicknameGateway({this.error});

  final Object? error;
  String? uid;
  String? nickname;

  @override
  Future<void> saveNickname({
    required String uid,
    required String nickname,
    String source = 'onboarding',
  }) async {
    this.uid = uid;
    this.nickname = nickname;
    if (error case final value?) throw value;
  }
}

class _WorkspaceProbe extends StatefulWidget {
  const _WorkspaceProbe({required this.uid, required this.events});

  final String uid;
  final List<String> events;

  @override
  State<_WorkspaceProbe> createState() => _WorkspaceProbeState();
}

class _WorkspaceProbeState extends State<_WorkspaceProbe> {
  @override
  void dispose() {
    widget.events.add('dispose:${widget.uid}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('personal ${widget.uid}');
}
