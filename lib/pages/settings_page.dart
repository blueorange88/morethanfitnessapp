import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtf_app/pages/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_repeat_lesson_grouping_mode.dart';
import '../models/app_theme_mode.dart';
import '../models/personal_tier_progress.dart';
import '../services/app_account_service.dart' hide AppTier;
import '../services/app_tier_access_service.dart';
import '../services/mtf_home_widget_service.dart';
import '../utils/personal_tier_parser.dart';
import 'lesson_type_management_page.dart';
import 'password_change_page.dart';
import '../widgets/aifc_tier_guide_chat_sheet.dart';
import '../widgets/home/schedule/home_repeat_lesson_grouping_sheet.dart';
import '../widgets/premium_banner_widget.dart';

import '../providers/theme_provider.dart';
import '../theme.dart';
import 'widget_settings_page.dart';
import '../widgets/aifc_interaction.dart';

const double kSettingsMaxContentWidth = 480;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.personalOwnerUid});

  final String? personalOwnerUid;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationSettingsChanged = false;
  bool _signingOut = false;
  HomeRepeatLessonGroupingMode _repeatLessonGroupingMode =
      HomeRepeatLessonGroupingMode.none;

  PremiumBannerData? _premiumBannerData;
  String _currentTierName = 'Beginner';
  String _nextTierName = 'Amateur';
  int _memberCountForTier = 0;
  int _lessonCountForTier = 0;
  bool _hasProductForTier = false;
  bool _trainerInfoDoneForTier = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRepeatLessonGroupingMode());
    unawaited(_loadPremiumBannerStatus());
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showActionToast(
    String message, {
    double bottomOffset = 76,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    AifcInteraction.toast(
      context: context,
      message: message,
      bottomOffset: bottomOffset,
      duration: duration,
    );
  }

  void _showPreparingToast(String label) {
    _showActionToast('$label 기능은 준비중입니다.');
  }

  void _openWidgetSettingsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WidgetSettingsPage()));
  }

  Future<void> _loadPremiumBannerStatus() async {
    try {
      final personalOwnerUid = (widget.personalOwnerUid ?? '').trim();
      if (personalOwnerUid.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .doc('trainer_profiles/$personalOwnerUid')
            .get(const GetOptions(source: Source.server));
        final profile = snapshot.data() ?? const <String, dynamic>{};
        final tier = parsePersonalTierLabel(profile['tier']) ?? 'Beginner';
        final progress = PersonalTierProgress.fromProfile(profile);
        final memberCount =
            ((profile['validMemberCount'] ??
                        profile['lifetimeQualifiedMemberCount'] ??
                        0)
                    as num)
                .toInt();
        if (!mounted) return;
        setState(() {
          _currentTierName = tier;
          _nextTierName = _resolveNextTierName(tier);
          _memberCountForTier = memberCount;
          _lessonCountForTier = progress.scheduleCount;
          _trainerInfoDoneForTier = progress.teacherInfoCompleted;
          _premiumBannerData = PremiumBannerData(
            currentTier: _resolveAppTier(tier),
            isSponsor: false,
            scheduleCount: progress.scheduleCount,
            memberCount: memberCount,
            trainerInfoDone: progress.teacherInfoCompleted,
            accountLinked: profile['accountLinked'] == true,
          );
        });
        return;
      }

      final tierAccess = await AppTierAccessService.loadTrainerAccess();
      if (!mounted) return;
      setState(() {
        _currentTierName = tierAccess.tierLabel;
        _nextTierName = _resolveNextTierName(tierAccess.tierLabel);
        _memberCountForTier = tierAccess.activeMemberCount;
        _hasProductForTier = false;
        _trainerInfoDoneForTier = tierAccess.profileCompleted;
        _premiumBannerData = PremiumBannerData(
          currentTier: _resolveAppTier(tierAccess.tierLabel),
          isSponsor: tierAccess.isSponsor,
          memberCount: tierAccess.activeMemberCount,
          trainerInfoDone: tierAccess.profileCompleted,
          accountLinked: tierAccess.kakaoLinked,
        );
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[MTF_SETTINGS_PREMIUM_BANNER] load failed: $error');
      }
      // 배너는 부가 정보라 실패해도 설정 화면 진입은 막지 않는다.
    }
  }

  String _resolveNextTierName(String tier) {
    switch (tier) {
      case 'Beginner':
        return 'Amateur';
      case 'Amateur':
        return 'Semi-Pro';
      case 'Semi-Pro':
        return 'Pro';
      case 'Pro':
        return 'Master';
      case 'Master':
        return 'Grand Prix';
      default:
        return 'Grand Prix';
    }
  }

  AppTier _resolveAppTier(String tier) {
    switch (tier) {
      case 'Beginner':
        return AppTier.beginner;
      case 'Amateur':
        return AppTier.amateur;
      case 'Semi-Pro':
        return AppTier.semiPro;
      case 'Pro':
        return AppTier.pro;
      case 'Master':
        return AppTier.master;
      case 'Grand Prix':
        return AppTier.grandPrix;
      default:
        return AppTier.beginner;
    }
  }

  Future<void> _openTierGuideSheet() async {
    final action = await AifcTierGuideChatSheet.show(
      context: context,
      trainerName: '',
      currentTierName: _currentTierName,
      nextTierName: _nextTierName,
      memberCount: _memberCountForTier,
      lessonCount: _lessonCountForTier,
      hasProduct: _hasProductForTier,
      trainerInfoDone: _trainerInfoDoneForTier,
    );

    if (!mounted || action == null || action == AifcTierGuideAction.later) {
      return;
    }

    switch (action) {
      case AifcTierGuideAction.sponsor:
        _showActionToast('후원 결제 화면은 준비중이에요. 곧 더 간편하게 연결할게요.');
        break;
      case AifcTierGuideAction.goFillInfo:
        _showActionToast('AI FC 안내 정보를 채워주세요.');
        break;
      case AifcTierGuideAction.goAddMember:
        _showActionToast('회원카드는 홈 또는 회원리스트에서 추가할 수 있어요.');
        break;
      case AifcTierGuideAction.goAddProduct:
        _showActionToast('레슨 상품 관리에서 상품을 추가해주세요.');
        break;
      case AifcTierGuideAction.later:
        break;
    }
  }

  Future<void> _loadRepeatLessonGroupingMode() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _repeatLessonGroupingMode = homeRepeatLessonGroupingModeFromString(
        prefs.getString(kHomeRepeatLessonGroupingModePrefsKey),
      );
    });
  }

  Future<void> _openRepeatLessonGroupingSheet() async {
    final picked = await HomeRepeatLessonGroupingSheet.show(
      context: context,
      currentMode: _repeatLessonGroupingMode,
      primaryColor: Theme.of(context).colorScheme.primary,
    );

    if (!mounted || picked == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kHomeRepeatLessonGroupingModePrefsKey,
      picked.storageValue,
    );

    if (!mounted) return;

    setState(() {
      _repeatLessonGroupingMode = picked;
      _notificationSettingsChanged = true;
    });

    _showActionToast('동일 회원 요일 자동 체크를 ${picked.shortLabel}으로 변경했어요.');
  }

  void _handleBackTap() {
    Navigator.of(context).pop(_notificationSettingsChanged ? true : null);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('로그아웃할까요?'),
            content: const Text('로그아웃하면 실제 회원 화면을 닫고 Guest 시작 화면으로 이동합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('로그아웃'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      if ((widget.personalOwnerUid ?? '').trim().isNotEmpty) {
        await MtfHomeWidgetService.clearPersonalScheduleData();
      }
      await AppAccountService.instance.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      _showActionToast(appAccountErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final account = AppAccountService.instance.currentSnapshot;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kSettingsMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _SettingsHeader(onBackTap: _handleBackTap),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Column(
                        children: [
                          // ── 화면 설정 ──────────────────────────────
                          _SettingsSectionCard(
                            title: '화면 설정',
                            subtitle: '앱 화면과 홈 위젯 표시 방식을 맞춰보세요',
                            icon: Icons.display_settings_rounded,
                            children: [
                              _SettingsThemeSelector(
                                selected: appTheme,
                                onSelected: (mode) async {
                                  await ref
                                      .read(appThemeProvider.notifier)
                                      .setTheme(mode);
                                  if (!mounted) return;
                                  _showActionToast(
                                    '${_appThemeLabel(mode)} 테마로 변경했어요.',
                                  );
                                },
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.widgets_outlined,
                                title: '위젯 설정',
                                subtitle: '홈 화면 위젯 표시 정보를 관리합니다',
                                onTap: _openWidgetSettingsPage,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── 운영 설정 ──────────────────────────────
                          _SettingsSectionCard(
                            title: '운영 설정',
                            subtitle: '수업 타입, 레슨 반복 방식, 알림을 관리합니다',
                            icon: Icons.tune_rounded,
                            children: [
                              _SettingsMenuTile(
                                icon: Icons.category_outlined,
                                title: '수업 유형 관리',
                                subtitle: 'PT수업, 필라테스, 그룹수업 등 수업 타입 설정',
                                onTap: () {
                                  final ownerUid =
                                      (widget.personalOwnerUid ?? '').trim();
                                  if (ownerUid.isEmpty) {
                                    _showPreparingToast('수업 유형 관리');
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => LessonTypeManagementPage(
                                            personalOwnerUid: ownerUid,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.event_repeat_rounded,
                                title: '동일 회원 요일 자동 체크',
                                subtitle: '레슨 수정 시 여러 요일을 자동 체크하는 기준',
                                trailingText:
                                    _repeatLessonGroupingMode.shortLabel,
                                onTap: _openRepeatLessonGroupingSheet,
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.notifications_outlined,
                                title: '알림 설정',
                                subtitle: '레슨 시작 전 알림 시간을 설정해요',
                                onTap: () async {
                                  final changed = await Navigator.of(
                                    context,
                                  ).push<bool>(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => NotificationSettingsPage(
                                            personalOwnerUid:
                                                widget.personalOwnerUid,
                                          ),
                                    ),
                                  );

                                  if (!mounted) return;

                                  if (changed == true) {
                                    setState(() {
                                      _notificationSettingsChanged = true;
                                    });

                                    _showActionToast('알림 설정을 저장했어요.');
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── 프리미엄 배너 ──────────────────────────
                          if (_premiumBannerData != null) ...[
                            PremiumBannerWidget(
                              data: _premiumBannerData!,
                              onTap: _openTierGuideSheet,
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (!account.isGuest) ...[
                            _SettingsSectionCard(
                              title: '계정',
                              subtitle:
                                  account.user?.email.isNotEmpty == true
                                      ? account.user!.email
                                      : 'Firebase 계정 연결됨',
                              icon: Icons.account_circle_outlined,
                              children: [
                                _SettingsMenuTile(
                                  icon: Icons.password_rounded,
                                  title: '비밀번호 변경',
                                  subtitle: '현재 비밀번호를 확인하고 안전하게 변경합니다',
                                  onTap:
                                      () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => const PasswordChangePage(),
                                        ),
                                      ),
                                ),
                                const _SettingsDivider(),
                                _SettingsMenuTile(
                                  icon: Icons.logout_rounded,
                                  title: _signingOut ? '로그아웃 중...' : '로그아웃',
                                  subtitle: 'Guest 시작 화면으로 안전하게 이동합니다',
                                  onTap: _signOut,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── 앱 정보 ────────────────────────────────
                          _SettingsSectionCard(
                            title: '앱 정보',
                            subtitle: '고객센터, 버전, 앱 정보를 확인합니다',
                            icon: Icons.info_outline_rounded,
                            children: [
                              _SettingsMenuTile(
                                icon: Icons.help_outline_rounded,
                                title: '고객센터',
                                subtitle: '문의와 피드백을 보냅니다',
                                onTap: () => _showPreparingToast('고객센터'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.campaign_outlined,
                                title: '공지사항',
                                subtitle: '업데이트와 안내사항을 확인합니다',
                                onTap: () => _showPreparingToast('공지사항'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.mobile_friendly_rounded,
                                title: '버전 정보',
                                subtitle: '모어댄 · MORE THAN',
                                trailingText: 'v1.0.0',
                                onTap:
                                    () =>
                                        _showActionToast('현재 버전은 v1.0.0 입니다.'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _appThemeLabel(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return '라이트';
    case AppThemeMode.dark:
      return '다크';
    case AppThemeMode.lululala:
      return '룰루랄라';
  }
}

// ── 헤더 ────────────────────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 16),
      decoration: BoxDecoration(
        gradient: context.mtfHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            InkWell(
              onTap: onBackTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '설정',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 카드 ────────────────────────────────────────────────────────────────

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ── 메뉴 타일 ────────────────────────────────────────────────────────────────

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingText;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = danger ? colors.error : colors.primary;
    final titleColor = danger ? colors.error : colors.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── 스위치 타일 ──────────────────────────────────────────────────────────────

class _SettingsThemeSelector extends StatelessWidget {
  const _SettingsThemeSelector({
    required this.selected,
    required this.onSelected,
  });

  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    const options = [
      (
        mode: AppThemeMode.light,
        label: '라이트',
        description: 'MORE THAN 네이비와 웜 옐로우',
        colors: [AppColors.warmIvory, AppColors.deepNavy, AppColors.warmYellow],
      ),
      (
        mode: AppThemeMode.dark,
        label: '다크',
        description: '짙은 네이비 기반의 어두운 화면',
        colors: [
          AppColors.darkBackground,
          AppColors.darkSurface,
          AppColors.warmYellow,
        ],
      ),
      (
        mode: AppThemeMode.lululala,
        label: '룰루랄라',
        description: '기존의 밝고 경쾌한 인디고·퍼플',
        colors: [
          AppColors.lululalaSurface,
          AppColors.lululalaPrimary,
          AppColors.lululalaSecondary,
        ],
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          InkWell(
            onTap: () => onSelected(options[index].mode),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _ThemeSwatch(colors: options[index].colors),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          options[index].label,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          options[index].description,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected == options[index].mode
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color:
                        selected == options[index].mode
                            ? colors.secondary
                            : colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (index != options.length - 1) const _SettingsDivider(),
        ],
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 34,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          for (final color in colors)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 구분선 ────────────────────────────────────────────────────────────────────

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1);
  }
}
