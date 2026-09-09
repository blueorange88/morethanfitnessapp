import 'package:flutter/material.dart';

class HomeLessonFooterActions extends StatelessWidget {
  const HomeLessonFooterActions({
    super.key,
    required this.isEditMode,
    required this.isLocked,
    required this.isCustomerSignedConfirmedLesson,
    required this.isContractLinkedConfirmedLesson,
    this.isBusy = false,
    this.isDeleting = false,
    required this.onCancel,
    required this.onDelete,
    required this.onSave,
  });

  final bool isEditMode;
  final bool isLocked;
  final bool isCustomerSignedConfirmedLesson;
  final bool isContractLinkedConfirmedLesson;
  final bool isBusy;
  final bool isDeleting;
  final VoidCallback onCancel;
  final Future<void> Function() onDelete;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lockedGuideText = isCustomerSignedConfirmedLesson
        ? '고객서명이 들어간 레슨확정은 임의로 확정취소 할 수 없어요.'
        : isContractLinkedConfirmedLesson
            ? '계약서와 연결된 레슨확정은 홈에서 임의로 수정하거나 삭제할 수 없어요.'
            : '확정된 레슨은 일정을 수정하거나 삭제할 수 없어요.';

    if (isLocked) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    isCustomerSignedConfirmedLesson ||
                            isContractLinkedConfirmedLesson
                        ? Icons.block_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lockedGuideText,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  side: BorderSide(color: colors.outline),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          TextButton(
            onPressed: isBusy ? null : onCancel,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
            child: const Text(
              '취소',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Spacer(),
          if (isEditMode) ...[
            OutlinedButton.icon(
              onPressed: isBusy
                  ? null
                  : () async {
                      await onDelete();
                    },
              icon: isBusy && isDeleting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 16),
              label: Text(
                isBusy && isDeleting ? '삭제 중…' : '삭제',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            onPressed: isBusy
                ? null
                : () async {
                    await onSave();
                  },
            icon: isBusy && !isDeleting
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSecondary,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text(
              isBusy && !isDeleting ? '저장 중…' : '저장',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
