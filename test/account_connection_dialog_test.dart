import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_account_service.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/account_connection_dialog.dart';

void main() {
  final themes = <String, ThemeData>{
    'light': lightTheme(),
    'dark': darkTheme(),
    'lululala': lululalaTheme(),
  };

  for (final themeEntry in themes.entries) {
    for (final width in <double>[320, 360, 384, 411]) {
      testWidgets(
        '${themeEntry.key} ${width.toInt()}dp 계정 연결 dialog가 스크롤 가능한 고정 카드로 표시된다',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 640));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final gateway = _FakeAccountGateway();

          await tester.pumpWidget(
            _TestHost(theme: themeEntry.value, service: _service(gateway)),
          );
          await tester.tap(find.byKey(const Key('open_account_dialog')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('account_connection_dialog')), findsOne);
          expect(find.byKey(const Key('link_email')), findsOne);
          expect(find.byKey(const Key('link_password')), findsOne);
          expect(find.byKey(const Key('link_password_confirmation')), findsOne);
          expect(find.byKey(const Key('link_kakao_preparing')), findsOne);
          expect(find.byKey(const Key('link_google_account')), findsOne);
          expect(find.byKey(const Key('link_naver_preparing')), findsOne);
          expect(find.byType(Image), findsOneWidget);
          expect(find.text('카카오·네이버 계정 연결은 준비 중이에요.'), findsOne);
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -240),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('cancel_account_connection')), findsOne);
          await tester.tap(find.byKey(const Key('cancel_account_connection')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('account_connection_dialog')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('invalid email은 입력과 dialog를 유지한다', (tester) async {
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(
      _TestHost(theme: lightTheme(), service: _service(gateway)),
    );
    await _openAndFill(
      tester,
      email: 'invalid-email',
      password: '123456',
      confirmation: '123456',
    );

    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pump();

    expect(find.text('이메일 주소 형식을 확인해주세요.'), findsWidgets);
    expect(find.byKey(const Key('account_connection_dialog')), findsOne);
    expect(_fieldText(tester, 'link_email'), 'invalid-email');
    expect(gateway.linkCalls, 0);
    await _cancel(tester);
  });

  testWidgets('password mismatch와 weak password는 입력을 유지한다', (tester) async {
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(
      _TestHost(theme: darkTheme(), service: _service(gateway)),
    );
    await _openAndFill(
      tester,
      email: 'tester@example.com',
      password: '123456',
      confirmation: '654321',
    );

    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pump();
    expect(find.text('비밀번호 확인이 일치하지 않아요.'), findsWidgets);
    expect(_fieldText(tester, 'link_email'), 'tester@example.com');
    expect(gateway.linkCalls, 0);

    await tester.enterText(find.byKey(const Key('link_password')), '123');
    await tester.enterText(
      find.byKey(const Key('link_password_confirmation')),
      '123',
    );
    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pump();
    expect(find.text('비밀번호는 6자 이상 입력해주세요.'), findsWidgets);
    expect(_fieldText(tester, 'link_password'), '123');
    expect(gateway.linkCalls, 0);
    await _cancel(tester);
  });

  testWidgets('keyboard open에서도 내부 스크롤과 취소가 가능하다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeAccountGateway();
    await tester.pumpWidget(
      _TestHost(
        theme: lululalaTheme(),
        service: _service(gateway),
        keyboardInset: 280,
      ),
    );
    await tester.tap(find.byKey(const Key('open_account_dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('link_email')));
    await tester.pump();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel_account_connection')), findsOne);
    expect(tester.takeException(), isNull);
    await _cancel(tester);
  });

  testWidgets('이메일 연결 성공은 anonymous UID를 유지하고 profile을 전환한다', (tester) async {
    final gateway = _FakeAccountGateway();
    final profile = _FakeProfileGateway();
    AppAccountUser? result;
    final service = AppAccountService(
      gateway: gateway,
      anonymousGateway: gateway,
      profileGateway: profile,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  key: const Key('open_account_dialog'),
                  onPressed: () async {
                    result = await AccountConnectionDialog.show(
                      context: context,
                      accountService: service,
                      expectedUid: 'owner-uid',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await _openAndFill(
      tester,
      email: 'tester@example.com',
      password: '123456',
      confirmation: '123456',
      tapOpen: true,
    );

    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const Key('account_link_success')), findsOneWidget);
    expect(find.text('계정이 연결됐어요 🙌'), findsOneWidget);
    expect(gateway.verificationCalls, 0);
    await tester.tap(
      find.byKey(const Key('send_verification_email_after_link')),
    );
    await tester.pumpAndSettle();
    expect(gateway.verificationCalls, 1);
    expect(
      find.byKey(const Key('verification_email_sent_message')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('continue_after_verification_email')),
    );
    await tester.pumpAndSettle();

    expect(result?.uid, 'owner-uid');
    expect(result?.isAnonymous, isFalse);
    expect(gateway.linkBeforeUid, 'owner-uid');
    expect(gateway.currentUser?.uid, 'owner-uid');
    expect(gateway.refreshCalls, 1);
    expect(profile.transitionCalls, 1);
    expect(find.byKey(const Key('account_connection_dialog')), findsNothing);
  });

  testWidgets('인증메일 too-many-requests는 연결 완료 상태와 재시도 버튼을 유지한다', (tester) async {
    final gateway = _FakeAccountGateway(
      verificationError: const AppAccountException(
        AppAccountErrorCode.tooManyRequests,
      ),
    );
    await tester.pumpWidget(
      _TestHost(theme: lightTheme(), service: _service(gateway)),
    );
    await _openAndFill(
      tester,
      email: 'tester@example.com',
      password: '123456',
      confirmation: '123456',
    );
    await tester.tap(find.byKey(const Key('link_email_account')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('send_verification_email_after_link')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('요청이 너무 많아요'), findsWidgets);
    expect(find.byKey(const Key('account_link_success')), findsOneWidget);
    expect(
      find.byKey(const Key('send_verification_email_after_link')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('continue_link_without_verification')),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('이메일 연결 계정에 Google을 추가해도 UID와 password provider를 유지한다', (
    tester,
  ) async {
    const before = AppAccountUser(
      uid: 'owner-uid',
      email: 'trainer@example.com',
      emailVerified: true,
      isAnonymous: false,
      providerIds: ['password'],
    );
    const after = AppAccountUser(
      uid: 'owner-uid',
      email: 'trainer@example.com',
      emailVerified: true,
      isAnonymous: false,
      providerIds: ['password', 'google.com'],
    );
    final gateway = _FakeAccountGateway(initialUser: before);
    final google = _FakeGoogleGateway(result: after);
    AppAccountUser? result;
    final service = _service(gateway, googleGateway: google);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  key: const Key('open_account_dialog'),
                  onPressed: () async {
                    result = await AccountConnectionDialog.show(
                      context: context,
                      accountService: service,
                      expectedUid: 'owner-uid',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_account_dialog')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email_provider_connected')), findsOneWidget);
    await tester.tap(find.byKey(const Key('link_google_account')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(result?.uid, before.uid);
    expect(result?.hasProvider('password'), isTrue);
    expect(result?.hasProvider('google.com'), isTrue);
    expect(google.calls, 1);
    expect(find.textContaining('Google 계정이 연결됐어요'), findsWidgets);
    expect(find.byKey(const Key('account_connection_dialog')), findsNothing);
  });

  testWidgets('Google account chooser 취소는 dialog와 기존 UID를 유지한다', (
    tester,
  ) async {
    const before = AppAccountUser(
      uid: 'owner-uid',
      email: 'trainer@example.com',
      emailVerified: true,
      isAnonymous: false,
      providerIds: ['password'],
    );
    final gateway = _FakeAccountGateway(initialUser: before);
    final google = _FakeGoogleGateway();
    await tester.pumpWidget(
      _TestHost(
        theme: darkTheme(),
        service: _service(gateway, googleGateway: google),
      ),
    );

    await tester.tap(find.byKey(const Key('open_account_dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('link_google_account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account_connection_dialog')), findsOneWidget);
    expect(find.byKey(const Key('account_link_error')), findsNothing);
    expect(gateway.currentUser?.uid, before.uid);
    expect(google.calls, 1);
    await _cancel(tester);
  });
}

AppAccountService _service(
  _FakeAccountGateway gateway, {
  AppGoogleIdentityGateway? googleGateway,
}) => AppAccountService(
  gateway: gateway,
  anonymousGateway: gateway,
  googleGateway: googleGateway,
  profileGateway: _FakeProfileGateway(),
);

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.theme,
    required this.service,
    this.keyboardInset = 0,
  });

  final ThemeData theme;
  final AppAccountService service;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardInset)),
            child: child!,
          ),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                key: const Key('open_account_dialog'),
                onPressed:
                    () => AccountConnectionDialog.show(
                      context: context,
                      accountService: service,
                      expectedUid: 'owner-uid',
                    ),
                child: const Text('open'),
              ),
            ),
      ),
    );
  }
}

Future<void> _openAndFill(
  WidgetTester tester, {
  required String email,
  required String password,
  required String confirmation,
  bool tapOpen = true,
}) async {
  if (tapOpen) {
    await tester.tap(find.byKey(const Key('open_account_dialog')));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('link_email')), email);
  await tester.enterText(find.byKey(const Key('link_password')), password);
  await tester.enterText(
    find.byKey(const Key('link_password_confirmation')),
    confirmation,
  );
}

