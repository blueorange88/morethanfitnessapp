import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mtf_app/pages/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_repeat_lesson_grouping_mode.dart';
import '../models/app_theme_mode.dart';
import '../services/app_account_service.dart';
import '../services/mtf_home_widget_service.dart';
import 'password_change_page.dart';
import '../widgets/home/schedule/home_repeat_lesson_grouping_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadRepeatLessonGroupingMode());
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WidgetSettingsPage(),
      ),
    );
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

    _showActionToast('반복 레슨 묶기 방식을 ${picked.shortLabel}으로 변경했어요.');
  }

  void _handleBackTap() {
    Navigator.of(context).pop(_notificationSettingsChanged ? true : null);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
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
                  _SettingsHeader(
                    onBackTap: _handleBackTap,
                  ),
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
                          _SettingsMenuTile(
                            icon: Icons.category_outlined,
                            title: '수업 유형 관리',
                            subtitle: 'PT수업, 필라테스, 그룹수업 등 수업 타입 설정',
                            onTap: () => _showPreparingToast('수업 유형 관리'),
                          ),
                          const _SettingsDivider(),
                          _SettingsMenuTile(
                            icon: Icons.event_repeat_rounded,
                            title: '반복 레슨 묶기 방식',
                            subtitle: '레슨 수정 시 여러 요일을 자동 체크하는 기준',
                            trailingText: _repeatLessonGroupingMode.shortLabel,
                            onTap: _openRepeatLessonGroupingSheet,
                          ),
                          const _SettingsDivider(),
                          _SettingsMenuTile(
                            icon: Icons.notifications_outlined,
                            title: '알림 설정',
                            subtitle: '레슨 시작 전 알림 시간을 설정해요',
                            onTap: () async {
                              final changed =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => NotificationSettingsPage(
                                    personalOwnerUid: widget.personalOwnerUid,
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
                          const SizedBox(height: 14),

                          // ── 프리미엄 배너 ──────────────────────────
                          _SettingsPremiumBanner(
                            onTap: () => _showPreparingToast('프리미엄 업그레이드'),
                          ),
                          const SizedBox(height: 14),

                          if (!account.isGuest) ...[
                            _SettingsSectionCard(
                              title: '계정',
                              subtitle: account.user?.email.isNotEmpty == true
                                  ? account.user!.email
                                  : 'Firebase 계정 연결됨',
                              icon: Icons.account_circle_outlined,
                              children: [
                                _SettingsMenuTile(
                                  icon: Icons.password_rounded,
                                  title: '비밀번호 변경',
                                  subtitle: '현재 비밀번호를 확인하고 안전하게 변경합니다',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PasswordChangePage(),
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
                                onTap: () =>
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
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 18),
      decoration: BoxDecoration(
        gradient: context.mtfHeaderGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                      ),
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
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '앱 설정',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '화면, 위젯, 수업 유형, 알림, 앱 정보를 한 곳에서 관리해요.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
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
                    color: selected == options[index].mode
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

// ── 프리미엄 배너 ─────────────────────────────────────────────────────────────

class _SettingsPremiumBanner extends StatelessWidget {
  const _SettingsPremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              AppColors.deepNavy,
              Color(0xFF163A54),
              Color(0xFF6D5A1F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.secondary.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFBBF24),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '프리미엄 기능',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'AI 인사이트, 인사이트, 계약 관리 기능을 준비중이에요.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
