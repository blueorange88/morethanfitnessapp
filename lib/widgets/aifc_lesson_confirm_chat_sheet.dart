import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';


enum AifcLessonConfirmStatus {
  completed,
  noShowDeducted,
  noShowNotDeducted,
  service,
}

extension AifcLessonConfirmStatusX on AifcLessonConfirmStatus {
  String get firestoreValue {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return 'no_show_deducted';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return 'no_show_not_deducted';
      case AifcLessonConfirmStatus.service:
        return 'service';
      case AifcLessonConfirmStatus.completed:
      default:
        return 'completed';
    }
  }

  bool get shouldDeduct {
    return this == AifcLessonConfirmStatus.completed ||
        this == AifcLessonConfirmStatus.noShowDeducted;
  }

  String get title {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '노쇼 차감';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '노쇼 미차감';
      case AifcLessonConfirmStatus.service:
        return '서비스 레슨';
      case AifcLessonConfirmStatus.completed:
      default:
        return '레슨 확정';
    }
  }

  String get cardTitle {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '노쇼 차감 1회 소진';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '노쇼 미차감 확정';
      case AifcLessonConfirmStatus.service:
        return '서비스 레슨 확정';
      case AifcLessonConfirmStatus.completed:
      default:
        return '레슨 확정 1회 소진';
    }
  }

  String get confirmButtonLabel {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '노쇼 차감 확정';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '노쇼 미차감 확정';
      case AifcLessonConfirmStatus.service:
        return '서비스 레슨 확정';
      case AifcLessonConfirmStatus.completed:
      default:
        return '레슨 확정';
    }
  }

  String get userBubbleText {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '노쇼 차감으로 확정 할게요';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '노쇼 미차감으로 확정 할게요';
      case AifcLessonConfirmStatus.service:
        return '서비스 레슨으로 확정 할게요';
      case AifcLessonConfirmStatus.completed:
      default:
        return '레슨 확정할게요';
    }
  }

  String aiBubbleText(String memberName) {
    final safeName = memberName.trim().isEmpty ? '회원' : memberName.trim();

    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '노쇼 1회 차감으로 기록하겠습니다.';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '휴~😅 노쇼 미차감으로 기록했어요.';
      case AifcLessonConfirmStatus.service:
        return '와~😄 $safeName님이 너무 좋아하시겠는데요.\n'
            '서비스 레슨이니 꼭! 꼭! 기록해둘게요.';
      case AifcLessonConfirmStatus.completed:
      default:
        return '$safeName님 레슨을 확정할게요.';
    }
  }
  String get confirmUserBubbleText {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '노쇼 차감으로 확정할게요';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '노쇼 미차감으로 확정할게요';
      case AifcLessonConfirmStatus.service:
        return '서비스 레슨으로 확정할게요';
      case AifcLessonConfirmStatus.completed:
      default:
        return '레슨진행으로 확정할게요';
    }
  }

  String confirmDoneAiBubbleText(String memberName) {
    final safeName = memberName.trim().isEmpty ? '회원' : memberName.trim();

    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return '네, $safeName님 레슨을 노쇼 1회 차감으로 기록했어요.';
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return '네, $safeName님 레슨을 노쇼 미차감으로 기록했어요.';
      case AifcLessonConfirmStatus.service:
        return '좋아요 😄\n$safeName님 레슨을 서비스 레슨으로 기록했어요.';
      case AifcLessonConfirmStatus.completed:
      default:
        return '네, $safeName님 레슨진행을 확정했어요.';
    }
  }

  Color get themeColor {
    switch (this) {
      case AifcLessonConfirmStatus.noShowDeducted:
        return AifcColors.noShowDeducted;
      case AifcLessonConfirmStatus.noShowNotDeducted:
        return AifcColors.noShowNotDeducted;
      case AifcLessonConfirmStatus.service:
        return AifcColors.service;
      case AifcLessonConfirmStatus.completed:
      default:
        return AifcColors.primary;
    }
  }
}

enum _LessonConfirmMode {
  initial,
  choosingMethod,
  methodSelected,
}


class AifcLessonConfirmChatSheet extends StatefulWidget {
  const AifcLessonConfirmChatSheet({
    super.key,
    required this.memberName,
    required this.lessonType,
    required this.totalSessions,
    required this.remainBefore,
    this.contractSigned = false,
    this.onConfirm,
  });

  final String memberName;
  final String lessonType;
  final int totalSessions;
  final int remainBefore;
  final bool contractSigned;
  final Future<void> Function(AifcLessonConfirmStatus status)? onConfirm;

