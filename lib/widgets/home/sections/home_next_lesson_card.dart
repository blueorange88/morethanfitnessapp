import 'package:flutter/material.dart';

class HomeNextLessonCard extends StatelessWidget {
  const HomeNextLessonCard({
    super.key,
    required this.name,
    required this.time,
    required this.type,
    required this.status,
    required this.enrolled,
    required this.cap,
    required this.primaryColor,
    this.emphasis = 0,
    this.visualSoftness = 0,
    this.isPriority = false,
    this.forceClear = false,
    this.hideLeftBar = false,
    this.memo = '',
    this.countText = '',
    this.isManualMember = false,
    this.onTap,

  });

  final String name;
  final String time;
  final String type;
  final String status;
  final int enrolled;
  final int cap;
  final int emphasis;
  final int visualSoftness;
  final bool isPriority;
  final bool forceClear;
  final bool hideLeftBar;
  final String memo;
  final String countText;
  final bool isManualMember;
  final Color primaryColor;
  final VoidCallback? onTap;

  String lessonShortLabel(String value) {
    switch (value.trim()) {
      case '레슨':
      case 'PT':
        return 'PT';
      case '그룹':
      case '그룹레슨':
        return '그룹';
      case '요가':
        return '요가';
      case '필라테스':
        return 'PL';
      case '재활':
        return '재활';
      case '상담':
        return '상담';
      default:
        return value.length <= 2 ? value : value.substring(0, 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool alreadyHasNim = name.trim().endsWith('님');
    final String displayName = alreadyHasNim ? name.trim() : '${name.trim()} 님';
    final String memoText = memo.trim();

    final bool isOngoing = emphasis == 3;
    final bool showPriorityStyle = isOngoing || isPriority;

    final bool showLeftLine = (isOngoing || emphasis > 0) && !hideLeftBar;

    final Color leftLineColor = showLeftLine
        ? primaryColor.withOpacity(isOngoing ? 1.0 : 0.82)
        : Colors.transparent;

    final double leftLineWidth = showLeftLine ? 4.0 : 0.0;

    final double cardOpacity = forceClear
        ? 1.0
        : isOngoing
        ? 1.0
        : showPriorityStyle
        ? 0.88
        : 0.65;

    final double iconOpacity = switch (emphasis) {
      3 => 0.20,
      2 => 0.16,
      1 => 0.12,
      _ => showPriorityStyle ? 0.12 : 0.08,
    };

    final Color badgeBg = switch (emphasis) {
      3 => const Color(0xFFD1FAE5),
      2 => primaryColor.withOpacity(0.18),
      1 => primaryColor.withOpacity(0.12),
      _ => const Color(0xFFDBEAFE),
    };

    final Color badgeText = switch (emphasis) {
      3 => const Color(0xFF047857),
      2 => primaryColor,
      1 => primaryColor,
      _ => const Color(0xFF1E40AF),
    };

    final Color cardColor = isOngoing
        ? primaryColor.withOpacity(0.08)
        : Colors.white;

    final Color outerBorderColor = showPriorityStyle
        ? primaryColor.withOpacity(isOngoing ? 0.48 : 0.38)
        : Colors.transparent;

    final double outerBorderWidth = showPriorityStyle ? 1.1 : 0.0;

    final double shadowOpacity = showPriorityStyle
        ? (isOngoing ? 0.14 : 0.11)
        : 0.035;

    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          opacity: cardOpacity,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: outerBorderColor,
            width: outerBorderWidth,
          ),
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(shadowOpacity),
              blurRadius: showPriorityStyle ? 12 : 5,
              spreadRadius: showPriorityStyle ? 0.2 : 0,
              offset: Offset(0, showPriorityStyle ? 5 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: leftLineWidth,
              height: 42,
              margin: EdgeInsets.only(right: showLeftLine ? 8 : 0),
              decoration: BoxDecoration(
                color: leftLineColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(iconOpacity),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                lessonShortLabel(type),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (countText.isNotEmpty)
                              Text(
                                countText,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                            if (isManualMember)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFFED7AA),
                                  ),
                                ),
                                child: const Text(
                                  '미등록',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEA580C),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      memoText.isEmpty ? '' : memoText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: badgeText,
                  fontSize: 11,
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