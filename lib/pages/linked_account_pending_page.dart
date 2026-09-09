import 'package:flutter/material.dart';

import '../services/app_account_service.dart';
import '../services/linked_account_access_service.dart';

class LinkedAccountPendingPage extends StatefulWidget {
  const LinkedAccountPendingPage({
    super.key,
    required this.service,
    required this.status,
    required this.onRetry,
  });

  final AppAccountService service;
  final LinkedAccountAccessStatus status;
  final VoidCallback onRetry;

  @override
  State<LinkedAccountPendingPage> createState() =>
      _LinkedAccountPendingPageState();
}

class _LinkedAccountPendingPageState extends State<LinkedAccountPendingPage> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.service.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appAccountErrorMessage(error))),
      );
      setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (widget.status) {
      LinkedAccountAccessStatus.migrationApprovalRequired =>
        '기존 운영 데이터 연결에는 별도 확인이 필요해요.',
      LinkedAccountAccessStatus.identityMismatch =>
        '계정 정보가 일치하지 않아 작업공간을 열 수 없어요.',
      LinkedAccountAccessStatus.permissionDenied => '프로필 접근 권한을 확인하지 못했어요.',
      LinkedAccountAccessStatus.anonymousNotAllowed =>
        'Guest 계정으로는 작업공간 프로필을 만들 수 없어요.',
      _ => '개인 작업공간을 준비하지 못했어요. 잠시 후 다시 시도해주세요.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('계정 연결')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '기존 회원·일정·계약 데이터는 이 계정에 자동으로 연결하지 않습니다.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: _signingOut ? null : widget.onRetry,
                    child: const Text('다시 확인'),
                  ),
                  TextButton(
                    onPressed: _signingOut ? null : _signOut,
                    child: Text(_signingOut ? '로그아웃 중…' : '로그아웃'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
