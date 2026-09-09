import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/splash_router.dart';
import 'pages/home_page.dart';
import 'pages/schedule_page.dart';
import 'pages/settings_page.dart';
import 'pages/my_page.dart';
import 'pages/client_list_page.dart';
import 'pages/contract_list_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashRouter(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: '/schedule',
        name: 'schedule',
        builder: (_, __) => const SchedulePage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: '/my',
        name: 'my',
        builder: (_, __) => const MyPage(),
      ),
      GoRoute(
        path: '/clients',
        name: 'clients',
        builder: (_, __) => const ClientListPage(),
      ),
      GoRoute(
        path: '/contracts',
        name: 'contracts',
        builder: (_, __) => const ContractListPage(),
      ),
    ],
  );
}