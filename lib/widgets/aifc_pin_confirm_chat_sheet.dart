import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';

class AifcPinConfirmChatSheet extends StatefulWidget {
  const AifcPinConfirmChatSheet({
    super.key,
    required this.title,
    required this.question,
    required this.onVerify,
    this.nickname = '강사',
    this.pinGuide,
    this.inputLabel,
    this.successText = '확인됐어요.\n이어서 진행할게요.',
    this.wrongText = 'PIN이 맞지 않아요.\n다시 입력해주세요.',
    this.errorText = 'PIN 확인 중 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
    this.minLength = 4,
    this.maxLength = 6,
  });

  final String title;
  final String question;
  final Future<bool> Function(String pin) onVerify;

  final String nickname;
  final String? pinGuide;
  final String? inputLabel;
  final String successText;
  final String wrongText;
  final String errorText;

  final int minLength;
  final int maxLength;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String question,
    required Future<bool> Function(String pin) onVerify,
    String nickname = '강사',
    String? pinGuide,
    String? inputLabel,
    String successText = '확인됐어요.\n이어서 진행할게요.',
    String wrongText = 'PIN이 맞지 않아요.\n다시 입력해주세요.',
    String errorText = 'PIN 확인 중 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
    int minLength = 4,
    int maxLength = 6,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcPinConfirmChatSheet(
        title: title,
        question: question,
        onVerify: onVerify,
        nickname: nickname,
        pinGuide: pinGuide,
        inputLabel: inputLabel,
        successText: successText,
        wrongText: wrongText,
        errorText: errorText,
        minLength: minLength,
        maxLength: maxLength,
      ),
    );
  }

  @override
  State<AifcPinConfirmChatSheet> createState() =>
      _AifcPinConfirmChatSheetState();
}

class _AifcPinConfirmChatSheetState extends State<AifcPinConfirmChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcPinConfirmChatSheet> {
  static const _groupInitial = 'pin_initial';

  String get _safeNickname => normalizeAifcNickname(widget.nickname);

  String get _safeNicknameLabel => aifcNicknameLabel(widget.nickname);

  static const _groupChecking = 'pin_checking';
  static const _groupRetry = 'pin_retry';

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
          _PinConfirmQuestionBlock(
            title: widget.title,
            message: widget.question,
            pinGuide: widget.pinGuide ??
                '진행하려면 $_safeNicknameLabel PIN 번호를 입력해주세요.',
          ),
          const SizedBox(height: 12),
          _PinInputCard(
            inputLabel: widget.inputLabel ?? '$_safeNicknameLabel PIN',
            minLength: widget.minLength,
            maxLength: widget.maxLength,
            submitLabel: '확인',
            onSubmit: _handleSubmitPin,
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmitPin(String pin) async {
    if (aifcIsBusy) return;

    final value = pin.trim();
    if (value.length < widget.minLength) return;

    HapticFeedback.mediumImpact();

    aifcSetActiveGroup(_groupChecking);

    aifcAddUserMessage(
      text: 'PIN 입력했어요',
      groupKey: _groupChecking,
    );

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    setState(() {
      aifcShowTyping = true;
      aifcLoading = true;
    });

    aifcScrollToBottom();

    bool verified = false;
    bool failedByError = false;

    try {
      await Future.wait<void>([
        Future.delayed(aifcTypingDuration),
            () async {
          verified = await widget.onVerify(value);
        }(),
      ]);
    } catch (_) {
      failedByError = true;
    }

    if (!mounted) return;

    setState(() {
      aifcShowTyping = false;
      aifcLoading = false;
    });

    if (failedByError) {
      aifcAddFcMessage(
        text: widget.errorText,
        groupKey: _groupRetry,
        child: _PinInputCard(
          inputLabel: widget.inputLabel ?? '$_safeNicknameLabel PIN',
          minLength: widget.minLength,
          maxLength: widget.maxLength,
          submitLabel: '다시 확인',
          onSubmit: _handleSubmitPin,
        ),
      );
      aifcSetActiveGroup(_groupRetry);
      return;
    }

    if (!verified) {
      HapticFeedback.lightImpact();

      aifcAddFcMessage(
        text: widget.wrongText,
        groupKey: _groupRetry,
        child: _PinInputCard(
          inputLabel: widget.inputLabel ?? '$_safeNicknameLabel PIN',
          minLength: widget.minLength,
          maxLength: widget.maxLength,
          submitLabel: '다시 확인',
          onSubmit: _handleSubmitPin,
        ),
      );

      aifcSetActiveGroup(_groupRetry);
      return;
    }

    aifcAddFcMessage(
      text: widget.successText,
      groupKey: _groupChecking,
    );

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(true);
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

class _PinInputCard extends StatefulWidget {
  const _PinInputCard({
    required this.inputLabel,
    required this.minLength,
    required this.maxLength,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String inputLabel;
  final int minLength;
  final int maxLength;
  final String submitLabel;
  final void Function(String pin) onSubmit;

  @override
  State<_PinInputCard> createState() => _PinInputCardState();
}

class _PinInputCardState extends State<_PinInputCard> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool get _canSubmit {
    return _controller.text.trim().length >= widget.minLength;
  }

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _submit() {
    if (!_canSubmit) return;

    widget.onSubmit(_controller.text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.maxLength),
          ],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: widget.inputLabel,
            hintText: '${widget.minLength}자리 이상 입력',
            filled: true,
            fillColor: AifcColors.cardSoftBg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AifcRadius.button),
              borderSide: const BorderSide(
                color: AifcColors.cardBorder,
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AifcRadius.button),
              borderSide: const BorderSide(
                color: AifcColors.cardBorder,
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AifcRadius.button),
              borderSide: const BorderSide(
                color: AifcColors.primary,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _canSubmit ? _submit : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedOpacity(
            opacity: _canSubmit ? 1.0 : 0.42,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AifcColors.primary,
                borderRadius: BorderRadius.circular(AifcRadius.button),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.submitLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinConfirmQuestionBlock extends StatelessWidget {
  const _PinConfirmQuestionBlock({
    required this.title,
    required this.message,
    required this.pinGuide,
  });

  final String title;
  final String message;
  final String pinGuide;

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
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: AifcColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AifcRadius.button),
            border: Border.all(
              color: AifcColors.primary.withOpacity(0.16),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AifcColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  pinGuide,
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
    );
  }
}