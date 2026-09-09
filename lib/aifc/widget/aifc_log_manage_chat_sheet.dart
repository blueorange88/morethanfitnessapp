import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/aifc_chat_bubble.dart';
import '../core/aifc_chat_flow.dart';
import '../core/aifc_sheet_frame.dart';
import '../core/aifc_theme.dart';

// ─── 레슨 확정 열거형 ─────────────────────────────────────

enum AifcLogStatus {
  normal,
  service,
  noShow,
  noShowNoDeduct,
}

extension AifcLogStatusX on AifcLogStatus {
  String get localKey {
    switch (this) {
      case AifcLogStatus.service:
        return 'service';
      case AifcLogStatus.noShow:
        return 'no_show';
      case AifcLogStatus.noShowNoDeduct:
        return 'no_show_no_deduct';
      case AifcLogStatus.normal:
      default:
        return 'normal';
    }
  }

  static AifcLogStatus fromLocalKey(String key) {
    switch (key) {
      case 'service':
        return AifcLogStatus.service;
      case 'no_show':
        return AifcLogStatus.noShow;
      case 'no_show_no_deduct':
        return AifcLogStatus.noShowNoDeduct;
      case 'normal':
      default:
        return AifcLogStatus.normal;
    }
  }

  String get label {
    switch (this) {
      case AifcLogStatus.service:
        return '서비스 처리';
      case AifcLogStatus.noShow:
        return '노쇼 처리';
      case AifcLogStatus.noShowNoDeduct:
        return '노쇼 미차감';
      case AifcLogStatus.normal:
      default:
        return '일반 레슨';
    }
  }

  String get subLabel {
    switch (this) {
      case AifcLogStatus.service:
        return '차감 없음';
      case AifcLogStatus.noShow:
        return '1회 차감';
      case AifcLogStatus.noShowNoDeduct:
        return '차감 없음';
      case AifcLogStatus.normal:
      default:
        return '1회 차감';
    }
  }

  Color get color {
    switch (this) {
      case AifcLogStatus.service:
        return AifcColors.service;
      case AifcLogStatus.noShow:
        return AifcColors.noShowDeducted;
      case AifcLogStatus.noShowNoDeduct:
        return AifcColors.noShowNotDeducted;
      case AifcLogStatus.normal:
      default:
        return AifcColors.primary;
    }
  }

  String userBubbleText(String memberName) {
    final n = memberName.trim().isEmpty ? '회원' : memberName.trim();
    switch (this) {
      case AifcLogStatus.service:
        return '$n 님 레슨을 서비스 처리할게요';
      case AifcLogStatus.noShow:
        return '$n 님 노쇼 처리할게요';
      case AifcLogStatus.noShowNoDeduct:
        return '$n 님 노쇼 미차감으로 처리할게요';
      case AifcLogStatus.normal:
      default:
        return '$n 님 일반 레슨으로 변경할게요';
    }
  }

  String doneBubbleText(String memberName) {
    final n = memberName.trim().isEmpty ? '회원' : memberName.trim();
    switch (this) {
      case AifcLogStatus.service:
        return '😄 $n 님이 너무 좋아하시겠는데요.\n서비스 레슨으로 기록했어요.';
      case AifcLogStatus.noShow:
        return '$n 님 레슨을 노쇼 1회 차감으로 기록했어요.';
      case AifcLogStatus.noShowNoDeduct:
        return '휴~😅 $n 님 레슨을 노쇼 미차감으로 기록했어요.';
      case AifcLogStatus.normal:
      default:
        return '$n 님 레슨을 일반 레슨으로 변경했어요.';
    }
  }
}

// ─── 시트 모드 열거형 ─────────────────────────────────────

enum _LogManageMode {
  initial,         // 첫 메뉴
  changingStatus, // 확정 방법 선택 중
  statusDone,     // 확정 방법 변경 완료
  unlockPin,      // 확정 취소 PIN 입력 중
  unlockDone,     // 확정 취소 완료
  exitConfirm,    // 진행 중 나가기 확인
}

