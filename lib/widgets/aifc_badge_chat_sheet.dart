import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/app_tier_access_service.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';

import 'package:mtf_app/pages/client_card_page.dart'
    show AchievementBadge, AchievementBadgeCode, AchievementIcChip;

class AifcBadgeChatSheet extends StatefulWidget {
  const AifcBadgeChatSheet({
    super.key,
    required this.memberName,
    required this.badges,
    required this.nickname,
    required this.onAddBadge,
    required this.onDeleteBadge,
    required this.onSetRepresentative,
    required this.onClearRepresentative,
  });

  final String memberName;
  final List<AchievementBadge> badges;
  final String nickname;

  final Future<void> Function(String title, AchievementBadgeCode code)
  onAddBadge;

  final Future<void> Function(AchievementBadge badge) onDeleteBadge;

  final Future<void> Function(AchievementBadge badge) onSetRepresentative;

  final Future<void> Function(AchievementBadge badge) onClearRepresentative;

  static Future<void> show({
    required BuildContext context,
    required String memberName,
    required List<AchievementBadge> badges,
    required String nickname,
    required Future<void> Function(String title, AchievementBadgeCode code)
    onAddBadge,
    required Future<void> Function(AchievementBadge badge) onDeleteBadge,
    required Future<void> Function(AchievementBadge badge)
    onSetRepresentative,
    required Future<void> Function(AchievementBadge badge)
    onClearRepresentative,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcBadgeChatSheet(
        memberName: memberName,
        badges: badges,
        nickname: nickname,
        onAddBadge: onAddBadge,
        onDeleteBadge: onDeleteBadge,
        onSetRepresentative: onSetRepresentative,
        onClearRepresentative: onClearRepresentative,
      ),
    );
  }

  @override
  State<AifcBadgeChatSheet> createState() => _AifcBadgeChatSheetState();
}

class _AifcBadgeChatSheetState extends State<AifcBadgeChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcBadgeChatSheet> {
  static const _groupInitial = 'badge_initial';
  static const _groupDetail = 'badge_detail';
  static const _groupAdd = 'badge_add';
  static const _groupAction = 'badge_action';

  String get _safeMemberName {
    final value = widget.memberName.trim();
    return value.isEmpty ? '회원' : value;
  }

  int _toneCursor = 0;

  String get _coachLabel {
    final value = widget.nickname.trim();
    if (value.isEmpty) return '강사님';
    return value.endsWith('님') ? value : '$value님';
  }

  String _nextTone(List<String> items) {
    if (items.isEmpty) return '';
    final index = _toneCursor % items.length;
    _toneCursor = (_toneCursor + 1) % 100000;
    return items[index];
  }

  String _badgeGiftQuestionText() {
    return _nextTone([
      '$_coachLabel, $_safeMemberName 회원님께 칭찬의 의미를 선물하시고 싶나요?',
      '$_safeMemberName 님의 좋은 순간을 메달로 남겨볼까요?',
      '오늘의 칭찬을 그냥 지나치지 말고 메달로 기록해둘게요.',
      '$_safeMemberName 님이 자랑스러워할 만한 성취를 하나 남겨볼까요?',
      '$_coachLabel이 본 $_safeMemberName 님의 성장을 메달로 표현해볼게요.',
    ]);
  }

  Future<void> _closeSheetAfterReply({
    int delayMs = 650,
  }) async {
    await Future.delayed(Duration(milliseconds: delayMs));

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  String _badgeDetailPraiseText(AchievementBadge badge) {
    final title = _badgeTitle(badge);

    if (title.contains('우수 출석')) {
      return '우수 출석이라니, $_safeMemberName 님이 정말 성실한데요?';
    }

    if (title.contains('100회')) {
      return '100회 레슨이라니, $_safeMemberName 님의 꾸준함이 정말 멋져요.';
    }

    if (title.contains('바디프로필')) {
      return '바디프로필 완료라니, $_safeMemberName 님이 해낸 과정이 느껴져요.';
    }

    if (title.contains('대회')) {
      return '대회 완료 메달이라니, $_safeMemberName 님의 도전이 빛나네요.';
    }

    return _nextTone([
      '$title 메달이라니, $_safeMemberName 님의 노력이 잘 보이네요.',
      '이 메달은 $_safeMemberName 님에게 좋은 동기부여가 될 것 같아요.',
      '$title 기록은 그냥 지나치기 아까운 성취예요.',
      '$_safeMemberName 님의 성장을 보여주는 좋은 메달이에요.',
      '이런 순간을 남겨두면 나중에 다시 봐도 뿌듯할 거예요.',
    ]);
  }

  @override
  void initState() {
    super.initState();

    aifcSetActiveGroup(_groupInitial);

    aifcAddFcMessage(
      text: '$_safeMemberName 님이 받은 메달이에요 🏅',
      groupKey: _groupInitial,
      child: _BadgeListBlock(
        badges: widget.badges,
        badgeTitle: _badgeTitle,
        badgeSubtitle: _badgeSubtitle,
        onBadgeTap: _handleBadgeTap,
        onAddTap: _handleOpenAddBadge,
      ),
    );
  }

  Future<void> _handleBadgeTap(AchievementBadge badge) async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    aifcSetActiveGroup(_groupDetail);

    await aifcUserThenFc(
      userText: '${_badgeTitle(badge)} 메달 확인',
      fcText: _badgeDetailPraiseText(badge),
      groupKey: _groupDetail,
      fcChild: _BadgeDetailBlock(
        badge: badge,
        badgeTitle: _badgeTitle(badge),
        badgeSubtitle: _badgeSubtitle(badge),
        isRepresentative: _isRepresentativeBadge(badge),
        onSetRepresentative: () => _handleSetRepresentative(badge),
        onClearRepresentative: () => _handleClearRepresentative(badge),
        onDelete: () => _handleDelete(badge),
      ),
    );
  }

