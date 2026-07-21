import 'package:flutter/material.dart';

class HomeLessonQuickActionsSection extends StatelessWidget {
  const HomeLessonQuickActionsSection({
    super.key,
    required this.hasLinkedMember,
    required this.memberName,
    required this.memberId,
    required this.linkedMemberDeleted,
    required this.isConfirmedLesson,
    required this.isCustomerSignedConfirmedLesson,
    required this.isContractLinkedConfirmedLesson,
    required this.loadHasContract,
    required this.onShowToast,
    required this.onOpenMemberCard,
    required this.onOpenWorkoutLog,
    required this.onOpenLessonConfirm,
    required this.onOpenSignRequest,
    required this.onLinkExistingMember,
    required this.onRegisterManualMember,
    required this.onCancelConfirmedLesson,
    this.canUseLessonContract = false,
    this.canUseMembershipManage = false,
    this.lessonContractLockedMessage = '레슨계약서는 Semi-Pro부터 사용할 수 있어요.',
    this.membershipManageLockedMessage = '회원권 관리는 Pro부터 사용할 수 있어요.',
    this.onOpenLessonContract,
    this.onOpenMembershipManage,
    this.onOpenLessonContractFromUnregistered,
    this.onOpenMembershipContractFromUnregistered,
    this.onOpenTierLockedFeature,
  });

  final bool hasLinkedMember;
  final String memberName;
  final String? memberId;
  final bool linkedMemberDeleted;
  final bool isConfirmedLesson;
  final bool isCustomerSignedConfirmedLesson;
  final bool isContractLinkedConfirmedLesson;

  final Future<bool> Function(String memberId) loadHasContract;
  final void Function(String message) onShowToast;

  final Future<void> Function() onOpenMemberCard;
  final Future<void> Function() onOpenWorkoutLog;
  final Future<void> Function() onOpenLessonConfirm;
  final Future<void> Function() onOpenSignRequest;
  final Future<void> Function() onLinkExistingMember;
  final Future<void> Function() onRegisterManualMember;
  final Future<void> Function() onCancelConfirmedLesson;

  final bool canUseLessonContract;
  final bool canUseMembershipManage;

  final String lessonContractLockedMessage;
  final String membershipManageLockedMessage;

  final Future<void> Function()? onOpenLessonContract;
  final Future<void> Function()? onOpenMembershipManage;
  final Future<void> Function()? onOpenLessonContractFromUnregistered;
  final Future<void> Function()? onOpenMembershipContractFromUnregistered;
  final Future<void> Function(String message)? onOpenTierLockedFeature;

