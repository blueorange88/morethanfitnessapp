import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';
import '../theme/app_colors.dart';
import '../services/app_account_service.dart' show appAccountErrorMessage;
import '../services/personal_member_card_save_service.dart';

class AifcQuickRegisterResult {
  const AifcQuickRegisterResult({
    required this.name,
    required this.phone,
    required this.consultDate,
    required this.goDetail,
  });

  final String name;
  final String phone;
  final DateTime? consultDate;
  final bool goDetail;
}

class AifcQuickRegisterChatSheet extends StatefulWidget {
  const AifcQuickRegisterChatSheet({
    super.key,
    required this.nickname,
    required this.onFastSave,
    this.onAccountLink,
  });

  final String nickname;
  final Future<void> Function(AifcQuickRegisterResult result) onFastSave;
  final Future<bool> Function()? onAccountLink;

  static Future<AifcQuickRegisterResult?> show({
    required BuildContext context,
    required String nickname,
    required Future<void> Function(AifcQuickRegisterResult result) onFastSave,
    Future<bool> Function()? onAccountLink,
  }) {
    return showModalBottomSheet<AifcQuickRegisterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => AifcQuickRegisterChatSheet(
            nickname: nickname,
            onFastSave: onFastSave,
            onAccountLink: onAccountLink,
          ),
    );
  }

  @override
  State<AifcQuickRegisterChatSheet> createState() =>
      _AifcQuickRegisterChatSheetState();
}

