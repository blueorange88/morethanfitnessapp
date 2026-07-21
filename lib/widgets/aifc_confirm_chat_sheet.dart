import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';

class AifcConfirmChatSheet extends StatefulWidget {
  const AifcConfirmChatSheet({
    super.key,
    required this.title,
    required this.message,
    this.nickname = '강사',
    this.cancelText = '아니요',
    this.confirmText = '확인',
    this.userCancelText,
    this.userConfirmText,
    this.cancelReplyText = '좋아요. 진행하지 않을게요.',
    this.confirmReplyText = '확인했어요. 이어서 진행할게요.',
    this.danger = false,
  });

  final String title;
  final String message;
  final String nickname;

  final String cancelText;
  final String confirmText;

  final String? userCancelText;
  final String? userConfirmText;

  final String cancelReplyText;
  final String confirmReplyText;

  final bool danger;

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String nickname = '강사',
    String cancelText = '아니요',
    String confirmText = '확인',
    String? userCancelText,
    String? userConfirmText,
    String cancelReplyText = '좋아요. 진행하지 않을게요.',
    String confirmReplyText = '확인했어요. 이어서 진행할게요.',
    bool danger = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcConfirmChatSheet(
        title: title,
        message: message,
        nickname: nickname,
        cancelText: cancelText,
        confirmText: confirmText,
        userCancelText: userCancelText,
        userConfirmText: userConfirmText,
        cancelReplyText: cancelReplyText,
        confirmReplyText: confirmReplyText,
        danger: danger,
      ),
    );

    return result == true;
  }

  @override
  State<AifcConfirmChatSheet> createState() => _AifcConfirmChatSheetState();
}

class _AifcConfirmChatSheetState extends State<AifcConfirmChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcConfirmChatSheet> {
  static const _groupInitial = 'confirm_initial';
  static const _groupCancel = 'confirm_cancel';
  static const _groupConfirm = 'confirm_confirm';

  String get _safeNickname => normalizeAifcNickname(widget.nickname);

  String get _safeNicknameLabel => aifcNicknameLabel(_safeNickname);

  Color get _confirmColor {
    return widget.danger ? AifcColors.noShowDeducted : AifcColors.primary;
  }

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
          _ConfirmMessageBlock(
            title: widget.title,
            message: widget.message,
            nicknameLabel: _safeNicknameLabel,
            danger: widget.danger,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ConfirmActionButton(
                  label: widget.cancelText,
                  foregroundColor: AifcColors.textMuted,
                  backgroundColor: Colors.white,
                  borderColor: AifcColors.cardBorder,
                  onTap: _handleCancelChoice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConfirmActionButton(
                  label: widget.confirmText,
                  foregroundColor: Colors.white,
                  backgroundColor: _confirmColor,
                  borderColor: _confirmColor,
                  onTap: _handleConfirmChoice,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelChoice() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    await aifcUserThenFc(
      userText: widget.userCancelText ?? '${widget.cancelText} 할게요',
      fcText: widget.cancelReplyText,
      groupKey: _groupCancel,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(false);
  }

  Future<void> _handleConfirmChoice() async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: widget.userConfirmText ?? '${widget.confirmText} 할게요',
      fcText: widget.confirmReplyText,
      groupKey: _groupConfirm,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  Future<void> _handleBottomCancel() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.72,
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
                  '취소',
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

class _ConfirmMessageBlock extends StatelessWidget {
  const _ConfirmMessageBlock({
    required this.title,
    required this.message,
    required this.nicknameLabel,
    required this.danger,
  });

  final String title;
  final String message;
  final String nicknameLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accentColor =
    danger ? AifcColors.noShowDeducted : AifcColors.primary;

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
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AifcRadius.button),
            border: Border.all(
              color: accentColor.withOpacity(0.16),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                danger
                    ? Icons.warning_amber_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$nicknameLabel, 선택 후 제가 이어서 처리할게요.',
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

class _ConfirmActionButton extends StatelessWidget {
  const _ConfirmActionButton({
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