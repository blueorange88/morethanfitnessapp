import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_my_page.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/managed_member_workspace_service.dart';
import 'package:mtf_app/services/personal_my_page_nudge_service.dart';

void main() {
  testWidgets('마이페이지 진입마다 미완성 정보 한 항목만 순환해 질문한다', (tester) async {
    final store = _FakeNudgeStore();
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(count: 0, limit: 10),
    );

    await _pumpPage(
      tester,
      gateway: gateway,
      anonymous: true,
      nudgeStore: store,
      autoNudgeEnabled: true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aifc_nudge_title')), findsOneWidget);
    expect(find.textContaining('어떤 이름으로 소개'), findsOneWidget);
    expect(find.text('해당 항목 입력하기'), findsOneWidget);
    expect(find.text('한 번에 완성하기'), findsOneWidget);
    expect(find.text('다음에 할게요'), findsOneWidget);
    await tester.tap(find.text('다음에 할게요'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpPage(
      tester,
      gateway: gateway,
      anonymous: true,
      nudgeStore: store,
      autoNudgeEnabled: true,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('연락처를 등록'), findsOneWidget);
  });

  testWidgets('한 번에 완성하기는 기존 선생님 정보 편집 UI로 이동한다', (tester) async {
    await _pumpPage(
      tester,
      gateway: _FakeMemberGateway(
        usage: const ManagedMemberUsage(count: 0, limit: 10),
      ),
      anonymous: true,
      nudgeStore: _FakeNudgeStore(),
      autoNudgeEnabled: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('한 번에 완성하기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_display_name')), findsOneWidget);
    expect(find.byKey(const Key('save_personal_profile')), findsOneWidget);
  });

  testWidgets('정보가 완성된 anonymous 계정은 연결 넛지에서 전용 시트를 연다', (tester) async {
    await _pumpPage(
      tester,
      gateway: _FakeMemberGateway(
        usage: const ManagedMemberUsage(
          count: 0,
          limit: 10,
          nickname: '레온',
          displayName: '레온',
          phone: '01012345678',
          activityRegion: '서울',
          primaryActivity: 'PT',
          affiliationType: 'freelancer',
        ),
      ),
      anonymous: true,
      nudgeStore: _FakeNudgeStore(),
      autoNudgeEnabled: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('계정 연결하기'), findsOneWidget);
    await tester.tap(find.text('계정 연결하기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('link_google_account')), findsOneWidget);
    expect(find.byKey(const Key('link_kakao_preparing')), findsOneWidget);
    expect(find.byKey(const Key('link_naver_preparing')), findsOneWidget);
    expect(find.text('카카오·네이버 계정 연결은 준비 중이에요.'), findsOneWidget);
    expect(find.byKey(const Key('link_email')), findsOneWidget);
  });

  testWidgets('anonymous Beginner는 서버 등급과 진행 조건을 표시하고 로그아웃을 숨긴다', (
    tester,
  ) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(
        count: 7,
        limit: 10,
        lifetimeQualifiedCount: 7,
        tier: 'Beginner',
        displayName: '레온',
        phone: '01012345678',
        activityRegion: '서울 강남구',
      ),
    );
    await _pumpPage(tester, gateway: gateway, anonymous: true);

    expect(find.text('BEGINNER'), findsOneWidget);
    expect(find.text('7명'), findsOneWidget);
    expect(find.text('3 / 5 완료'), findsOneWidget);
    expect(find.textContaining('회원 3명을 더 등록'), findsOneWidget);
    await _scrollTo(tester, const Key('open_account_and_records'));
    expect(find.byKey(const Key('open_account_and_records')), findsOneWidget);
    expect(find.byKey(const Key('personal_account_sign_out')), findsNothing);
  });

  testWidgets('linked 계정은 이메일 인증 상태와 비밀번호 변경·로그아웃을 표시한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(
        count: 10,
        limit: 10,
        lifetimeQualifiedCount: 10,
        tier: 'Amateur',
        accountLinked: true,
        profileCompleted: true,
        displayName: '레온',
        phone: '01012345678',
        activityRegion: '서울',
        primaryActivity: 'PT',
        affiliationType: 'freelancer',
      ),
    );
    await _pumpPage(tester, gateway: gateway, anonymous: false);

    expect(find.text('AMATEUR'), findsOneWidget);
    await _scrollTo(tester, const Key('open_password_change'));
    expect(find.textContaining('tr***@example.com'), findsOneWidget);
    expect(find.textContaining('인증 완료 ✓'), findsOneWidget);
    expect(find.byKey(const Key('personal_connect_google')), findsOneWidget);
    expect(find.text('카카오 · 네이버'), findsOneWidget);
    expect(find.byKey(const Key('open_password_change')), findsOneWidget);
    expect(find.byKey(const Key('personal_account_sign_out')), findsOneWidget);
    expect(find.byKey(const Key('link_email_account')), findsNothing);
  });

  testWidgets('Google 연결 후 MyPage가 password와 Google 상태를 함께 표시한다', (
    tester,
  ) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(
        count: 10,
        limit: 10,
        lifetimeQualifiedCount: 10,
        tier: 'Amateur',
        accountLinked: true,
        profileCompleted: true,
        displayName: '레온',
        phone: '01012345678',
        activityRegion: '서울',
        primaryActivity: 'PT',
        affiliationType: 'freelancer',
      ),
    );
    await _pumpPage(
      tester,
      gateway: gateway,
      anonymous: false,
      auth: _FakeAuthGateway(
        anonymous: false,
        providerIds: const ['password', 'google.com'],
      ),
    );

    await _scrollTo(tester, const Key('personal_google_connected'));
    expect(find.byKey(const Key('personal_google_connected')), findsOneWidget);
    expect(find.text('Google 계정 연결됨'), findsOneWidget);
    expect(find.textContaining('tr***@example.com'), findsOneWidget);
  });

  for (final scenario in const [
    (tier: 'Semi-Pro', count: 32, text: '회원 18명을 더 등록'),
    (tier: 'Pro', count: 50, text: 'Pro로 성장했어요'),
  ]) {
    testWidgets('${scenario.tier} 카드는 서버 tier와 누적 회원 수만 표시한다', (tester) async {
      final gateway = _FakeMemberGateway(
        usage: ManagedMemberUsage(
          count: scenario.count,
          limit: 100,
          lifetimeQualifiedCount: scenario.count,
          tier: scenario.tier,
          accountLinked: true,
          profileCompleted: true,
          displayName: '레온',
          phone: '01012345678',
          activityRegion: '서울',
          primaryActivity: 'PT',
          affiliationType: 'freelancer',
        ),
      );
      await _pumpPage(tester, gateway: gateway, anonymous: false);

      expect(find.text(scenario.tier.toUpperCase()), findsOneWidget);
      expect(find.text('${scenario.count}명'), findsOneWidget);
      expect(find.textContaining(scenario.text), findsOneWidget);
    });
  }

  testWidgets('내 정보 누락과 저장 실패는 입력 화면과 값을 유지한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(count: 0, limit: 10),
      profileError: StateError('network'),
    );
    await _pumpPage(tester, gateway: gateway, anonymous: true);

    await _scrollTo(tester, const Key('save_personal_profile'));
    await tester.tap(find.byKey(const Key('save_personal_profile')));
    await tester.pump();
    expect(find.byKey(const Key('profile_save_error')), findsOneWidget);
    expect(find.textContaining('연락처, 활동 지역'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile_display_name')),
      '입력 유지',
    );
    await tester.enterText(
      find.byKey(const Key('profile_phone')),
      '01012345678',
    );
    await tester.enterText(
      find.byKey(const Key('profile_activity_region')),
      '서울',
    );
    await tester.enterText(
      find.byKey(const Key('profile_primary_activity')),
      'PT',
    );
    await _scrollTo(tester, const Key('profile_affiliation_type'));
    await tester.tap(find.byKey(const Key('profile_affiliation_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('프리랜서').last);
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('save_personal_profile'));
    await tester.tap(find.byKey(const Key('save_personal_profile')));
    await tester.pumpAndSettle();

    expect(gateway.profileCalls, 1);
    expect(find.text('입력 유지'), findsOneWidget);
    expect(find.byKey(const Key('profile_save_error')), findsOneWidget);
  });

  testWidgets('이메일 연결은 UID를 유지하고 profile linked 전환을 한 번 호출한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(count: 10, limit: 10),
    );
    final auth = _FakeAuthGateway(anonymous: true);
    final profile = _FakeProfileGateway();
    await _pumpPage(
      tester,
      gateway: gateway,
      anonymous: true,
      auth: auth,
      profile: profile,
    );

    await _openEmailLinkSheet(tester);
    await _scrollTo(tester, const Key('link_email'));
    await tester.enterText(
      find.byKey(const Key('link_email')),
      'trainer@example.com',
    );
    await tester.enterText(find.byKey(const Key('link_password')), 'secret12');
    await tester.enterText(
      find.byKey(const Key('link_password_confirmation')),
      'secret12',
    );
    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('continue_link_without_verification')),
    );
    await tester.pumpAndSettle();

    expect(auth.linkBeforeUid, 'owner-uid');
    expect(auth.currentUser?.uid, 'owner-uid');
    expect(profile.transitionCalls, 1);
    expect(auth.refreshCalls, 1);
    expect(auth.verificationCalls, 0);
  });

  testWidgets('계정 연결 전용 진입은 canonical 이메일 연결 뒤 true로 복귀한다', (tester) async {
    final auth = _FakeAuthGateway(anonymous: true);
    final profile = _FakeProfileGateway();
    bool? linkedResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    linkedResult = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder:
                            (_) => PersonalMyPage(
                              uid: 'owner-uid',
                              accountService: AppAccountService(
                                gateway: auth,
                                anonymousGateway: auth,
                                profileGateway: profile,
                              ),
                              memberGateway: _FakeMemberGateway(
                                usage: const ManagedMemberUsage(
                                  count: 8,
                                  limit: 10,
                                  lifetimeQualifiedCount: 10,
                                ),
                              ),
                              autoNudgeEnabled: false,
                              openAccountLinkOnStart: true,
                            ),
                      ),
                    );
                  },
                  child: const Text('계정 연결 시작'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('계정 연결 시작'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('link_email')),
      'trainer@example.com',
    );
    await tester.enterText(find.byKey(const Key('link_password')), 'secret12');
    await tester.enterText(
      find.byKey(const Key('link_password_confirmation')),
      'secret12',
    );
    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('continue_link_without_verification')),
    );
    await tester.pumpAndSettle();

    expect(linkedResult, isTrue);
    expect(auth.linkBeforeUid, 'owner-uid');
    expect(auth.currentUser?.uid, 'owner-uid');
    expect(profile.transitionCalls, 1);
  });

  testWidgets('미인증 계정은 마스킹 이메일과 재전송·인증 확인을 제공한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(
        count: 10,
        limit: 10,
        lifetimeQualifiedCount: 10,
        tier: 'Amateur',
        accountLinked: true,
      ),
    );
    final auth = _FakeAuthGateway(
      anonymous: false,
      emailVerified: false,
      reloadEmailVerified: true,
    );
    await _pumpPage(tester, gateway: gateway, anonymous: false, auth: auth);

    await _scrollTo(tester, const Key('send_email_verification'));
    expect(find.textContaining('tr***@example.com'), findsOneWidget);
    expect(find.textContaining('인증 필요'), findsOneWidget);
    await tester.tap(find.byKey(const Key('send_email_verification')));
    await tester.pumpAndSettle();
    expect(auth.verificationCalls, 1);

    await tester.tap(find.byKey(const Key('refresh_email_verification')));
    await tester.pumpAndSettle();
    expect(auth.reloadCalls, 1);
    expect(find.textContaining('인증 완료 ✓'), findsOneWidget);
    expect(find.byKey(const Key('send_email_verification')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('부분 연결 후 재시작해도 profile 전환을 마무리하고 true로 복귀한다', (tester) async {
    final auth = _FakeAuthGateway(anonymous: false);
    final profile = _FakeProfileGateway();
    bool? linkedResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    linkedResult = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder:
                            (_) => PersonalMyPage(
                              uid: 'owner-uid',
                              accountService: AppAccountService(
                                gateway: auth,
                                anonymousGateway: auth,
                                profileGateway: profile,
                              ),
                              memberGateway: _FakeMemberGateway(
                                usage: const ManagedMemberUsage(
                                  count: 10,
                                  limit: 10,
                                  lifetimeQualifiedCount: 10,
                                ),
                              ),
                              autoNudgeEnabled: false,
                              openAccountLinkOnStart: true,
                            ),
                      ),
                    );
                  },
                  child: const Text('계정 연결 마무리'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('계정 연결 마무리'));
    await tester.pumpAndSettle();

    expect(linkedResult, isTrue);
    expect(auth.linkBeforeUid, isNull);
    expect(auth.refreshCalls, 1);
    expect(profile.transitionCalls, 1);
  });

  testWidgets('기존 이메일 충돌은 자동 병합 없이 입력값과 화면을 유지한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(count: 0, limit: 10),
    );
    final auth = _FakeAuthGateway(
      anonymous: true,
      linkError: const AppAccountException(
        AppAccountErrorCode.emailAlreadyInUse,
      ),
    );
    await _pumpPage(tester, gateway: gateway, anonymous: true, auth: auth);

    await _openEmailLinkSheet(tester);
    await _scrollTo(tester, const Key('link_email'));
    await tester.enterText(
      find.byKey(const Key('link_email')),
      'used@example.com',
    );
    await tester.enterText(find.byKey(const Key('link_password')), 'secret12');
    await tester.enterText(
      find.byKey(const Key('link_password_confirmation')),
      'secret12',
    );
    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pumpAndSettle();

    expect(find.text('used@example.com'), findsOneWidget);
    expect(find.textContaining('이미 사용 중인 이메일'), findsWidgets);
    expect(find.textContaining('안전한 계정 전환 절차'), findsOneWidget);
    expect(auth.signOutCalls, 0);
  });

  testWidgets('계정 연결 네트워크 실패는 입력값과 시트를 유지하고 재시도를 안내한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(count: 10, limit: 10),
    );
    final auth = _FakeAuthGateway(anonymous: true);
    final profile = _FakeProfileGateway(
      transitionErrors: [
        FirebaseFunctionsException(
          code: 'unavailable',
          message: 'network unavailable',
        ),
      ],
    );
    await _pumpPage(
      tester,
      gateway: gateway,
      anonymous: true,
      auth: auth,
      profile: profile,
    );

    await _openEmailLinkSheet(tester);
    await _scrollTo(tester, const Key('link_email'));
    await tester.enterText(
      find.byKey(const Key('link_email')),
      'retry@example.com',
    );
    await tester.enterText(find.byKey(const Key('link_password')), 'secret12');
    await tester.enterText(
      find.byKey(const Key('link_password_confirmation')),
      'secret12',
    );
    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pumpAndSettle();

    expect(find.text('retry@example.com'), findsOneWidget);
    expect(find.textContaining('이 화면에서 다시 시도'), findsWidgets);
    expect(find.byKey(const Key('link_email_account')), findsOneWidget);
    expect(profile.transitionCalls, 1);
  });

  testWidgets('linked 로그아웃은 현재 UID widget cache를 먼저 정리한다', (tester) async {
    final gateway = _FakeMemberGateway(
      usage: const ManagedMemberUsage(count: 0, limit: 10, accountLinked: true),
    );
    final auth = _FakeAuthGateway(anonymous: false);
    final events = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalMyPage(
          uid: 'owner-uid',
          accountService: AppAccountService(
            gateway: auth,
            anonymousGateway: auth,
            profileGateway: _FakeProfileGateway(),
          ),
          memberGateway: gateway,
          onBeforeSignOut: (uid) async => events.add('clear:$uid'),
          autoNudgeEnabled: false,
        ),
      ),
    );
    await tester.pump();
    await _scrollTo(tester, const Key('personal_account_sign_out'));
    await tester.tap(find.byKey(const Key('personal_account_sign_out')));
    await tester.pumpAndSettle();

    expect(events, ['clear:owner-uid']);
    expect(auth.signOutCalls, 1);
  });
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    350,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openEmailLinkSheet(WidgetTester tester) async {
  await _scrollTo(tester, const Key('open_account_and_records'));
  await tester.tap(find.byKey(const Key('open_account_and_records')));
  await tester.pumpAndSettle();
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeMemberGateway gateway,
  required bool anonymous,
  _FakeAuthGateway? auth,
  _FakeProfileGateway? profile,
  PersonalMyPageNudgeStore? nudgeStore,
  bool autoNudgeEnabled = false,
}) async {
  final resolvedAuth = auth ?? _FakeAuthGateway(anonymous: anonymous);
  await tester.pumpWidget(
    MaterialApp(
      home: PersonalMyPage(
        uid: 'owner-uid',
        accountService: AppAccountService(
          gateway: resolvedAuth,
          anonymousGateway: resolvedAuth,
          profileGateway: profile ?? _FakeProfileGateway(),
        ),
        memberGateway: gateway,
        nudgeStore: nudgeStore ?? _FakeNudgeStore(),
        autoNudgeEnabled: autoNudgeEnabled,
      ),
    ),
  );
  await tester.pump();
}

