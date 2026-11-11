import 'package:flutter/material.dart';
import '../../widgets/mtf_back_button.dart';
import '../../widgets/mtf_header_neon_overlay.dart';

import '../../theme.dart';

/// 레슨계약서 화면에서만 쓰는 입력 칸 모양: 둥근 알약 대신 문서 양식처럼 각이 작은
/// 테두리와 배경 없는 칸을 쓴다.
ThemeData contractFormTheme(BuildContext context) {
  final base = Theme.of(context);
  final scheme = base.colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: false,
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
    ),
  );
}

/// 레슨계약서 화면 공통 머리말(뒤로 가기 + 제목).
class LessonContractHeader extends StatelessWidget {
  const LessonContractHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.backKey,
    this.trailing,
    this.bottom,
    this.neon = true,
  });

  final String title;
  final VoidCallback onBack;
  final Key? backKey;
  final Widget? trailing;

  /// 머리말 안쪽 제목 줄 아래에 붙는 영역(요약 카드 등). 있으면 머리말이 그만큼 늘어난다.
  final Widget? bottom;

  /// 회원리스트 머리말처럼 아랫가장자리에 형광선(네온 라인)을 그린다.
  final bool neon;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final radius = kMtfHeaderBottomRadius;
    final header = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 16),
      decoration: BoxDecoration(
        gradient: context.mtfHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
        // 회원리스트 머리말과 같은 아래쪽 그림자(형광선이 같은 배경 위에서 보이도록).
        boxShadow:
            neon
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
                : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                MtfBackButton(key: backKey, onTap: onBack),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
    if (!neon) return header;
    return MtfHeaderNeonOverlay(
      isExpanded: false,
      bottomRadius: radius,
      child: header,
    );
  }
}

/// 문서 양식의 한 항목: 굵은 제목 + 가는 선 + 내용을 각진 테두리 안에 담는다.
class LessonContractSectionCard extends StatelessWidget {
  const LessonContractSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outline),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// 제목 줄을 눌러 접고 펼 수 있는 카드. 처음에는 접혀 있다.
class LessonContractCollapsibleCard extends StatelessWidget {
  const LessonContractCollapsibleCard({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.toggleKey,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: toggleKey,
            borderRadius: BorderRadius.circular(6),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, thickness: 1, color: scheme.outline),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ],
      ),
    );
  }
}
