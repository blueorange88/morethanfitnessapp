import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class HomeBottomNavBar extends StatelessWidget {
  const HomeBottomNavBar({
    super.key,
    required this.activeIndex,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onChanged,
    required this.onCenterTap,
  });

  final int activeIndex;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<int> onChanged;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return SizedBox(
      height: 100 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _HomeBottomNavNotchPainter(
                backgroundColor: tokens.navigationSheetBackground,
                shadowColor: scheme.shadow,
              ),
              child: Container(
                height: 74 + bottomInset,
                padding: EdgeInsets.fromLTRB(12, 14, 12, 10 + bottomInset),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _HomeNavItem(
                              icon: Icons.bar_chart_outlined,
                              label: '인사이트',
                              index: 0,
                              activeIndex: activeIndex,
                              primaryColor: primaryColor,
                              inactiveColor: scheme.onSurfaceVariant,
                              onTap: () => onChanged(0),
                            ),
                          ),
                          Expanded(
                            child: _HomeNavItem(
                              icon: Icons.description_outlined,
                              label: '신규 계약',
                              index: 1,
                              activeIndex: activeIndex,
                              primaryColor: primaryColor,
                              inactiveColor: scheme.onSurfaceVariant,
                              onTap: () => onChanged(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 74),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _HomeNavItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: '상담',
                              index: 2,
                              activeIndex: activeIndex,
                              primaryColor: primaryColor,
                              inactiveColor: scheme.onSurfaceVariant,
                              onTap: () => onChanged(2),
                            ),
                          ),
                          Expanded(
                            child: _HomeNavItem(
                              icon: Icons.credit_card_outlined,
                              label: '고객리스트',
                              index: 3,
                              activeIndex: activeIndex,
                              primaryColor: primaryColor,
                              inactiveColor: scheme.onSurfaceVariant,
                              onTap: () => onChanged(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onCenterTap,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          secondaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_add_alt_1,
                        color: scheme.onSecondary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '빠른 등록',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
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

class _HomeBottomNavNotchPainter extends CustomPainter {
  const _HomeBottomNavNotchPainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  final Color backgroundColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double topRadius = 28;
    const double notchRadius = 38;
    const double notchDepth = 31;

    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, topRadius)
      ..quadraticBezierTo(0, 0, topRadius, 0)
      ..lineTo(size.width / 2 - notchRadius - 18, 0)
      ..cubicTo(
        size.width / 2 - notchRadius + 4,
        0,
        size.width / 2 - notchRadius + 2,
        notchDepth,
        size.width / 2,
        notchDepth,
      )
      ..cubicTo(
        size.width / 2 + notchRadius - 2,
        notchDepth,
        size.width / 2 + notchRadius - 4,
        0,
        size.width / 2 + notchRadius + 18,
        0,
      )
      ..lineTo(size.width - topRadius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, topRadius)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawShadow(path, shadowColor.withOpacity(0.10), 14, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeBottomNavNotchPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.activeIndex,
    required this.primaryColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int activeIndex;
  final Color primaryColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == activeIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? primaryColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? primaryColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
