import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../core/aifc_avatar.dart';

enum AifcHomeScheduleAction {
  copyWeek,
  pasteWeek,
  deleteWeek,
  timeRange,
  allRowsMinute,
  repeatGrouping,
}

enum _ScheduleMenuPage { main, bulk, time }

/// 일괄관리 시트 색상. 앱의 네이비·아이보리 톤을 따르고 어두운 모드에서는 앱 어두운 표면색을 쓴다.
/// `_ScheduleActionSheetBodyState.build`에서 현재 테마를 반영한다.
bool _sheetDark = false;

Color get sheetBg => _sheetDark ? AppColors.darkSurface : AppColors.warmIvory;
Color get sheetCard => _sheetDark ? AppColors.darkSurface2 : Colors.white;
Color get sheetBorder =>
    _sheetDark ? AppColors.darkBorder : AppColors.lightBorder;
Color get sheetHandle =>
    _sheetDark ? AppColors.darkBorder : const Color(0xFFD5CFC0);
Color get sheetText =>
    _sheetDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
Color get sheetSub =>
    _sheetDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
Color get sheetDanger =>
    _sheetDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
Color get sheetDangerBorder =>
    _sheetDark ? const Color(0x66FCA5A5) : const Color(0xFFFECACA);
Color get sheetHint =>
    _sheetDark ? AppColors.darkTextTertiary : AppColors.lightTextHint;

class AifcHomeScheduleActionChatSheet {
  const AifcHomeScheduleActionChatSheet._();

  static Future<AifcHomeScheduleAction?> show({
    required BuildContext context,
    required String nickname,
    required String targetLabel,
    required bool hasCopiedSchedules,
    String? copiedSourceLabel,
    int copiedCount = 0,
    bool openBulkFirst = false,
    required Color primaryColor,
  }) {
    final safeName = _nicknameLabel(nickname);
    // 어두운 모드에서는 네이비 강조색이 표면에 묻히므로 앱의 골드 계열로 바꾼다.
    final accent =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.goldLight
            : primaryColor;

    return showModalBottomSheet<AifcHomeScheduleAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ScheduleActionSheetBody(
          nicknameLabel: safeName,
          targetLabel: targetLabel,
          hasCopiedSchedules: hasCopiedSchedules,
          copiedSourceLabel: copiedSourceLabel,
          copiedCount: copiedCount,
          primaryColor: accent,
          openBulkFirst: openBulkFirst,
        );
      },
    );
  }

  static String _nicknameLabel(String value) {
    final text = value.trim();
    if (text.isEmpty) return '강사님';
    return text.endsWith('님') ? text : '$text님';
  }
}

class _ScheduleActionSheetBody extends StatefulWidget {
  const _ScheduleActionSheetBody({
    required this.nicknameLabel,
    required this.targetLabel,
    required this.hasCopiedSchedules,
    required this.openBulkFirst,
    required this.copiedSourceLabel,
    required this.copiedCount,
    required this.primaryColor,
  });

  final String nicknameLabel;
  final String targetLabel;
  final bool hasCopiedSchedules;
  final bool openBulkFirst;
  final String? copiedSourceLabel;
  final int copiedCount;
  final Color primaryColor;

  @override
  State<_ScheduleActionSheetBody> createState() =>
      _ScheduleActionSheetBodyState();
}

class _ScheduleActionSheetBodyState extends State<_ScheduleActionSheetBody> {
  late _ScheduleMenuPage _page;

  @override
  void initState() {
    super.initState();
    _page =
        widget.openBulkFirst ? _ScheduleMenuPage.bulk : _ScheduleMenuPage.main;
  }

  void _go(_ScheduleMenuPage page) {
    HapticFeedback.selectionClick();
    setState(() {
      _page = page;
    });
  }

