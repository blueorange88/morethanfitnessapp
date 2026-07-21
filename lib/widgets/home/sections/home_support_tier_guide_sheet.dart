import 'package:flutter/material.dart';

import '../../../aifc/core/aifc_avatar.dart';

class HomeSupportTierGuideSheet {
  const HomeSupportTierGuideSheet._();

  static Future<void> show({
    required BuildContext context,
    required String highlightTier,
    required Color primaryColor,
    required Color secondaryColor,
    required int litePrice,
    required int semiProPrice,
    required int proPrice,
    required String Function(int value) formatMonthlyPrice,
    required void Function(String supportTier) onSponsorTap,
  }) async {
    Widget buildTierCard({
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
          color:
              highlighted ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
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

    String normalizeSupportTier(String value) {
      final text = value.trim();

      if (text == 'lite' || text == 'amateur') {
        return 'amateur';
      }

      if (text == 'semiPro') {
        return 'semiPro';
      }

      if (text == 'pro') {
        return 'pro';
      }

      return 'amateur';
    }

    String supportCtaLabel(String tier) {
      switch (tier) {
        case 'semiPro':
          return '든든하게 응원하기';
        case 'pro':
          return 'Pro 응원하기';
        case 'amateur':
        default:
          return 'MORE NEXT STEP 응원하기';
      }
    }

    String supportPreparingText(String tier) {
      switch (tier) {
        case 'semiPro':
          return 'Semi-Pro 응원 결제 기능은 준비 중이에요. 지금은 어떤 기능을 더 든든하게 사용할 수 있는지 먼저 안내드릴게요.';
        case 'pro':
          return 'Pro 응원 결제 기능은 준비 중이에요. 이미 Pro 기능을 사용 중이어도, AI FC 개발을 선택후원으로 응원할 수 있게 준비하고 있어요.';
        case 'amateur':
        default:
          return 'Amateur 응원 결제 기능은 준비 중이에요. 지금은 어떤 기능으로 강사님께 도움을 줄 수 있는지 안내만 먼저 보여드릴게요.';
      }
    }

    final selectedSupportTier = normalizeSupportTier(highlightTier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.of(sheetContext).size.height * 0.86;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: maxSheetHeight,
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
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
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                            'MORE THAN의 다음 걸음을 응원해주실 수 있어요',
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
                    const Text(
                      '기능은 계속 넓혀가되, 강사님들이 부담 없이 사용할 수 있는 방향으로 운영하려고 해요.\n'
                      '도움이 되셨다면 선택후원으로 AI FC의 개발을 응원해주세요.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildTierCard(
                      tierName: 'MORE NEXT STEP',
                      subtitle: 'MORE THAN 의 다음 한걸음을 응원해주세요',
                      description:
                          '목표 D-DAY 설정과 기본 스마트 알림으로\n회원 관리의 첫 흐름을 열어볼 수 있어요.',
                      price: litePrice,
                      icon: Icons.directions_walk_rounded,
                      highlighted:
                          highlightTier == 'lite' || highlightTier == 'amateur',
                    ),
                    buildTierCard(
                      tierName: '든든하게 응원하기',
                      subtitle: '닭가슴살 하나 얹어, 관리도 더 든든하게 근손실도 막아주세요',
                      description:
                          'MORE 데이, 레슨계약서, 메달 관리처럼\n회원별 중요한 흐름을 더 든든하게 챙길 수 있어요.',
                      price: semiProPrice,
                      icon: Icons.fitness_center_rounded,
                      highlighted: highlightTier == 'semiPro',
                    ),
                    buildTierCard(
                      tierName: '프로는 프로답게',
                      subtitle: '커피 한 잔 값으로 고급 인사이트와 더 향상된 AI FC를 경험해보세요',
                      description:
                          'MORE 포커스, 회원권계약서, 자동 AI 관리 포인트로\n놓치기 쉬운 회원 흐름까지 챙길 수 있어요.',
                      price: proPrice,
                      icon: Icons.local_cafe_rounded,
                      highlighted: highlightTier == 'pro',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      supportPreparingText(selectedSupportTier),
                      style: const TextStyle(
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                              onSponsorTap(selectedSupportTier);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              supportCtaLabel(selectedSupportTier),
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
          ),
        );
      },
    );
  }
}
