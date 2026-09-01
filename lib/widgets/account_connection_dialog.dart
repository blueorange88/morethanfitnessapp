import 'package:flutter/material.dart';

import '../services/app_account_service.dart';
import 'aifc_interaction.dart';

abstract final class AccountConnectionDialog {
  static Future<AppAccountUser?> show({
    required BuildContext context,
    required AppAccountService accountService,
    required String expectedUid,
    bool completeExistingLinkOnly = false,
  }) async {
    var current = accountService.currentUser;
    if (current != null && !current.isAnonymous) {
      current = await accountService.completeCurrentEmailLink();
      if (current.uid != expectedUid) {
        throw const AppAccountException(
          AppAccountErrorCode.uidChangedUnexpectedly,
        );
      }
      if (completeExistingLinkOnly) return current;
    }
    if (!context.mounted) return null;

    final googleLinkedBefore = current?.hasProvider('google.com') == true;
    final result = await showDialog<AppAccountUser>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder:
          (_) => _AccountConnectionDialogCard(
            accountService: accountService,
            expectedUid: expectedUid,
            initialUser: current,
          ),
    );
    if (result != null &&
        !googleLinkedBefore &&
        result.hasProvider('google.com') &&
        context.mounted) {
      AifcInteraction.toast(
        context: context,
        message: 'Google 계정이 연결됐어요. 기존 데이터는 그대로 유지됩니다.',
        duration: const Duration(seconds: 4),
      );
    }
    return result;
  }
}

class _AccountConnectionDialogCard extends StatefulWidget {
  const _AccountConnectionDialogCard({
    required this.accountService,
    required this.expectedUid,
    required this.initialUser,
  });

  final AppAccountService accountService;
  final String expectedUid;
  final AppAccountUser? initialUser;

  @override
  State<_AccountConnectionDialogCard> createState() =>
      _AccountConnectionDialogCardState();
}

