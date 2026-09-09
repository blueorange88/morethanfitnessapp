import 'package:flutter/material.dart';

class ShadcnCalendar extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onSelect;

  const ShadcnCalendar({
    super.key,
    required this.month,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay =
    DateTime(month.year, month.month, 1);
    final firstWeekday = firstDay.weekday;
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            firstWeekday - 1,
                (_) => const SizedBox.shrink(),
          )..addAll(
            List.generate(daysInMonth, (i) {
              final date = DateTime(month.year, month.month, i + 1);
              return GestureDetector(
                onTap: () => onSelect(date),
                child: Center(child: Text("${i + 1}")),
              );
            }),
          ),
        )
      ],
    );
  }
}