class _FakeNudgeStore implements PersonalMyPageNudgeStore {
  final Map<String, String> values = {};

  @override
  Future<String?> readLastKey(String uid) async => values[uid];

  @override
  Future<void> writeLastKey(String uid, String key) async {
    values[uid] = key;
  }
}

class _FakeMemberGateway implements ManagedMemberWorkspaceGateway {
  _FakeMemberGateway({required this.usage, this.profileError});

  final ManagedMemberUsage usage;
  final Object? profileError;
  int profileCalls = 0;

  @override
  Stream<ManagedMemberUsage> watchUsage() => Stream.value(usage);

  @override
  Stream<List<ManagedMemberSummary>> watchMembers() => Stream.value(const []);

  @override
  Future<void> updateTrainerProfile({
    required String displayName,
    required String phone,
    required String activityRegion,
    required String primaryActivity,
    String? affiliationType,
    String? nickname,
    String? realName,
    String? jobTitle,
    String? contractTrainerNameSource,
    String? contractTrainerCustomName,
    String? nameEn,
    List<String>? activityRegions,
    String? gymName,
    String? centerLocation,
    String? intro,
  }) async {
    profileCalls++;
    if (profileError case final error?) throw error;
  }

  @override
  Future<Map<String, dynamic>> pauseMembership({
    required String memberId,
    required int pauseDays,
  }) async => <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> resumeMembership({
    required String memberId,
  }) async => <String, dynamic>{};

