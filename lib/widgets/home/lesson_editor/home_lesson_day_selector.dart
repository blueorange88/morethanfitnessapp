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

  /// 예전 호출부와의 호환용. 선택한 요일의 색은 레슨계약서 칩과 같은 색을 쓴다.
  final Color activeColor;

  // 레슨계약서·회원권계약서 칩(home_lesson_quick_actions_section.dart)과 같은 색.
  static const Color selectedBackgroundLight = Color(0xFFFFF1C2);
  static const Color selectedBackgroundDark = Color(0xFF4A401F);
  static const Color selectedBorder = Color(0xFFEFCB62);
  static const Color selectedTextLight = Color(0xFF0B1E32);
  static const Color selectedTextDark = Color(0xFFFFF4CF);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children:
          allDays.map((day) {
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
                  color:
                      isSelected
                          ? (dark
                              ? selectedBackgroundDark
                              : selectedBackgroundLight)
                          : (dark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        isSelected
                            ? selectedBorder
                            : (dark
                                ? Colors.white.withOpacity(0.24)
                                : Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected
                            ? (dark ? selectedTextDark : selectedTextLight)
                            : (dark
                                ? Colors.white.withOpacity(0.88)
                                : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
