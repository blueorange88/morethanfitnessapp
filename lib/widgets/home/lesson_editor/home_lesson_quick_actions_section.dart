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
    this.isPersistedSchedule = true,
    this.canUseLessonContract = false,
    this.canUseMembershipManage = false,
    this.onOpenLessonContract,
    this.onOpenMembershipManage,
    this.onOpenLessonContractFromUnregistered,
    this.onOpenMembershipContractFromUnregistered,
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
  final bool isPersistedSchedule;

  final bool canUseLessonContract;
  final bool canUseMembershipManage;

  final Future<void> Function()? onOpenLessonContract;
  final Future<void> Function()? onOpenMembershipManage;
  final Future<void> Function()? onOpenLessonContractFromUnregistered;
  final Future<void> Function()? onOpenMembershipContractFromUnregistered;

  @override
  Widget build(BuildContext context) {
    if (!isPersistedSchedule) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanMemberId = (memberId ?? '').trim();

    final bool hasUsableLinkedMember =
        hasLinkedMember && !linkedMemberDeleted && cleanMemberId.isNotEmpty;

    final canUseLinkedMemberActions = hasUsableLinkedMember;
    final canUseConfirmActions =
        isPersistedSchedule && hasUsableLinkedMember && !isConfirmedLesson;

    final linkedMemberDisabledMessage =
        isConfirmedLesson ? '이미 확정된 레슨이에요.' : '기존 회원 연결 후 사용할 수 있어요.';

    Widget buildQuickAction({
      Key? actionKey,
      required String label,
      required IconData icon,
      required Future<void> Function() onTap,
      bool enabled = true,
      String disabledMessage = '이미 확정했습니다',
      Color? foregroundColor,
      Future<void> Function()? onDisabledTap,
      bool isContractTask = false,
    }) {
      final color = isContractTask
          ? (isDark ? const Color(0xFFFFF4CF) : const Color(0xFF0B1E32))
          : enabled
              ? (foregroundColor ?? colors.primary)
              : colors.onSurfaceVariant;
      final iconColor = isContractTask
          ? (isDark ? const Color(0xFFEFCB62) : const Color(0xFF9A6810))
          : color;
      final backgroundColor = isContractTask
          ? (isDark ? const Color(0xFF4A401F) : const Color(0xFFFFF1C2))
          : enabled
              ? colors.surface
              : colors.surfaceContainerHigh;
      final borderColor = isContractTask
          ? const Color(0xFFEFCB62)
          : enabled
              ? color.withValues(alpha: 0.18)
              : colors.outline;

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
          key: actionKey,
          height: 36,
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );

      return button;
    }

    Widget buildMemberCardAction() {
      return buildQuickAction(
        actionKey: const Key('aifc_member_card_action'),
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
        actionKey: const Key('aifc_lesson_contract_action'),
        label: '레슨계약서',
        icon: Icons.description_outlined,
        isContractTask: true,
        enabled: canUseLinkedMemberActions && hasCallback,
        disabledMessage: canUseLinkedMemberActions
            ? '레슨계약서를 열 수 없어요.'
            : linkedMemberDisabledMessage,
        onTap: onOpenLessonContract ?? () async {},
      );
    }

    Widget buildMembershipManageAction() {
      final hasCallback = onOpenMembershipManage != null;

      return buildQuickAction(
        actionKey: const Key('aifc_membership_contract_action'),
        label: '회원권계약서',
        icon: Icons.card_membership_rounded,
        isContractTask: true,
        enabled: canUseLinkedMemberActions && hasCallback,
        disabledMessage: canUseLinkedMemberActions
            ? '회원권계약서를 열 수 없어요.'
            : linkedMemberDisabledMessage,
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
            actionKey: const Key('aifc_link_existing_member_action'),
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
            actionKey: const Key('aifc_register_member_action'),
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
              actionKey: const Key('aifc_lesson_contract_action'),
              label: '레슨계약서',
              icon: Icons.description_outlined,
              isContractTask: true,
              onTap: onOpenLessonContractFromUnregistered!,
            ),
          if (onOpenMembershipContractFromUnregistered != null)
            buildQuickAction(
              actionKey: const Key('aifc_membership_contract_action'),
              label: '회원권계약서',
              icon: Icons.assignment_outlined,
              isContractTask: true,
              onTap: onOpenMembershipContractFromUnregistered!,
            ),
        ],
      );
    }

    Widget buildLinkedActions({
      required bool hasContract,
    }) {
      final cancelBlockedByProtectedRecord = isCustomerSignedConfirmedLesson ||
          isContractLinkedConfirmedLesson ||
          hasContract;

      final cancelDisabledMessage = isCustomerSignedConfirmedLesson
          ? '회원 서명이 포함된 레슨확정은 임의로 확정취소할 수 없어요.'
          : '계약서와 연결된 레슨확정은 홈에서 임의로 취소할 수 없어요.';

      return Wrap(
        spacing: 5,
        runSpacing: 7,
        children: [
          if (isPersistedSchedule)
            buildLessonConfirmAction(hasContract: hasContract),
          if (isPersistedSchedule && isConfirmedLesson)
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
          if (isPersistedSchedule && hasContract && !isConfirmedLesson)
            buildSignRequestAction(),
          if (isPersistedSchedule) buildWorkoutLogAction(),
          buildMemberCardAction(),
          if (onOpenLessonContract != null) buildLessonContractAction(),
          if (onOpenMembershipManage != null) buildMembershipManageAction(),
        ],
      );
    }

    return Column(
      key: const Key('aifc_quick_actions_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AIFC 추천업무',
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
