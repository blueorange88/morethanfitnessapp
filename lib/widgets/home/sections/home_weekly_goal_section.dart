import 'package:flutter/material.dart';

import 'home_goal_info.dart';

class HomeWeeklyGoalSection extends StatelessWidget {
  const HomeWeeklyGoalSection({
    super.key,
    required this.title,
    required this.weekCount,
    required this.goalTarget,
    required this.progress,
    required this.topFirst,
    required this.topSecond,
    required this.primaryColor,
    this.onEdit,
  });

  final String title;
  final int weekCount;
  final int goalTarget;
  final double progress;
  final String topFirst;
  final String topSecond;
  final Color primaryColor;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: '주간 레슨 목표 수정',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '주간 횟수',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '$weekCount/$goalTarget',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: primaryColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: HomeGoalInfo(
                          label: '가장 많은 레슨',
                          value: topFirst,
                        ),
                      ),
                      Expanded(
                        child: HomeGoalInfo(
                          label: '다음 레슨 타입',
                          value: topSecond,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
