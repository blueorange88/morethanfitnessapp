import 'package:flutter/material.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../services/app_account_service.dart';
import '../services/managed_member_workspace_service.dart';
import '../services/personal_my_page_nudge_service.dart';
import '../services/personal_schedule_widget_sync_service.dart';
import 'password_change_page.dart';

List<PersonalProfileNudgeKey> personalMissingProfileFields(
  ManagedMemberUsage usage,
) {
  return [
    if (usage.nickname.trim().isEmpty) PersonalProfileNudgeKey.displayName,
    if (usage.phone.trim().isEmpty) PersonalProfileNudgeKey.phone,
    if (usage.activityRegion.trim().isEmpty)
      PersonalProfileNudgeKey.activityRegion,
    if (usage.primaryActivity.trim().isEmpty)
      PersonalProfileNudgeKey.primaryActivity,
    if (usage.affiliationType.trim().isEmpty)
      PersonalProfileNudgeKey.affiliationType,
  ];
}

class PersonalMyPage extends StatefulWidget {
  const PersonalMyPage({
    super.key,
    required this.uid,
    required this.accountService,
    required this.memberGateway,
    this.onBeforeSignOut,
    this.nudgeStore = const SharedPreferencesPersonalMyPageNudgeStore(),
    this.autoNudgeEnabled = true,
  });

  final String uid;
  final AppAccountService accountService;
  final ManagedMemberWorkspaceGateway memberGateway;
  final Future<void> Function(String uid)? onBeforeSignOut;
  final PersonalMyPageNudgeStore nudgeStore;
  final bool autoNudgeEnabled;

  @override
  State<PersonalMyPage> createState() => _PersonalMyPageState();
}

class _PersonalMyPageState extends State<PersonalMyPage> {
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _activityRegionController = TextEditingController();
  final _primaryActivityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _profileCardKey = GlobalKey();
  final _displayNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _activityRegionFocus = FocusNode();
  final _primaryActivityFocus = FocusNode();

