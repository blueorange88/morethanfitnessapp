// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtf_app/pages/client_list_page.dart';

import 'theme.dart';
import 'providers/theme_provider.dart';

// 페이지들
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'services/mtf_widget_interactivity.dart';
import 'pages/widget_settings_page.dart';

import 'package:flutter/foundation.dart';
import 'pages/member_signature_web_page.dart';
import 'pages/account_gate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/firebase_emulator_config.dart';
import 'widgets/firebase_emulator_banner.dart';
import 'services/mtf_route_observer.dart';
import 'services/app_environment.dart';
import 'services/mtf_firebase_initializer.dart';
import 'widgets/app_environment_banner.dart';

Future<void> main() => runMtfApp(environment: AppEnvironment.prod);

Future<void> runMtfApp({required AppEnvironment environment}) async {
  WidgetsFlutterBinding.ensureInitialized();

  AppEnvironmentConfig.select(environment);

  final firebaseApp = await MtfFirebaseInitializer.initialize(environment);
  AppEnvironmentConfig.bindFirebaseApp(firebaseApp);
  AppEnvironmentConfig.debugLogEnvironment();

  Object? firebaseEmulatorStartupError;
  try {
    await FirebaseEmulatorConfig.configure();
  } catch (error) {
    firebaseEmulatorStartupError = error;
  }

  if (firebaseEmulatorStartupError == null && !kIsWeb) {
    try {
      await registerMtfWidgetInteractivity();
    } catch (e) {
      debugPrint('위젯 인터랙션 등록 실패: $e');
    }
  }

  runApp(
    ProviderScope(
      child: MyApp(
        firebaseEmulatorStartupError: firebaseEmulatorStartupError,
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({
    this.firebaseEmulatorStartupError,
    super.key,
  });

  final Object? firebaseEmulatorStartupError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    return MaterialApp(
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: '모어댄',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [mtfRouteObserver],
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        Widget result = child ?? const SizedBox.shrink();
        result = FirebaseEmulatorBanner(
          enabled: FirebaseEmulatorConfig.isEnabled,
          child: result,
        );
        return AppEnvironmentBanner(
          enabled: AppEnvironmentConfig.isDev,
          child: result,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => firebaseEmulatorStartupError == null
            ? _buildAppHome()
            : const _FirebaseEmulatorStartupErrorPage(),
        '/sign': (context) => firebaseEmulatorStartupError == null
            ? _buildAppHome()
            : const _FirebaseEmulatorStartupErrorPage(),
        '/widget-settings': (context) => const WidgetSettingsPage(),
      },
    );
  }
}

class _FirebaseEmulatorStartupErrorPage extends StatelessWidget {
  const _FirebaseEmulatorStartupErrorPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
        key: Key('firebase_emulator_startup_error'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 44),
                SizedBox(height: 16),
                Text(
                  '로컬 Firebase에 연결하지 못했어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Emulator Suite와 USB 포트 연결을 확인한 뒤 앱을 다시 시작해주세요.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  // 0=고객리스트, 1=홈, 2=테스트, 3=설정
  int _index = 1;

  static const _titles = ['고객리스트', '홈', '테스트', '설정'];

  final List<Widget> _pages = const [
    ClientListPage(),
    HomePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 홈(index 1)일 때만 AppBar 숨김 → 왼쪽 상단 "홈" 안 보임
      appBar: _index == 1
          ? null
          : AppBar(
              title: Text(_titles[_index]),
            ),
      body: IndexedStack(index: _index, children: _pages),
    );
  }
}

Widget _buildAppHome() {
  final uri = Uri.base;
  final token = uri.queryParameters['t']?.trim() ?? '';

  final isMemberSignPath = uri.path == '/sign' || uri.path.endsWith('/sign');

  if (kIsWeb) {
    if (isMemberSignPath && token.isNotEmpty) {
      return MemberSignatureWebPage(token: token);
    }

    return const Scaffold(
      backgroundColor: Color(0xFFF3F4F6),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '회원 서명 링크로 접속해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  return const AppAccountGate();
}
