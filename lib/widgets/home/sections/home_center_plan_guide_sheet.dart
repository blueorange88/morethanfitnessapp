import 'package:flutter/material.dart';

import '../../../aifc/core/aifc_avatar.dart';

class HomeCenterPlanGuideSheet {
  const HomeCenterPlanGuideSheet._();

  static Future<void> show({
    required BuildContext context,
    required String highlightTier,
    required Color primaryColor,
    required Color secondaryColor,
    required int masterPrice,
    required int grandPrixPrice,
    required String Function(int value) formatMonthlyPrice,
    required void Function(String centerTier) onCenterPlanTap,
  }) async {
    String normalizeCenterTier(String value) {
      final text = value.trim();

      if (text == 'grandPrix' || text == 'Grand Prix') {
        return 'grandPrix';
      }

      return 'master';
    }

    String ctaLabel(String tier) {
      switch (tier) {
        case 'grandPrix':
          return 'Grand Prix 플랜 문의하기';
        case 'master':
        default:
          return 'Master 플랜 문의하기';
      }
    }

    String guideText(String tier) {
      switch (tier) {
        case 'grandPrix':
          return 'Grand Prix는 여러 지점이나 브랜드 단위로 회원, 강사, 운영 흐름을 함께 관리하는 최상위 조직 플랜이에요.';
        case 'master':
        default:
          return 'Master는 센터나 팀 단위로 회원 관리, 강사 관리, 운영 통계를 함께 보고 싶은 경우에 맞는 플랜이에요.';
      }
    }

    final selectedCenterTier = normalizeCenterTier(highlightTier);

    Widget buildCenterPlanCard({
      required String tierName,
      required String subtitle,
      required String description,
      required int price,
      required IconData icon,
      required bool highlighted,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFFEEF2FF)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? primaryColor : const Color(0xFFE5E7EB),
            width: highlighted ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: highlighted
                    ? LinearGradient(
                  colors: [
                    primaryColor,
                    secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: highlighted ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: highlighted
                    ? null
                    : Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: Icon(
                icon,
                color: highlighted ? Colors.white : primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tierName,
                        style: TextStyle(
                          color: highlighted
                              ? primaryColor
                              : const Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (highlighted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '추천',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11.2,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '월 ${formatMonthlyPrice(price)}',
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AifcAvatar(
                        size: 42,
                        isAnimating: true,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '센터 단위 운영은 별도 플랜으로 관리해요',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    guideText(selectedCenterTier),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  buildCenterPlanCard(
                    tierName: 'Master',
                    subtitle: '센터 / 팀 단위 운영 관리',
                    description: '소속 강사, 회원 현황, 센터 운영 통계를 함께 관리하는 플랜이에요.',
                    price: masterPrice,
                    icon: Icons.storefront_rounded,
                    highlighted: selectedCenterTier == 'master',
                  ),
                  buildCenterPlanCard(
                    tierName: 'Grand Prix',
                    subtitle: '여러 지점 / 브랜드 단위 관리',
                    description: '여러 센터나 지점의 운영 흐름을 한눈에 보고 관리하는 최상위 플랜이에요.',
                    price: grandPrixPrice,
                    icon: Icons.account_tree_rounded,
                    highlighted: selectedCenterTier == 'grandPrix',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '센터 플랜 결제와 지점 연결 기능은 준비 중이에요. 지금은 운영 구조와 플랜 방향만 먼저 안내드릴게요.',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10.8,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B7280),
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            '나중에',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            onCenterPlanTap(selectedCenterTier);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            ctaLabel(selectedCenterTier),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
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