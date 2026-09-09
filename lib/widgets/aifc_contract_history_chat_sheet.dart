import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';

enum AifcContractHistoryAction {
  close,
  openContract,
}

class AifcContractHistorySheetItem {
  const AifcContractHistorySheetItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isCurrent,
  });

  final String title;
  final String subtitle;
  final String badge;
  final bool isCurrent;
}

class AifcContractHistoryChatSheet extends StatefulWidget {
  const AifcContractHistoryChatSheet({
    super.key,
    required this.memberName,
    required this.items,
  });

  final String memberName;
  final List<AifcContractHistorySheetItem> items;

  static Future<AifcContractHistoryAction?> show({
    required BuildContext context,
    required String memberName,
    required List<AifcContractHistorySheetItem> items,
  }) {
    return showModalBottomSheet<AifcContractHistoryAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcContractHistoryChatSheet(
        memberName: memberName,
        items: items,
      ),
    );
  }

  @override
  State<AifcContractHistoryChatSheet> createState() =>
      _AifcContractHistoryChatSheetState();
}

class _AifcContractHistoryChatSheetState
    extends State<AifcContractHistoryChatSheet>
    with TickerProviderStateMixin,
        AifcChatFlowMixin<AifcContractHistoryChatSheet> {
  static const _groupInitial = 'contract_history_initial';
  static const _groupAction = 'contract_history_action';

  String get _memberName {
    final value = widget.memberName.trim();
    return value.isEmpty ? '회원' : value;
  }

  @override
  void initState() {
    super.initState();

    aifcSetActiveGroup(_groupInitial);

    aifcAddFcMessage(
      text: '$_memberName 님의 계약 이력을 확인해볼게요.\n'
          '현재 적용 계약과 이전 계약 흐름을 한 번에 볼 수 있어요.',
      groupKey: _groupInitial,
      child: _ContractHistoryPanel(
        items: widget.items,
        onOpenContract: _handleOpenContract,
      ),
    );
  }

  Future<void> _handleOpenContract() async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: '레슨계약서로 이동할게요',
      fcText: '좋아요. 레슨계약서 작성/확인 화면으로 연결할게요.',
      groupKey: _groupAction,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(AifcContractHistoryAction.openContract);
  }

  void _close() {
    if (aifcIsBusy) return;
    Navigator.of(context).pop(AifcContractHistoryAction.close);
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.80,
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
              ],
            ),
          ),
        ),
        if (!aifcIsBusy)
          SafeArea(
            top: false,
            child: GestureDetector(
              onTap: _close,
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
          )
        else
          const SizedBox(height: 14),
      ],
    );
  }
}

class _ContractHistoryPanel extends StatelessWidget {
  const _ContractHistoryPanel({
    required this.items,
    required this.onOpenContract,
  });

  final List<AifcContractHistorySheetItem> items;
  final VoidCallback onOpenContract;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AifcColors.cardSoftBg,
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(color: AifcColors.cardBorder),
            ),
            child: const Text(
              '아직 표시할 계약 이력이 없어요.\n'
                  '레슨계약서를 작성하면 현재 계약과 지난 계약을 이곳에서 확인할 수 있어요.',
              style: TextStyle(
                color: AifcColors.textMuted,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          for (final item in items) _ContractHistoryTile(item: item),
        const SizedBox(height: 10),
        _ContractHistoryActionButton(
          label: '레슨계약서 작성 / 확인으로 이동',
          icon: Icons.edit_document,
          onTap: onOpenContract,
        ),
      ],
    );
  }
}

class _ContractHistoryTile extends StatelessWidget {
  const _ContractHistoryTile({
    required this.item,
  });

  final AifcContractHistorySheetItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.isCurrent ? AifcColors.primary : AifcColors.textMuted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isCurrent
            ? AifcColors.primary.withOpacity(0.06)
            : AifcColors.cardSoftBg,
        borderRadius: BorderRadius.circular(AifcRadius.button),
        border: Border.all(
          color: item.isCurrent
              ? AifcColors.primary.withOpacity(0.18)
              : AifcColors.cardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isCurrent ? Icons.verified_outlined : Icons.history_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AifcColors.fcText,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AifcColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.badge,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractHistoryActionButton extends StatelessWidget {
  const _ContractHistoryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AifcColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AifcRadius.button),
          ),
        ),
      ),
    );
  }
}