import 'package:flutter/material.dart';

import '../services/account_password_service.dart';
import '../services/app_account_service.dart';
import 'onboarding_page.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({
    super.key,
    this.forced = false,
    this.passwordService,
    this.accountService,
    this.onCompleted,
  });

  final bool forced;
  final AccountPasswordService? passwordService;
  final AppAccountService? accountService;
  final VoidCallback? onCompleted;

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  late final AccountPasswordService _passwordService;
  late final AppAccountService _accountService;
  bool _busy = false;
  bool _obscure = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _passwordService = widget.passwordService ?? AccountPasswordService();
    _accountService = widget.accountService ?? AppAccountService.instance;
  }

  @override
  void dispose() {
    _clearSensitiveInputs();
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _clearSensitiveInputs() {
    _currentController.clear();
    _newController.clear();
    _confirmationController.clear();
  }

  Future<void> _changePassword() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    var completed = false;
    try {
      await _passwordService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
        confirmation: _confirmationController.text,
      );
      completed = true;
    } catch (error) {
      if (mounted) {
        setState(() => _message = accountPasswordErrorMessage(error));
      }
    } finally {
      _clearSensitiveInputs();
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || !completed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비밀번호를 안전하게 변경했어요.')),
    );
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _sendReset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _passwordService.sendPasswordReset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입력하신 계정을 확인할 수 있다면 재설정 메일을 보내드려요.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = accountPasswordErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _accountService.signOut();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = appAccountErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced && !_busy,
      child: Scaffold(
        key: const Key('password_change_page'),
        backgroundColor: kOnboardingBg,
        appBar: AppBar(
          backgroundColor: kOnboardingBg,
          foregroundColor: kOnboardingText,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !widget.forced,
          title: Text(
            widget.forced ? '첫 로그인 비밀번호 변경' : '비밀번호 변경',
            style: const TextStyle(
              color: kOnboardingText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kOnboardingBorder),
                  boxShadow: [
                    BoxShadow(
                      color: kOnboardingPrimary.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        color: kOnboardingPrimary,
                        size: 34,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.forced ? '새 비밀번호를 설정해주세요' : '계정 비밀번호를 변경할게요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kOnboardingText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.forced
                            ? '계속하기 전에 임시 비밀번호를 변경해주세요.'
                            : '현재 비밀번호를 확인한 뒤 새 비밀번호로 변경합니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kOnboardingMuted,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PasswordField(
                        key: const Key('current_password_field'),
                        controller: _currentController,
                        label: '현재 비밀번호',
                        obscure: _obscure,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        key: const Key('new_password_field'),
                        controller: _newController,
                        label: '새 비밀번호',
                        obscure: _obscure,
                        enabled: !_busy,
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        key: const Key('confirm_password_field'),
                        controller: _confirmationController,
                        label: '새 비밀번호 확인',
                        obscure: _obscure,
                        enabled: !_busy,
                        onSubmitted: (_) => _changePassword(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          label: Text(_obscure ? '비밀번호 보기' : '비밀번호 숨기기'),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _message!,
                          key: const Key('password_change_message'),
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('change_password_button'),
                        onPressed: _busy ? null : _changePassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: kOnboardingPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(_busy ? '확인 중...' : '비밀번호 변경'),
                      ),
                      TextButton(
                        key: const Key('password_change_reset_button'),
                        onPressed: _busy ? null : _sendReset,
                        child: const Text('비밀번호 재설정 메일 받기'),
                      ),
                      if (widget.forced)
                        TextButton(
                          key: const Key('password_change_sign_out_button'),
                          onPressed: _busy ? null : _signOut,
                          child: const Text('로그아웃'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscure,
    required this.enabled,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: kOnboardingMuted,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: kOnboardingPrimary,
          ),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: kOnboardingBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: kOnboardingBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: kOnboardingPrimary,
              width: 1.5,
            ),
          ),
        ),
      );
}
