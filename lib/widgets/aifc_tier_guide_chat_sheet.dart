import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../models/personal_tier_progress.dart';

enum AifcTierGuideAction {
  later,
  sponsor,
  goFillInfo,
  goAddMember,
  goAddProduct,
}

class AifcTierGuideChatSheet extends StatefulWidget {
  const AifcTierGuideChatSheet({
    super.key,
    required this.trainerName,
    required this.currentTierName,
    required this.nextTierName,
    required this.memberCount,
    required this.lessonCount,
    required this.hasProduct,
    required this.trainerInfoDone,
  });

  final String trainerName;
  final String currentTierName;
  final String nextTierName;
  final int memberCount;
  final int lessonCount;
  final bool hasProduct;
  final bool trainerInfoDone;

  static Future<AifcTierGuideAction?> show({
    required BuildContext context,
    required String trainerName,
    required String currentTierName,
    required String nextTierName,
    required int memberCount,
    required int lessonCount,
    required bool hasProduct,
    required bool trainerInfoDone,
  }) {
    return showModalBottomSheet<AifcTierGuideAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcTierGuideChatSheet(
        trainerName: trainerName,
        currentTierName: currentTierName,
        nextTierName: nextTierName,
        memberCount: memberCount,
        lessonCount: lessonCount,
        hasProduct: hasProduct,
        trainerInfoDone: trainerInfoDone,
      ),
    );
  }

  @override
  State<AifcTierGuideChatSheet> createState() => _AifcTierGuideChatSheetState();
}

class _AifcTierGuideChatSheetState extends State<AifcTierGuideChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcTierGuideChatSheet> {
  late String _selectedTierName;

  String get _name {
    final v = widget.trainerName.trim();
    if (v.isEmpty) return '강사님';
    return v.endsWith('님') ? v : '$v님';
  }

  @override
  void initState() {
    super.initState();
    _selectedTierName = widget.currentTierName;

    aifcSetActiveGroup('initial');

    aifcAddFcMessage(
      text: '$_name, 지금 등급은 ${widget.currentTierName}예요.\n'
          '등급은 결제 여부보다 선생님의 활용 흐름을 보여주는 단계예요.',
      groupKey: 'initial',
    );
    final scheduleComplete = widget.lessonCount >= 10;
    final progress = PersonalTierProgress(
      currentTier: widget.currentTierName,
      scheduleCount: widget.lessonCount,
      scheduleGoal: PersonalTierProgress.defaultScheduleGoal,
      scheduleMissionCompleted: scheduleComplete,
      teacherInfoCompleted: widget.trainerInfoDone,
      completedMissionCount:
          (scheduleComplete ? 1 : 0) + (widget.trainerInfoDone ? 1 : 0),
      totalMissionCount: PersonalTierProgress.defaultMissionTotal,
    );
    debugPrint(progress.debugLog(source: 'tierGuide'));
  }

  void _handleTierSelected(String tierName) {
    if (aifcIsBusy) return;
    if (tierName == _selectedTierName) return;

    HapticFeedback.lightImpact();
    final previousTier = _selectedTierName;
    setState(() => _selectedTierName = tierName);
    debugPrint(
      '[MTF_TIER_GUIDE_SELECT] selectedTier=$tierName '
      'previousTier=$previousTier presentation=replace messageAppended=false',
    );
  }

  Future<void> _handleAction(AifcTierGuideAction action) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    String userText;
    String fcReply;

    switch (action) {
      case AifcTierGuideAction.sponsor:
        userText = '후원 안내 볼게요';
        fcReply = '좋아요. 후원 안내로 연결할게요.\n'
            '후원은 기능을 바로 열고, 모어댄 개발을 응원하는 방식이에요.';
        break;

      case AifcTierGuideAction.goFillInfo:
        userText = '내 정보 채울게요';
        fcReply = '좋아요. 마이페이지의 AI FC 안내 정보를 채워주세요.\n'
            '이름, 연락처, 레슨 분야, 센터명이 있으면 관리 흐름이 더 자연스러워져요.';
        break;

      case AifcTierGuideAction.goAddMember:
        userText = '회원 추가할게요';
        fcReply = '좋아요. 고객카드에 회원을 쌓아가면 다음 등급 조건도 자연스럽게 채워져요.';
        break;

      case AifcTierGuideAction.goAddProduct:
        userText = '레슨 상품 추가할게요';
        fcReply = '좋아요. 레슨 상품을 등록해두면 계약서 작성 때 바로 불러올 수 있어요.';
        break;

      case AifcTierGuideAction.later:
        userText = '나중에 볼게요';
        fcReply = '좋아요. 필요할 때 언제든 다시 확인해드릴게요.';
        break;
    }

