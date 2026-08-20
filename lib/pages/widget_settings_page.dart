import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/app_theme_mode.dart';
import '../models/widget_theme.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

const Color kWidgetSettingsPrimary = Color(0xFF4F46E5);
const Color kWidgetSettingsPrimary2 = Color(0xFF9333EA);
const Color kWidgetSettingsBg = Color(0xFFF3F4F6);
const Color kWidgetSettingsCard = Colors.white;
const Color kWidgetSettingsBorder = Color(0xFFE5E7EB);
const Color kWidgetSettingsText = Color(0xFF111827);
const Color kWidgetSettingsMuted = Color(0xFF6B7280);
const double kWidgetSettingsMaxContentWidth = 480;

class WidgetSettingsPage extends ConsumerStatefulWidget {
  const WidgetSettingsPage({super.key});

  @override
  ConsumerState<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends ConsumerState<WidgetSettingsPage> {
  OverlayEntry? _actionToastEntry;
  Timer? _actionToastTimer;

  @override
  void dispose() {
    _hideActionToast();
    super.dispose();
  }

  Future<void> _setTheme(AppThemeMode value) async {
    await ref.read(appThemeProvider.notifier).setTheme(value);
    if (!mounted) return;
    _showActionToast('${_appThemeLabel(value)} 앱·위젯 테마로 변경했어요.');
  }

  Future<void> _updateWidgets() async {
    await HomeWidget.updateWidget(
      name: 'MtfScheduleWidgetReceiver',
      androidName: 'MtfScheduleWidgetReceiver',
      qualifiedAndroidName: 'com.example.mtf_app.MtfScheduleWidgetReceiver',
    );

    await HomeWidget.updateWidget(
      name: 'MtfNextLessonWidgetReceiver',
      androidName: 'MtfNextLessonWidgetReceiver',
      qualifiedAndroidName: 'com.example.mtf_app.MtfNextLessonWidgetReceiver',
    );
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

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kWidgetSettingsMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _WidgetSettingsHeader(
                    onBackTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Column(
                        children: [
                          _WidgetSettingsSectionCard(
                            title: '위젯 테마',
                            subtitle: '앱 화면 스타일과 함께 변경돼요',
                            icon: Icons.palette_outlined,
                            children: [
                              _WidgetThemeTile(
                                title: '라이트',
                                subtitle: '네이비와 웜 옐로우 브랜드 테마',
                                selected: appTheme == AppThemeMode.light,
                                preview: _ThemePreviewFromData(
                                    theme: kMtfWidgetThemes[
                                        WidgetThemeType.brandLight]!),
                                onTap: () => _setTheme(AppThemeMode.light),
                              ),
                              const _WidgetSettingsDivider(),
                              _WidgetThemeTile(
                                title: '다크',
                                subtitle: '네이비 배경과 골드 포인트',
                                selected: appTheme == AppThemeMode.dark,
                                preview: _ThemePreviewFromData(
                                    theme: kMtfWidgetThemes[
                                        WidgetThemeType.dark]!),
                                onTap: () => _setTheme(AppThemeMode.dark),
                              ),
                              const _WidgetSettingsDivider(),
                              _WidgetThemeTile(
                                title: '룰루랄라',
                                subtitle: '기존의 밝고 경쾌한 인디고·퍼플',
                                selected: appTheme == AppThemeMode.lululala,
                                preview: _ThemePreviewFromData(
                                    theme: kMtfWidgetThemes[
                                        WidgetThemeType.light]!),
                                onTap: () => _setTheme(AppThemeMode.lululala),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _WidgetSettingsSectionCard(
                            title: '표시 설정',
                            subtitle: '스케줄러 위젯의 시간표 표시 방식을 관리해요',
                            icon: Icons.display_settings_rounded,
                            children: [
                              _WidgetSettingsMenuTile(
                                icon: Icons.schedule_rounded,
                                title: '시간 범위 설정',
                                subtitle: '홈 수업일정에서 설정한 시간 범위를 위젯에 반영합니다',
                                trailingText: '홈에서 설정',
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              const _WidgetSettingsDivider(),
                              _WidgetSettingsMenuTile(
                                icon: Icons.calendar_view_week_rounded,
                                title: '요일 표시',
                                subtitle: '전체, 평일, 주말 표시를 홈 화면 설정과 맞춥니다',
                                trailingText: '자동 반영',
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              const _WidgetSettingsDivider(),
                              _WidgetSettingsMenuTile(
                                icon: Icons.access_time_rounded,
                                title: '현재 시간 표시',
                                subtitle: '오늘 요일과 현재 시간 칸을 강조합니다',
                                trailingText: '사용 중',
                                onTap: () =>
                                    _showActionToast('현재 시간 강조가 적용되어 있어요.'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _WidgetSettingsSectionCard(
                            title: '위젯 종류',
                            subtitle: '홈 화면에 추가할 위젯 타입을 정리합니다',
                            icon: Icons.widgets_outlined,
                            children: [
                              _WidgetSettingsMenuTile(
                                icon: Icons.calendar_month_outlined,
                                title: '전체 스케줄러',
                                subtitle: '주간 수업일정을 한눈에 보는 큰 위젯',
                                trailingText: '사용 가능',
                                onTap: () => _showActionToast(
                                    '전체 스케줄러 위젯은 홈 화면에서 추가할 수 있어요.'),
                              ),
                              const _WidgetSettingsDivider(),
                              _WidgetSettingsMenuTile(
                                icon: Icons.event_available_rounded,
                                title: '다음 레슨',
                                subtitle: '다음/다다음 레슨과 메모를 빠르게 확인합니다',
                                trailingText: '사용 가능',
                                onTap: () => _showActionToast(
                                    '다음 레슨 위젯은 홈 화면에서 추가할 수 있어요.'),
                              ),
                              const _WidgetSettingsDivider(),
                              _WidgetSettingsMenuTile(
                                icon: Icons.auto_awesome_rounded,
                                title: '자동 시간 초점',
                                subtitle: '현재 시간 주변 일정만 보여주는 위젯',
                                trailingText: '준비중',
                                onTap: () => _showPreparingToast('자동 시간 초점 위젯'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _WidgetSettingsSectionCard(
                            title: '안내',
                            subtitle: '위젯 사용 전 알아두면 좋아요',
                            icon: Icons.info_outline_rounded,
                            children: const [
                              _WidgetInfoText(
                                '전체 스케줄러는 안정성을 위해 시간표 본문을 이미지 방식으로 표시합니다. '
                                '시간 범위나 수업일정이 바뀌면 위젯 이미지도 자동으로 다시 그려집니다.',
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

class _WidgetSettingsHeader extends StatelessWidget {
  const _WidgetSettingsHeader({
    required this.onBackTap,
  });

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 18),
      decoration: BoxDecoration(
        gradient: gradient,
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
                    '위젯 설정',
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
                    Icons.widgets_rounded,
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
                        '홈 화면 위젯 관리',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '스케줄러, 다음 레슨, 테마 표시 방식을 설정할 수 있어요.',
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

class _WidgetSettingsSectionCard extends StatelessWidget {
  const _WidgetSettingsSectionCard({
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
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
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: scheme.onSecondaryContainer,
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
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
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

class _WidgetSettingsMenuTile extends StatelessWidget {
  const _WidgetSettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 20,
                color: scheme.onSecondaryContainer,
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
                      color: scheme.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
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
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _WidgetThemeTile extends StatelessWidget {
  const _WidgetThemeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? tokens.widgetPreviewSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border:
              selected ? Border.all(color: tokens.widgetPreviewBorder) : null,
        ),
        child: Row(
          children: [
            preview,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? scheme.secondary : scheme.onSurfaceVariant,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetSettingsDivider extends StatelessWidget {
  const _WidgetSettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _WidgetInfoText extends StatelessWidget {
  const _WidgetInfoText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
    );
  }
}

class _ThemePreviewLight extends StatelessWidget {
  const _ThemePreviewLight();

  @override
  Widget build(BuildContext context) {
    return _MiniPreview(
      bg: Colors.white,
      header: const Color(0xFFEFF6FF),
      line: const Color(0xFFE5E7EB),
      block: const Color(0xFF4F46E5),
    );
  }
}

class _ThemePreviewFromData extends StatelessWidget {
  const _ThemePreviewFromData({
    required this.theme,
  });

  final MtfWidgetThemeData theme;

  @override
  Widget build(BuildContext context) {
    final bg = widgetColorFromHex(theme.bodyBgColor);
    final headerStart = widgetColorFromHex(theme.headerStartColor);
    final headerEnd = widgetColorFromHex(theme.headerEndColor);
    final line = widgetColorFromHex(theme.gridLineColor);
    final rowEven = widgetColorFromHex(theme.rowEvenColor);
    final block = theme.isDark
        ? const Color(0xFFE8C97A)
        : theme.type == WidgetThemeType.pinkperfume
            ? const Color(0xFFDB2777)
            : theme.type == WidgetThemeType.brownHistory
                ? const Color(0xFF8B5E34)
                : theme.type == WidgetThemeType.ttobak
                    ? const Color(0xFF111827)
                    : const Color(0xFF4F46E5);

    return Container(
      width: 58,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Container(
            height: 11,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerStart, headerEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
                          child: Container(color: rowEven.withOpacity(0.65))),
                      Expanded(child: Container(color: bg)),
                      Expanded(
                          child: Container(color: rowEven.withOpacity(0.65))),
                    ],
                  ),
                ),
                Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: line)),
                Positioned(
                    left: 28,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: line)),
                Positioned(
                    left: 44,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: line)),
                Positioned(
                  left: 16,
                  top: 8,
                  width: 19,
                  height: 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Positioned(
                  left: 36,
                  top: 21,
                  width: 15,
                  height: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: block.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
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

class _MiniPreview extends StatelessWidget {
  const _MiniPreview({
    required this.bg,
    required this.header,
    required this.line,
    required this.block,
  });

  final Color bg;
  final Color header;
  final Color line;
  final Color block;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Container(
            height: 11,
            decoration: BoxDecoration(
              color: header,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: line)),
                Positioned(
                    left: 28,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: line)),
                Positioned(
                    left: 44,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 1, color: line)),
                Positioned(
                    left: 16,
                    top: 8,
                    width: 19,
                    height: 9,
                    child: Container(
                        decoration: BoxDecoration(
                            color: block,
                            borderRadius: BorderRadius.circular(4)))),
                Positioned(
                    left: 36,
                    top: 21,
                    width: 15,
                    height: 8,
                    child: Container(
                        decoration: BoxDecoration(
                            color: block.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SketchMiniPreviewPainter extends CustomPainter {
  const _SketchMiniPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()..color = const Color(0xFFFDFCF8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(12),
      ),
      paper,
    );

    final line = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final block = Paint()
      ..color = Colors.black.withOpacity(0.13)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(9),
      ),
      line,
    );

    canvas.drawLine(const Offset(4, 12), Offset(size.width - 4, 12), line);

    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 12), Offset(x, size.height - 4), line);
    }

    for (int i = 1; i < 4; i++) {
      final y = 12 + (size.height - 16) * i / 4;
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), line);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(17, 17, 19, 10),
        const Radius.circular(4),
      ),
      block,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
