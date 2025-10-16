// lib/pages/schedule_page.dart
import 'package:flutter/material.dart';
import '../widgets/schedule_table.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('이번 주 스케줄', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(child: ScheduleTable(weekOffset: 0)), // ← const 제거
            const SizedBox(height: 10),
            // 필요 시 아래 두 섹션을 주석 해제해서 다음/지난 주 보이기
            // ExpansionTile(
            //   title: const Text('다음 주 스케줄'),
            //   children: const [SizedBox(height: 300, child: ScheduleTable(weekOffset: 1))],
            // ),
            // ExpansionTile(
            //   initiallyExpanded: false,
            //   title: const Text('지난 주 스케줄'),
            //   children: const [SizedBox(height: 300, child: ScheduleTable(weekOffset: -1))],
            // ),
          ],
        ),
      ),
    );
  }
}
