import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'widget_settings_page.dart';

const Color kSettingsPrimary = Color(0xFF4F46E5);
const Color kSettingsPrimary2 = Color(0xFF9333EA);
const Color kSettingsBg = Color(0xFFF3F4F6);
const Color kSettingsCard = Colors.white;
const Color kSettingsBorder = Color(0xFFE5E7EB);
const Color kSettingsText = Color(0xFF111827);
const Color kSettingsMuted = Color(0xFF6B7280);
const double kSettingsMaxContentWidth = 480;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  OverlayEntry? _actionToastEntry;
  Timer? _actionToastTimer;

  @override
  void dispose() {
    _hideActionToast();
    super.dispose();
  }

  void _hideActionToast() {
    _actionToastTimer?.cancel();
    _actionToastTimer = null;
    _actionToastEntry?.remove();
    _actionToastEntry = null;
  }

  void _showActionToast(
      String message, {
        double bottomOffset = 76,
        Duration duration = const Duration(milliseconds: 1400),
      }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _hideActionToast();

    _actionToastEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: bottomOffset,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withOpacity(0.94),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

    overlay.insert(_actionToastEntry!);

    _actionToastTimer = Timer(duration, _hideActionToast);
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

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(darkModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
        isTablet ? kSettingsMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: kSettingsBg,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _SettingsHeader(
                    onBackTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Column(
                        children: [
                          _SettingsSectionCard(
                            title: '화면 설정',
                            subtitle: '앱 화면과 홈 위젯 표시 방식을 맞춰보세요',
                            icon: Icons.display_settings_rounded,
                            children: [
                              _SettingsSwitchTile(
                                icon: Icons.dark_mode_outlined,
                                title: '다크 모드',
                                subtitle: dark ? '어두운 화면으로 사용 중' : '밝은 화면으로 사용 중',
                                value: dark,
                                onChanged: (_) {
                                  ref.read(darkModeProvider.notifier).toggle();
                                  _showActionToast(
                                    dark ? '라이트 모드로 변경했어요.' : '다크 모드로 변경했어요.',
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
                          _SettingsSectionCard(
                            title: '운영 설정',
                            subtitle: '수업, 수업일정, 알림 방식을 내 운영에 맞게 설정해요',
                            icon: Icons.tune_rounded,
                            children: [
                              _SettingsMenuTile(
                                icon: Icons.category_outlined,
                                title: '수업 유형 관리',
                                subtitle: 'PT수업, 필라테스, 그룹수업 등 수업 타입 설정',
                                onTap: () => _showPreparingToast('수업 유형 관리'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.schedule_rounded,
                                title: '기본 수업 시간 설정',
                                subtitle: '30분, 50분, 60분 등 기본 수업 시간 설정',
                                onTap: () => _showPreparingToast('기본 수업 시간 설정'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.access_time_rounded,
                                title: '수업 시간 범위 설정',
                                subtitle: '홈 수업일정의 시작/종료 시간을 관리해요',
                                onTap: () => _showPreparingToast('일정 시간 범위 설정'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.notifications_outlined,
                                title: '알림 설정',
                                subtitle: '수업, 만료, 체크 필요 알림 관리',
                                onTap: () => _showPreparingToast('알림 설정'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SettingsSectionCard(
                            title: '회원 / 문서 관리',
                            subtitle: '계약서, 동의서, 삭제 대기 회원을 한 곳에서 확인해요',
                            icon: Icons.folder_copy_outlined,
                            children: [
                              _SettingsMenuTile(
                                icon: Icons.description_outlined,
                                title: '계약서 관리',
                                subtitle: '내 수업 회원의 계약서와 지난 계약서를 확인해요',
                                onTap: () => _showPreparingToast('계약서 관리'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.privacy_tip_outlined,
                                title: '개인정보동의서 관리',
                                subtitle: '수업일지 사용 동의서를 확인하고 정리해요',
                                onTap: () => _showPreparingToast('개인정보동의서 관리'),
                              ),
                              const _SettingsDivider(),
                              _SettingsMenuTile(
                                icon: Icons.restore_from_trash_rounded,
                                title: '삭제 대기 회원 복구',
                                subtitle: '내 수업에서 삭제 처리한 회원을 다시 확인해요',
                                onTap: () => _showPreparingToast('삭제 대기 회원 복구'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SettingsPremiumBanner(
                            onTap: () => _showPreparingToast('프리미엄 업그레이드'),
                          ),
                          const SizedBox(height: 14),
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
                                subtitle: 'More Than Fitness',
                                trailingText: 'v1.0.0',
                                onTap: () => _showActionToast('현재 버전은 v1.0.0 입니다.'),
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

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.onBackTap,
  });

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kSettingsPrimary, kSettingsPrimary2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
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
                        '앱 운영 설정',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '수업, 위젯, 문서, 앱 정보를 한 곳에서 살펴볼 수 있어요.',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: kSettingsCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kSettingsBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
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
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: kSettingsPrimary,
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
                      style: const TextStyle(
                        color: kSettingsText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: kSettingsMuted,
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
    final color = danger ? const Color(0xFFDC2626) : kSettingsPrimary;
    final titleColor = danger ? const Color(0xFFDC2626) : kSettingsText;

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
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
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
                    style: const TextStyle(
                      color: kSettingsMuted,
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
                style: const TextStyle(
                  color: kSettingsMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kSettingsPrimary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: kSettingsPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kSettingsText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kSettingsMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: kSettingsPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: kSettingsBorder,
    );
  }
}

class _SettingsPremiumBanner extends StatelessWidget {
  const _SettingsPremiumBanner({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              Color(0xFF111827),
              Color(0xFF4F46E5),
              Color(0xFFF97316),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kSettingsPrimary.withOpacity(0.18),
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
                    'AI 인사이트, 운영통계, 계약 관리 기능을 준비중이에요.',
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
            SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}