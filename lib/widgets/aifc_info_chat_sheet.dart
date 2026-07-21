import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';

class AifcInfoChatSheet extends StatefulWidget {
  const AifcInfoChatSheet({
    super.key,
    required this.title,
    required this.message,
    this.nickname = '강사',
    this.items = const [],
    this.confirmText = '확인',
    this.userConfirmText = '확인했습니다',
    this.replyText = '확인되었습니다.',
    this.icon = Icons.info_outline_rounded,
    this.accentColor = AifcColors.primary,
  });

  final String title;
  final String message;
  final String nickname;
  final List<String> items;

  final String confirmText;
  final String userConfirmText;
  final String replyText;

  final IconData icon;
  final Color accentColor;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String nickname = '강사',
    List<String> items = const [],
    String confirmText = '확인',
    String userConfirmText = '확인했습니다',
    String replyText = '확인되었습니다.',
    IconData icon = Icons.info_outline_rounded,
    Color accentColor = AifcColors.primary,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcInfoChatSheet(
        title: title,
        message: message,
        nickname: nickname,
        items: items,
        confirmText: confirmText,
        userConfirmText: userConfirmText,
        replyText: replyText,
        icon: icon,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<AifcInfoChatSheet> createState() => _AifcInfoChatSheetState();
}

class _AifcInfoChatSheetState extends State<AifcInfoChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcInfoChatSheet> {
  static const _groupInitial = 'info_initial';
  static const _groupDone = 'info_done';

  String get _safeNickname => normalizeAifcNickname(widget.nickname);

  String get _safeNicknameLabel => aifcNicknameLabel(widget.nickname);

  @override
  void initState() {
    super.initState();

    aifcSetActiveGroup(_groupInitial);

    aifcAddFcMessage(
      text: '',
      groupKey: _groupInitial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoMessageBlock(
            title: widget.title,
            message: widget.message,
            items: widget.items,
            nicknameLabel: _safeNicknameLabel,
            icon: widget.icon,
            accentColor: widget.accentColor,
          ),
          const SizedBox(height: 12),
          _InfoActionButton(
            label: widget.confirmText,
            foregroundColor: Colors.white,
            backgroundColor: widget.accentColor,
            borderColor: widget.accentColor,
            onTap: _handleConfirm,
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirm() async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: widget.userConfirmText,
      fcText: widget.replyText,
      groupKey: _groupDone,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _handleBottomCancel() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.76,
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
          GestureDetector(
            onTap: _handleBottomCancel,
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
      ],
    );
  }
}

class _InfoMessageBlock extends StatelessWidget {
  const _InfoMessageBlock({
    required this.title,
    required this.message,
    required this.items,
    required this.nicknameLabel,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String message;
  final List<String> items;
  final String nicknameLabel;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AifcColors.fcText,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1.35,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: AifcColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AifcColors.cardSoftBg,
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(
                color: AifcColors.cardBorder,
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        color: AifcColors.fcText,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AifcRadius.button),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.16),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$nicknameLabel, 확인 후 계속 진행하시면 됩니다.',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoActionButton extends StatelessWidget {
  const _InfoActionButton({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AifcRadius.button),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}