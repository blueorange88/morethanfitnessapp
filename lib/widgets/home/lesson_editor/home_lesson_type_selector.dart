import 'package:flutter/material.dart';

import 'package:mtf_app/models/lesson_type_item.dart';

class HomeLessonTypeSelector extends StatelessWidget {
  const HomeLessonTypeSelector({
    super.key,
    required this.lessonTypes,
    required this.selectedTypeId,
    required this.onSelected,
    required this.onAddTap,
    required this.onChipLongPress,
  });

  final List<LessonTypeItem> lessonTypes;
  final String selectedTypeId;
  final ValueChanged<LessonTypeItem> onSelected;
  final VoidCallback onAddTap;
  final ValueChanged<LessonTypeItem> onChipLongPress;

  Color _colorFromHex(String hex) {
    var value = hex.trim().replaceFirst('#', '');

    if (value.length == 6) {
      value = 'FF$value';
    }

    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return const Color(0xFF4F46E5);
    }

    return Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...lessonTypes.map((item) {
          final bool isSelected = selectedTypeId == item.id;
          final Color baseColor = _colorFromHex(item.colorHex);

          return GestureDetector(
            onLongPress: () => onChipLongPress(item),
            onTap: () => onSelected(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? baseColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? baseColor : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.0 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: baseColor.withOpacity(0.28),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : null,
              ),
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: onAddTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                width: 0.9,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 13,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(width: 3),
                Text(
                  '추가',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}