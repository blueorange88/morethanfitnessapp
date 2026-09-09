import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../core/aifc_chat_bubble.dart';
import '../core/aifc_sheet_frame.dart';
import '../core/aifc_typing_dots.dart';

class AifcChatSheet extends StatefulWidget {
  const AifcChatSheet({
    super.key,
    required this.question,
    required this.inputLabel,
    required this.onSave,
    this.initialValue = '',
    this.keyboardType,
    this.maxLines = 1,
    this.skipLabel = '나중에 알려드릴게요',
    this.autoCompleteHints = const [],
    this.skipClosesImmediately = false,
    this.onSkip,
  });

  final String question;
  final String inputLabel;
  final Future<String> Function(String value) onSave;
  final String initialValue;
  final TextInputType? keyboardType;
  final int maxLines;
  final String skipLabel;
  final List<String> autoCompleteHints;
  final bool skipClosesImmediately;
  final VoidCallback? onSkip;

  static Future<String?> show({
    required BuildContext context,
    required String question,
    required String inputLabel,
    required Future<String> Function(String value) onSave,
    String initialValue = '',
    TextInputType? keyboardType,
    int maxLines = 1,
    String skipLabel = '나중에 알려드릴게요',
    List<String> autoCompleteHints = const [],
    VoidCallback? onSkip,
    bool skipClosesImmediately = false,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcChatSheet(
        question: question,
        inputLabel: inputLabel,
        onSave: onSave,
        initialValue: initialValue,
        keyboardType: keyboardType,
        maxLines: maxLines,
        skipLabel: skipLabel,
        autoCompleteHints: autoCompleteHints,
        onSkip: onSkip,
        skipClosesImmediately: skipClosesImmediately,
      ),
    );
  }

  @override
  State<AifcChatSheet> createState() => _AifcChatSheetState();
}

enum _BubbleType {
  fc,
  user,
}

class _Bubble {
  const _Bubble({
    required this.type,
    required this.text,
  });

  final _BubbleType type;
  final String text;
}

