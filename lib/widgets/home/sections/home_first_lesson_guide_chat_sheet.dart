import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../aifc/core/aifc_chat_bubble.dart';
import '../../../aifc/core/aifc_chat_flow.dart';
import '../../../aifc/core/aifc_sheet_frame.dart';
import '../../../aifc/core/aifc_theme.dart';

enum HomeFirstLessonGuideAction { openCustomerCard, later }

enum _FirstLessonChoice { usage, customerCard, later }

class HomeFirstLessonGuideChatSheet extends StatefulWidget {
  const HomeFirstLessonGuideChatSheet({
    super.key,
    required this.canCreateCustomerCard,
  });

  final bool canCreateCustomerCard;

  static Future<HomeFirstLessonGuideAction?> show({
    required BuildContext context,
    required bool canCreateCustomerCard,
  }) {
    return showModalBottomSheet<HomeFirstLessonGuideAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeFirstLessonGuideChatSheet(
        canCreateCustomerCard: canCreateCustomerCard,
      ),
    );
  }

  @override
  State<HomeFirstLessonGuideChatSheet> createState() =>
      _HomeFirstLessonGuideChatSheetState();
}

class _HomeFirstLessonGuideChatSheetState
    extends State<HomeFirstLessonGuideChatSheet>
    with
        TickerProviderStateMixin,
        AifcChatFlowMixin<HomeFirstLessonGuideChatSheet> {
  @override
  void initState() {
    super.initState();
    aifcSetActiveGroup('first_lesson');
    aifcAddFcMessage(
      text: '첫 레슨을 등록했어요.\n모어댄 사용방법을 살펴볼까요?',
      groupKey: 'first_lesson',
      child: _ChoiceCard(onSelected: _handleChoice),
    );
  }

  Future<void> _handleChoice(_FirstLessonChoice choice) async {
    if (aifcIsBusy) return;
    HapticFeedback.mediumImpact();

    switch (choice) {
      case _FirstLessonChoice.usage:
        await aifcUserThenFc(
          userText: '사용방법 보기',
          fcText: '일정표에서 레슨을 눌러 시간과 메모를 수정할 수 있어요.\n'
              '레슨을 확정하면 레슨일지와 기록이 차곡차곡 쌓여요.\n'
              '필요할 때 AI FC가 다음 할 일을 함께 안내할게요.',
          groupKey: 'usage',
        );
        break;
      case _FirstLessonChoice.customerCard:
        await aifcUserThenFc(
          userText: '고객카드 등록 알아보기',
          fcText: widget.canCreateCustomerCard
              ? '좋아요. 고객카드에서 회원 정보와 레슨 흐름을 함께 관리할 수 있어요.'
              : '고객카드 등록은 Amateur부터 사용할 수 있어요.\n'
                  '레슨 일정 10개와 선생님 정보 입력을 완료하면 열려요.',
          groupKey: 'customer_card',
        );
        await Future.delayed(aifcCloseAfterReplyDelay);
        if (!mounted) return;
        Navigator.of(context).pop(
          widget.canCreateCustomerCard
              ? HomeFirstLessonGuideAction.openCustomerCard
              : HomeFirstLessonGuideAction.later,
        );
        break;
      case _FirstLessonChoice.later:
        await aifcUserThenFc(
          userText: '나중에 할게요',
          fcText: '좋아요. 필요할 때 제가 다시 옆에서 도와드릴게요.',
          groupKey: 'later',
        );
        await Future.delayed(aifcCloseAfterReplyDelay);
        if (!mounted) return;
        Navigator.of(context).pop(HomeFirstLessonGuideAction.later);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.78,
      children: [
        Flexible(
          child: SingleChildScrollView(
            controller: aifcScrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
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
                if (aifcShowTyping) const AifcTypingBubble(),
              ],
            ),
          ),
        ),
        if (!aifcIsBusy)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(HomeFirstLessonGuideAction.later),
            child: const Text('닫기'),
          ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.onSelected});

  final ValueChanged<_FirstLessonChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AifcColors.cardBorder),
      ),
      child: Column(
        children: [
          _button('사용방법 보기', _FirstLessonChoice.usage),
          _button('고객카드 등록 알아보기', _FirstLessonChoice.customerCard),
          _button('나중에 할게요', _FirstLessonChoice.later),
        ],
      ),
    );
  }

  Widget _button(String label, _FirstLessonChoice value) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => onSelected(value),
    );
  }
}