  Future<void> _handleSetRepresentative(AchievementBadge badge) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '대표 메달로 설정할게요',
      groupKey: _groupAction,
      action: () async {
        await widget.onSetRepresentative(badge);
      },
      successText: '${_badgeTitle(badge)}을 대표 메달로 설정했어요 ✨',
      errorText: '대표 메달을 설정하지 못했어요.\n다시 시도해주세요.',
      closeAfterReply: true,
    );
  }

  Future<void> _handleClearRepresentative(AchievementBadge badge) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '대표 메달에서 해제할게요',
      groupKey: _groupAction,
      action: () async {
        await widget.onClearRepresentative(badge);
      },
      successText: '${_badgeTitle(badge)} 대표 설정을 해제했어요.\n필요하면 다른 메달을 대표로 다시 설정할 수 있어요.',
      errorText: '대표 메달 해제에 실패했어요.\n다시 시도해주세요.',
      closeAfterReply: true,
    );
  }

  Future<void> _handleDelete(AchievementBadge badge) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcUserThenFc(
      userText: '${_badgeTitle(badge)} 메달 삭제할게요',
      fcText: '정말 삭제할까요?',
      groupKey: _groupAction,
      fcChild: _BadgeDeleteConfirmBlock(
        badge: badge,
        badgeTitle: _badgeTitle(badge),
        onCancel: _handleCancelDelete,
        onConfirm: () => _handleDeleteConfirmed(badge),
      ),
    );
  }

  Future<void> _handleCancelDelete() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    await aifcUserThenFc(
      userText: '삭제하지 않을게요',
      fcText: '좋아요. 메달은 그대로 둘게요.',
      groupKey: _groupAction,
    );

    await _closeSheetAfterReply();
  }

  Future<void> _handleDeleteConfirmed(AchievementBadge badge) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '삭제 확인',
      groupKey: _groupAction,
      action: () async {
        await widget.onDeleteBadge(badge);
      },
      successText: '${_badgeTitle(badge)} 메달을 삭제했어요.',
      errorText: '메달을 삭제하지 못했어요.\n다시 시도해주세요.',
      closeAfterReply: true,
    );
  }

  Future<void> _handleOpenAddBadge() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    aifcSetActiveGroup(_groupAdd);

    await aifcUserThenFc(
      userText: '메달을 추가할게요',
      fcText: _badgeGiftQuestionText(),
      groupKey: _groupAdd,
      fcChild: _BadgeAddBlock(
        onPick: _handleAddBadge,
      ),
    );
  }

  Future<void> _handleAddBadge(
      String title,
      AchievementBadgeCode code,
      ) async {
    if (aifcIsBusy) return;

    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '$cleanTitle 메달 추가할게요',
      groupKey: _groupAdd,
      action: () async {
        await widget.onAddBadge(cleanTitle, code);
      },
      successText: '$cleanTitle 메달을 추가했어요 🎖️',
      errorText: '메달을 추가하지 못했어요.\n다시 시도해주세요.',
      closeAfterReply: true,
    );
  }

  bool _isRepresentativeBadge(AchievementBadge badge) {
    if (badge.isRepresentative) return true;

    final selected = widget.badges.where((item) => item.isRepresentative);
    if (selected.isEmpty) return false;

    return selected.first.id == badge.id;
  }

  String _badgeTitle(AchievementBadge badge) {
    final title = badge.title.trim();
    if (title.isNotEmpty) return title;

    switch (badge.code) {
      case AchievementBadgeCode.lesson100:
        return '100회 레슨';
      case AchievementBadgeCode.bodyProfileDone:
        return '바디프로필 완료';
      case AchievementBadgeCode.competitionDone:
        return '대회 완료';
      case AchievementBadgeCode.weddingDone:
        return '웨딩촬영 완료';
      case AchievementBadgeCode.ddayDone:
        return 'D-DAY 목표 완료';
      case AchievementBadgeCode.reregister10:
        return '재등록 10회';
      case AchievementBadgeCode.longTerm:
        return '장기회원';
      case AchievementBadgeCode.attendance:
        return '우수 출석';
      case AchievementBadgeCode.manual:
        return '메달';
    }
  }

  String _badgeSubtitle(AchievementBadge badge) {
    final sourceLabel = switch (badge.source) {
      'sessions' => '레슨 기록',
      'goal_dday' => 'D-DAY 목표',
      'trainer' => '담당 강사 부여',
      'test' => '테스트',
      _ => badge.isAuto ? '자동 메달' : '수동 메달',
    };

    return '$sourceLabel · ${DateFormat('yyyy.MM.dd').format(badge.earnedAt)}';
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

class _BadgeListBlock extends StatelessWidget {
  const _BadgeListBlock({
    required this.badges,
    required this.badgeTitle,
    required this.badgeSubtitle,
    required this.onBadgeTap,
    required this.onAddTap,
  });

  final List<AchievementBadge> badges;
  final String Function(AchievementBadge badge) badgeTitle;
  final String Function(AchievementBadge badge) badgeSubtitle;
  final ValueChanged<AchievementBadge> onBadgeTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (badges.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(
              color: AifcColors.cardSoftBg,
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(color: AifcColors.cardBorder),
            ),
            child: const Text(
              '아직 등록된 메달이 없어요.\n100회 레슨, 바디프로필 완료, 우수 출석 같은 성취가 생기면 여기에 표시돼요.',
              style: TextStyle(
                color: AifcColors.textMuted,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          ...badges.map((badge) {
            final isRep = badge.isRepresentative;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onBadgeTap(badge),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: isRep
                        ? AifcColors.primary.withOpacity(0.06)
                        : AifcColors.cardSoftBg,
                    borderRadius: BorderRadius.circular(AifcRadius.button),
                    border: Border.all(color: AifcColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      AchievementIcChip(
                        code: badge.code,
                        width: 44,
                        height: 32,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badgeTitle(badge),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AifcColors.fcText,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              badgeSubtitle(badge),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AifcColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isRep) const SizedBox(width: 8),
                      if (isRep) const _RepresentativeBadgeChip(),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AifcColors.textHint,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAddTap,
          icon: const Icon(Icons.add_rounded),
          label: const Text('메달 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AifcColors.primary,
            side: BorderSide(color: AifcColors.primary.withOpacity(0.25)),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AifcRadius.button),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeDetailBlock extends StatelessWidget {
  const _BadgeDetailBlock({
    required this.badge,
    required this.badgeTitle,
    required this.badgeSubtitle,
    required this.isRepresentative,
    required this.onSetRepresentative,
    required this.onDelete,
    required this.onClearRepresentative,
  });

  final AchievementBadge badge;
  final String badgeTitle;
  final String badgeSubtitle;
  final bool isRepresentative;
  final VoidCallback onSetRepresentative;
  final VoidCallback onDelete;
  final VoidCallback onClearRepresentative;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AchievementIcChip(
                code: badge.code,
                width: 56,
                height: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badgeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AifcColors.fcText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badgeSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AifcColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TypeChip(
                text: badge.isAuto ? '자동 메달' : '수동 메달',
                color: badge.isAuto ? AifcColors.primary : AifcColors.textMuted,
              ),
              if (isRepresentative) ...[
                const SizedBox(width: 6),
                const _RepresentativeBadgeChip(),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (isRepresentative) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AifcColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AifcRadius.button),
                border: Border.all(
                  color: AifcColors.primary.withOpacity(0.16),
                ),
              ),
              child: const Text(
                '현재 대표 메달',
                style: TextStyle(
                  color: AifcColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _BadgeDetailActionRow(
            isRepresentative: isRepresentative,
            onSetRepresentative: onSetRepresentative,
            onClearRepresentative: onClearRepresentative,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _BadgeDetailActionRow extends StatelessWidget {
  const _BadgeDetailActionRow({
    required this.isRepresentative,
    required this.onSetRepresentative,
    required this.onClearRepresentative,
    required this.onDelete,
  });

  final bool isRepresentative;
  final VoidCallback onSetRepresentative;
  final VoidCallback onClearRepresentative;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final mainLabel = isRepresentative ? '대표 메달 해제' : '대표 메달로 설정';
    final mainIcon = isRepresentative
        ? Icons.remove_circle_outline_rounded
        : Icons.workspace_premium_outlined;

    final mainButton = _AifcBadgeActionButton(
      label: mainLabel,
      icon: mainIcon,
      foregroundColor: AifcColors.primary,
      borderColor: AifcColors.primary.withOpacity(0.24),
      backgroundColor: AifcColors.primary.withOpacity(0.05),
      onTap: isRepresentative ? onClearRepresentative : onSetRepresentative,
    );

    final deleteButton = _AifcBadgeActionButton(
      label: '삭제',
      icon: Icons.delete_outline_rounded,
      foregroundColor: AifcColors.danger,
      borderColor: AifcColors.danger.withOpacity(0.24),
      backgroundColor: AifcColors.danger.withOpacity(0.05),
      onTap: onDelete,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              mainButton,
              const SizedBox(height: 8),
              deleteButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: mainButton,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: deleteButton,
            ),
          ],
        );
      },
    );
  }
}

class _AifcBadgeActionButton extends StatelessWidget {
  const _AifcBadgeActionButton({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AifcRadius.button),
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AifcRadius.button),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: 17,
                color: foregroundColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeDeleteConfirmBlock extends StatelessWidget {
  const _BadgeDeleteConfirmBlock({
    required this.badge,
    required this.badgeTitle,
    required this.onCancel,
    required this.onConfirm,
  });

  final AchievementBadge badge;
  final String badgeTitle;
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
            '$badgeTitle 메달을 정말 삭제할까요?\n되돌릴 수 없어요.',
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

class _BadgeAddBlock extends StatefulWidget {
  const _BadgeAddBlock({
    required this.onPick,
  });

  final void Function(String title, AchievementBadgeCode code) onPick;

  @override
  State<_BadgeAddBlock> createState() => _BadgeAddBlockState();
}

class _BadgeAddBlockState extends State<_BadgeAddBlock> {
  final TextEditingController _controller = TextEditingController();

  static const _presetOptions = [
    _PresetBadgeOption(
      title: '우수 출석',
      code: AchievementBadgeCode.attendance,
    ),
    _PresetBadgeOption(
      title: '운동 습관 형성',
      code: AchievementBadgeCode.manual,
    ),
    _PresetBadgeOption(
      title: '체중 감량 성공',
      code: AchievementBadgeCode.manual,
    ),
    _PresetBadgeOption(
      title: '근력 향상',
      code: AchievementBadgeCode.manual,
    ),
    _PresetBadgeOption(
      title: '컨디션 회복',
      code: AchievementBadgeCode.manual,
    ),
    _PresetBadgeOption(
      title: '부상 복귀',
      code: AchievementBadgeCode.manual,
    ),
    _PresetBadgeOption(
      title: '트레이너 추천',
      code: AchievementBadgeCode.manual,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    widget.onPick(title, AchievementBadgeCode.manual);
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _presetOptions)
                InkWell(
                  onTap: () => widget.onPick(option.title, option.code),
                  borderRadius: BorderRadius.circular(AifcRadius.button),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AifcColors.primary.withOpacity(0.08),
                      borderRadius:
                      BorderRadius.circular(AifcRadius.button),
                      border: Border.all(
                        color: AifcColors.primary.withOpacity(0.16),
                      ),
                    ),
                    child: Text(
                      option.title,
                      style: const TextStyle(
                        color: AifcColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(color: AifcColors.cardBorder),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
              decoration: const InputDecoration(
                hintText: '직접 입력',
                hintStyle: TextStyle(
                  color: AifcColors.textHint,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                color: AifcColors.fcText,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: text.isEmpty ? null : _handleSubmit,
            icon: const Icon(Icons.add_rounded),
            label: const Text('추가'),
            style: FilledButton.styleFrom(
              backgroundColor: AifcColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AifcColors.cardBorder,
              disabledForegroundColor: AifcColors.textHint,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AifcRadius.button),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetBadgeOption {
  const _PresetBadgeOption({
    required this.title,
    required this.code,
  });

  final String title;
  final AchievementBadgeCode code;
}

class _RepresentativeBadgeChip extends StatelessWidget {
  const _RepresentativeBadgeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE68A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '대표',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}