// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mtf_app/pages/client_list_page.dart';

import 'firebase_options.dart';
import 'theme.dart';
import 'providers/theme_provider.dart';

// 페이지들
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/test_hub_pages.dart';
import 'services/mtf_widget_interactivity.dart';
import 'pages/widget_settings_page.dart';

import 'package:flutter/foundation.dart';
import 'pages/member_signature_web_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    try {
      await registerMtfWidgetInteractivity();
    } catch (e) {
      debugPrint('위젯 인터랙션 등록 실패: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'More Than Fitness',
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => _buildAppHome(),
        '/sign': (context) => _buildAppHome(),
        '/widget-settings': (context) => const WidgetSettingsPage(),
      },
    );
  }
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
    TestHubPage(),
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

  final isMemberSignPath =
      uri.path == '/sign' || uri.path.endsWith('/sign');

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

  return const RootPage();
}