    await aifcRunActionThenReply(
      userText: userText,
      groupKey: 'tier_action',
      action: () async {
        await Future.delayed(const Duration(milliseconds: 220));
      },
      successText: fcReply,
      closeAfterReply: true,
      popResult: action,
    );
  }

  String _tierMainMessage(String tierName) {
    switch (tierName) {
      case 'Beginner':
        return 'Beginner는 주 단위 스케줄러를 쉽고  빠른방법으로 사용하고 저장하는 단계예요.\n'
            '스케줄과 내 정보를 조금만 채우면 Amateur로 올라갈 수 있어요.';

      case 'Amateur':
        return 'Amateur는 고객카드와 AI FC의 기능을 통해 회원관리와 레슨일정 관리가 더 쉬어지는 단계예요.\n'
            '고객카드가 쌓이면 Semi-Pro 흐름으로 넘어갈 수 있어요.';

      case 'Semi-Pro':
        return 'Semi-Pro부터는 계약서 작성과 전자서명으로 조금 더 정확하고, 체계적으로 관리 할 수 있는  단계예요.\n'
            '레슨 상품, 금액, 횟수, 서명 기록을 더 체계적으로 관리할 수 있어요.';

      case 'Pro':
        return 'Pro는 고급 인사이트, 향상된 AI FC, 위젯 고급 기능까지 전체적인 흐름을 관리 할 수 있는 단계예요.\n'
            '재등록, 매출, 수업 흐름까지 더 넓게 볼 수 있어요.';

      case 'Master':
        return 'Master는 많은 회원을 안정적으로 관리하는 단계예요.\n'
            '센터 단위 운영이나 팀 관리가 필요한 단계에서 많은 부분을 활용 할 수 있는 기능입니다.';

      case 'Grand Prix':
        return 'Grand Prix는 최상위 운영 단계예요.\n'
            '최고 수준의 AI FC의 기능으로 다수 회원, 여러 지점, 팀 단위 관리,감독하며 더 효율적으로 사용할 수 있는 단계에요.';

      default:
        return '$tierName 단계의 기능을 확인해볼게요.';
    }
  }

  Future<void> _handleLater() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(AifcTierGuideAction.later);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: AifcSheetFrame(
        maxHeightFactor: 0.9,
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
                  _CurrentTierSummaryCard(
                    currentTierName: widget.currentTierName,
                    nextTierName: widget.nextTierName,
                    memberCount: widget.memberCount,
                    lessonCount: widget.lessonCount,
                    hasProduct: widget.hasProduct,
                    trainerInfoDone: widget.trainerInfoDone,
                  ),
                  const SizedBox(height: 12),
                  _TierSelectCard(
                    selectedTierName: _selectedTierName,
                    onSelected: _handleTierSelected,
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.025, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _TierDetailCard(
                      key: ValueKey(_selectedTierName),
                      tierName: _selectedTierName,
                      description: _tierMainMessage(_selectedTierName),
                      isCurrent: _selectedTierName == widget.currentTierName,
                      memberCount: widget.memberCount,
                      lessonCount: widget.lessonCount,
                      hasProduct: widget.hasProduct,
                      trainerInfoDone: widget.trainerInfoDone,
                      onAction: _handleAction,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          if (!aifcIsBusy)
            GestureDetector(
              onTap: _handleLater,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    '나중에',
                    style: TextStyle(
                      color: AifcColors.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CurrentTierSummaryCard extends StatelessWidget {
  const _CurrentTierSummaryCard({
    required this.currentTierName,
    required this.nextTierName,
    required this.memberCount,
    required this.lessonCount,
    required this.hasProduct,
    required this.trainerInfoDone,
  });

  final String currentTierName;
  final String nextTierName;
  final int memberCount;
  final int lessonCount;
  final bool hasProduct;
  final bool trainerInfoDone;

  @override
  Widget build(BuildContext context) {
    final progressItems = <_TierProgressItem>[
      _TierProgressItem(
        label: '레슨 일정',
        value: '$lessonCount / 10',
        done: lessonCount >= 10,
      ),
      _TierProgressItem(
        label: '선생님 정보 입력 완료',
        value: trainerInfoDone ? '완료' : '미완료',
        done: trainerInfoDone,
      ),
    ];
    final completedCount = progressItems.where((item) => item.done).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0DEFF),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: AifcColors.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  currentTierName == 'Beginner'
                      ? 'Amateur 승급 조건 · $completedCount / 2 완료'
                      : '현재 $currentTierName · 다음 $nextTierName',
                  style: const TextStyle(
                    color: Color(0xFF1E1B4B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...progressItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    item.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.done
                        ? AifcColors.primary
                        : const Color(0xFFD1D5DB),
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          softWrap: true,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.value,
                          style: TextStyle(
                            color: item.done
                                ? AifcColors.primary
                                : const Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

class _TierProgressItem {
  const _TierProgressItem({
    required this.label,
    required this.value,
    required this.done,
  });

  final String label;
  final String value;
  final bool done;
}

class _TierSelectCard extends StatelessWidget {
  const _TierSelectCard({
    required this.selectedTierName,
    required this.onSelected,
  });

  final String selectedTierName;
  final ValueChanged<String> onSelected;

  static const _tiers = [
    'Beginner',
    'Amateur',
    'Semi-Pro',
    'Pro',
    'Master',
    'Grand Prix',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _tiers.map((tier) {
        final active = tier == selectedTierName;

        return GestureDetector(
          onTap: () => onSelected(tier),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color:
                  active ? AifcColors.primary.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? AifcColors.primary.withOpacity(0.28)
                    : const Color(0xFFE0DEFF),
                width: active ? 1.1 : 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: active ? AifcColors.primary : const Color(0xFFB8B6DA),
                  size: 17,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    tier,
                    softWrap: true,
                    style: TextStyle(
                      color:
                          active ? AifcColors.primary : const Color(0xFF1E1B4B),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TierDetailCard extends StatelessWidget {
  const _TierDetailCard({
    super.key,
    required this.tierName,
    required this.description,
    required this.isCurrent,
    required this.memberCount,
    required this.lessonCount,
    required this.hasProduct,
    required this.trainerInfoDone,
    required this.onAction,
  });

  final String tierName;
  final String description;
  final bool isCurrent;
  final int memberCount;
  final int lessonCount;
  final bool hasProduct;
  final bool trainerInfoDone;
  final ValueChanged<AifcTierGuideAction> onAction;

  @override
  Widget build(BuildContext context) {
    final rows = _featureRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          description,
          softWrap: true,
          style: const TextStyle(
            color: AifcColors.textHint,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE0DEFF),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isCurrent
                        ? Icons.emoji_events_rounded
                        : Icons.workspace_premium_outlined,
                    color: AifcColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCurrent ? '$tierName · 현재 단계' : tierName,
                      style: const TextStyle(
                        color: Color(0xFF1E1B4B),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InfoRow(
                      icon: row.icon,
                      title: row.title,
                      subtitle: row.subtitle,
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._actionButtons(),
      ],
    );
  }

  List<_TierFeatureRow> _featureRows() {
    switch (tierName) {
      case 'Beginner':
        return const [
          _TierFeatureRow(
            icon: Icons.play_circle_outline_rounded,
            title: '시작 단계',
            subtitle: '첫 레슨, 첫 회원, 내 정보 입력을 준비하는 단계예요.',
          ),
          _TierFeatureRow(
            icon: Icons.schedule_rounded,
            title: 'Amateur 승급 조건',
            subtitle: '현재 레슨 일정 10개와 선생님 정보 입력을 모두 완료해보세요.',
          ),
        ];

      case 'Amateur':
        return const [
          _TierFeatureRow(
            icon: Icons.credit_card_outlined,
            title: '고객카드와 회원관리',
            subtitle: '회원 정보를 고객카드에서 체계적으로 관리할 수 있어요.',
          ),
          _TierFeatureRow(
            icon: Icons.history_rounded,
            title: '회원별 레슨 이력',
            subtitle: '회원별 레슨 기록과 남은 회차를 함께 확인할 수 있어요.',
          ),
        ];

      case 'Semi-Pro':
        return const [
          _TierFeatureRow(
            icon: Icons.description_outlined,
            title: '계약서 작성',
            subtitle: '회원 정보와 레슨 조건을 계약서로 남길 수 있어요.',
          ),
          _TierFeatureRow(
            icon: Icons.draw_rounded,
            title: '전자서명 관리',
            subtitle: '서명 완료 계약서를 기준으로 횟수와 금액을 관리해요.',
          ),
        ];

      case 'Pro':
        return const [
          _TierFeatureRow(
            icon: Icons.bar_chart_rounded,
            title: '인사이트',
            subtitle: '레슨 추이, 매출 흐름, 재등록 흐름을 더 자세히 볼 수 있어요.',
          ),
          _TierFeatureRow(
            icon: Icons.auto_awesome_rounded,
            title: '강화된 AI FC',
            subtitle: '관리 체크와 추천 흐름이 더 똑똑해지는 단계예요.',
          ),
        ];

      case 'Master':
        return const [
          _TierFeatureRow(
            icon: Icons.groups_rounded,
            title: '센터 단위 운영',
            subtitle: '많은 회원과 수업 흐름을 안정적으로 관리하는 단계예요.',
          ),
          _TierFeatureRow(
            icon: Icons.manage_accounts_rounded,
            title: '관리 확장',
            subtitle: '팀, 센터, 운영자 관리로 확장하기 좋은 단계예요.',
          ),
        ];

      case 'Grand Prix':
        return const [
          _TierFeatureRow(
            icon: Icons.apartment_rounded,
            title: '최상위 운영',
            subtitle: '다수 지점과 팀 단위 운영까지 바라볼 수 있는 단계예요.',
          ),
          _TierFeatureRow(
            icon: Icons.workspace_premium_rounded,
            title: '브랜드 운영',
            subtitle: '개인 강사를 넘어 브랜드/센터 운영 흐름에 가까워져요.',
          ),
        ];

      default:
        return const [];
    }
  }

  List<Widget> _actionButtons() {
    final buttons = <Widget>[];

    if (tierName == 'Beginner' && !trainerInfoDone) {
      buttons.add(
        _TierActionButton(
          label: '내 정보 채우기',
          onTap: () => onAction(AifcTierGuideAction.goFillInfo),
        ),
      );
    }

    if ((tierName == 'Amateur' || tierName == 'Semi-Pro') && memberCount < 30) {
      buttons.add(
        _TierActionButton(
          label: '회원 관리 시작하기',
          onTap: () => onAction(AifcTierGuideAction.goAddMember),
        ),
      );
    }

    if (tierName == 'Amateur' && !hasProduct) {
      buttons.add(
        _TierActionButton(
          label: '레슨 상품 등록하기',
          onTap: () => onAction(AifcTierGuideAction.goAddProduct),
          outlined: true,
        ),
      );
    }

    if (tierName == 'Semi-Pro' || tierName == 'Pro') {
      buttons.add(
        _TierActionButton(
          label: '후원 안내 보기',
          onTap: () => onAction(AifcTierGuideAction.sponsor),
          outlined: true,
        ),
      );
    }

    if (buttons.isEmpty) {
      buttons.add(
        _TierActionButton(
          label: '확인했어요',
          onTap: () => onAction(AifcTierGuideAction.later),
          outlined: true,
        ),
      );
    }

    return buttons
        .map(
          (button) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: button,
          ),
        )
        .toList();
  }
}

class _TierFeatureRow {
  const _TierFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _TierActionButton extends StatelessWidget {
  const _TierActionButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined
              ? AifcColors.primary.withOpacity(0.07)
              : AifcColors.primary,
          borderRadius: BorderRadius.circular(AifcRadius.button),
          border: Border.all(
            color: outlined
                ? AifcColors.primary.withOpacity(0.18)
                : AifcColors.primary,
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: outlined ? AifcColors.primary : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE0DEFF),
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            color: AifcColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E1B4B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AifcColors.textHint,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