class _AifcChatSheetState extends State<AifcChatSheet>
    with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_Bubble> _bubbles = [];
  final List<AnimationController> _bubbleAnims = [];

  Timer? _typingDebounce;

  bool _fcIsTyping = false;
  bool _userIsTyping = false;
  bool _answered = false;
  bool _isSaving = false;
  bool _inputFocused = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialValue.trim().isNotEmpty) {
      _inputCtrl.text = widget.initialValue.trim();
    }

    _addBubble(
      _Bubble(
        type: _BubbleType.fc,
        text: widget.question,
      ),
    );

    _inputCtrl.addListener(_onInputChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();

    _inputCtrl.removeListener(_onInputChanged);
    _focusNode.removeListener(_onFocusChanged);

    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();

    for (final controller in _bubbleAnims) {
      controller.dispose();
    }

    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;

    setState(() {
      _inputFocused = _focusNode.hasFocus;
    });
  }

  void _addBubble(_Bubble bubble) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _bubbles.add(bubble);
    _bubbleAnims.add(controller);

    controller.forward();
    _scrollToBottom();
  }

  void _onInputChanged() {
    if (_answered) return;

    _typingDebounce?.cancel();

    final hasText = _inputCtrl.text.trim().isNotEmpty;

    setState(() {
      _userIsTyping = hasText;
      _fcIsTyping = false;
    });

    _scrollToBottom();
  }

  List<String> _autoCompleteMatches() {
    if (_answered || _isSaving) return const [];

    final query = _inputCtrl.text.trim().toLowerCase();

    if (query.isEmpty) return const [];

    final seen = <String>{};
    final hints = <String>[];

    for (final raw in widget.autoCompleteHints) {
      final text = raw.trim();
      if (text.isEmpty) continue;

      final key = text.toLowerCase();
      if (seen.contains(key)) continue;

      if (key.contains(query)) {
        seen.add(key);
        hints.add(text);
      }
    }

    return hints.take(4).toList();
  }

  void _applyAutoCompleteHint(String value) {
    if (_answered || _isSaving) return;

    _inputCtrl.text = value;
    _inputCtrl.selection = TextSelection.collapsed(offset: value.length);
    _focusNode.requestFocus();

    setState(() {
      _userIsTyping = value.trim().isNotEmpty;
      _fcIsTyping = false;
    });
  }

  Future<void> _submit() async {
    if (_answered || _isSaving) return;

    final value = _inputCtrl.text.trim();
    if (value.isEmpty) return;

    _answered = true;
    _typingDebounce?.cancel();

    setState(() {
      _userIsTyping = false;
      _fcIsTyping = false;
      _isSaving = true;
    });

    _addBubble(
      _Bubble(
        type: _BubbleType.user,
        text: value,
      ),
    );

    _inputCtrl.clear();
    _focusNode.unfocus();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _fcIsTyping = true;
    });

    _scrollToBottom();

    String replyText = '';
    var saveSucceeded = false;

    try {
      replyText = await widget.onSave(value);
      saveSucceeded = true;
    } catch (_) {
      replyText = '저장하지 못했어요.\n다시 시도해주세요.';
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _fcIsTyping = false;
      _isSaving = false;
    });

    _addBubble(
      _Bubble(
        type: _BubbleType.fc,
        text: replyText.isNotEmpty
            ? replyText
            : '$value(으)로 안내할게요 😊\n언제든 마이페이지에서 바꿀 수 있어요.',
      ),
    );

    if (!saveSucceeded) {
      setState(() {
        _answered = false;
      });
      _inputCtrl.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      _focusNode.requestFocus();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;

    Navigator.of(context).pop(value);
  }

  Future<void> _skip() async {
    if (_answered) return;

    _answered = true;
    _typingDebounce?.cancel();

    setState(() {
      _userIsTyping = false;
      _fcIsTyping = false;
      _isSaving = false;
    });

    widget.onSkip?.call();

    // 1) 사용자가 "나중에"라고 보낸 것처럼 오른쪽 말풍선 추가
    _addBubble(
      _Bubble(
        type: _BubbleType.user,
        text: widget.skipLabel.trim().isEmpty
            ? '나중에 알려드릴게요'
            : widget.skipLabel.replaceAll('알려드릴게요', '').trim().isEmpty
                ? '나중에 알려드릴게요'
                : '나중에 알려드릴게요',
      ),
    );

    _inputCtrl.clear();
    _focusNode.unfocus();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 2) FC가 생각하는 중
    setState(() {
      _fcIsTyping = true;
    });

    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    // 3) FC 답변
    setState(() {
      _fcIsTyping = false;
    });

    _addBubble(
      const _Bubble(
        type: _BubbleType.fc,
        text: '좋아요. 천천히 알려주세요 😄\n필요할 때 제가 다시 여쭤볼게요.',
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;

    Navigator.of(context).pop(null);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollCtrl.hasClients) return;

      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      showHandle: true,
      maxHeightFactor: null,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(_bubbles.length, (index) {
                  return _AnimatedBubble(
                    controller: _bubbleAnims[index],
                    child: _buildBubble(_bubbles[index]),
                  );
                }),
                if (_userIsTyping) _buildUserTypingBubble(),
                if (_fcIsTyping) _buildFcTypingBubble(),
              ],
            ),
          ),
        ),
        if (!_answered) ...[
          _buildAutoCompleteHints(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _buildInputRow(),
          ),
          if (widget.onSkip != null)
            GestureDetector(
              onTap: widget.skipClosesImmediately
                  ? () {
                      widget.onSkip?.call();
                      Navigator.of(context).pop(null);
                    }
                  : _skip,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  widget.skipLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ] else
          const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBubble(_Bubble bubble) {
    final side =
        bubble.type == _BubbleType.fc ? AifcBubbleSide.fc : AifcBubbleSide.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AifcChatBubble(
        side: side,
        text: bubble.text,
      ),
    );
  }

  Widget _buildFcTypingBubble() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AifcTypingBubble(),
    );
  }

  Widget _buildUserTypingBubble() {
    final tokens = context.mtfThemeTokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: tokens.aifcUserBubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.aifcUserBubble.withOpacity(0.24),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AifcTypingDots(
            color: tokens.aifcUserBubbleForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildAutoCompleteHints() {
    final matches = _autoCompleteMatches();
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;

    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: tokens.aifcSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '자동완성',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            ...matches.map((item) {
              return InkWell(
                onTap: () => _applyAutoCompleteHint(item),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.north_west_rounded,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;

    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: tokens.aifcInputSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _inputFocused || hasText
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline,
          width: _inputFocused || hasText ? 1.5 : 1,
        ),
        boxShadow: _inputFocused
            ? [
                BoxShadow(
                  color: theme.colorScheme.secondary.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Expanded(
              child: TextField(
            controller: _inputCtrl,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            autofocus: true,
            textInputAction: widget.maxLines == 1
                ? TextInputAction.send
                : TextInputAction.newline,
            onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
            decoration: InputDecoration(
              hintText: widget.inputLabel,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )),
          AnimatedOpacity(
            opacity: hasText ? 1.0 : 0.28,
            duration: const Duration(milliseconds: 60),
            child: GestureDetector(
              onTap: hasText ? _submit : null,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                  boxShadow: hasText
                      ? [
                          BoxShadow(
                            color:
                                theme.colorScheme.secondary.withOpacity(0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: theme.colorScheme.onSecondary,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBubble extends StatelessWidget {
  const _AnimatedBubble({
    required this.controller,
    required this.child,
  });

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ),
    );

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}
