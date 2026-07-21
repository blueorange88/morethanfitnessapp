import 'package:flutter/material.dart';

class HomePasteConflictSummaryCard extends StatelessWidget {
  const HomePasteConflictSummaryCard({
    super.key,
    required this.conflictExamples,
    required this.confirmedCount,
    required this.editableCount,
    required this.primaryColor,
  });

  final List<Map<String, dynamic>> conflictExamples;
  final int confirmedCount;
  final int editableCount;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final examples = conflictExamples.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0DEFF),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomePasteSummaryRow(
            label: '덮어쓰기 가능',
            value: '$editableCount개',
            valueColor: primaryColor,
          ),
          const SizedBox(height: 7),
          _HomePasteSummaryRow(
            label: '확정 보호',
            value: '$confirmedCount개',
            valueColor: confirmedCount > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF9CA3AF),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              height: 0.5,
              color: const Color(0xFFE0DEFF),
            ),
            const SizedBox(height: 8),
            ...examples.map((conflict) {
              final day = (conflict['day'] ?? '').toString();
              final time = (conflict['time'] ?? '').toString();
              final endTime = (conflict['endTime'] ?? '').toString();
              final name = (conflict['name'] ?? '').toString();
              final isConfirmed = conflict['isConfirmed'] == true;

              final timeLabel = endTime.isNotEmpty ? '$time ~ $endTime' : time;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${isConfirmed ? "🔒 " : "• "}$day $timeLabel ${name.isNotEmpty ? "($name)" : ""}',
                  style: TextStyle(
                    color: isConfirmed
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: isConfirmed ? FontWeight.w800 : FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              );
            }),
            if (conflictExamples.length > 4)
              Text(
                '외 ${conflictExamples.length - 4}건',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HomePasteSummaryRow extends StatelessWidget {
  const _HomePasteSummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7C7ABB),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}