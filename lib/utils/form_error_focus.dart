import 'package:flutter/material.dart';

/// 입력 오류가 있는 칸으로 화면을 옮기고, 글자 입력 칸이면 커서를 놓는다.
///
/// 저장·확인을 눌렀을 때 필수 칸이 비어 있거나 틀렸다면 사용자가 칸을 직접 찾지 않도록 쓴다.
/// - [anchorContext]: 칸(또는 칸이 속한 영역)의 `BuildContext`. 있으면 그 자리로 스크롤한다.
/// - [focusNode]: 글자 입력 칸의 `FocusNode`. 스크롤이 끝난 뒤 포커스(커서)를 준다.
///   날짜·선택 칸처럼 글자를 직접 입력하지 않는 칸은 넘기지 않는다.
Future<void> revealAndFocus({
  BuildContext? anchorContext,
  FocusNode? focusNode,
  double alignment = 0.15,
  Duration duration = const Duration(milliseconds: 300),
}) async {
  if (anchorContext != null && anchorContext.mounted) {
    await Scrollable.ensureVisible(
      anchorContext,
      alignment: alignment,
      duration: duration,
      curve: Curves.easeOut,
    );
  }
  final node = focusNode;
  if (node != null && node.context?.mounted == true && node.canRequestFocus) {
    node.requestFocus();
  }
}

/// `Form.validate()`가 실패한 뒤 호출한다. 오류가 난 칸 중 화면 맨 위의 칸으로 이동하고,
/// 글자 입력 칸이면 커서를 놓는다. 이동할 칸이 있었으면 true.
Future<bool> focusFirstInvalidFormField(
  BuildContext? formContext, {
  double alignment = 0.2,
}) async {
  await WidgetsBinding.instance.endOfFrame;
  if (formContext == null || !formContext.mounted) return false;

  Element? firstInvalid;
  double? firstDy;
  void inspect(Element element) {
    if (element is StatefulElement && element.state is FormFieldState) {
      final state = element.state as FormFieldState;
      final box = element.renderObject;
      if (state.hasError && box is RenderBox && box.hasSize) {
        final dy = box.localToGlobal(Offset.zero).dy;
        if (firstDy == null || dy < firstDy!) {
          firstDy = dy;
          firstInvalid = element;
        }
      }
    }
    element.visitChildren(inspect);
  }

  (formContext as Element).visitChildren(inspect);
  final target = firstInvalid;
  if (target == null) return false;

  await Scrollable.ensureVisible(
    target,
    alignment: alignment,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  FocusNode? node;
  void findInput(Element element) {
    if (node != null) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      node = (element.state as EditableTextState).widget.focusNode;
      return;
    }
    element.visitChildren(findInput);
  }

  target.visitChildren(findInput);
  final input = node;
  if (input != null && input.context?.mounted == true) input.requestFocus();
  return true;
}
