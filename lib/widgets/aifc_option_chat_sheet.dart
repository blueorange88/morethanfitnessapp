import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';

class AifcOptionItem<T> {
  const AifcOptionItem({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
}

class AifcOptionChatSheet<T> extends StatefulWidget {
  const AifcOptionChatSheet({
    super.key,
    required this.title,
    required this.message,
    required this.items,
    required this.selectedValue,
    this.nickname = '강사',
    this.closeText = '닫기',
    this.pickedReplyText,
    this.guidanceText = '계약서 기준에 맞는 항목을 선택해주세요.',
  });

  final String title;
  final String message;
  final List<AifcOptionItem<T>> items;
  final T? selectedValue;
  final String nickname;
  final String closeText;
  final String Function(AifcOptionItem<T> item)? pickedReplyText;
  final String guidanceText;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    required List<AifcOptionItem<T>> items,
    T? selectedValue,
    String nickname = '강사',
    String closeText = '닫기',
    String Function(AifcOptionItem<T> item)? pickedReplyText,
    String guidanceText = '계약서 기준에 맞는 항목을 선택해주세요.',
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcOptionChatSheet<T>(
        title: title,
        message: message,
        items: items,
        selectedValue: selectedValue,
        nickname: nickname,
        closeText: closeText,
        pickedReplyText: pickedReplyText,
        guidanceText: guidanceText,
      ),
    );
  }

  @override
  State<AifcOptionChatSheet<T>> createState() => _AifcOptionChatSheetState<T>();
}

class _AifcOptionChatSheetState<T> extends State<AifcOptionChatSheet<T>>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcOptionChatSheet<T>> {
  static const _groupInitial = 'option_initial';
  static const _groupPicked = 'option_picked';

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
          _OptionIntroBlock(
            title: widget.title,
            message: widget.message,
            nicknameLabel: _safeNicknameLabel,
            guidanceText: widget.guidanceText,
          ),
          const SizedBox(height: 12),
          _OptionListCard<T>(
            items: widget.items,
            selectedValue: widget.selectedValue,
            onPick: _handlePick,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePick(AifcOptionItem<T> item) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: '${item.title} 선택합니다',
      fcText: widget.pickedReplyText?.call(item) ??
          '확인되었습니다. ${item.title} 항목으로 적용합니다.',
      groupKey: _groupPicked,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(item.value);
  }

  Future<void> _handleClose() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.78,
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
            onTap: _handleClose,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  widget.closeText,
                  style: const TextStyle(
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

class _OptionIntroBlock extends StatelessWidget {
  const _OptionIntroBlock({
    required this.title,
    required this.message,
    required this.nicknameLabel,
    required this.guidanceText,
  });

  final String title;
  final String message;
  final String nicknameLabel;
  final String guidanceText;

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
        if (guidanceText.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AifcColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(
                color: AifcColors.primary.withValues(alpha: 0.16),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.rule_folder_outlined,
                  size: 16,
                  color: AifcColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$nicknameLabel, $guidanceText',
                    style: const TextStyle(
                      color: AifcColors.primary,
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
      ],
    );
  }
}

class _OptionListCard<T> extends StatelessWidget {
  const _OptionListCard({
    required this.items,
    required this.selectedValue,
    required this.onPick,
  });

  final List<AifcOptionItem<T>> items;
  final T? selectedValue;
  final ValueChanged<AifcOptionItem<T>> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _OptionTile<T>(
            item: items[i],
            selected: selectedValue == items[i].value,
            onTap: () => onPick(items[i]),
          ),
          if (i != items.length - 1)
            Container(
              height: 0.5,
              color: AifcColors.cardBorder,
            ),
        ],
      ],
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AifcOptionItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AifcColors.primary : AifcColors.fcText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected
                    ? AifcColors.primary.withValues(alpha: 0.10)
                    : AifcColors.cardSoftBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AifcColors.primary.withValues(alpha: 0.22)
                      : AifcColors.cardBorder,
                  width: 0.7,
                ),
              ),
              child: Icon(
                selected
                    ? Icons.check_rounded
                    : item.icon ?? Icons.article_outlined,
                size: 17,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.subtitle != null &&
                      item.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle!,
                      style: const TextStyle(
                        color: AifcColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: selected ? AifcColors.primary : AifcColors.textHint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