  static Future<AifcLessonConfirmStatus?> show({
    required BuildContext context,
    required String memberName,
    required String lessonType,
    required int totalSessions,
    required int remainBefore,
    bool contractSigned = false,
    Future<void> Function(AifcLessonConfirmStatus status)? onConfirm,
  }) {
    return showModalBottomSheet<AifcLessonConfirmStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcLessonConfirmChatSheet(
        memberName: memberName,
        lessonType: lessonType,
        totalSessions: totalSessions,
        remainBefore: remainBefore,
        contractSigned: contractSigned,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<AifcLessonConfirmChatSheet> createState() =>
      _AifcLessonConfirmChatSheetState();
}

class _AifcLessonConfirmChatSheetState
    extends State<AifcLessonConfirmChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin {

  _LessonConfirmMode _mode = _LessonConfirmMode.initial;
  AifcLessonConfirmStatus _selectedStatus =
      AifcLessonConfirmStatus.completed;

  String get _safeMemberName {
    final value = widget.memberName.trim();
    return value.isEmpty ? '회원' : value;
  }

  String get _safeLessonType {
    final value = widget.lessonType.trim();
    return value.isEmpty ? '레슨' : value;
  }

  @override
  void initState() {
    super.initState();

    aifcSetActiveGroup(_LessonConfirmMode.initial);

    aifcAddFcMessage(
      text: '$_safeMemberName 님 $_safeLessonType 레슨을 1회 소진할까요?',
      groupKey: _LessonConfirmMode.initial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LessonConfirmCard(
            status: AifcLessonConfirmStatus.completed,
            lessonType: _safeLessonType,
            totalSessions: widget.totalSessions,
            remainBefore: widget.remainBefore,
            remainAfter: _remainAfterFor(AifcLessonConfirmStatus.completed),
            lessonNumber: _lessonNumberFor(AifcLessonConfirmStatus.completed),
          ),
          const SizedBox(height: 10),
          _InitialLessonActionCard(
            onConfirm: () => _handleConfirm(AifcLessonConfirmStatus.completed),
            onChangeMethod: _handleChangeMethod,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  int _remainAfterFor(AifcLessonConfirmStatus status) {
    final next = status.shouldDeduct && widget.remainBefore > 0
        ? widget.remainBefore - 1
        : widget.remainBefore;

    if (widget.totalSessions > 0) {
      return next.clamp(0, widget.totalSessions).toInt();
    }

    return math.max(0, next);
  }

  int _lessonNumberFor(AifcLessonConfirmStatus status) {
    if (widget.totalSessions <= 0) return 0;

    final doneBefore = (widget.totalSessions - widget.remainBefore)
        .clamp(0, widget.totalSessions)
        .toInt();

    if (status.shouldDeduct) {
      return (doneBefore + 1).clamp(1, widget.totalSessions).toInt();
    }

    return doneBefore.clamp(0, widget.totalSessions).toInt();
  }

  Future<void> _handleChangeMethod() async {
    if (_mode != _LessonConfirmMode.initial || aifcIsBusy) return;

    HapticFeedback.lightImpact();

    setState(() {
      _mode = _LessonConfirmMode.choosingMethod;
    });

    await aifcUserThenFc(
      userText: '레슨 확정방법 변경하고 싶어요',
      fcText: '레슨 확정 방법을 선택해주세요.',
      groupKey: _LessonConfirmMode.choosingMethod,
      fcChild: _MethodSelectorCard(
        onPickStatus: _handlePickStatus,
      ),
    );
  }

  Future<void> _handlePickStatus(AifcLessonConfirmStatus status) async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    setState(() {
      _selectedStatus = status;
      _mode = _LessonConfirmMode.methodSelected;
    });

    await aifcUserThenFc(
      userText: status.userBubbleText,
      fcText: status.aiBubbleText(_safeMemberName),
      groupKey: _LessonConfirmMode.methodSelected,
      fcChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LessonConfirmCard(
            status: status,
            lessonType: _safeLessonType,
            totalSessions: widget.totalSessions,
            remainBefore: widget.remainBefore,
            remainAfter: _remainAfterFor(status),
            lessonNumber: _lessonNumberFor(status),
          ),
          const SizedBox(height: 10),
          _SelectedLessonActionCard(
            status: status,
            onConfirm: () => _handleConfirm(status),
            onChooseAnother: _handleChooseAnotherMethod,
          ),
        ],
      ),
    );
  }

  Future<void> _handleChooseAnotherMethod() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    setState(() {
      _mode = _LessonConfirmMode.choosingMethod;
    });

    await aifcUserThenFc(
      userText: '다른 방법 선택할게요',
      fcText: '좋아요. 다시 선택해주세요.',
      groupKey: _LessonConfirmMode.choosingMethod,
      fcChild: _MethodSelectorCard(
        onPickStatus: _handlePickStatus,
      ),
    );
  }

  Future<void> _handleConfirm(AifcLessonConfirmStatus status) async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _selectedStatus = status;
    });

    await aifcRunActionThenReply(
      userText: status.confirmUserBubbleText,
      groupKey: 'confirming',
      action: () async {
        await widget.onConfirm?.call(status);
      },
      successText: status.confirmDoneAiBubbleText(_safeMemberName),
      closeAfterReply: true,
      popResult: status,
    );
  }

  Future<void> _handleCancel() async {
    HapticFeedback.lightImpact();

    await aifcHandleCancel(
      isDirty: false,
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
          GestureDetector(
            onTap: _handleCancel,
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

class _LessonConfirmCard extends StatelessWidget {
  const _LessonConfirmCard({
    required this.status,
    required this.lessonType,
    required this.totalSessions,
    required this.remainBefore,
    required this.remainAfter,
    required this.lessonNumber,
  });

  final AifcLessonConfirmStatus status;
  final String lessonType;
  final int totalSessions;
  final int remainBefore;
  final int remainAfter;
  final int lessonNumber;

  @override
  Widget build(BuildContext context) {
    final bool shouldDeduct = status.shouldDeduct;

    final String remainText = shouldDeduct
        ? '총 $totalSessions회 중 $remainBefore회 → $remainAfter회'
        : '총 $totalSessions회 중 $remainBefore회 유지';

    final String lessonRecordText = shouldDeduct && totalSessions > 0
        ? '$lessonNumber/$totalSessions회차로 기록'
        : '회차 소진 없이 기록';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: AifcColors.cardSoftBg,
        borderRadius: BorderRadius.circular(AifcRadius.button),
        border: Border.all(color: AifcColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardRow(label: '처리 방식', value: status.cardTitle),
          const SizedBox(height: 8),
          _CardRow(label: '레슨 형태', value: lessonType),
          const SizedBox(height: 8),
          _CardRow(label: '잔여 레슨', value: remainText),
          const SizedBox(height: 9),
          Container(height: 0.5, color: AifcColors.cardBorder),
          const SizedBox(height: 8),
          Text(
            lessonRecordText,
            style: TextStyle(
              color: status.themeColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialLessonActionCard extends StatelessWidget {
  const _InitialLessonActionCard({
    required this.onConfirm,
    required this.onChangeMethod,
  });

  final VoidCallback onConfirm;
  final VoidCallback onChangeMethod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _BubbleActionButton(
                label: '확정방법 변경',
                foregroundColor: AifcColors.textMuted,
                backgroundColor: Colors.white,
                borderColor: AifcColors.cardBorder,
                onTap: onChangeMethod,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _BubbleActionButton(
                label: '레슨 확정',
                foregroundColor: Colors.white,
                backgroundColor: AifcColors.primary,
                borderColor: AifcColors.primary,
                onTap: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MethodSelectorCard extends StatelessWidget {
  const _MethodSelectorCard({
    required this.onPickStatus,
  });

  final void Function(AifcLessonConfirmStatus status) onPickStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MethodOptionRow(
          label: '노쇼 차감',
          subLabel: '1회 차감',
          color: AifcColors.noShowDeducted,
          onTap: () => onPickStatus(AifcLessonConfirmStatus.noShowDeducted),
        ),
        Container(height: 0.5, color: AifcColors.cardBorder),
        _MethodOptionRow(
          label: '노쇼 미차감',
          subLabel: '차감 없음',
          color: AifcColors.noShowNotDeducted,
          onTap: () => onPickStatus(AifcLessonConfirmStatus.noShowNotDeducted),
        ),
        Container(height: 0.5, color: AifcColors.cardBorder),
        _MethodOptionRow(
          label: '서비스 레슨',
          subLabel: '차감 없음',
          color: AifcColors.service,
          onTap: () => onPickStatus(AifcLessonConfirmStatus.service),
        ),
      ],
    );
  }
}

class _SelectedLessonActionCard extends StatelessWidget {
  const _SelectedLessonActionCard({
    required this.status,
    required this.onConfirm,
    required this.onChooseAnother,
  });

  final AifcLessonConfirmStatus status;
  final VoidCallback onConfirm;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BubbleActionButton(
          label: status.confirmButtonLabel,
          foregroundColor: Colors.white,
          backgroundColor: status.themeColor,
          borderColor: status.themeColor,
          onTap: onConfirm,
        ),
        const SizedBox(height: 8),
        _BubbleActionButton(
          label: '다른 방법 선택',
          foregroundColor: AifcColors.textMuted,
          backgroundColor: Colors.white,
          borderColor: AifcColors.cardBorder,
          onTap: onChooseAnother,
        ),
      ],
    );
  }
}

class _MethodOptionRow extends StatelessWidget {
  const _MethodOptionRow({
    required this.label,
    required this.subLabel,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              subLabel,
              style: TextStyle(
                color: color.withOpacity(0.65),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: color,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleActionButton extends StatelessWidget {
  const _BubbleActionButton({
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
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AifcRadius.button),
          border: Border.all(
            color: borderColor,
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
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

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AifcColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AifcColors.fcText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}