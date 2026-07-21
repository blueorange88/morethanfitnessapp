import 'package:flutter/material.dart';

import '../../../models/home_repeat_lesson_grouping_mode.dart';

class HomeRepeatLessonGroupingSheet {
  const HomeRepeatLessonGroupingSheet._();

  static Future<HomeRepeatLessonGroupingMode?> show({
    required BuildContext context,
    required HomeRepeatLessonGroupingMode currentMode,
    required Color primaryColor,
  }) {
    return showModalBottomSheet<HomeRepeatLessonGroupingMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        HomeRepeatLessonGroupingMode selectedMode = currentMode;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Widget buildOption(HomeRepeatLessonGroupingMode mode) {
              final selected = selectedMode == mode;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setSheetState(() {
                    selectedMode = mode;
                  });
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? primaryColor : const Color(0xFFE5E7EB),
                      width: selected ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selected ? primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: selected
                              ? null
                              : Border.all(
                            color: const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.calendar_month_outlined,
                          color: selected ? Colors.white : primaryColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.title,
                              style: TextStyle(
                                color: selected
                                    ? primaryColor
                                    : const Color(0xFF111827),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              mode.description,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11.3,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.16),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.event_repeat_rounded,
                              color: Color(0xFF4F46E5),
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '반복 레슨 묶기 방식',
                                  style: TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '레슨 수정 시 여러 요일을 자동 체크하는 기준을 정해요.',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      buildOption(HomeRepeatLessonGroupingMode.none),
                      buildOption(HomeRepeatLessonGroupingMode.sameMemberSameTime),
                      buildOption(HomeRepeatLessonGroupingMode.sameMemberAnyTime),
                      const SizedBox(height: 4),
                      const Text(
                        '주의: 같은 회원 전체 묶기는 시간대가 다른 레슨도 함께 체크합니다. 저장 시 선택된 요일은 현재 시트의 시간 기준으로 맞춰질 수 있어요.',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10.8,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                '취소',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop(selectedMode);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                '적용',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}