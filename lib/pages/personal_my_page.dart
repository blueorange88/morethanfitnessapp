import 'package:flutter/material.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../services/app_account_service.dart';
import '../services/managed_member_workspace_service.dart';
import '../services/personal_my_page_nudge_service.dart';
import '../services/personal_schedule_widget_sync_service.dart';
import '../widgets/account_connection_dialog.dart';
import '../widgets/aifc_interaction.dart';
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
    this.openAccountLinkOnStart = false,
  });

  final String uid;
  final AppAccountService accountService;
  final ManagedMemberWorkspaceGateway memberGateway;
  final Future<void> Function(String uid)? onBeforeSignOut;
  final PersonalMyPageNudgeStore nudgeStore;
  final bool autoNudgeEnabled;
  final bool openAccountLinkOnStart;

  @override
  State<PersonalMyPage> createState() => _PersonalMyPageState();
}

class _PersonalMyPageState extends State<PersonalMyPage> {
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _activityRegionController = TextEditingController();
  final _primaryActivityController = TextEditingController();
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
  bool _signingOut = false;
  bool _verificationBusy = false;
  AppAccountUser? _currentUser;
  bool _autoNudgeHandled = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.accountService.currentUser;
    if (widget.openAccountLinkOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final linked = await _openAccountSheet(completeExistingLinkOnly: true);
        if (!mounted || !linked) return;
        Navigator.of(context).pop(true);
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _activityRegionController.dispose();
    _primaryActivityController.dispose();
    _displayNameFocus.dispose();
    _phoneFocus.dispose();
    _activityRegionFocus.dispose();
    _primaryActivityFocus.dispose();
    super.dispose();
  }

