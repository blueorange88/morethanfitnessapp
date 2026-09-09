import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/guest_preview_page.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/services/home_guest_schedule_repository.dart';
import 'package:mtf_app/widgets/home/sections/home_bottom_nav_bar.dart';
import 'package:mtf_app/widgets/home/sections/home_header_section.dart';
import 'package:mtf_app/widgets/home/sections/home_this_week_schedule_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Guest 홈은 실제 홈 공통 구조를 서버 초기화 없이 사용한다', (tester) async {
    await _pumpGuestHome(tester);

    expect(find.byType(HomeHeaderSection), findsOneWidget);
    expect(find.byType(HomeThisWeekScheduleSection), findsOneWidget);
    expect(find.byType(HomeBottomNavBar), findsOneWidget);
    expect(find.text('체험 중 · 일정은 이 기기에만 저장돼요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guest 헤더는 동행 문구를 표시하고 좁은 화면에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpGuestHome(tester);

    expect(find.text('우리, 같이 시작해볼까요'), findsOneWidget);
    expect(find.textContaining('함께'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('회원·레슨일지·인사이트 기능은 탭 가능한 샘플 동선이다', (tester) async {
    await _pumpGuestHome(tester);

    await tester.tap(find.text('레슨일지'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('예시'), findsOneWidget);
    expect(find.textContaining('레슨 기록도'), findsOneWidget);
    Navigator.of(tester.element(find.text('예시'))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('인사이트').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('인사이트'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('계약서 soft gate는 누적되지 않고 레이아웃을 움직이지 않는다', (tester) async {
    await _pumpGuestHome(tester);
    final before =
        tester.getTopLeft(find.byKey(const Key('guest_local_only_notice')));

    await tester.tap(find.text('계약서'));
    await tester.pump();
    await tester.tap(find.text('계약서'));
    await tester.pump();

    expect(find.textContaining('계약서 작성도'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('guest_local_only_notice'))),
      before,
    );
  });

  testWidgets('Guest 하단 내비는 선택 상태를 바꾸고 실제 Firebase 페이지를 열지 않는다',
      (tester) async {
    await _pumpGuestHome(tester);

    await tester.tap(find.text('고객리스트'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('회원관리'), findsOneWidget);
    expect(find.text('예시'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('6번째 일정은 입력을 유지하고 계정 연결 취소 후에도 로컬 5개를 보존한다', (tester) async {
    final repository = GuestScheduleRepository();
    for (var index = 0; index < 5; index++) {
      final start = DateTime(2026, 7, 15, 8 + index);
      await repository.save(
        nameOrAlias: '별칭 $index',
        lessonType: 'PT',
        startAt: start,
        endAt: start.add(const Duration(minutes: 50)),
        memo: '',
        colorHex: '#4F46E5',
      );
    }
    await _pumpGuestHome(tester, repository: repository);

    await tester.tap(find.byKey(const Key('guest_add_schedule_button')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const Key('guest_schedule_alias')),
      '여섯번째 별칭',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -700),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_guest_schedule')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.byKey(const Key('guest_schedule_limit_message')), findsOneWidget);
    expect(find.text('여섯번째 별칭'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('guest_schedule_connect_account')),
    );
    await tester.tap(find.byKey(const Key('guest_schedule_connect_account')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('이메일 계정 연결'), findsOneWidget);

    Navigator.of(tester.element(find.text('이메일 계정 연결'))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('여섯번째 별칭'), findsOneWidget);
    expect(await repository.load(), hasLength(5));
  });
}

Future<void> _pumpGuestHome(
  WidgetTester tester, {
  GuestScheduleRepository? repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GuestPreviewPage(
        service: AppAccountService(gateway: _FakeAuthGateway()),
        scheduleRepository: repository ?? GuestScheduleRepository(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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
