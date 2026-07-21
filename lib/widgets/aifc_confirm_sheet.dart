import 'package:flutter/material.dart';

import '../aifc/core/aifc_nickname.dart';
import 'aifc_confirm_chat_sheet.dart';

/// TODO: 모든 AifcConfirmSheet.show 사용처를 AifcConfirmChatSheet 또는
/// _showAifcConfirm helper로 교체한 뒤 이 파일은 삭제 예정.
///
/// 지금은 기존 호출부가 남아 있어도 새 채팅형 확인 시트가 뜨도록 연결만 해둡니다.
class AifcConfirmSheet {
  const AifcConfirmSheet._();

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    String nickname = '강사',
    String? userCancelText,
    String? userConfirmText,
    String cancelReplyText = '좋아요. 진행하지 않을게요.',
    String confirmReplyText = '확인했어요. 이어서 진행할게요.',
    bool danger = false,
  }) {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: normalizeAifcNickname(nickname),
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
      userCancelText: userCancelText ?? _defaultUserCancelText(cancelText),
      userConfirmText: userConfirmText ?? _defaultUserConfirmText(confirmText),
      cancelReplyText: cancelReplyText,
      confirmReplyText: confirmReplyText,
      danger: danger,
    );
  }

  static String _defaultUserCancelText(String cancelText) {
    final clean = cancelText.trim();

    if (clean.isEmpty) {
      return '취소할게요';
    }

    if (clean.endsWith('할게요') || clean.endsWith('하겠습니다')) {
      return clean;
    }

    if (clean == '나중에') {
      return '나중에 할게요';
    }

    return '$clean할게요';
  }

  static String _defaultUserConfirmText(String confirmText) {
    final clean = confirmText.trim();

    if (clean.isEmpty) {
      return '확인할게요';
    }

    if (clean.endsWith('할게요') || clean.endsWith('하겠습니다')) {
      return clean;
    }

    return '$clean할게요';
  }
}