  @override
  Future<void> createMember({
    required String idempotencyKey,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  }) async {}

  @override
  Future<void> transitionMember({
    required String memberId,
    required String nextState,
  }) async {}

  @override
  Future<void> updateMember({
    required String memberId,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  }) async {}
}

class _FakeProfileGateway implements AnonymousProfileGateway {
  _FakeProfileGateway({List<Object>? transitionErrors})
    : transitionErrors = transitionErrors ?? <Object>[];

  int transitionCalls = 0;
  final List<Object> transitionErrors;

  @override
  Future<void> bootstrapAnonymousBeginnerProfile() async {}

  @override
  Future<void> transitionAnonymousProfileToLinked() async {
    transitionCalls++;
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

class _FakeAuthGateway
    implements
        AppAccountAuthGateway,
        AppAnonymousIdentityGateway,
        AppEmailVerificationGateway {
  _FakeAuthGateway({
    required bool anonymous,
    this.linkError,
    bool? emailVerified,
    this.reloadEmailVerified,
    List<String>? providerIds,
  }) : _user = AppAccountUser(
         uid: 'owner-uid',
         email: anonymous ? '' : 'trainer@example.com',
         emailVerified: emailVerified ?? !anonymous,
         isAnonymous: anonymous,
         providerIds:
             providerIds ?? (anonymous ? const [] : const ['password']),
       );

  AppAccountUser? _user;
  final Object? linkError;
  final bool? reloadEmailVerified;
  String? linkBeforeUid;
  int refreshCalls = 0;
  int verificationCalls = 0;
  int reloadCalls = 0;
  int signOutCalls = 0;

  @override
  AppAccountUser? get currentUser => _user;

  @override
  Stream<AppAccountUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  }) async {
    linkBeforeUid = _user?.uid;
    if (linkError case final error?) throw error;
    _user = AppAccountUser(
      uid: _user!.uid,
      email: email,
      emailVerified: false,
      isAnonymous: false,
      providerIds: const ['password'],
    );
    return _user!;
  }

  @override
  Future<void> forceRefreshIdToken() async => refreshCalls++;

  @override
  Future<void> sendEmailVerification() async => verificationCalls++;

  @override
  Future<AppAccountUser> reloadCurrentUser() async {
    reloadCalls++;
    final current = _user!;
    _user = AppAccountUser(
      uid: current.uid,
      email: current.email,
      emailVerified: reloadEmailVerified ?? current.emailVerified,
      isAnonymous: current.isAnonymous,
      providerIds: current.providerIds,
    );
    return _user!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _user = null;
  }

  @override
  Future<AppAccountUser> signInAnonymously() async => _user!;

  @override
  Future<AppAccountUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();
}