class _AifcQuickRegisterChatSheetState extends State<AifcQuickRegisterChatSheet>
    with
        TickerProviderStateMixin,
        AifcChatFlowMixin<AifcQuickRegisterChatSheet> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();

  DateTime? _consultDate;
  bool _discardPromptVisible = false;
  bool _accountLinkPromptVisible = false;
  String? _lastValidationMessage;

  @override
  void initState() {
    super.initState();

    _nameC.addListener(_handleInputChanged);
    _phoneC.addListener(_handleInputChanged);

    aifcSetActiveGroup('quick_register');

    aifcAddFcMessage(
      text: '$_safeNickname, 바쁘시죠?\n이름과 휴대폰 번호만 알려주시면 제가 먼저 등록해둘게요.',
      groupKey: 'quick_register',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '상담 예약일이 있다면 함께 남겨주세요.\n일정이 가까워지면 제가 챙겨드릴게요.',
            style: TextStyle(
              color: AifcColors.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _RegisterInputCard(
            nameC: _nameC,
            phoneC: _phoneC,
            consultDateText: _formatDate(_consultDate),
            onConsultDateTap: _pickConsultDate,
            onClearConsultDate:
                _consultDate == null
                    ? null
                    : () {
                      setState(() {
                        _consultDate = null;
                        _discardPromptVisible = false;
                        _lastValidationMessage = null;
                      });
                    },
          ),
          const SizedBox(height: 12),
          _QuickRegisterActionCard(
            onFastSave: () => _submit(goDetail: false),
            onGoDetail: () => _submit(goDetail: true),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameC.removeListener(_handleInputChanged);
    _phoneC.removeListener(_handleInputChanged);

    _nameC.dispose();
    _phoneC.dispose();

    super.dispose();
  }

  String get _safeNickname {
    return aifcNicknameLabel(widget.nickname);
  }

  bool get _isDirty {
    return _nameC.text.trim().isNotEmpty ||
        _phoneC.text.trim().isNotEmpty ||
        _consultDate != null;
  }

  void _handleInputChanged() {
    if (!mounted) return;

    if (_discardPromptVisible || _lastValidationMessage != null) {
      setState(() {
        _discardPromptVisible = false;
        _lastValidationMessage = null;
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '선택 안 함';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickConsultDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _consultDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null) return;

    setState(() {
      _consultDate = picked;
      _discardPromptVisible = false;
      _lastValidationMessage = null;
    });
  }

  Future<void> _submit({required bool goDetail}) async {
    if (aifcIsBusy) return;

    final name = _nameC.text.trim();
    final phone = _phoneC.text.trim().replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty) {
      _showValidationBubble('이름을 먼저 입력해주세요.');
      return;
    }

    if (phone.isEmpty) {
      _showValidationBubble('휴대폰 번호를 입력해주세요.');
      return;
    }

    if (phone.length < 9 || phone.length > 11) {
      _showValidationBubble('휴대폰 번호 형식을 확인해주세요.');
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _discardPromptVisible = false;
      _lastValidationMessage = null;
    });

    final result = AifcQuickRegisterResult(
      name: name,
      phone: phone,
      consultDate: _consultDate,
      goDetail: goDetail,
    );

    final memberLabel = aifcPersonLabel(name);

    await aifcRunActionThenReply(
      userText: goDetail ? '고객카드까지 이어서 작성할게요' : '빠른등록할게요',
      groupKey: 'quick_register_done',
      action: () async {
        if (goDetail) {
          await Future.delayed(const Duration(milliseconds: 250));
          return;
        }
        await widget.onFastSave(result);
      },
      successText:
          goDetail
              ? '$memberLabel 기본 정보를 먼저 등록하고,\n고객카드 작성으로 이어갈게요.'
              : '$memberLabel을 등록했어요.\n필요하면 고객카드에서 더 자세히 채울 수 있어요.',
      errorTextBuilder: personalMemberUpdateErrorMessage,
      onError: _handleSubmitError,
      closeAfterReply: true,
      popResult: result,
    );
  }

  void _handleSubmitError(Object error) {
    _accountLinkPromptVisible =
        personalMemberUpdateRequiresAccountLink(error) &&
        widget.onAccountLink != null;
  }

  Future<void> _openAccountConnection() async {
    final onAccountLink = widget.onAccountLink;
    if (aifcIsBusy || onAccountLink == null) return;

    HapticFeedback.mediumImpact();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      aifcLoading = true;
    });

    var linked = false;
    Object? linkError;
    try {
      linked = await onAccountLink();
    } catch (error) {
      linkError = error;
    } finally {
      if (mounted) {
        setState(() {
          aifcLoading = false;
        });
      }
    }
    if (!mounted) return;
    if (linkError != null) {
      aifcAddFcMessage(
        text: appAccountErrorMessage(linkError),
        groupKey: 'quick_register_account_link_error',
      );
      return;
    }
    if (!linked) return;

    setState(() {
      _accountLinkPromptVisible = false;
    });
    aifcSetActiveGroup('quick_register_account_linked');
    aifcAddFcMessage(
      text: '계정이 연결됐어요. 입력한 내용은 그대로예요.\n빠른등록을 다시 눌러주세요.',
      groupKey: 'quick_register_account_linked',
    );
  }

  void _showValidationBubble(String message) {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    if (_lastValidationMessage == message) {
      aifcSetActiveGroup('quick_register_validation');
      aifcScrollToBottom();
      return;
    }

    _lastValidationMessage = message;

    aifcSetActiveGroup('quick_register_validation');

    aifcAddFcMessage(text: message, groupKey: 'quick_register_validation');
  }

  Future<void> _handleCancel() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    if (!_isDirty) {
      Navigator.of(context).pop(null);
      return;
    }

    if (_discardPromptVisible) {
      aifcScrollToBottom();
      return;
    }

    setState(() {
      _discardPromptVisible = true;
    });
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;

    await aifcUserThenFc(
      userText: '취소할게요',
      fcText: '작성 중인 고객등록을 닫을까요?\n지금 닫으면 입력한 내용은 저장되지 않아요.',
      groupKey: 'quick_register_discard',
      fcChild: Row(
        children: [
          Expanded(
            child: _SmallActionButton(
              label: '계속 작성',
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              backgroundColor: tokens.aifcInputSurface,
              borderColor: tokens.cardBorder,
              onTap: () {
                _handleKeepWriting();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SmallActionButton(
              label: '닫기',
              foregroundColor: Colors.white,
              backgroundColor: AifcColors.noShowDeducted,
              borderColor: AifcColors.noShowDeducted,
              onTap: () {
                _closeWithoutSaving();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleKeepWriting() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    setState(() {
      _discardPromptVisible = false;
      _lastValidationMessage = null;
    });

    await aifcUserThenFc(
      userText: '계속 작성할게요',
      fcText: '좋아요. 이어서 작성해주세요.',
      groupKey: 'quick_register',
    );
  }

  void _closeWithoutSaving() {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                    dimmed:
                        aifcMessages[i].groupKey != null &&
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_accountLinkPromptVisible)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _SmallActionButton(
                    label: '계정 연결하기',
                    foregroundColor: colorScheme.onSecondary,
                    backgroundColor: colorScheme.secondary,
                    borderColor: colorScheme.secondary,
                    onTap: _openAccountConnection,
                  ),
                ),
              GestureDetector(
                onTap: _handleCancel,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RegisterInputCard extends StatelessWidget {
  const _RegisterInputCard({
    required this.nameC,
    required this.phoneC,
    required this.consultDateText,
    required this.onConsultDateTap,
    required this.onClearConsultDate,
  });

  final TextEditingController nameC;
  final TextEditingController phoneC;
  final String consultDateText;
  final VoidCallback onConsultDateTap;
  final VoidCallback? onClearConsultDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Column(
      children: [
        TextField(
          controller: nameC,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(context, label: '이름', hint: '예: 김모어'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phoneC,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: _inputDecoration(
            context,
            label: '휴대폰 번호',
            hint: '01012345678',
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onConsultDateTap,
          borderRadius: BorderRadius.circular(AifcRadius.button),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.aifcInputSurface,
              borderRadius: BorderRadius.circular(AifcRadius.button),
              border: Border.all(color: tokens.cardBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '상담 예약일 · $consultDateText',
                    style: TextStyle(
                      color:
                          consultDateText == '선택 안 함'
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onClearConsultDate != null)
                  GestureDetector(
                    onTap: onClearConsultDate,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: tokens.aifcInputSurface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.cardBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.cardBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.secondary, width: 1.2),
      ),
    );
  }
}

class _QuickRegisterActionCard extends StatelessWidget {
  const _QuickRegisterActionCard({
    required this.onFastSave,
    required this.onGoDetail,
  });

  final VoidCallback onFastSave;
  final VoidCallback onGoDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SmallActionButton(
          label: '빠른등록',
          foregroundColor: scheme.onSecondary,
          backgroundColor: scheme.secondary,
          borderColor: scheme.secondary,
          onTap: onFastSave,
        ),
        const SizedBox(height: 8),
        _SmallActionButton(
          label: '고객카드까지 이어서 작성하기',
          foregroundColor: scheme.primary,
          backgroundColor: scheme.secondaryContainer,
          borderColor: scheme.outline,
          onTap: onGoDetail,
        ),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
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