  @override
  Widget build(BuildContext context) {
    final cleanMemberId = (memberId ?? '').trim();

    final bool hasUsableLinkedMember =
        hasLinkedMember && !linkedMemberDeleted && cleanMemberId.isNotEmpty;

    final canUseLinkedMemberActions = hasUsableLinkedMember;
    final canUseConfirmActions = hasUsableLinkedMember && !isConfirmedLesson;

    final linkedMemberDisabledMessage = isConfirmedLesson
        ? '이미 확정된 레슨이에요.'
        : '기존 회원 연결 후 사용할 수 있어요.';

    Widget buildQuickAction({
      required String label,
      required IconData icon,
      required Future<void> Function() onTap,
      bool enabled = true,
      String disabledMessage = '이미 확정했습니다',
      Color? foregroundColor,
      Future<void> Function()? onDisabledTap,
      bool isRecommended = false,
    }) {
      final color = enabled
          ? (foregroundColor ?? const Color(0xFF4F46E5))
          : const Color(0xFF9CA3AF);

      final button = InkWell(
        onTap: enabled
            ? () {
          onTap();
        }
            : () {
          if (onDisabledTap != null) {
            onDisabledTap();
            return;
          }

          onShowToast(disabledMessage);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? color.withOpacity(isRecommended ? 0.34 : 0.18)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: enabled && isRecommended
                ? [
              BoxShadow(
                color: color.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                  isRecommended ? FontWeight.w800 : FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _RecommendedActionWash(
          enabled: enabled && isRecommended,
          color: color,
          child: button,
        ),
      );
    }

    Widget buildMemberCardAction() {
      return buildQuickAction(
        label: '회원카드',
        icon: Icons.person_outline,
        enabled: canUseLinkedMemberActions,
        disabledMessage: linkedMemberDisabledMessage,
        onTap: onOpenMemberCard,
      );
    }

    Widget buildWorkoutLogAction() {
      return buildQuickAction(
        label: '레슨일지',
        icon: Icons.menu_book_outlined,
        enabled: canUseLinkedMemberActions,
        disabledMessage: linkedMemberDisabledMessage,
        onTap: onOpenWorkoutLog,
      );
    }

    Widget buildLessonConfirmAction({
      required bool hasContract,
    }) {
      if (isConfirmedLesson) {
        return buildQuickAction(
          label: '확정완료',
          icon: Icons.lock_outline_rounded,
          foregroundColor: const Color(0xFF059669),
          enabled: false,
          disabledMessage: '이미 확정된 레슨이에요.',
          onTap: () async {},
        );
      }

      if (hasContract) {
        return buildQuickAction(
          label: '빠른 서명',
          icon: Icons.draw_rounded,
          foregroundColor: const Color(0xFF059669),
          enabled: canUseConfirmActions,
          disabledMessage: linkedMemberDisabledMessage,
          onTap: onOpenLessonConfirm,
        );
      }

      return buildQuickAction(
        label: '레슨확정',
        icon: Icons.check_circle_outline_rounded,
        foregroundColor: const Color(0xFF059669),
        enabled: canUseConfirmActions,
        disabledMessage: linkedMemberDisabledMessage,
        onTap: onOpenLessonConfirm,
      );
    }

    Widget buildLessonContractAction() {
      final hasCallback = onOpenLessonContract != null;

      return buildQuickAction(
        label: '레슨계약서',
        icon: Icons.description_outlined,
        foregroundColor: const Color(0xFF7C3AED),
        isRecommended: true,
        enabled: canUseLinkedMemberActions && canUseLessonContract && hasCallback,
        disabledMessage: canUseLinkedMemberActions
            ? lessonContractLockedMessage
            : linkedMemberDisabledMessage,
        onDisabledTap: canUseLinkedMemberActions && !canUseLessonContract
            ? () async {
          if (onOpenTierLockedFeature != null) {
            await onOpenTierLockedFeature!(lessonContractLockedMessage);
            return;
          }

          onShowToast(lessonContractLockedMessage);
        }
            : null,
        onTap: onOpenLessonContract ?? () async {},
      );
    }

    Widget buildMembershipManageAction() {
      final hasCallback = onOpenMembershipManage != null;

      return buildQuickAction(
        label: '회원권 관리',
        icon: Icons.card_membership_rounded,
        foregroundColor: const Color(0xFF9333EA),
        isRecommended: true,
        enabled:
        canUseLinkedMemberActions && canUseMembershipManage && hasCallback,
        disabledMessage: canUseLinkedMemberActions
            ? membershipManageLockedMessage
            : linkedMemberDisabledMessage,
        onDisabledTap: canUseLinkedMemberActions && !canUseMembershipManage
            ? () async {
          if (onOpenTierLockedFeature != null) {
            await onOpenTierLockedFeature!(membershipManageLockedMessage);
            return;
          }

          onShowToast(membershipManageLockedMessage);
        }
            : null,
        onTap: onOpenMembershipManage ?? () async {},
      );
    }

    Widget buildSignRequestAction() {
      return buildQuickAction(
        label: '서명 요청',
        icon: Icons.qr_code_2_rounded,
        foregroundColor: const Color(0xFF2563EB),
        enabled: canUseConfirmActions,
        disabledMessage: linkedMemberDisabledMessage,
        onTap: onOpenSignRequest,
      );
    }

    Widget buildUnlinkedActions() {
      return Wrap(
        spacing: 5,
        runSpacing: 7,
        children: [
          buildQuickAction(
            label: '기존 회원 연결',
            icon: Icons.link_rounded,
            foregroundColor: const Color(0xFF4F46E5),
            onTap: () async {
              final cleanName = memberName.trim();

              if (cleanName.isEmpty) {
                onShowToast('회원 이름을 먼저 입력해주세요.');
                return;
              }

              await onLinkExistingMember();
            },
          ),
          buildQuickAction(
            label: '내 회원으로 등록',
            icon: Icons.person_add_alt_1_rounded,
            foregroundColor: const Color(0xFFEA580C),
            onTap: () async {
              final cleanName = memberName.trim();

              if (cleanName.isEmpty) {
                onShowToast('회원 이름을 먼저 입력해주세요.');
                return;
              }

              await onRegisterManualMember();
            },
          ),
          if (onOpenLessonContractFromUnregistered != null)
            buildQuickAction(
              label: '레슨계약서',
              icon: Icons.description_outlined,
              foregroundColor: const Color(0xFF7C3AED),
              isRecommended: true,
              onTap: onOpenLessonContractFromUnregistered!,
            ),
          if (onOpenMembershipContractFromUnregistered != null)
            buildQuickAction(
              label: '회원권계약서',
              icon: Icons.assignment_outlined,
              foregroundColor: const Color(0xFF9333EA),
              isRecommended: true,
              onTap: onOpenMembershipContractFromUnregistered!,
            ),
        ],
      );
    }

    Widget buildLinkedActions({
      required bool hasContract,
    }) {
      final cancelBlockedByProtectedRecord =
          isCustomerSignedConfirmedLesson ||
              isContractLinkedConfirmedLesson ||
              hasContract;

      final cancelDisabledMessage = isCustomerSignedConfirmedLesson
          ? '회원 서명이 포함된 레슨확정은 임의로 확정취소할 수 없어요.'
          : '계약서와 연결된 레슨확정은 홈에서 임의로 취소할 수 없어요.';

      return Wrap(
        spacing: 5,
        runSpacing: 7,
        children: [
          buildLessonConfirmAction(hasContract: hasContract),
          if (isConfirmedLesson)
            buildQuickAction(
              label: '확정취소',
              icon: cancelBlockedByProtectedRecord
                  ? Icons.block_rounded
                  : Icons.lock_open_rounded,
              foregroundColor: const Color(0xFFDC2626),
              enabled: !cancelBlockedByProtectedRecord,
              disabledMessage: cancelDisabledMessage,
              onTap: onCancelConfirmedLesson,
            ),
          if (hasContract && !isConfirmedLesson) buildSignRequestAction(),
          buildWorkoutLogAction(),
          buildMemberCardAction(),
          if (onOpenLessonContract != null) buildLessonContractAction(),
          if (onOpenMembershipManage != null) buildMembershipManageAction(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI FC 추천 업무',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        if (!hasUsableLinkedMember)
          buildUnlinkedActions()
        else
          FutureBuilder<bool>(
            future: loadHasContract(cleanMemberId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Wrap(
                  spacing: 5,
                  runSpacing: 7,
                  children: [
                    buildQuickAction(
                      label: '확인중',
                      icon: Icons.hourglass_empty_rounded,
                      enabled: false,
                      disabledMessage: '회원 정보를 확인하고 있어요.',
                      onTap: () async {},
                    ),
                    buildMemberCardAction(),
                    buildWorkoutLogAction(),
                  ],
                );
              }

              final hasContract = snapshot.data == true;

              return buildLinkedActions(
                hasContract: hasContract,
              );
            },
          ),
      ],
    );
  }
}

class _RecommendedActionWash extends StatefulWidget {
  const _RecommendedActionWash({
    required this.enabled,
    required this.color,
    required this.child,
  });

  final bool enabled;
  final Color color;
  final Widget child;

  @override
  State<_RecommendedActionWash> createState() => _RecommendedActionWashState();
}

class _RecommendedActionWashState extends State<_RecommendedActionWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );

    _opacity = Tween<double>(
      begin: 0.00,
      end: 0.16,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _RecommendedActionWash oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.enabled == oldWidget.enabled) return;

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        widget.color.withOpacity(_opacity.value),
                        widget.color.withOpacity(_opacity.value * 0.45),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}