String _fieldText(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

Future<void> _cancel(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const Key('cancel_account_connection')),
  );
  await tester.tap(find.byKey(const Key('cancel_account_connection')));
  await tester.pumpAndSettle();
}

class _FakeAccountGateway
    implements AppAccountAuthGateway, AppAnonymousIdentityGateway {
  _FakeAccountGateway({this.verificationError, AppAccountUser? initialUser})
    : _user =
          initialUser ??
          const AppAccountUser(
            uid: 'owner-uid',
            email: '',
            emailVerified: false,
            isAnonymous: true,
          );

  AppAccountUser? _user;
  int linkCalls = 0;
  int refreshCalls = 0;
  int verificationCalls = 0;
  String? linkBeforeUid;
  final Object? verificationError;

  @override
  AppAccountUser? get currentUser => _user;

  @override
  Stream<AppAccountUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  }) async {
    linkCalls++;
    linkBeforeUid = _user?.uid;
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
  Future<void> sendEmailVerification() async {
    verificationCalls++;
    if (verificationError case final error?) throw error;
  }

  @override
  Future<AppAccountUser> signInAnonymously() async => _user!;

  @override
  Future<AppAccountUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async => _user = null;
}

class _FakeGoogleGateway implements AppGoogleIdentityGateway {
  _FakeGoogleGateway({this.result});

  final AppAccountUser? result;
  int calls = 0;

  @override
  Future<AppAccountUser?> linkWithGoogleCredential() async {
    calls++;
    return result;
  }
}

class _FakeProfileGateway implements AnonymousProfileGateway {
  int transitionCalls = 0;

  @override
  Future<void> bootstrapAnonymousBeginnerProfile() async {}

  @override
  Future<void> transitionAnonymousProfileToLinked() async {
    transitionCalls++;
  }

  @override
  Future<Map<String, dynamic>> reconcilePersonalTier() async => const {};
}