  void _popAction(AifcHomeScheduleAction action) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(action);
  }

  String get _copiedLabel {
    final source = widget.copiedSourceLabel?.trim() ?? '';
    if (source.isEmpty) return '복사한 스케줄';
    return source;
  }

  @override
  Widget build(BuildContext context) {
    _sheetDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.84,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: switch (_page) {
                _ScheduleMenuPage.main => _buildMainPage(context),
                _ScheduleMenuPage.bulk => _buildBulkPage(context),
                _ScheduleMenuPage.time => _buildTimePage(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainPage(BuildContext context) {
    return Column(
      key: const ValueKey('schedule_main'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Handle(),
        const SizedBox(height: 14),
        _FcBubble(
          primaryColor: widget.primaryColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.nicknameLabel}, 스케줄표 조정이 필요하시면 제가 도와드릴게요.',
                style: TextStyle(
                  color: sheetText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '어떤 작업이 먼저 필요하세요?',
                style: TextStyle(
                  color: sheetText.withOpacity(0.64),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CategoryTile(
          icon: Icons.dashboard_customize_rounded,
          title: '스케줄 일괄관리',
          subtitle: '복사 / 붙여넣기 / 미확정 일정 전체삭제',
          primaryColor: widget.primaryColor,
          onTap: () => _go(_ScheduleMenuPage.bulk),
        ),
        _CategoryTile(
          icon: Icons.tune_rounded,
          title: '시간표 설정',
          subtitle: '첫 시간 / 마지막 시간 / 전체 시작 분 설정',
          primaryColor: widget.primaryColor,
          onTap: () => _go(_ScheduleMenuPage.time),
        ),
        const SizedBox(height: 8),
        _TipBox(
          primaryColor: widget.primaryColor,
          text: '팁: 숫자 시간 칸을 길게 누르면 해당 시간 줄만 따로 시작 분을 바꿀 수 있어요.',
        ),
        const SizedBox(height: 8),
        _CloseButtonText(),
      ],
    );
  }

  Widget _buildBulkPage(BuildContext context) {
    return Column(
      key: const ValueKey('schedule_bulk'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Handle(),
        const SizedBox(height: 12),
        if (widget.openBulkFirst)
          _PlainHeader(title: '스케줄 일괄관리', primaryColor: widget.primaryColor)
        else
          _BackHeader(
            title: '스케줄 일괄관리',
            primaryColor: widget.primaryColor,
            onBack: () => _go(_ScheduleMenuPage.main),
          ),
        const SizedBox(height: 10),
        _FcBubble(
          primaryColor: widget.primaryColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '스케줄 일괄관리를 도와드릴게요.',
                style: TextStyle(
                  color: sheetText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '스케줄표의 복사, 붙여넣기, 미확정 일정 전체삭제를 여기서 할 수 있어요.\n'
                '‘이번 주 스케줄’ 글씨를 길게 눌러도 바로 열 수 있어요.',
                style: TextStyle(
                  color: sheetText.withOpacity(0.62),
                  fontSize: 11.3,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              if (widget.hasCopiedSchedules && widget.copiedCount > 0) ...[
                const SizedBox(height: 10),
                _CopiedInfo(
                  primaryColor: widget.primaryColor,
                  text: '$_copiedLabel ${widget.copiedCount}개가 준비되어 있어요.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.copy_rounded,
          title: '스케줄 복사',
          subtitle: '${widget.targetLabel}의 레슨일정을 복사해둘게요.',
          primaryColor: widget.primaryColor,
          onTap: () => _popAction(AifcHomeScheduleAction.copyWeek),
        ),
        _ActionTile(
          icon: Icons.content_paste_rounded,
          title: '스케줄 붙여넣기',
          subtitle:
              widget.hasCopiedSchedules
                  ? '복사해둔 스케줄을 ${widget.targetLabel}에 붙여넣어요.'
                  : '먼저 복사한 스케줄이 필요해요.',
          disabled: !widget.hasCopiedSchedules,
          primaryColor: widget.primaryColor,
          onTap:
              widget.hasCopiedSchedules
                  ? () => _popAction(AifcHomeScheduleAction.pasteWeek)
                  : null,
        ),
        _ActionTile(
          icon: Icons.delete_forever_outlined,
          title: '미확정 스케줄 전체삭제',
          subtitle: '확정된 레슨은 보호하고 미확정 일정만 삭제해요.',
          danger: true,
          primaryColor: widget.primaryColor,
          onTap: () => _popAction(AifcHomeScheduleAction.deleteWeek),
        ),
        const SizedBox(height: 8),
        _CloseButtonText(),
      ],
    );
  }

  Widget _buildTimePage(BuildContext context) {
    return Column(
      key: const ValueKey('schedule_time'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Handle(),
        const SizedBox(height: 12),
        _BackHeader(
          title: '시간표 설정',
          primaryColor: widget.primaryColor,
          onBack: () => _go(_ScheduleMenuPage.main),
        ),
        const SizedBox(height: 10),
        _FcBubble(
          primaryColor: widget.primaryColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '시간표 설정을 도와드릴게요.',
                style: TextStyle(
                  color: sheetText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '스케줄표의 시작/끝 시간과 전체 시작 분을 정리할 수 있어요.\n'
                '위젯 미리보기 기준에도 함께 반영돼요.',
                style: TextStyle(
                  color: sheetText.withOpacity(0.62),
                  fontSize: 11.3,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.schedule_rounded,
          title: '첫/마지막 시간 설정',
          subtitle: '스케줄표에 표시할 첫 시간과 마지막 시간을 정해요.',
          primaryColor: widget.primaryColor,
          onTap: () => _popAction(AifcHomeScheduleAction.timeRange),
        ),
        _ActionTile(
          icon: Icons.more_time_rounded,
          title: '전체 시작 분 설정',
          subtitle: '모든 시간 줄의 기본 시작 분을 한 번에 맞춰요.',
          primaryColor: widget.primaryColor,
          onTap: () => _popAction(AifcHomeScheduleAction.allRowsMinute),
        ),
        _ActionTile(
          icon: Icons.event_repeat_rounded,
          title: '동일 회원 요일 자동 체크',
          subtitle: '레슨 수정 시 여러 요일을 자동 체크하는 기준을 정해요.',
          primaryColor: widget.primaryColor,
          onTap: () => _popAction(AifcHomeScheduleAction.repeatGrouping),
        ),
        const SizedBox(height: 8),
        _TipBox(
          primaryColor: widget.primaryColor,
          text: '특정 시간 줄만 바꾸고 싶다면 06시, 07시 같은 숫자 시간 칸을 길게 눌러주세요.',
        ),
        const SizedBox(height: 8),
        _CloseButtonText(),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: sheetHandle,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PlainHeader extends StatelessWidget {
  _PlainHeader({required this.title, required this.primaryColor});

  final String title;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.dashboard_customize_rounded,
            color: primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: sheetText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackHeader extends StatelessWidget {
  _BackHeader({
    required this.title,
    required this.primaryColor,
    required this.onBack,
  });

  final String title;
  final Color primaryColor;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: sheetCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sheetBorder),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: sheetText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FcBubble extends StatelessWidget {
  _FcBubble({required this.child, required this.primaryColor});

  final Widget child;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AifcAvatar(size: 34, isAnimating: true, backgroundColor: sheetCard),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: sheetCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: sheetBorder),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      primaryColor: primaryColor,
      onTap: onTap,
      trailingIcon: Icons.chevron_right_rounded,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onTap,
    this.disabled = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback? onTap;
  final bool disabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      primaryColor: danger ? sheetDanger : primaryColor,
      onTap: disabled ? null : onTap,
      disabled: disabled,
      danger: danger,
      trailingIcon: Icons.chevron_right_rounded,
    );
  }
}

class _BaseTile extends StatelessWidget {
  _BaseTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onTap,
    required this.trailingIcon,
    this.disabled = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback? onTap;
  final IconData trailingIcon;
  final bool disabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        danger
            ? sheetDanger
            : disabled
            ? sheetHint
            : sheetText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: disabled ? 0.48 : 1.0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: sheetCard,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: danger ? sheetDangerBorder : sheetBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: primaryColor),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: disabled ? sheetHint : sheetSub,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  trailingIcon,
                  color: disabled ? sheetHint : primaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopiedInfo extends StatelessWidget {
  _CopiedInfo({required this.primaryColor, required this.text});

  final Color primaryColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.13)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primaryColor,
          fontSize: 11.3,
          fontWeight: FontWeight.w900,
          height: 1.35,
        ),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  _TipBox({required this.primaryColor, required this.text});

  final Color primaryColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: sheetCard.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sheetBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 15,
            color: primaryColor.withOpacity(0.78),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: sheetSub,
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButtonText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '닫기',
          style: TextStyle(
            color: sheetHint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
