import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../aifc/core/aifc_avatar.dart';
import '../services/app_tier_access_service.dart';

enum AifcTierFeatureGateAction {
  later,
  showTierGuide,
}

class AifcTierFeatureGateSheet {
  const AifcTierFeatureGateSheet._();

  static Future<AifcTierFeatureGateAction?> show({
    required BuildContext context,
    required AppTierAccessSnapshot access,
    required AppTierFeatureKey feature,
    Color primaryColor = const Color(0xFF4F46E5),
    Color secondaryColor = const Color(0xFF9333EA),
  }) {
    final info = AppTierAccessService.featureInfo(feature);

    return showModalBottomSheet<AifcTierFeatureGateAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AifcTierFeatureGateBody(
        access: access,
        info: info,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
    );
  }

  static Future<bool> guard({
    required BuildContext context,
    required AppTierAccessSnapshot? access,
    required AppTierFeatureKey feature,
    required Future<AppTierAccessSnapshot> Function() loadAccess,
    Future<void> Function(AppTierFeatureInfo info)? onShowTierGuide,
    String entryPoint = 'unknown',
    Color primaryColor = const Color(0xFF4F46E5),
    Color secondaryColor = const Color(0xFF9333EA),
  }) async {
    final resolvedAccess = access ?? await loadAccess();

    if (AppTierAccessService.canUseFeature(resolvedAccess, feature)) {
      if (kDebugMode) {
        final info = AppTierAccessService.featureInfo(feature);
        debugPrint(
          '[MTF_TIER_GATE] feature=${feature.name} '
          'currentTier=${resolvedAccess.tierLabel} '
          'requiredTier=${info.requiredTierLabel} result=allow '
          'entryPoint=$entryPoint',
        );
      }
      return true;
    }

    if (kDebugMode) {
      final info = AppTierAccessService.featureInfo(feature);
      debugPrint(
        '[MTF_TIER_GATE] feature=${feature.name} '
        'currentTier=${resolvedAccess.tierLabel} '
        'requiredTier=${info.requiredTierLabel} result=block '
        'entryPoint=$entryPoint',
      );
    }

    if (!context.mounted) return false;

    final action = await show(
      context: context,
      access: resolvedAccess,
      feature: feature,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
    );

    if (!context.mounted) return false;

    if (action == AifcTierFeatureGateAction.showTierGuide &&
        onShowTierGuide != null) {
      await onShowTierGuide(AppTierAccessService.featureInfo(feature));
    }

    return false;
  }
}

class _AifcTierFeatureGateBody extends StatelessWidget {
  const _AifcTierFeatureGateBody({
    required this.access,
    required this.info,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final AppTierAccessSnapshot access;
  final AppTierFeatureInfo info;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final currentTier = access.tierLabel;
    final requiredTier = info.requiredTierLabel;
    final requiredItems =
        AppTierAccessService.tierFeatureSummaryItems(info.requiredRank);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F4FF),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FcMessageBubble(
                        text: '${info.title}은 $requiredTier부터 사용할 수 있어요.\n'
                            '현재 등급은 $currentTier예요.',
                      ),
                      const SizedBox(height: 12),
                      _FeatureLockCard(
                        info: info,
                        currentTier: currentTier,
                        requiredTier: requiredTier,
                        primaryColor: primaryColor,
                        secondaryColor: secondaryColor,
                      ),
                      const SizedBox(height: 12),
                      _TierBenefitCard(
                        tierName: requiredTier,
                        items: requiredItems,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pop(AifcTierFeatureGateAction.later);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(
                            color: Color(0xFFE0DEFF),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          '닫기',
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
                          HapticFeedback.mediumImpact();
                          Navigator.of(context)
                              .pop(AifcTierFeatureGateAction.showTierGuide);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          '등급 안내 보기',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FcMessageBubble extends StatelessWidget {
  const _FcMessageBubble({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AifcAvatar(
          size: 36,
          isAnimating: true,
          backgroundColor: Colors.white,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: const Color(0xFFE0DEFF),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E1B4B),
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureLockCard extends StatelessWidget {
  const _FeatureLockCard({
    required this.info,
    required this.currentTier,
    required this.requiredTier,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final AppTierFeatureInfo info;
  final String currentTier;
  final String requiredTier;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0DEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      secondaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$currentTier → $requiredTier',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            info.description,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12.2,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBenefitCard extends StatelessWidget {
  const _TierBenefitCard({
    required this.tierName,
    required this.items,
    required this.primaryColor,
  });

  final String tierName;
  final List<String> items;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$tierName에서 열리는 기능',
            style: TextStyle(
              color: primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF312E81),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