  List<PersonalProfileNudgeKey> _missingProfileFields(
    ManagedMemberUsage usage,
  ) => personalMissingProfileFields(usage);

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
        _AifcSheetAction(value: _ProfileNudgeAction.all, label: '한 번에 완성하기'),
        _AifcSheetAction(value: _ProfileNudgeAction.later, label: '다음에 할게요'),
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
      message:
          '회원과 레슨 기록을 안전하게 이어가도록\n계정을 연결해둘까요?\n\n'
          '휴대폰을 바꾸거나 앱을 다시 설치해도\n지금 기록을 이어갈 수 있어요.',
      actions: const [
        _AifcSheetAction(value: _AccountNudgeAction.connect, label: '계정 연결하기'),
        _AifcSheetAction(value: _AccountNudgeAction.later, label: '다음에 할게요'),
      ],
    );
    if (mounted && action == _AccountNudgeAction.connect) {
      await _openAccountSheet();
    }
  }

  Future<bool> _openAccountSheet({
    bool completeExistingLinkOnly = false,
  }) async {
    try {
      final linked = await AccountConnectionDialog.show(
        context: context,
        accountService: widget.accountService,
        expectedUid: widget.uid,
        completeExistingLinkOnly: completeExistingLinkOnly,
      );
      if (!mounted || linked == null) return false;
      setState(() {
        _currentUser = linked;
        _linkError = null;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = appAccountErrorMessage(error);
      setState(() => _linkError = message);
      AifcInteraction.toast(
        context: context,
        message: message,
        duration: const Duration(seconds: 3),
      );
      return false;
    }
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
      AifcInteraction.feedbackSnack(
        context: context,
        message: '선생님 내 정보를 저장했어요.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileError = '선생님 내 정보를 저장하지 못했어요. 입력값은 그대로 두었어요.';
      });
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
        await PersonalScheduleWidgetSyncService(
          uid: widget.uid,
        ).clearForSignOut();
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

  Future<void> _sendVerificationEmail() async {
    if (_verificationBusy) return;
    setState(() {
      _verificationBusy = true;
      _linkError = null;
    });
    try {
      await widget.accountService.sendCurrentUserEmailVerification();
      if (!mounted) return;
      AifcInteraction.toast(
        context: context,
        message: '인증메일을 보냈어요. 메일의 링크를 눌러 인증을 완료해주세요.',
        duration: const Duration(seconds: 4),
      );
    } catch (error) {
      if (!mounted) return;
      final message = appAccountErrorMessage(error);
      setState(() => _linkError = message);
      AifcInteraction.toast(
        context: context,
        message: message,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _verificationBusy = false);
    }
  }

  Future<void> _refreshVerificationStatus() async {
    if (_verificationBusy) return;
    setState(() {
      _verificationBusy = true;
      _linkError = null;
    });
    try {
      final refreshed = await widget.accountService.refreshCurrentUser();
      if (refreshed.uid != widget.uid) {
        throw const AppAccountException(
          AppAccountErrorCode.uidChangedUnexpectedly,
        );
      }
      if (!mounted) return;
      setState(() => _currentUser = refreshed);
      AifcInteraction.toast(
        context: context,
        message:
            refreshed.emailVerified
                ? '이메일 인증이 확인됐어요.'
                : '아직 인증이 완료되지 않았어요. 메일의 링크를 확인해주세요.',
        duration: const Duration(seconds: 3),
      );
    } catch (error) {
      if (!mounted) return;
      final message = appAccountErrorMessage(error);
      setState(() => _linkError = message);
      AifcInteraction.toast(
        context: context,
        message: message,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _verificationBusy = false);
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
                  subtitle: Text(anonymous ? '익명으로 사용 중' : '이메일 계정으로 연결됨'),
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
          const Text(
            '선생님 내 정보',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('승급에 필요한 5개 항목이에요. 상세 주소는 필수가 아니에요.'),
          const SizedBox(height: 14),
          _profileField(
            _displayNameController,
            _displayNameFocus,
            '이름/활동명',
            const Key('profile_display_name'),
          ),
          _profileField(
            _phoneController,
            _phoneFocus,
            '연락처',
            const Key('profile_phone'),
            keyboardType: TextInputType.phone,
          ),
          _profileField(
            _activityRegionController,
            _activityRegionFocus,
            '활동 지역 (시/구/동)',
            const Key('profile_activity_region'),
          ),
          _profileField(
            _primaryActivityController,
            _primaryActivityFocus,
            '주 활동 종목',
            const Key('profile_primary_activity'),
          ),
          DropdownButtonFormField<String>(
            key: const Key('profile_affiliation_type'),
            initialValue: _affiliationType,
            decoration: const InputDecoration(labelText: '소속 형태'),
            items: const [
              DropdownMenuItem(value: 'freelancer', child: Text('프리랜서')),
              DropdownMenuItem(value: 'center', child: Text('센터 소속')),
              DropdownMenuItem(value: 'personal_shop', child: Text('개인샵')),
            ],
            onChanged:
                _savingProfile
                    ? null
                    : (value) => setState(() {
                      _affiliationType = value;
                      _profileDirty = true;
                    }),
          ),
          if (_profileError != null) ...[
            const SizedBox(height: 10),
            Text(
              _profileError!,
              key: const Key('profile_save_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
  }) => Padding(
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
            '${_maskedEmail(user?.email ?? '')}\n'
            '${user?.emailVerified == true ? '인증 완료 ✓' : '인증 필요'}',
          ),
        ),
        if (user?.emailVerified != true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('send_email_verification'),
                    onPressed:
                        _verificationBusy ? null : _sendVerificationEmail,
                    child: const Text('인증메일 다시 보내기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('refresh_email_verification'),
                    onPressed:
                        _verificationBusy ? null : _refreshVerificationStatus,
                    child: Text(_verificationBusy ? '확인 중' : '인증 확인'),
                  ),
                ),
              ],
            ),
          ),
        ListTile(
          key: Key(
            user?.hasProvider('google.com') == true
                ? 'personal_google_connected'
                : 'personal_connect_google',
          ),
          leading: Image.asset(
            'assets/branding/google_sign_in_square_light.png',
            width: 40,
            height: 40,
          ),
          title: Text(
            user?.hasProvider('google.com') == true
                ? 'Google 계정 연결됨'
                : 'Google 계정 연결',
          ),
          subtitle: Text(
            user?.hasProvider('google.com') == true
                ? '이메일 로그인과 함께 사용할 수 있어요.'
                : '기존 UID와 기록을 유지한 채 연결해요.',
          ),
          trailing:
              user?.hasProvider('google.com') == true
                  ? const Icon(Icons.check_circle_outline_rounded)
                  : const Icon(Icons.chevron_right_rounded),
          onTap:
              user?.hasProvider('google.com') == true
                  ? null
                  : _openAccountSheet,
        ),
        const ListTile(
          leading: Icon(Icons.more_horiz_rounded),
          title: Text('카카오 · 네이버'),
          subtitle: Text('준비 중'),
          enabled: false,
        ),
        ListTile(
          key: const Key('open_password_change'),
          leading: const Icon(Icons.password_rounded),
          title: const Text('비밀번호 변경'),
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => PasswordChangePage(
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
            child: Text(
              _linkError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  );

  static String _maskedEmail(String email) {
    final clean = email.trim();
    final separator = clean.indexOf('@');
    if (separator <= 0 || separator == clean.length - 1) return clean;
    final local = clean.substring(0, separator);
    final domain = clean.substring(separator + 1);
    final visible = local.length <= 2 ? 1 : 2;
    final prefix = local.substring(0, visible.clamp(0, local.length));
    return '$prefix***@$domain';
  }
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
            Text(
              usage.tier.toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(linked ? '이메일 계정 연결됨' : '계정 연결 전'),
            const SizedBox(height: 12),
            const Text('기록이 차곡차곡 쌓이고 있어요.'),
            const SizedBox(height: 14),
            _row('누적 유효 회원', '${usage.lifetimeQualifiedCount}명'),
            _row('내 정보', '$profileCount / 5 완료'),
            _row('계정 연결', linked ? '완료' : '미완료'),
            const Divider(height: 24),
            Text(
              _progressText(usage, linked, profileCount),
              key: const Key('personal_tier_progress'),
            ),
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
    final target =
        tier == 'semi-pro' || tier == 'semipro'
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
      builder:
          (_) => _AifcActionSheet<T>(
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
