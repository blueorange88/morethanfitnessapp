import 'package:flutter/material.dart';

class HomeLessonDaySelector extends StatelessWidget {
  const HomeLessonDaySelector({
    super.key,
    required this.allDays,
    required this.selectedDays,
    required this.onDayTapped,
    this.activeColor = const Color(0xFF4F46E5),
  });

  final List<String> allDays;
  final Set<String> selectedDays;
  final ValueChanged<String> onDayTapped;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: allDays.map((day) {
        final bool isSelected = selectedDays.contains(day);

        return GestureDetector(
          onTap: () {
            onDayTapped(day);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withOpacity(0.10)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? activeColor : Colors.grey.shade300,
              ),
            ),
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? activeColor : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
