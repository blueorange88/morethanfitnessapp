import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';

class AifcCareMilestoneSheetItem {
  const AifcCareMilestoneSheetItem({
    required this.id,
    required this.title,
    required this.badge,
    required this.isAuto,
    required this.isManual,
    required this.isDone,
    this.canComplete = false,
    this.canDelete = false,
  });

  final String id;
  final String title;
  final String badge;
  final bool isAuto;
  final bool isManual;
  final bool isDone;
  final bool canComplete;
  final bool canDelete;
}

class AifcCareMilestoneChatSheet extends StatefulWidget {
  const AifcCareMilestoneChatSheet({
    super.key,
    required this.memberName,
    required this.nickname,
    required this.autoItems,
    required this.activeItems,
    required this.doneItems,
    required this.onComplete,
    required this.onDelete,
  });

  final String memberName;
  final String nickname;
  final List<String> autoItems;
  final List<AifcCareMilestoneSheetItem> activeItems;
  final List<AifcCareMilestoneSheetItem> doneItems;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(String id) onDelete;

  static Future<void> show({
    required BuildContext context,
    required String memberName,
    required String nickname,
    required List<String> autoItems,
    required List<AifcCareMilestoneSheetItem> activeItems,
    required List<AifcCareMilestoneSheetItem> doneItems,
    required Future<void> Function(String id) onComplete,
    required Future<void> Function(String id) onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcCareMilestoneChatSheet(
        memberName: memberName,
        nickname: nickname,
        autoItems: autoItems,
        activeItems: activeItems,
        doneItems: doneItems,
        onComplete: onComplete,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<AifcCareMilestoneChatSheet> createState() =>
      _AifcCareMilestoneChatSheetState();
}

class _AifcCareMilestoneChatSheetState
    extends State<AifcCareMilestoneChatSheet>
    with TickerProviderStateMixin,
        AifcChatFlowMixin<AifcCareMilestoneChatSheet> {
  static const _groupInitial = 'care_milestone_initial';
  static const _groupAction = 'care_milestone_action';

  String get _safeMemberName {
    final value = widget.memberName.trim();
    return value.isEmpty ? '회원' : value;
  }

  String get _coachLabel {
    return aifcNicknameLabel(widget.nickname);
  }

  @override
  void initState() {
    super.initState();

    aifcSetActiveGroup(_groupInitial);

    aifcAddFcMessage(
      text: '$_coachLabel, $_safeMemberName 님의 MORE 포커스를 정리해볼게요.\n'
          '자동으로 잡힌 포인트와 직접 추가한 관리 포인트를 함께 볼 수 있어요.',
      groupKey: _groupInitial,
      child: _CareMilestoneOverviewBlock(
        autoItems: widget.autoItems,
        activeItems: widget.activeItems,
        doneItems: widget.doneItems,
        onComplete: _handleComplete,
        onDelete: _handleDelete,
      ),
    );
  }

  Future<void> _handleComplete(AifcCareMilestoneSheetItem item) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '${item.title} 완료로 기록할게요',
      groupKey: _groupAction,
      action: () async {
        await widget.onComplete(item.id);
      },
      successText: '${item.title} 항목을 완료로 기록했어요.',
      errorText: 'MORE 포커스를 완료 처리하지 못했어요.\n다시 시도해주세요.',
      closeAfterReply: true,
    );
  }

  Future<void> _handleDelete(AifcCareMilestoneSheetItem item) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: '${item.title} 삭제할게요',
      fcText: '정말 삭제할까요?\n회원 관리 체크포인트에서 사라져요.',
      groupKey: _groupAction,
      fcChild: _CareMilestoneDeleteConfirmBlock(
        item: item,
        onCancel: _handleCancelDelete,
        onConfirm: () => _handleDeleteConfirmed(item),
      ),
    );
  }

  Future<void> _handleCancelDelete() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    await aifcUserThenFc(
      userText: '삭제하지 않을게요',
      fcText: '좋아요. MORE 포커스는 그대로 둘게요.',
      groupKey: _groupAction,
    );

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleDeleteConfirmed(AifcCareMilestoneSheetItem item) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '삭제 확인',
      groupKey: _groupAction,
      action: () async {
        await widget.onDelete(item.id);
      },
      successText: '${item.title} 항목을 삭제했어요.',
      errorText: 'MORE 포커스를 삭제하지 못했어요.\n다시 시도해주세요.',
      closeAfterReply: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.82,
      children: [
        Flexible(
          child: SingleChildScrollView(
            controller: aifcScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < aifcMessages.length; i++)
                  AifcAnimatedChatMessage(
                    controller: aifcMessageAnimations[i],
                    dimmed: aifcMessages[i].groupKey != null &&
                        aifcActiveGroupKey != null &&
                        aifcMessages[i].groupKey != aifcActiveGroupKey,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AifcChatBubble(
                        side: aifcMessages[i].side,
                        text: aifcMessages[i].text,
                        child: aifcMessages[i].child,
                      ),
                    ),
                  ),
                if (aifcShowTyping)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AifcTypingBubble(),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (aifcIsBusy)
          const SizedBox(height: 16)
        else
          SafeArea(
            top: false,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    '닫기',
                    style: TextStyle(
                      color: AifcColors.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CareMilestoneOverviewBlock extends StatelessWidget {
  const _CareMilestoneOverviewBlock({
    required this.autoItems,
    required this.activeItems,
    required this.doneItems,
    required this.onComplete,
    required this.onDelete,
  });

  final List<String> autoItems;
  final List<AifcCareMilestoneSheetItem> activeItems;
  final List<AifcCareMilestoneSheetItem> doneItems;
  final ValueChanged<AifcCareMilestoneSheetItem> onComplete;
  final ValueChanged<AifcCareMilestoneSheetItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final hasAny =
        autoItems.isNotEmpty || activeItems.isNotEmpty || doneItems.isNotEmpty;

    if (!hasAny) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: AifcColors.cardSoftBg,
          borderRadius: BorderRadius.circular(AifcRadius.button),
          border: Border.all(color: AifcColors.cardBorder),
        ),
        child: const Text(
          '아직 표시할 MORE 포커스가 없어요.\n'
              '잔여 회차, 재등록, 목표 이후 케어 같은 포인트가 생기면 여기에 표시돼요.',
          style: TextStyle(
            color: AifcColors.textMuted,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (autoItems.isNotEmpty) ...[
          const _CareSectionTitle('자동 MORE 포커스'),
          ...autoItems.map((title) {
            return _CareMilestoneTile(
              title: title,
              badge: '자동 계산',
              icon: Icons.auto_awesome_rounded,
              color: AifcColors.primary,
            );
          }),
        ],
        const _CareSectionTitle('진행 중'),
        if (activeItems.isEmpty)
          const _CareEmptyText('진행 중인 MORE 포커스가 없어요.')
        else
          ...activeItems.map((item) {
            final color = item.isManual
                ? const Color(0xFF059669)
                : AifcColors.primary;

            return _CareMilestoneTile(
              title: item.title,
              badge: item.badge,
              icon: item.isManual
                  ? Icons.edit_note_rounded
                  : Icons.auto_awesome_rounded,
              color: color,
              onComplete: item.canComplete ? () => onComplete(item) : null,
              onDelete: item.canDelete ? () => onDelete(item) : null,
            );
          }),
        if (doneItems.isNotEmpty) ...[
          const _CareSectionTitle('완료됨'),
          ...doneItems.map((item) {
            return _CareMilestoneTile(
              title: item.title,
              badge: item.badge,
              icon: Icons.check_circle_rounded,
              color: AifcColors.textMuted,
            );
          }),
        ],
      ],
    );
  }
}

class _CareSectionTitle extends StatelessWidget {
  const _CareSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AifcColors.fcText,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CareEmptyText extends StatelessWidget {
  const _CareEmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AifcColors.textMuted,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CareMilestoneTile extends StatelessWidget {
  const _CareMilestoneTile({
    required this.title,
    required this.badge,
    required this.icon,
    required this.color,
    this.onComplete,
    this.onDelete,
  });

  final String title;
  final String badge;
  final IconData icon;
  final Color color;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: AifcColors.cardSoftBg,
        borderRadius: BorderRadius.circular(AifcRadius.button),
        border: Border.all(color: AifcColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AifcColors.fcText,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: color.withOpacity(0.14),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onComplete != null)
            IconButton(
              tooltip: '완료',
              onPressed: onComplete,
              icon: const Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: AifcColors.primary,
              ),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: '삭제',
              onPressed: onDelete,
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
    );
  }
}

class _CareMilestoneDeleteConfirmBlock extends StatelessWidget {
  const _CareMilestoneDeleteConfirmBlock({
    required this.item,
    required this.onCancel,
    required this.onConfirm,
  });

  final AifcCareMilestoneSheetItem item;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AifcColors.cardSoftBg,
        borderRadius: BorderRadius.circular(AifcRadius.button),
        border: Border.all(color: AifcColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.title} 항목을 정말 삭제할까요?\n회원 관리 체크포인트에서 사라져요.',
            style: const TextStyle(
              color: AifcColors.fcText,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AifcColors.textMuted,
                    side: const BorderSide(color: AifcColors.cardBorder),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AifcRadius.button),
                    ),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AifcColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AifcRadius.button),
                    ),
                  ),
                  child: const Text(
                    '삭제 확인',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}