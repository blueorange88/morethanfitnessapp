import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_workspace_ready_page.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/managed_member_workspace_service.dart';

void main() {
  testWidgets('빈 개인 작업공간은 Beginner와 첫 회원 안내를 표시한다', (tester) async {
    final gateway = _FakeMemberGateway();
    await _pumpPage(tester, gateway);

    expect(find.text('0명 · Beginner'), findsOneWidget);
    expect(find.text('첫 회원을 등록해보세요.'), findsOneWidget);
    expect(find.text('첫 회원 등록'), findsOneWidget);
    expect(
        find.byKey(const Key('create_managed_member_button')), findsOneWidget);
  });

  testWidgets('회원 등록은 Cloud Function gateway만 한 번 호출한다', (tester) async {
    final gateway = _FakeMemberGateway();
    await _pumpPage(tester, gateway);

    await tester.tap(find.byKey(const Key('create_managed_member_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('managed_member_name')),
      '김회원',
    );
    await _fillQualificationFields(tester);
    await tester.tap(find.byKey(const Key('save_managed_member_button')));
    await tester.pumpAndSettle();

    expect(gateway.createCalls, 1);
    expect(gateway.lastName, '김회원');
    expect(find.byKey(const Key('managed_member_name')), findsNothing);
    expect(find.text('1명 · Beginner'), findsWidgets);
  });

  testWidgets('저장 실패 시 입력 화면을 닫지 않고 입력값을 유지한다', (tester) async {
    final gateway = _FakeMemberGateway(createError: StateError('network'));
    await _pumpPage(tester, gateway);

    await tester.tap(find.byKey(const Key('create_managed_member_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('managed_member_name')),
      '재시도회원',
    );
    await _fillQualificationFields(tester);
    await tester.tap(find.byKey(const Key('save_managed_member_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('managed_member_error')), findsOneWidget);
    expect(find.text('재시도회원'), findsOneWidget);
  });

  testWidgets('10명 한도 오류는 명확한 안내를 표시한다', (tester) async {
    final gateway = _FakeMemberGateway(
      createError: FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'member_limit_reached',
      ),
    );
    await _pumpPage(tester, gateway);

    await tester.tap(find.byKey(const Key('create_managed_member_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('managed_member_name')), '열한번째');
    await _fillQualificationFields(tester);
    await tester.tap(find.byKey(const Key('save_managed_member_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('관리 중인 회원을 10명까지'), findsOneWidget);
  });

  testWidgets('회원 목록은 gateway가 제공한 개인 작업공간 회원만 표시한다', (tester) async {
    final gateway = _FakeMemberGateway(
      members: const [
        ManagedMemberSummary(
          memberId: 'mine',
          name: '내 회원',
          phone: '01012341234',
          managementState: 'paused',
        ),
      ],
    );
    await _pumpPage(tester, gateway);

    expect(find.text('내 회원'), findsOneWidget);
    expect(find.textContaining('회원권 정지'), findsOneWidget);
    expect(find.text('다른 트레이너 회원'), findsNothing);
  });

  testWidgets('누적 유효 회원과 등급 표시를 갱신한다', (tester) async {
    final gateway = _FakeMemberGateway();
    await _pumpPage(tester, gateway);

    gateway.emitUsage(const ManagedMemberUsage(
      count: 10,
      limit: 10,
      lifetimeQualifiedCount: 10,
      tier: 'Amateur',
    ));
    await tester.pump();
    expect(find.text('10명 · Amateur'), findsWidgets);
  });

  testWidgets('같은 등록 화면의 재시도는 동일 idempotency key를 사용한다', (tester) async {
    final gateway = _FakeMemberGateway(createError: StateError('network'));
    await _pumpPage(tester, gateway);

    await tester.tap(find.byKey(const Key('create_managed_member_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('managed_member_name')), '중복방지');
    await _fillQualificationFields(tester);
    await tester.tap(find.byKey(const Key('save_managed_member_button')));
    await tester.pumpAndSettle();
    final firstKey = gateway.lastIdempotencyKey;
    gateway.createError = null;
    await tester.tap(find.byKey(const Key('save_managed_member_button')));
    await tester.pumpAndSettle();

    expect(gateway.createCalls, 2);
    expect(gateway.lastIdempotencyKey, firstKey);
  });
}

Future<void> _fillQualificationFields(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('managed_member_gender')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('남성').last);
  await tester.enterText(
    find.byKey(const Key('managed_member_phone')),
    '01012345678',
  );
  await tester.enterText(
    find.byKey(const Key('managed_member_activity_region')),
    '서울',
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeMemberGateway memberGateway,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PersonalWorkspaceReadyPage(
        service: AppAccountService(gateway: _FakeAuthGateway()),
        uid: 'owner-uid',
        memberGateway: memberGateway,
      ),
    ),
  );
  await tester.pump();
}

class _FakeMemberGateway implements ManagedMemberWorkspaceGateway {
  _FakeMemberGateway({this.createError, List<ManagedMemberSummary>? members})
      : _members = members ?? const [];

  final _usage = StreamController<ManagedMemberUsage>.broadcast(sync: true);
  final List<ManagedMemberSummary> _members;
  Object? createError;
  var _currentUsage = const ManagedMemberUsage(count: 0, limit: 10);
  int createCalls = 0;
  String? lastIdempotencyKey;
  String? lastName;

  void emitUsage(ManagedMemberUsage value) {
    _currentUsage = value;
    _usage.add(value);
  }

  @override
  Stream<ManagedMemberUsage> watchUsage() async* {
    yield _currentUsage;
    yield* _usage.stream;
  }

  @override
  Stream<List<ManagedMemberSummary>> watchMembers() async* {
    yield _members;
  }

  @override
  Future<void> createMember({
    required String idempotencyKey,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  }) async {
    createCalls++;
    lastIdempotencyKey = idempotencyKey;
    lastName = name;
    if (createError case final error?) throw error;
    emitUsage(ManagedMemberUsage(
      count: _currentUsage.count + 1,
      limit: _currentUsage.limit,
      lifetimeQualifiedCount: _currentUsage.lifetimeQualifiedCount + 1,
      tier: _currentUsage.tier,
    ));
  }

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
  }) async {}
}

class _FakeAuthGateway implements AppAccountAuthGateway {
  @override
  AppAccountUser? get currentUser => null;

  @override
  Stream<AppAccountUser?> authStateChanges() => const Stream.empty();

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
}