// ─── 메인 위젯 ────────────────────────────────────────────

class AifcLogManageChatSheet extends StatefulWidget {
  const AifcLogManageChatSheet({
    super.key,
    required this.memberName,
    required this.currentStatus,
    required this.isLocked,
    this.lessonSummaryText = '',
    this.onChangeStatus,
    this.onConfirmCancel,
    this.onViewDetail,
  });

  /// 회원 이름
  final String memberName;

  /// 현재 레슨 상태 ('normal' | 'service' | 'no_show' | 'no_show_no_deduct')
  final String currentStatus;

  /// 잠금 여부
  final bool isLocked;

  /// 예: 2026.06.05 목요일 18:00 PT 레슨
  final String lessonSummaryText;

  /// 상태 변경 콜백
  final Future<void> Function(String newStatus)? onChangeStatus;

  /// PIN 검증 + 실제 확정취소 처리
  final Future<bool> Function(String pin)? onConfirmCancel;

  /// 상세 보기 버튼 콜백
  final VoidCallback? onViewDetail;

  static Future<void> show({
    required BuildContext context,
    required String memberName,
    required String currentStatus,
    required bool isLocked,
    String lessonSummaryText = '',
    Future<void> Function(String newStatus)? onChangeStatus,
    Future<bool> Function(String pin)? onConfirmCancel,
    VoidCallback? onViewDetail,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcLogManageChatSheet(
        memberName: memberName,
        currentStatus: currentStatus,
        isLocked: isLocked,
        lessonSummaryText: lessonSummaryText,
        onChangeStatus: onChangeStatus,
        onConfirmCancel: onConfirmCancel,
        onViewDetail: onViewDetail,
      ),
    );
  }

  @override
  State<AifcLogManageChatSheet> createState() =>
      _AifcLogManageChatSheetState();
}

// ─── State ────────────────────────────────────────────────

class _AifcLogManageChatSheetState extends State<AifcLogManageChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcLogManageChatSheet> {
  _LogManageMode _mode = _LogManageMode.initial;
  _LogManageMode _modeBeforeExitConfirm = _LogManageMode.initial;

  final TextEditingController _pinController = TextEditingController();
  final GlobalKey _pinConfirmButtonKey = GlobalKey();
  bool _pinObscure = true;

  AifcLogStatus get _currentStatus =>
      AifcLogStatusX.fromLocalKey(widget.currentStatus);


  String get _safeName {
    final v = widget.memberName.trim();
    return v.isEmpty ? '회원' : v;
  }

  String get _lessonSummary {
    final value = widget.lessonSummaryText.trim();
    if (value.isEmpty) return '레슨';
    return value;
  }

  // ── 초기화 ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    aifcSetActiveGroup(_LogManageMode.initial);

