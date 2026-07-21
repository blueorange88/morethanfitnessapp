import 'package:flutter/material.dart';

import '../aifc/core/aifc_chat_sheet.dart';
import 'aifc_snack_bar.dart';
import 'aifc_toast.dart';

class AifcInteraction {
  const AifcInteraction._();

  static void toast({
    required BuildContext context,
    required String message,
    double bottomOffset = 76,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    AifcToast.show(
      context: context,
      message: message,
      bottomOffset: bottomOffset,
      duration: duration,
    );
  }

  static void hideToast() {
    AifcToast.hide();
  }

  static void undoSnack({
    required BuildContext context,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    AifcSnackBar.show(
      context: context,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static Future<String?> ask({
    required BuildContext context,
    required String question,
    required String inputLabel,
    required Future<String> Function(String value) onSave,
    String initialValue = '',
    TextInputType? keyboardType,
    int maxLines = 1,
    String skipLabel = '나중에',
    VoidCallback? onSkip,
  }) {
    return AifcChatSheet.show(
      context: context,
      question: question,
      inputLabel: inputLabel,
      onSave: onSave,
      initialValue: initialValue,
      keyboardType: keyboardType,
      maxLines: maxLines,
      skipLabel: skipLabel,
      onSkip: onSkip,
    );
  }
}