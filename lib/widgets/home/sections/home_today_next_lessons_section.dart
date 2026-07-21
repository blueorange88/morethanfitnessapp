import 'package:flutter/material.dart';

import 'home_next_lesson_card.dart';

class HomeTodayNextLessonsSection extends StatelessWidget {
  const HomeTodayNextLessonsSection({
    super.key,
    required this.nextLessons,
    required this.primaryColor,
    required this.buildCountText,
    required this.onLessonTap,
  });

  final List<Map<String, dynamic>> nextLessons;
  final Color primaryColor;
  final String Function(Map<String, dynamic> data) buildCountText;
  final void Function(String day, String time) onLessonTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 다음 레슨',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (nextLessons.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '오늘 남은 레슨이 없습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...nextLessons.asMap().entries.map((entry) {
              final idx = entry.key;
              final data = entry.value;

              final day = data['day'] as String;
              final time = data['time'] as String;
              final name = data['name'] as String;
              final type = data['type'] as String;

              final isOngoing = data['isOngoing'] == true;

              final minutesToStart = data['minutesToStart'] is int
                  ? data['minutesToStart'] as int
                  : 9999;

              final int visualSoftness = data['visualSoftness'] is int
                  ? data['visualSoftness'] as int
                  : 0;

              final bool isNextAfterOngoing = data['isNextAfterOngoing'] == true;

              final int? gapFromPreviousMinutes = data['gapFromPreviousMinutes'] is int
                  ? data['gapFromPreviousMinutes'] as int
                  : null;

              final bool clearNextAfterOngoing =
                  isNextAfterOngoing &&
                      minutesToStart <= 90 &&
                      (gapFromPreviousMinutes == null || gapFromPreviousMinutes <= 60);

              int emphasis = 0;

              if (isOngoing) {
                emphasis = 3;
              } else if (minutesToStart <= 10) {
                emphasis = 2;
              } else if (minutesToStart <= 30) {
                emphasis = 1;
              }

              String statusText = '다음';

              if (isOngoing) {
                statusText = '진행중';
              } else if (minutesToStart <= 10) {
                statusText = '곧 시작';
              } else if (minutesToStart <= 30) {
                statusText = '30분 전';
              } else if (minutesToStart <= 120) {
                statusText = '예정';
              }

              final bool isFirstVisibleCard = idx == 0;

              final bool isWithinTwoHours =
                  isOngoing || minutesToStart <= 120;

              final bool forceClearCard =
                  isFirstVisibleCard && isWithinTwoHours;

              final bool isPriorityCard =
                  !forceClearCard && isWithinTwoHours;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: idx == nextLessons.length - 1 ? 0 : 8,
                ),
                child: HomeNextLessonCard(
                  name: name,
                  time: time,
                  type: type,
                  status: statusText,
                  emphasis: emphasis,
                  visualSoftness: visualSoftness,
                  isPriority: isPriorityCard,
                  forceClear: forceClearCard,
                  enrolled: 0,
                  cap: 0,
                  primaryColor: primaryColor,
                  memo: (data['memo'] ?? '').toString(),
                  countText: buildCountText(data),
                  isManualMember: data['isManualMember'] == true,
                  onTap: () => onLessonTap(day, time),
                ),
              );
            }),
        ],
      ),
    );
  }
}