import 'package:flutter/material.dart';

import 'aifc_chat_bubble.dart';

class AifcChatFlowMessage {
  const AifcChatFlowMessage({
    required this.side,
    required this.text,
    this.child,
    this.groupKey,
  });

  final AifcBubbleSide side;
  final String text;
  final Widget? child;

  /// 현재 단계 구분용입니다.
  /// 예: 'initial', 'choosingMethod', 'confirming'
  final Object? groupKey;
}

class AifcAnimatedChatMessage extends StatelessWidget {
  const AifcAnimatedChatMessage({
    super.key,
    required this.controller,
    required this.child,
    this.dimmed = false,
  });

  final AnimationController controller;
  final Widget child;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
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
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: dimmed ? 0.55 : 1.0,
          child: child,
        ),
      ),
    );
  }
}

mixin AifcChatFlowMixin<T extends StatefulWidget>
on State<T>, TickerProviderStateMixin<T> {
  final ScrollController aifcScrollController = ScrollController();

  final List<AifcChatFlowMessage> aifcMessages = [];
  final List<AnimationController> aifcMessageAnimations = [];

  bool aifcShowTyping = false;
  bool aifcLoading = false;
  bool aifcFetching = false;

  Object? aifcActiveGroupKey;

  bool get aifcIsBusy {
    return aifcShowTyping || aifcLoading || aifcFetching;
  }

  Duration get aifcMessageAnimationDuration {
    return const Duration(milliseconds: 280);
  }

  Duration get aifcTypingDuration {
    return const Duration(milliseconds: 780);
  }

  Duration get aifcCloseAfterReplyDelay {
    return const Duration(milliseconds: 850);
  }

  @override
  void dispose() {
    aifcScrollController.dispose();

    for (final controller in aifcMessageAnimations) {
      controller.dispose();
    }

    super.dispose();
  }

  void aifcSetActiveGroup(Object? groupKey) {
    if (!mounted) return;

    setState(() {
      aifcActiveGroupKey = groupKey;
    });
  }

  void aifcAddMessage(AifcChatFlowMessage message) {
    if (!mounted) return;

    final controller = AnimationController(
      vsync: this,
      duration: aifcMessageAnimationDuration,
    );

    setState(() {
      aifcMessages.add(message);
      aifcMessageAnimations.add(controller);
    });

    controller.forward();
    aifcScrollToBottom();
  }

  void aifcAddFcMessage({
    required String text,
    Widget? child,
    Object? groupKey,
  }) {
    aifcAddMessage(
      AifcChatFlowMessage(
        side: AifcBubbleSide.fc,
        text: text,
        child: child,
        groupKey: groupKey,
      ),
    );
  }

  void aifcAddUserMessage({
    required String text,
    Object? groupKey,
  }) {
    aifcAddMessage(
      AifcChatFlowMessage(
        side: AifcBubbleSide.user,
        text: text,
        groupKey: groupKey,
      ),
    );
  }

  void aifcScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !aifcScrollController.hasClients) return;

      aifcScrollController.animateTo(
        aifcScrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> aifcShowTypingThen(
      Future<void> Function() action, {
        Duration? duration,
      }) async {
    if (!mounted) return;

    setState(() {
      aifcShowTyping = true;
    });

    aifcScrollToBottom();

    await Future.delayed(duration ?? aifcTypingDuration);
    if (!mounted) return;

    setState(() {
      aifcShowTyping = false;
    });

    await action();
  }

  /// 가장 기본 대화 흐름:
  /// 사용자 말풍선 → typing → FC 답변
  Future<void> aifcUserThenFc({
    required String userText,
    required String fcText,
    Widget? fcChild,
    Object? groupKey,
    bool setActiveGroup = true,
  }) async {
    if (aifcIsBusy) return;

    if (setActiveGroup) {
      aifcSetActiveGroup(groupKey);
    }

    aifcAddUserMessage(
      text: userText,
      groupKey: groupKey,
    );

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    await aifcShowTypingThen(() async {
      aifcAddFcMessage(
        text: fcText,
        child: fcChild,
        groupKey: groupKey,
      );
    });
  }

  /// 저장/확정/삭제/차감처럼 실제 작업이 있는 흐름:
  /// 사용자 말풍선 → typing/loading → 작업 실행 → FC 성공 답변 → 필요하면 닫기
  Future<void> aifcRunActionThenReply({
    required String userText,
    required Future<void> Function() action,
    required String successText,
    String errorText = '처리 중 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
    Widget? successChild,
    Object? groupKey,
    bool closeAfterReply = false,
    Object? popResult,
    bool setActiveGroup = true,
  }) async {
    if (aifcIsBusy) return;

    if (setActiveGroup) {
      aifcSetActiveGroup(groupKey);
    }

    aifcAddUserMessage(
      text: userText,
      groupKey: groupKey,
    );

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    setState(() {
      aifcShowTyping = true;
      aifcLoading = true;
    });

    aifcScrollToBottom();

    try {
      await Future.wait<void>([
        Future.delayed(aifcTypingDuration),
        action(),
      ]);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        aifcShowTyping = false;
        aifcLoading = false;
      });

      aifcAddFcMessage(
        text: errorText,
        groupKey: groupKey,
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      aifcShowTyping = false;
      aifcLoading = false;
    });

    aifcAddFcMessage(
      text: successText,
      child: successChild,
      groupKey: groupKey,
    );

    if (!closeAfterReply) return;

    await Future.delayed(aifcCloseAfterReplyDelay);
    if (!mounted) return;

    Navigator.of(context).pop(popResult);
  }

  /// 기록 불러오기처럼 데이터를 가져와서 다음 말풍선에 카드로 보여주는 흐름
  Future<R?> aifcFetchWithTyping<R>({
    required Future<R> Function() fetch,
    String errorText = '기록을 불러오지 못했어요.\n잠시 후 다시 시도해주세요.',
    Object? groupKey,
  }) async {
    if (aifcIsBusy) return null;

    setState(() {
      aifcShowTyping = true;
      aifcFetching = true;
    });

    aifcScrollToBottom();

    try {
      final results = await Future.wait<dynamic>([
        Future.delayed(aifcTypingDuration),
        fetch(),
      ]);

      if (!mounted) return null;

      setState(() {
        aifcShowTyping = false;
        aifcFetching = false;
      });

      return results[1] as R;
    } catch (_) {
      if (!mounted) return null;

      setState(() {
        aifcShowTyping = false;
        aifcFetching = false;
      });

      aifcAddFcMessage(
        text: errorText,
        groupKey: groupKey,
      );

      return null;
    }
  }

  /// 취소 공통 처리:
  /// - 작업 중이면 취소 막기
  /// - 변경사항 없으면 바로 닫기
  /// - 변경사항 있으면 confirmIfDirty로 한 번 묻기
  Future<void> aifcHandleCancel({
    required bool isDirty,
    Future<bool> Function()? confirmIfDirty,
    Object? popResult,
  }) async {
    if (aifcIsBusy) return;

    if (!isDirty) {
      Navigator.of(context).pop(popResult);
      return;
    }

    if (confirmIfDirty == null) {
      Navigator.of(context).pop(popResult);
      return;
    }

    final shouldClose = await confirmIfDirty();

    if (!mounted) return;

    if (shouldClose) {
      Navigator.of(context).pop(popResult);
    }
  }
}