import 'package:flutter/material.dart';

import 'aifc_confirm_chat_sheet.dart';

abstract final class AifcAccountLinkRequiredChatSheet {
  static const title = '오, 벌써 누적 회원 등록이 10명에 도달했어요 🎉';
  static const message =
      '이제 이메일 계정을 연결하면\n'
      '지금까지의 회원과 일정은 그대로 두고\n'
      '계속 회원을 등록할 수 있어요.\n\n'
      '계정을 연결해도 기존 데이터는 사라지지 않아요.';

  static Future<bool> show({
    required BuildContext context,
    required String nickname,
  }) {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: nickname,
      title: title,
      message: message,
      cancelText: '나중에',
      confirmText: '계정 연결하기',
      userCancelText: '나중에 할게요',
      userConfirmText: '계정을 연결할게요',
      cancelReplyText: '좋아요. 입력한 내용은 그대로 둘게요.',
      confirmReplyText: '좋아요. 기존 기록을 그대로 두고 계정을 연결할게요.',
    );
  }

  static Future<bool> showLinked({
    required BuildContext context,
    required String nickname,
  }) {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: nickname,
      title: '연결됐어요 🙌',
      message: '입력하신 내용도 그대로 있어요.\n입력 화면에서 회원 저장을 다시 눌러주세요.',
      cancelText: '나중에',
      confirmText: '입력 화면으로 돌아가기',
      userCancelText: '나중에 저장할게요',
      userConfirmText: '입력 화면으로 돌아갈게요',
      cancelReplyText: '좋아요. 입력한 내용은 그대로 둘게요.',
      confirmReplyText: '좋아요. 입력 화면에서 회원 저장을 다시 눌러주세요.',
    );
  }
}
