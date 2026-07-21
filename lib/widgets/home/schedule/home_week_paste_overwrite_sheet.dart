
import 'package:flutter/material.dart';

import '../../../aifc/core/aifc_chat_bubble.dart';
import '../sections/home_paste_conflict_summary_card.dart';

class HomeWeekPasteOverwriteSheet {
  const HomeWeekPasteOverwriteSheet._();

  static Future<bool> show({
    required BuildContext context,
    required String targetLabel,
    required List<Map<String, dynamic>> conflictExamples,
    required Color primaryColor,
  }) async {
    final confirmedConflicts =
    conflictExamples.where((e) => e['isConfirmed'] == true).toList();

    final editableConflicts =
    conflictExamples.where((e) => e['isConfirmed'] != true).toList();

    final confirmedCount = confirmedConflicts.length;
    final editableCount = editableConflicts.length;

    String mainText;
    String subText;

    if (confirmedCount > 0 && editableCount > 0) {
      mainText = '$targetLabel 에 겹치는 레슨일정이 있어요.';
      subText = '미확정 일정 $editableCount개는 덮어쓸 수 있고,\n'
          '확정된 일정 $confirmedCount개는 보호해서 제외할게요.';
    } else if (confirmedCount > 0) {
      mainText = '$targetLabel 에 확정된 레슨일정과 겹치는 일정이 있어요.';
      subText = '확정된 레슨은 삭제하거나 덮어쓸 수 없어요.\n'
          '겹치는 복사 일정은 제외하고 나머지만 붙여넣을게요.';
    } else {
      mainText = '$targetLabel 에 같은 시간의 레슨일정이 있어요.';
      subText = '기존 미확정 일정 $editableCount개를 삭제하고\n'
          '복사한 일정으로 덮어쓸 수 있어요.';
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4FF),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.14),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0DEFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AifcChatBubble(
                            side: AifcBubbleSide.fc,
                            text: mainText,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subText,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 11.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                HomePasteConflictSummaryCard(
                                  conflictExamples: conflictExamples,
                                  confirmedCount: confirmedCount,
                                  editableCount: editableCount,
                                  primaryColor: primaryColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          AifcChatBubble(
                            side: AifcBubbleSide.user,
                            text: confirmedCount > 0
                                ? '확정된 일정은 제외하고 붙여넣을게요'
                                : '겹치는 일정은 덮어쓰고 붙여넣을게요',
                          ),
                          const SizedBox(height: 10),
                          AifcChatBubble(
                            side: AifcBubbleSide.fc,
                            text: confirmedCount > 0
                                ? '좋아요. 확정된 레슨은 안전하게 보호하고 진행할게요.'
                                : '좋아요. 기존 미확정 일정은 정리하고 새 일정으로 넣어둘게요.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C7ABB),
                              side: const BorderSide(
                                color: Color(0xFFE0DEFF),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '붙여넣기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return result == true;
  }
}