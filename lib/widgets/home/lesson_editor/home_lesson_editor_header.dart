import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class HomeLessonEditorHeader extends StatelessWidget {
  const HomeLessonEditorHeader({
    super.key,
    required this.day,
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.endTimeIsEmpty,
    required this.onClose,
    required this.onTimeTap,
    this.onEndTimeTap,
  });

  final String day;
  final String startTimeLabel;
  final String endTimeLabel;
  final bool endTimeIsEmpty;
  final VoidCallback onClose;
  final VoidCallback onTimeTap;
  final VoidCallback? onEndTimeTap;

  @override
  Widget build(BuildContext context) {
    // 라이트 모드는 다른 화면 헤더와 같은 앱 메인 네이비 그라데이션에 흰 글씨,
    // 다크 모드는 저장 버튼과 같은 색(테마의 secondary)에 그 위에 쓰는 색(onSecondary) 글씨를 쓴다.
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = scheme.secondary;
    final fg = isDark ? scheme.onSecondary : Colors.white;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [
                    Color.lerp(base, Colors.white, 0.10)!,
                    base,
                    Color.lerp(base, Colors.black, 0.10)!,
                  ]
                  : [
                    AppColors.lightGradientStart,
                    Color.lerp(
                      AppColors.lightGradientStart,
                      AppColors.lightGradientEnd,
                      0.5,
                    )!,
                    AppColors.lightGradientEnd,
                  ],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 30,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x2BFFFFFF), Colors.transparent],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Divider(height: 1, color: fg.withValues(alpha: 0.18)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 13, 24, 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: fg.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$day요일',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: fg,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: onTimeTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 3,
                            ),
                            child: Text(
                              startTimeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: fg,
                                letterSpacing: -0.2,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '—',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: fg.withValues(alpha: 0.50),
                            height: 1.0,
                          ),
                        ),
                      ),
                      Flexible(
                        child: GestureDetector(
                          onTap: onEndTimeTap ?? onTimeTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 3,
                            ),
                            child: Text(
                              endTimeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color:
                                    endTimeIsEmpty
                                        ? fg.withValues(alpha: 0.40)
                                        : fg.withValues(alpha: 0.80),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClose,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close_rounded,
                      size: 24,
                      color: fg.withValues(alpha: 0.72),
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