class _AccountConnectionDialogCardState
    extends State<_AccountConnectionDialogCard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _verificationEmailSent = false;
  String? _error;
  AppAccountUser? _linkedUser;
  late AppAccountUser? _currentUser;

  bool get _emailAlreadyLinked =>
      _currentUser != null && _currentUser?.isAnonymous == false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.initialUser;
  }

  @override
  void dispose() {
    AifcInteraction.hideToast();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_passwordController.text != _passwordConfirmationController.text) {
      _showError('비밀번호 확인이 일치하지 않아요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final beforeUid = widget.accountService.currentUser?.uid;
      final linked = await widget.accountService.linkAnonymousWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (beforeUid == null ||
          linked.uid != beforeUid ||
          linked.uid != widget.expectedUid) {
        throw const AppAccountException(
          AppAccountErrorCode.uidChangedUnexpectedly,
        );
      }
      if (!mounted) return;
      _passwordController.clear();
      _passwordConfirmationController.clear();
      setState(() {
        _busy = false;
        _linkedUser = linked;
        _currentUser = linked;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(appAccountErrorMessage(error));
    }
  }

  Future<void> _linkGoogle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final beforeUid = widget.accountService.currentUser?.uid;
      final linked = await widget.accountService.linkCurrentUserWithGoogle();
      if (!mounted) return;
      if (linked == null) {
        setState(() => _busy = false);
        return;
      }
      if (beforeUid == null ||
          linked.uid != beforeUid ||
          linked.uid != widget.expectedUid) {
        throw const AppAccountException(
          AppAccountErrorCode.uidChangedUnexpectedly,
        );
      }
      Navigator.of(context).pop(linked);
    } catch (error) {
      if (!mounted) return;
      if (error is AppAccountException &&
          error.code == AppAccountErrorCode.googleCanceled) {
        setState(() => _busy = false);
        return;
      }
      _showError(appAccountErrorMessage(error));
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_busy || _linkedUser == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accountService.sendCurrentUserEmailVerification();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _verificationEmailSent = true;
      });
      AifcInteraction.toast(
        context: context,
        message: '인증메일을 보냈어요. 메일의 링크를 눌러 인증을 완료해주세요.',
        duration: const Duration(seconds: 4),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(appAccountErrorMessage(error));
    }
  }

  void _finishLinked() {
    final linked = _linkedUser;
    if (linked == null) return;
    Navigator.of(context).pop(linked);
  }

  void _showError(String message) {
    setState(() {
      _busy = false;
      _error = message;
    });
    AifcInteraction.toast(
      context: context,
      message: message,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final compact = media.size.width <= 360;
    final horizontalInset = compact ? 14.0 : 24.0;

    return PopScope(
      canPop: _linkedUser == null && !_busy,
      child: Dialog(
        key: const Key('account_connection_dialog'),
        insetPadding: EdgeInsets.symmetric(
          horizontal: horizontalInset,
          vertical: 24,
        ),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 24,
              24,
              compact ? 18 : 24,
              18,
            ),
            child:
                _linkedUser == null
                    ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '계정 연결하기',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '기존 회원과 일정은 그대로 유지돼요.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_emailAlreadyLinked)
                          Container(
                            key: const Key('email_provider_connected'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mark_email_read_outlined,
                                  color: scheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '이메일 계정이 연결되어 있어요.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          TextField(
                            key: const Key('link_email'),
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(labelText: '이메일'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const Key('link_password'),
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: const InputDecoration(
                              labelText: '비밀번호',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            key: const Key('link_password_confirmation'),
                            controller: _passwordConfirmationController,
                            enabled: !_busy,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: '비밀번호 확인',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _busy
                                      ? null
                                      : () =>
                                          setState(() => _obscure = !_obscure),
                              child: Text(_obscure ? '비밀번호 보기' : '비밀번호 숨기기'),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          Text(
                            _error!,
                            key: const Key('account_link_error'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_error!.contains('이미 사용 중'))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '기록은 자동으로 합치지 않습니다. 기존 계정으로 바꾸려면 '
                                '별도의 안전한 계정 전환 절차가 필요해요.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],
                        if (!_emailAlreadyLinked)
                          FilledButton(
                            key: const Key('link_email_account'),
                            onPressed: _busy ? null : _submit,
                            child: Text(_busy ? '연결 중' : '이메일로 연결'),
                          ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: scheme.outlineVariant),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                '또는 다른 계정으로',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: scheme.outlineVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: _SocialProviderOption(
                                key: Key('link_kakao_preparing'),
                                monogram: 'K',
                                label: '카카오',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GoogleProviderOption(
                                key: Key(
                                  _currentUser?.hasProvider('google.com') ==
                                          true
                                      ? 'link_google_connected'
                                      : 'link_google_account',
                                ),
                                connected:
                                    _currentUser?.hasProvider('google.com') ==
                                    true,
                                onPressed:
                                    _busy ||
                                            _currentUser?.hasProvider(
                                                  'google.com',
                                                ) ==
                                                true
                                        ? null
                                        : _linkGoogle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: _SocialProviderOption(
                                key: Key('link_naver_preparing'),
                                monogram: 'N',
                                label: '네이버',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '카카오·네이버 계정 연결은 준비 중이에요.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          key: const Key('cancel_account_connection'),
                          onPressed:
                              _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                      ],
                    )
                    : _buildLinkSuccess(theme, scheme),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkSuccess(ThemeData theme, ColorScheme scheme) {
    return Column(
      key: const Key('account_link_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.verified_user_outlined, size: 46, color: scheme.primary),
        const SizedBox(height: 14),
        Text(
          '계정이 연결됐어요 🙌',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '기존 회원과 일정은 그대로 유지됩니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (_verificationEmailSent)
          Container(
            key: const Key('verification_email_sent_message'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '인증메일을 보냈어요. 메일의 링크를 눌러 인증을 완료해주세요.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (_error != null) ...[
          Text(
            _error!,
            key: const Key('verification_email_error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        FilledButton(
          key: Key(
            _verificationEmailSent
                ? 'continue_after_verification_email'
                : 'send_verification_email_after_link',
          ),
          onPressed:
              _busy
                  ? null
                  : _verificationEmailSent
                  ? _finishLinked
                  : _sendVerificationEmail,
          child: Text(
            _busy
                ? '전송 중'
                : _verificationEmailSent
                ? '회원 저장 계속하기'
                : '인증메일 보내기',
          ),
        ),
        TextButton(
          key: const Key('continue_link_without_verification'),
          onPressed: _busy ? null : _finishLinked,
          child: const Text('나중에'),
        ),
      ],
    );
  }
}

class _SocialProviderOption extends StatelessWidget {
  const _SocialProviderOption({
    super.key,
    required this.monogram,
    required this.label,
  });

  final String monogram;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: false,
      label: '$label 계정 연결 준비 중',
      child: Opacity(
        opacity: 0.62,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                monogram,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleProviderOption extends StatelessWidget {
  const _GoogleProviderOption({
    super.key,
    required this.connected,
    required this.onPressed,
  });

  final bool connected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: connected ? 'Google 계정 연결됨' : 'Google 계정 연결',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color:
                connected
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/branding/google_sign_in_square_light.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(height: 3),
              Text(
                connected ? '연결됨' : 'Google 연결',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: connected ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
