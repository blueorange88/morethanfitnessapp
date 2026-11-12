import 'dart:async';

import 'package:flutter/material.dart';

/// 작성 중인 레슨일지를 두고 나가려 할 때 고르는 선택.
enum LeaveDraftChoice { save, discard, stay }

/// `작성 중인 레슨일지가 있어요` 확인창. 저장하고 나가면 내용이 유지되고, 삭제하고 나가면
/// 저장하지 않은 내용이 사라진다. 창 밖을 눌러 닫으면 계속 작성한다.
Future<LeaveDraftChoice> showLeaveDraftDialog(BuildContext context) async {
  final choice = await showDialog<LeaveDraftChoice>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          key: const ValueKey<String>('leave_draft_dialog'),
          title: const Text('작성 중인 레슨일지가 있어요'),
          content: const Text('저장하지 않고 나가면 지금까지 쓴 내용이 사라져요.\n저장하고 나갈까요?'),
          actions: [
            TextButton(
              key: const ValueKey<String>('leave_draft_stay'),
              onPressed:
                  () => Navigator.of(dialogContext).pop(LeaveDraftChoice.stay),
              child: const Text('계속 작성'),
            ),
            TextButton(
              key: const ValueKey<String>('leave_draft_discard'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed:
                  () =>
                      Navigator.of(dialogContext).pop(LeaveDraftChoice.discard),
              child: const Text('삭제하고 나가기'),
            ),
            FilledButton(
              key: const ValueKey<String>('leave_draft_save'),
              onPressed:
                  () => Navigator.of(dialogContext).pop(LeaveDraftChoice.save),
              child: const Text('저장하고 나가기'),
            ),
          ],
        ),
  );
  return choice ?? LeaveDraftChoice.stay;
}

/// 레슨일지 작성 화면을 감싸서, 저장하지 않은 내용이 있을 때 뒤로 가기·화면 닫기를
/// 가로채 확인창을 보여준다. 바뀐 내용이 없으면 그냥 나간다.
///
/// - [isDirty]: 저장하지 않은 변경이 있는지.
/// - [onSave]: `저장하고 나가기`. 저장에 성공하면 이 함수가 화면을 닫아야 한다(검증에
///   걸리면 화면에 남는다).
class LeaveDraftGuard extends StatelessWidget {
  const LeaveDraftGuard({
    super.key,
    required this.isDirty,
    required this.onSave,
    required this.child,
  });

  final bool Function() isDirty;
  final FutureOr<void> Function() onSave;
  final Widget child;

  Future<void> _handle(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (!isDirty()) {
      navigator.pop();
      return;
    }
    final choice = await showLeaveDraftDialog(context);
    if (!context.mounted) return;
    switch (choice) {
      case LeaveDraftChoice.save:
        await onSave();
      case LeaveDraftChoice.discard:
        navigator.pop();
      case LeaveDraftChoice.stay:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handle(context);
      },
      child: child,
    );
  }
}
