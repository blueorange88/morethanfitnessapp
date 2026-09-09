import 'package:flutter/material.dart';

import '../../../aifc/core/aifc_chat_bubble.dart';
import '../../../theme/app_colors.dart';

class HomeWeekPasteOverwriteSheet {
  const HomeWeekPasteOverwriteSheet._();

  static Future<bool> show({
    required BuildContext context,
    required String targetLabel,
    required int conflictCount,
    required int pasteableCount,
    required Color primaryColor,
  }) async {
    final allConflicting = pasteableCount == 0;
    final title =
        allConflicting ? '붙여넣을 수 있는 일정이 없어요' : '겹치는 일정이 $conflictCount개 있어요';
    final body = allConflicting
        ? '$conflictCount개 일정이 모두 기존 일정과 겹쳐요.'
        : '기존 일정과 겹치는 $conflictCount개를 제외하고\n'
            '나머지 $pasteableCount개 일정을 $targetLabel에 붙여넣을까요?';

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final tokens = sheetContext.mtfThemeTokens;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
              ),
              decoration: BoxDecoration(
                color: tokens.sheetBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.14),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
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
                        color: tokens.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: AifcChatBubble(
                        side: AifcBubbleSide.fc,
                        text: title,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              body,
                              key: const Key('week_paste_conflict_body'),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '기존 일정은 변경되지 않아요.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11.5,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: allConflicting
                        ? SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const Key('week_paste_conflict_ack'),
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(false),
                              child: const Text('확인'),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  key: const Key('week_paste_conflict_cancel'),
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(false),
                                  child: const Text('취소'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  key: const Key('week_paste_conflict_confirm'),
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tokens.gradeSheetAccent,
                                    foregroundColor:
                                        theme.colorScheme.onSecondary,
                                  ),
                                  child: Text(
                                    '$conflictCount개 제외하고 붙여넣기',
                                    textAlign: TextAlign.center,
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
