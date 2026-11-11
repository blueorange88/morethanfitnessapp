import 'package:flutter/material.dart';

/// 계약 파기 사유 선택지(서버에 그대로 기록되는 문장).
const List<String> kContractVoidReasons = ['잘못 작성함', '회원 요청', '기타'];

/// 완료된 계약서를 파기하기 전에 사유를 고르는 바텀시트. 고른 사유를 돌려주고, 닫으면 null.
///
/// 파기하면 계약서는 효력이 없어지고 이 계약으로 등록된 횟수([sessionCount])도 되돌려진다는 것,
/// 이어서 회원이 서명해야 한다는 것을 알려 준다.
Future<String?> showContractVoidReasonSheet(
  BuildContext context, {
  int? sessionCount,
  int windowDays = 3,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _VoidReasonSheet(
          sessionCount: sessionCount,
          windowDays: windowDays,
        ),
  );
}

class _VoidReasonSheet extends StatefulWidget {
  const _VoidReasonSheet({
    required this.sessionCount,
    required this.windowDays,
  });

  final int? sessionCount;
  final int windowDays;

  @override
  State<_VoidReasonSheet> createState() => _VoidReasonSheetState();
}

class _VoidReasonSheetState extends State<_VoidReasonSheet> {
  String _reason = kContractVoidReasons.first;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = widget.sessionCount;
    return Container(
      key: const Key('contract_void_sheet'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        18 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '계약을 파기할까요?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '파기하면 이 계약서는 효력이 없어지고'
            '${count == null ? '' : ' 등록된 $count회도'} 되돌려져요.\n'
            '계약 완료 후 ${widget.windowDays}일 안에, 레슨을 받기 전에만 파기할 수 있어요.\n'
            '이어서 회원이 파기 확인 서명을 해야 해요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final reason in kContractVoidReasons)
                ChoiceChip(
                  key: ValueKey<String>('contract_void_reason_$reason'),
                  label: Text(reason),
                  selected: _reason == reason,
                  onSelected: (_) => setState(() => _reason = reason),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('contract_void_continue'),
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.of(context).pop(_reason),
            child: const Text('회원 서명 받고 파기하기'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('contract_void_cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
