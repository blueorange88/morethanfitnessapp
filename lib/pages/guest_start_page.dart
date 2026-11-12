import 'package:flutter/material.dart';

import '../services/app_account_service.dart';
import '../services/app_environment.dart';
import 'email_auth_page.dart';
import 'guest_preview_page.dart';

class GuestStartPage extends StatelessWidget {
  const GuestStartPage({
    super.key,
    required this.service,
    this.onOpenDebugLegacyWorkspace,
  });

  final AppAccountService service;
  final VoidCallback? onOpenDebugLegacyWorkspace;

  @override
  Widget build(BuildContext context) {
    AppEnvironmentConfig.debugLogLegacyWorkspaceAccess('guestStart');
    final showDebugLegacyWorkspace =
        AppEnvironmentConfig.canOpenDebugLegacyWorkspace &&
        onOpenDebugLegacyWorkspace != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                        SizedBox(height: 22),
                        Text(
                          '모어댄',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '가입 없이 먼저 둘러보고,\n실제 회원을 관리할 때 계정을 연결하세요.',
                          style: TextStyle(
                            color: Color(0xFFEDE9FE),
                            height: 1.45,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('guest_preview_button'),
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GuestPreviewPage(service: service),
                          ),
                        ),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('가입 없이 둘러보기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('email_auth_button'),
                    onPressed: () => _openEmail(context),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('이메일로 시작하기'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('google_auth_button'),
                    onPressed: null,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: const Text('Google 로그인 · 후속 준비 중'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                  if (showDebugLegacyWorkspace) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('open_debug_legacy_workspace'),
                      onPressed: onOpenDebugLegacyWorkspace,
                      icon: const Icon(Icons.storage_rounded),
                      label: const Text('DEV 기존 데이터 열기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Guest 체험에서는 예시 데이터만 사용하며 실제 회원정보를 서버에 저장하지 않습니다. '
                    '계정을 연결하면 다른 기기에서도 이어서 관리할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      height: 1.45,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openEmail(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EmailAuthPage(service: service)));
  }
}