    aifcAddFcMessage(
      text: '$_safeName 님의 $_lessonSummary 확정 내역 변경을 도와드릴게요.\n어떤 내역 변경을 도와드릴까요?',
      groupKey: _LogManageMode.initial,
      child: _InitialMenuCard(
        currentStatus: _currentStatus,
        isLocked: widget.isLocked,
        onChangeStatus: _handleOpenStatusMenu,
        onUnlock: widget.isLocked ? _handleOpenPinInput : null,
        onViewDetail: _handleViewDetail,
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // ── 상세 보기 ─────────────────────────────────────────

  Future<void> _handleViewDetail() async {
    if (aifcIsBusy) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onViewDetail?.call();
  }

  // ── 상태 변경 메뉴 열기 ───────────────────────────────

  Future<void> _handleOpenStatusMenu() async {
    if (aifcIsBusy) return;
    HapticFeedback.lightImpact();

    setState(() => _mode = _LogManageMode.changingStatus);

    await aifcUserThenFc(
      userText: '레슨 확정 방법을 변경할게요',
      fcText: '레슨 확정 방법 변경 시 회원에게 알림톡이 발송 대상에 추가돼요.\n어떤 방식으로 변경할까요?',
      groupKey: _LogManageMode.changingStatus,
      fcChild: _StatusSelectorCard(
        currentStatus: _currentStatus,
        onPick: _handlePickStatus,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!aifcScrollController.hasClients) return;

      aifcScrollController.animateTo(
        aifcScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ── 상태 선택 후 처리 ─────────────────────────────────

  Future<void> _handlePickStatus(AifcLogStatus next) async {
    if (aifcIsBusy) return;
    HapticFeedback.mediumImpact();

    setState(() => _mode = _LogManageMode.statusDone);

    await aifcRunActionThenReply(
      userText: next.userBubbleText(_safeName),
      groupKey: _LogManageMode.statusDone,
      action: () async {
        await widget.onChangeStatus?.call(next.localKey);
      },
      successText: next.doneBubbleText(_safeName),
      closeAfterReply: true,
    );
  }

  // ── PIN 입력 열기 ─────────────────────────────────────

  Future<void> _scrollChatToBottomAfterKeyboard() async {
    // 메시지 추가 직후 1번
    await Future.delayed(const Duration(milliseconds: 120));

    if (!mounted || !aifcScrollController.hasClients) return;

    await aifcScrollController.animateTo(
      aifcScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );

    // 키보드가 완전히 올라온 뒤 한 번 더
    await Future.delayed(const Duration(milliseconds: 260));

    if (!mounted || !aifcScrollController.hasClients) return;

    await aifcScrollController.animateTo(
      aifcScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _ensurePinConfirmVisible() async {
    // 키보드가 올라오는 시간까지 기다렸다가 여러 번 보정
    for (final delay in const [120, 260, 420]) {
      await Future.delayed(Duration(milliseconds: delay));

      if (!mounted) return;

      final targetContext = _pinConfirmButtonKey.currentContext;

      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.72,
        );
      } else if (aifcScrollController.hasClients) {
        await aifcScrollController.animateTo(
          aifcScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _handleOpenPinInput() async {
    if (aifcIsBusy) return;
    HapticFeedback.lightImpact();

    setState(() => _mode = _LogManageMode.unlockPin);

    await aifcUserThenFc(
      userText: '레슨 확정을 취소할게요',
      fcText: '$_safeName 님의 $_lessonSummary 확정을 취소할까요?\n\n진행하려면 PIN 번호를 입력해주세요.',
      groupKey: _LogManageMode.unlockPin,
      fcChild: _PinInputCard(
        controller: _pinController,
        obscure: _pinObscure,
        confirmButtonKey: _pinConfirmButtonKey,
        onToggleObscure: () => setState(() => _pinObscure = !_pinObscure),
        onSubmit: _handlePinSubmit,
        onInputTap: _ensurePinConfirmVisible,
      ),
    );

    await _ensurePinConfirmVisible();
  }

  // ── PIN 제출 ──────────────────────────────────────────

  Future<void> _handlePinSubmit() async {
    if (aifcIsBusy) return;

    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    HapticFeedback.mediumImpact();

    setState(() => _mode = _LogManageMode.unlockDone);

    await aifcRunActionThenReply(
      userText: 'PIN 입력 완료',
      groupKey: _LogManageMode.unlockDone,
      action: () async {
        final ok = await widget.onConfirmCancel?.call(pin) ?? false;
        if (!ok) throw Exception('pin_wrong');
      },
      successText: '레슨 확정취소가 완료됐어요.\n홈 스케줄표와 회원카드 회차에도 함께 반영했어요.',
      errorText: 'PIN이 맞지 않거나 레슨 확정취소 중 오류가 발생했어요.\n다시 확인해주세요.',
      closeAfterReply: true,
    );
  }


  // ── 취소 ──────────────────────────────────────────────

  bool get _isChangingFlow {
    return _mode != _LogManageMode.initial ||
        _pinController.text
            .trim()
            .isNotEmpty ||
        aifcMessages.length > 1;
  }

  Future<void> _handleCancel() async {
    await _handleCancelTap();
  }

  Future<void> _handleBackPressed() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    // 이미 "나갈까요?" 확인 대화가 떠 있는 상태에서
    // 뒤로가기를 한 번 더 누르면 바로 닫기
    if (_mode == _LogManageMode.exitConfirm) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (!_isChangingFlow) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    await _openExitConfirmChat();
  }

  Future<void> _handleCancelTap() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openExitConfirmChat() async {
    if (_mode == _LogManageMode.exitConfirm) return;

    _modeBeforeExitConfirm = _mode;

    setState(() {
      _mode = _LogManageMode.exitConfirm;
    });

    await aifcUserThenFc(
      userText: '취소 할게요',
      fcText: '레슨 확정 내역 변경을 나중에 할까요?\n\n'
          '$_safeName 님 레슨 확정 내역 변경을 취소할까요?\n'
          '* 작성한 내용은 사라져요.',
      groupKey: _LogManageMode.exitConfirm,
      fcChild: _ExitConfirmCard(
        onContinue: _handleContinueAfterExitConfirm,
        onExit: _handleExitAfterConfirm,
      ),
    );
  }

  Future<void> _handleContinueAfterExitConfirm() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    setState(() {
      _mode = _modeBeforeExitConfirm;
    });

    aifcSetActiveGroup(_modeBeforeExitConfirm);
  }

  Future<void> _handleExitAfterConfirm() async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── 빌드 ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;

    return WillPopScope(
      onWillPop: () async {
        await _handleBackPressed();
        return false;
      },
      child: AifcSheetFrame(
        maxHeightFactor: 0.80,
        children: [
          Flexible(
            child: SingleChildScrollView(
              controller: aifcScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                keyboardOpen ? 220 : 18,
              ),
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
          else if (_mode != _LogManageMode.exitConfirm)
            SafeArea(
              top: false,
              child: GestureDetector(
                onTap: _handleCancelTap,
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
            )
          else
            const SizedBox(height: 10),
        ],
      ),

    );
  }
}

// ─── 초기 메뉴 카드 ────────────────────────────────────────

class _InitialMenuCard extends StatelessWidget {
  const _InitialMenuCard({
    required this.currentStatus,
    required this.isLocked,
    required this.onChangeStatus,
    this.onUnlock,
    this.onViewDetail,
  });

  final AifcLogStatus currentStatus;
  final bool isLocked;
  final VoidCallback onChangeStatus;
  final VoidCallback? onUnlock;
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurrentStatusRow(status: currentStatus, isLocked: isLocked),
        const SizedBox(height: 10),

        if (isLocked) ...[
          _NoticeBox(
            text: '레슨 확정 방법 변경 또는 확정 취소 시 회원에게 알림톡이 발송 대상에 추가돼요.',
          ),
          const SizedBox(height: 10),
        ],

        if (onViewDetail != null) ...[
          _MenuRow(
            icon: Icons.visibility_outlined,
            label: '상세 보기',
            color: AifcColors.textMuted,
            onTap: onViewDetail!,
          ),
          _Divider(),
        ],

        if (!isLocked)
          _MenuRow(
            icon: Icons.tune_rounded,
            label: '레슨 확정 방법 변경',
            subLabel: currentStatus.label,
            color: AifcColors.primary,
            onTap: onChangeStatus,
          ),

        if (isLocked && onUnlock != null) ...[
          _Divider(),
          _MenuRow(
            icon: Icons.lock_open_rounded,
            label: '레슨 확정 취소',
            subLabel: '알림톡 발송 · PIN 필요',
            color: AifcColors.warning,
            onTap: onUnlock!,
          ),
        ],
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AifcRadius.button),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 현재 상태 표시 행 ────────────────────────────────────

class _CurrentStatusRow extends StatelessWidget {
  const _CurrentStatusRow({
    required this.status,
    required this.isLocked,
  });

  final AifcLogStatus status;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AifcColors.cardSoftBg,
        borderRadius: BorderRadius.circular(AifcRadius.button),
        border: Border.all(color: AifcColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Text(
            '현재 상태',
            style: const TextStyle(
              color: AifcColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AifcRadius.chip),
              border: Border.all(color: status.color.withOpacity(0.30)),
            ),
            child: Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (isLocked) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(AifcRadius.chip),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Text(
                '확정됨',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 상태 선택 카드 ───────────────────────────────────────

class _StatusSelectorCard extends StatelessWidget {
  const _StatusSelectorCard({
    required this.currentStatus,
    required this.onPick,
  });

  final AifcLogStatus currentStatus;
  final void Function(AifcLogStatus) onPick;

  @override
  Widget build(BuildContext context) {
    final options = [
      AifcLogStatus.normal,
      AifcLogStatus.service,
      AifcLogStatus.noShow,
      AifcLogStatus.noShowNoDeduct,
    ];

    return Column(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) _Divider(),
          _StatusOptionRow(
            status: options[i],
            isCurrent: options[i] == currentStatus,
            onTap: () => onPick(options[i]),
          ),
        ],
      ],
    );
  }
}

class _StatusOptionRow extends StatelessWidget {
  const _StatusOptionRow({
    required this.status,
    required this.isCurrent,
    required this.onTap,
  });

  final AifcLogStatus status;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCurrent ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    status.label,
                    style: TextStyle(
                      color: isCurrent
                          ? status.color.withOpacity(0.45)
                          : status.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: status.color.withOpacity(0.10),
                        borderRadius:
                        BorderRadius.circular(AifcRadius.chip),
                      ),
                      child: Text(
                        '현재',
                        style: TextStyle(
                          color: status.color.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              status.subLabel,
              style: TextStyle(
                color: isCurrent
                    ? status.color.withOpacity(0.35)
                    : status.color.withOpacity(0.65),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isCurrent
                  ? status.color.withOpacity(0.25)
                  : status.color,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PIN 입력 카드 ────────────────────────────────────────

class _PinInputCard extends StatelessWidget {
  const _PinInputCard({
    required this.controller,
    required this.obscure,
    required this.confirmButtonKey,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onInputTap,
  });

  final TextEditingController controller;
  final bool obscure;
  final GlobalKey confirmButtonKey;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onInputTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 안내 박스
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(AifcRadius.button),
            border: Border.all(color: const Color(0xFFFDE68A), width: 0.5),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: Color(0xFF92400E)),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  '레슨 확정 취소 시 회원에게 알림톡이 발송 대상에 추가돼요.\n레슨일지에는 취소 이력이 남고, 회차와 홈 스케줄표도 함께 정리됩니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // PIN 입력 필드
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AifcRadius.button),
            border: Border.all(color: AifcColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onTap: onInputTap,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: 'PIN 번호 입력',
                    hintStyle: const TextStyle(
                      color: AifcColors.textHint,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    color: AifcColors.fcText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: AifcColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 확인 버튼
        KeyedSubtree(
          key: confirmButtonKey,
          child: _ActionButton(
            label: 'PIN 확인',
            color: AifcColors.warning,
            onTap: onSubmit,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ExitConfirmCard extends StatelessWidget {
  const _ExitConfirmCard({
    required this.onContinue,
    required this.onExit,
  });

  final VoidCallback onContinue;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionButton(
          label: '계속 진행',
          color: AifcColors.primary,
          onTap: onContinue,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onExit,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(color: AifcColors.cardBorder),
            ),
            child: const Text(
              '취소 할게요',
              style: TextStyle(
                color: AifcColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 공통 메뉴 행 ─────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subLabel,
  });

  final IconData icon;
  final String label;
  final String? subLabel;
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
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 8),
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
            if (subLabel != null) ...[
              Text(
                subLabel!,
                style: TextStyle(
                  color: color.withOpacity(0.60),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right_rounded, size: 17, color: color),
          ],
        ),
      ),
    );
  }
}



// ─── 공통 액션 버튼 ───────────────────────────────────────


class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AifcRadius.button),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ─── 구분선 ───────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: AifcColors.cardBorder);
}