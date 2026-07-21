import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_nickname.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';

enum AifcConsultChecklistAction {
  later,
  saveDraft,
}

class AifcConsultChecklistResult {
  const AifcConsultChecklistResult({
    required this.items,
    required this.memo,
  });

  final List<String> items;
  final String memo;
}

class AifcConsultChecklistChatSheet extends StatefulWidget {
  const AifcConsultChecklistChatSheet({
    super.key,
    required this.trainerName,
  });

  final String trainerName;

  static Future<AifcConsultChecklistResult?> show({
    required BuildContext context,
    required String trainerName,
  }) {
    return showModalBottomSheet<AifcConsultChecklistResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcConsultChecklistChatSheet(
        trainerName: trainerName,
      ),
    );
  }

  @override
  State<AifcConsultChecklistChatSheet> createState() =>
      _AifcConsultChecklistChatSheetState();
}

class _AifcConsultChecklistChatSheetState
    extends State<AifcConsultChecklistChatSheet>
    with
        TickerProviderStateMixin,
        AifcChatFlowMixin<AifcConsultChecklistChatSheet> {
  static const _groupInitial = 'consult_initial';
  static const _groupSave = 'consult_save';

  final Set<String> _selectedItems = <String>{};
  final TextEditingController _memoController = TextEditingController();

  String get _trainerLabel => aifcNicknameLabel(widget.trainerName);

  static const List<_ConsultSectionData> _sections = [
    _ConsultSectionData(
      title: '목표',
      icon: Icons.flag_rounded,
      items: [
        '체중 감량',
        '근력 증가',
        '체형 교정',
        '통증 완화',
        '바디프로필',
        '대회 / 촬영',
      ],
    ),
    _ConsultSectionData(
      title: '현재 상태',
      icon: Icons.monitor_heart_outlined,
      items: [
        '운동 경험 있음',
        '운동 경험 적음',
        '허리 / 골반 불편',
        '어깨 / 목 불편',
        '무릎 / 발목 불편',
        '체력 저하',
      ],
    ),
    _ConsultSectionData(
      title: '생활 패턴',
      icon: Icons.schedule_rounded,
      items: [
        '수면 부족',
        '식사 불규칙',
        '야근 / 교대근무',
        '음주 잦음',
        '스트레스 높음',
        '좌식 시간 많음',
      ],
    ),
    _ConsultSectionData(
      title: '상담 메모',
      icon: Icons.assignment_outlined,
      items: [
        '상담 후 체험 권장',
        '기초 평가 필요',
        '의학적 확인 권장',
        '식단 안내 필요',
        '주 2회 권장',
        '재상담 필요',
      ],
    ),
  ];

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
          _ConsultIntroBlock(trainerLabel: _trainerLabel),
          const SizedBox(height: 12),
          _ConsultChecklistBlock(
            sections: _sections,
            selectedItems: _selectedItems,
            onToggle: _toggleItem,
          ),
          const SizedBox(height: 12),
          _ConsultMemoField(controller: _memoController),
          const SizedBox(height: 12),
          _ConsultActionBlock(
            selectedCount: _selectedItems.length,
            onSave: _handleSave,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _toggleItem(String value) {
    if (aifcIsBusy) return;

    HapticFeedback.selectionClick();

    setState(() {
      if (_selectedItems.contains(value)) {
        _selectedItems.remove(value);
      } else {
        _selectedItems.add(value);
      }
    });
  }

  Future<void> _handleSave() async {
    if (aifcIsBusy) return;

    final items = _selectedItems.toList()..sort();
    final memo = _memoController.text.trim();

    if (items.isEmpty && memo.isEmpty) {
      HapticFeedback.lightImpact();

      await aifcUserThenFc(
        userText: '아직 저장하지 않을게요',
        fcText: '좋아요. 상담 체크리스트는 필요할 때 다시 열어드릴게요.',
        groupKey: _groupSave,
      );

      await Future.delayed(aifcCloseAfterReplyDelay);
      if (!mounted) return;

      Navigator.of(context).pop(null);
      return;
    }

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: '상담 내용을 정리해둘게요',
      fcText: '좋아요. 선택한 상담 포인트를 정리했어요.\n'
          '다음 단계에서는 이 내용을 회원카드 SPECIAL NOTE나 상담 기록으로 바로 저장하도록 연결하면 됩니다.',
      groupKey: _groupSave,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(
      AifcConsultChecklistResult(
        items: items,
        memo: memo,
      ),
    );
  }

  Future<void> _handleBottomCancel() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.86,
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

class _ConsultSectionData {
  const _ConsultSectionData({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;
}

class _ConsultIntroBlock extends StatelessWidget {
  const _ConsultIntroBlock({
    required this.trainerLabel,
  });

  final String trainerLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AifcColors.cardBorder),
      ),
      child: Text(
        '$trainerLabel, 첫 상담이나 OT 때 확인할 내용을 빠르게 체크해볼게요.\n'
        '회원의 목표, 현재 상태, 생활 패턴을 먼저 잡아두면 이후 회원카드와 레슨일지가 훨씬 정확해져요.',
        style: const TextStyle(
          color: AifcColors.fcText,
          fontSize: 12.5,
          height: 1.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConsultChecklistBlock extends StatelessWidget {
  const _ConsultChecklistBlock({
    required this.sections,
    required this.selectedItems,
    required this.onToggle,
  });

  final List<_ConsultSectionData> sections;
  final Set<String> selectedItems;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sections.map((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE0DEFF),
                width: 0.7,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      section.icon,
                      size: 17,
                      color: AifcColors.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      section.title,
                      style: const TextStyle(
                        color: AifcColors.fcText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: section.items.map((item) {
                    final selected = selectedItems.contains(item);

                    return GestureDetector(
                      onTap: () => onToggle(item),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AifcColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AifcColors.primary
                                : const Color(0xFFE0DEFF),
                          ),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF4B5563),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ConsultMemoField extends StatelessWidget {
  const _ConsultMemoField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: '상담 메모',
        hintText: '예: 주 2회 가능, 허리 불편, 식사 불규칙, 체험 후 등록 상담',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0DEFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0DEFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AifcColors.primary,
            width: 1.3,
          ),
        ),
      ),
    );
  }
}

class _ConsultActionBlock extends StatelessWidget {
  const _ConsultActionBlock({
    required this.selectedCount,
    required this.onSave,
  });

  final int selectedCount;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onSave,
        style: FilledButton.styleFrom(
          backgroundColor: AifcColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AifcRadius.button),
          ),
        ),
        icon: const Icon(Icons.assignment_turned_in_rounded),
        label: Text(
          selectedCount <= 0 ? '상담 내용 확인' : '선택 $selectedCount개 정리하기',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
