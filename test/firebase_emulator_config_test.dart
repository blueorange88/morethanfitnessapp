import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/main.dart' as app;
import 'package:mtf_app/services/firebase_emulator_config.dart';
import 'package:mtf_app/services/mtf_firebase_functions.dart';
import 'package:mtf_app/widgets/firebase_emulator_banner.dart';

void main() {
  test('Debug와 dart-define이 모두 참일 때만 Emulator를 사용한다', () {
    expect(FirebaseEmulatorConfig.host, '127.0.0.1');
    expect(FirebaseEmulatorConfig.authPort, 9099);
    expect(FirebaseEmulatorConfig.firestorePort, 8080);
    expect(FirebaseEmulatorConfig.functionsPort, 5001);
    expect(
      FirebaseEmulatorConfig.shouldUseEmulators(
        debugMode: true,
        requested: true,
      ),
      isTrue,
    );
    expect(
      FirebaseEmulatorConfig.shouldUseEmulators(
        debugMode: true,
        requested: false,
      ),
      isFalse,
    );
    expect(
      FirebaseEmulatorConfig.shouldUseEmulators(
        debugMode: false,
        requested: true,
      ),
      isFalse,
    );
    expect(
      FirebaseEmulatorConfig.shouldUseEmulators(
        debugMode: true,
        requested: true,
        isWeb: true,
      ),
      isFalse,
    );
  });

  test('Auth, Firestore, Functions 순서로 한 번씩 연결한다', () async {
    final calls = <String>[];
    await FirebaseEmulatorConfig.configureConnectors(
      enabled: true,
      auth: () => calls.add('auth'),
      firestore: () => calls.add('firestore'),
      functions: () => calls.add('functions'),
    );

    expect(calls, ['auth', 'firestore', 'functions']);
    expect(MtfFirebaseFunctions.region, 'asia-northeast3');
  });

  test('Emulator가 비활성이면 connector를 호출하지 않는다', () async {
    final calls = <String>[];
    await FirebaseEmulatorConfig.configureConnectors(
      enabled: false,
      auth: () => calls.add('auth'),
      firestore: () => calls.add('firestore'),
      functions: () => calls.add('functions'),
    );

    expect(calls, isEmpty);
  });

  test('연결 실패 시 다음 connector나 production fallback을 실행하지 않는다', () async {
    final calls = <String>[];

    await expectLater(
      FirebaseEmulatorConfig.configureConnectors(
        enabled: true,
        auth: () => calls.add('auth'),
        firestore: () {
          calls.add('firestore');
          throw StateError('offline');
        },
        functions: () => calls.add('functions'),
      ),
      throwsA(isA<FirebaseEmulatorConfigurationException>()),
    );
    expect(calls, ['auth', 'firestore']);
  });

  testWidgets('Emulator 모드에서만 작은 LOCAL EMULATOR 표시를 겹친다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FirebaseEmulatorBanner(
          enabled: true,
          child: Scaffold(body: Text('home')),
        ),
      ),
    );
    expect(find.byKey(const Key('local_emulator_banner')), findsOneWidget);
    expect(find.text('home'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: FirebaseEmulatorBanner(
          enabled: false,
          child: Scaffold(body: Text('home')),
        ),
      ),
    );
    expect(find.byKey(const Key('local_emulator_banner')), findsNothing);
  });

  testWidgets('초기 Emulator 설정 실패는 실제 홈 대신 오류 화면을 표시한다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: app.MyApp(
          firebaseEmulatorStartupError:
              FirebaseEmulatorConfigurationException(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('firebase_emulator_startup_error')),
      findsOneWidget,
    );
    expect(find.byType(app.RootPage), findsNothing);
  });
}