  String? _affiliationType;
  String? _loadedProfileSignature;
  String? _profileError;
  String? _linkError;
  bool _profileDirty = false;
  bool _savingProfile = false;
  bool _linking = false;
  bool _signingOut = false;
  AppAccountUser? _currentUser;
  bool _autoNudgeHandled = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.accountService.currentUser;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _activityRegionController.dispose();
    _primaryActivityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _displayNameFocus.dispose();
    _phoneFocus.dispose();
    _activityRegionFocus.dispose();
    _primaryActivityFocus.dispose();
    super.dispose();
  }

  List<PersonalProfileNudgeKey> _missingProfileFields(
          ManagedMemberUsage usage) =>
      personalMissingProfileFields(usage);

  void _scheduleEntryNudge(ManagedMemberUsage usage, bool anonymous) {
    if (!widget.autoNudgeEnabled || _autoNudgeHandled) return;
    _autoNudgeHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final missing = _missingProfileFields(usage);
      if (missing.isNotEmpty) {
        final lastKey = await widget.nudgeStore.readLastKey(widget.uid);
        final key = selectNextPersonalProfileNudge(
          missing: missing,
          lastKey: lastKey,
        );
        if (key == null || !mounted) return;
        await widget.nudgeStore.writeLastKey(widget.uid, key.name);
        if (!mounted) return;
        await _showProfileNudge(key, usage.nickname);
        return;
      }
      if (anonymous) await _showAccountNudge();
    });
  }

  Future<void> _showProfileNudge(
    PersonalProfileNudgeKey key,
    String nickname,
  ) async {
    final action = await _AifcActionSheet.show<_ProfileNudgeAction>(
      context: context,
      title: '선생님을 조금 더 알아가고 싶어요.',
      message: personalProfileNudgeMessage(key, nickname: nickname),
      actions: const [
        _AifcSheetAction(
          value: _ProfileNudgeAction.single,
          label: '해당 항목 입력하기',
        ),
        _AifcSheetAction(
          value: _ProfileNudgeAction.all,
          label: '한 번에 완성하기',
        ),
        _AifcSheetAction(
          value: _ProfileNudgeAction.later,
          label: '다음에 할게요',
        ),
      ],
    );
    if (!mounted || action == null || action == _ProfileNudgeAction.later) {
      return;
    }
    await _focusProfileEditor(
      action == _ProfileNudgeAction.single ? key : null,
    );
  }

  Future<void> _focusProfileEditor(PersonalProfileNudgeKey? key) async {
    final cardContext = _profileCardKey.currentContext;
    if (cardContext != null) {
      await Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 280),
        alignment: 0.05,
      );
    }
    if (!mounted || key == null) return;
    final focus = switch (key) {
      PersonalProfileNudgeKey.displayName => _displayNameFocus,
      PersonalProfileNudgeKey.phone => _phoneFocus,
      PersonalProfileNudgeKey.activityRegion => _activityRegionFocus,
      PersonalProfileNudgeKey.primaryActivity => _primaryActivityFocus,
      PersonalProfileNudgeKey.affiliationType => null,
    };
    focus?.requestFocus();
  }

  Future<void> _showAccountNudge() async {
    final action = await _AifcActionSheet.show<_AccountNudgeAction>(
      context: context,
      title: '계정과 기록을 안전하게 이어가요.',
      message: '회원과 레슨 기록을 안전하게 이어가도록\n계정을 연결해둘까요?\n\n'
          '휴대폰을 바꾸거나 앱을 다시 설치해도\n지금 기록을 이어갈 수 있어요.',
      actions: const [
        _AifcSheetAction(
          value: _AccountNudgeAction.connect,
          label: '계정 연결하기',
        ),
        _AifcSheetAction(
          value: _AccountNudgeAction.later,
          label: '다음에 할게요',
        ),
      ],
    );
    if (mounted && action == _AccountNudgeAction.connect) {
      await _openAccountSheet();
    }
  }

  Future<void> _openAccountSheet() async {
    final user = _currentUser ?? widget.accountService.currentUser;
    if (user?.isAnonymous ?? true) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AccountConnectionSheet(
          emailController: _emailController,
          passwordController: _passwordController,
          passwordConfirmationController: _passwordConfirmationController,
          onLinkEmail: _linkEmail,
        ),
      );
      if (mounted) setState(() {});
      return;
    }
    await _AifcActionSheet.show<_LinkedAccountAction>(
      context: context,
      title: '계정 및 기록',
      message: '이메일 계정으로 연결되어 있어요.\n현재 기록은 같은 UID로 안전하게 이어집니다.',
      actions: const [
        _AifcSheetAction(
          value: _LinkedAccountAction.password,
          label: '비밀번호 변경',
        ),
        _AifcSheetAction(
          value: _LinkedAccountAction.close,
          label: '닫기',
        ),
      ],
    ).then((action) {
      if (!mounted || action != _LinkedAccountAction.password) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PasswordChangePage(
            accountService: widget.accountService,
          ),
        ),
      );
    });
  }

  void _loadProfileIfSafe(ManagedMemberUsage usage) {
    final signature = [
      usage.nickname,
      usage.displayName,
      usage.phone,
      usage.activityRegion,
      usage.primaryActivity,
      usage.affiliationType,
    ].join('\u001f');
    if (_profileDirty || signature == _loadedProfileSignature) return;
    _loadedProfileSignature = signature;
    _displayNameController.text = usage.nickname;
    _phoneController.text = usage.phone;
    _activityRegionController.text = usage.activityRegion;
    _primaryActivityController.text = usage.primaryActivity;
    _affiliationType =
        usage.affiliationType.isEmpty ? null : usage.affiliationType;
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    final missing = <String>[
      if (_displayNameController.text.trim().isEmpty) '이름/활동명',
      if (_phoneController.text.trim().isEmpty) '연락처',
      if (_activityRegionController.text.trim().isEmpty) '활동 지역',
      if (_primaryActivityController.text.trim().isEmpty) '주 활동 종목',
      if ((_affiliationType ?? '').isEmpty) '소속 형태',
    ];
    if (missing.isNotEmpty) {
      setState(() => _profileError = '${missing.join(', ')}을(를) 입력해주세요.');
      return;
    }
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });
    try {
      await widget.memberGateway.updateTrainerProfile(
        displayName: _displayNameController.text.trim(),
        phone: _phoneController.text.trim(),
        activityRegion: _activityRegionController.text.trim(),
        primaryActivity: _primaryActivityController.text.trim(),
        affiliationType: _affiliationType!,
      );
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileDirty = false;
        _loadedProfileSignature = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선생님 내 정보를 저장했어요.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileError = '선생님 내 정보를 저장하지 못했어요. 입력값은 그대로 두었어요.';
      });
    }
  }

  Future<String?> _linkEmail() async {
    if (_linking) return _linkError;
    if (_passwordController.text != _passwordConfirmationController.text) {
      setState(() => _linkError = '비밀번호 확인이 일치하지 않아요.');
      return _linkError;
    }
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      final beforeUid = widget.accountService.currentUser?.uid;
      final linked = await widget.accountService.linkAnonymousWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (beforeUid == null || linked.uid != beforeUid) {
        throw const AppAccountException(
          AppAccountErrorCode.uidChangedUnexpectedly,
        );
      }
      var verificationSent = false;
      if (!linked.emailVerified) {
        try {
          await widget.accountService.sendCurrentUserEmailVerification();
          verificationSent = true;
        } catch (_) {
          verificationSent = false;
        }
      }
      if (!mounted) return null;
      _passwordController.clear();
      _passwordConfirmationController.clear();
      setState(() {
        _linking = false;
        _currentUser = linked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              verificationSent ? '계정을 연결했어요. 이메일 인증 메일도 보냈어요.' : '계정을 연결했어요.'),
        ),
      );
      return null;
    } catch (error) {
      if (!mounted) return appAccountErrorMessage(error);
      setState(() {
        _linking = false;
        _linkError = appAccountErrorMessage(error);
      });
      return _linkError;
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      final clear = widget.onBeforeSignOut;
      if (clear != null) {
        await clear(widget.uid);
      } else {
        await PersonalScheduleWidgetSyncService(uid: widget.uid)
            .clearForSignOut();
      }
      await widget.accountService.signOut();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _signingOut = false;
        _linkError = appAccountErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: StreamBuilder<ManagedMemberUsage>(
        stream: widget.memberGateway.watchUsage(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('계정 정보를 불러오지 못했어요.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final usage = snapshot.data!;
          _loadProfileIfSafe(usage);
          final user = _currentUser ?? widget.accountService.currentUser;
          final anonymous = user?.isAnonymous ?? !usage.accountLinked;
          _scheduleEntryNudge(usage, anonymous);
          return ListView(
            key: const Key('personal_my_page'),
            padding: const EdgeInsets.all(20),
            children: [
              _AccountTierCard(usage: usage, user: user),
              const SizedBox(height: 16),
              _buildProfileCard(),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  key: const Key('open_account_and_records'),
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('계정 및 기록'),
                  subtitle: Text(
                    anonymous ? '익명으로 사용 중' : '이메일 계정으로 연결됨',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openAccountSheet,
                ),
              ),
              if (!anonymous) ...[
                const SizedBox(height: 16),
                _buildLinkedAccountCard(user),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard() => Card(
        key: _profileCardKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('선생님 내 정보',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('승급에 필요한 5개 항목이에요. 상세 주소는 필수가 아니에요.'),
              const SizedBox(height: 14),
              _profileField(_displayNameController, _displayNameFocus, '이름/활동명',
                  const Key('profile_display_name')),
              _profileField(_phoneController, _phoneFocus, '연락처',
                  const Key('profile_phone'),
                  keyboardType: TextInputType.phone),
              _profileField(_activityRegionController, _activityRegionFocus,
                  '활동 지역 (시/구/동)', const Key('profile_activity_region')),
              _profileField(_primaryActivityController, _primaryActivityFocus,
                  '주 활동 종목', const Key('profile_primary_activity')),
              DropdownButtonFormField<String>(
                key: const Key('profile_affiliation_type'),
                initialValue: _affiliationType,
                decoration: const InputDecoration(labelText: '소속 형태'),
                items: const [
                  DropdownMenuItem(value: 'freelancer', child: Text('프리랜서')),
                  DropdownMenuItem(value: 'center', child: Text('센터 소속')),
                  DropdownMenuItem(value: 'personal_shop', child: Text('개인샵')),
                ],
                onChanged: _savingProfile
                    ? null
                    : (value) => setState(() {
                          _affiliationType = value;
                          _profileDirty = true;
                        }),
              ),
              if (_profileError != null) ...[
                const SizedBox(height: 10),
                Text(_profileError!,
                    key: const Key('profile_save_error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('save_personal_profile'),
                onPressed: _savingProfile ? null : _saveProfile,
                child: Text(_savingProfile ? '저장 중' : '내 정보 저장'),
              ),
            ],
          ),
        ),
      );

  Widget _profileField(
    TextEditingController controller,
    FocusNode focusNode,
    String label,
    Key key, {
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          enabled: !_savingProfile,
          onChanged: (_) => _profileDirty = true,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _buildLinkedAccountCard(AppAccountUser? user) => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.mark_email_read_outlined),
              title: const Text('이메일 계정 연결됨'),
              subtitle: Text(
                '${user?.email ?? ''}\n이메일 인증: ${user?.emailVerified == true ? '완료' : '미완료'}',
              ),
            ),
            ListTile(
              key: const Key('open_password_change'),
              leading: const Icon(Icons.password_rounded),
              title: const Text('비밀번호 변경'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PasswordChangePage(
                    accountService: widget.accountService,
                  ),
                ),
              ),
            ),
            ListTile(
              key: const Key('personal_account_sign_out'),
              leading: const Icon(Icons.logout_rounded),
              title: Text(_signingOut ? '로그아웃 중' : '로그아웃'),
              enabled: !_signingOut,
              onTap: _signingOut ? null : _signOut,
            ),
            if (_linkError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_linkError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      );
}

class _AccountTierCard extends StatelessWidget {
  const _AccountTierCard({required this.usage, required this.user});

  final ManagedMemberUsage usage;
  final AppAccountUser? user;

  @override
  Widget build(BuildContext context) {
    final linked = user?.isAnonymous == false && usage.accountLinked;
    final profileCount = usage.completedProfileFieldCount;
    return Card(
      key: const Key('personal_account_tier_card'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(usage.tier.toUpperCase(),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(linked ? '이메일 계정 연결됨' : '계정 연결 전'),
            const SizedBox(height: 12),
            const Text('기록이 차곡차곡 쌓이고 있어요.'),
            const SizedBox(height: 14),
            _row('누적 유효 회원', '${usage.lifetimeQualifiedCount}명'),
            _row('내 정보', '$profileCount / 5 완료'),
            _row('계정 연결', linked ? '완료' : '미완료'),
            const Divider(height: 24),
            Text(_progressText(usage, linked, profileCount),
                key: const Key('personal_tier_progress')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label)), Text(value)]),
      );

  static String _progressText(
    ManagedMemberUsage usage,
    bool linked,
    int profileCount,
  ) {
    final tier = usage.tier.trim().toLowerCase();
    if (tier == 'pro') return '회원 50명 관리 경험이 쌓여 Pro로 성장했어요.';
    final target = tier == 'semi-pro' || tier == 'semipro'
        ? 50
        : tier == 'amateur'
            ? 30
            : 10;
    final remaining = (target - usage.lifetimeQualifiedCount).clamp(0, target);
    final conditions = <String>[
      if (remaining > 0) '회원 $remaining명을 더 등록',
      if (!linked) '계정 연결',
      if (profileCount < 5) '내 정보 ${5 - profileCount}개 입력',
    ];
    if (conditions.isEmpty) return '서버에서 다음 등급을 확인하고 있어요.';
    return '${conditions.join(' · ')}하면 다음 단계 준비가 끝나요.';
  }
}

enum _ProfileNudgeAction { single, all, later }

enum _AccountNudgeAction { connect, later }

enum _LinkedAccountAction { password, close }

class _AifcSheetAction<T> {
  const _AifcSheetAction({required this.value, required this.label});

  final T value;
  final String label;
}

class _AifcActionSheet<T> extends StatelessWidget {
  const _AifcActionSheet({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<_AifcSheetAction<T>> actions;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    required List<_AifcSheetAction<T>> actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AifcActionSheet<T>(
        title: title,
        message: message,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.8,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: AifcChatBubble(
              side: AifcBubbleSide.fc,
              text: '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    key: const Key('aifc_nudge_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 16),
                  for (final action in actions) ...[
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(action.value),
                      child: Text(action.label),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountConnectionSheet extends StatefulWidget {
  const _AccountConnectionSheet({
    required this.emailController,
    required this.passwordController,
    required this.passwordConfirmationController,
    required this.onLinkEmail,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmationController;
  final Future<String?> Function() onLinkEmail;

  @override
  State<_AccountConnectionSheet> createState() =>
      _AccountConnectionSheetState();
}

class _AccountConnectionSheetState extends State<_AccountConnectionSheet> {
  bool _emailExpanded = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onLinkEmail();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.9,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: AifcChatBubble(
              side: AifcBubbleSide.fc,
              text: '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '계정 연결하기',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '회원과 레슨 기록을 안전하게 이어가도록 계정을 연결해둘까요?',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const Key('link_google_preparing'),
                    onPressed: null,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Google로 연결 · 준비 중'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('link_kakao_preparing'),
                    onPressed: null,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('카카오로 연결 · 준비 중'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('expand_email_link'),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _emailExpanded = true),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('이메일로 연결'),
                  ),
                  if (_emailExpanded) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('link_email'),
                      controller: widget.emailController,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: '이메일'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('link_password'),
                      controller: widget.passwordController,
                      enabled: !_busy,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: '비밀번호'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('link_password_confirmation'),
                      controller: widget.passwordConfirmationController,
                      enabled: !_busy,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: '비밀번호 확인'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _obscure = !_obscure),
                        child: Text(_obscure ? '비밀번호 보기' : '비밀번호 숨기기'),
                      ),
                    ),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        key: const Key('account_link_error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_error!.contains('이미 사용 중'))
                        const Text(
                          '기록은 자동으로 합치지 않습니다. 기존 계정으로 바꾸려면 '
                          '별도의 안전한 계정 전환 절차가 필요해요.',
                        ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('link_email_account'),
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? '연결 중' : '이메일 계정 연결'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    '현재 기록은 그대로 유지돼요.\n지금 연결하지 않아도 계속 사용할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
