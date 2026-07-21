import 'package:flutter/material.dart';

import '../models/anatomy_log.dart';

class Step4Confirm extends StatelessWidget {
  const Step4Confirm(
      {super.key, required this.memberName, required this.records});

  final String memberName;
  final List<AnatomyLogRecord> records;

  String _typeLabel(AnatomyRecordType value) => switch (value) {
        AnatomyRecordType.exercise => '운동',
        AnatomyRecordType.pain => '통증',
        AnatomyRecordType.caution => '주의',
        AnatomyRecordType.mobility => '가동성',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(memberName.trim().isEmpty ? '해부학 기록 확인' : '$memberName 님 해부학 기록',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...records.map((record) => Card(
              child: ListTile(
                title: Text(
                    '${record.bodyPartLabel} · ${_typeLabel(record.recordType)}'),
                subtitle: Text([
                  if (record.exerciseName.isNotEmpty) record.exerciseName,
                  if (record.recordType == AnatomyRecordType.pain)
                    '통증 ${record.painLevel}/10',
                  if (record.memo.isNotEmpty) record.memo,
                ].join(' · ')),
              ),
            )),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '기록은 현재 레슨일지에 저장됩니다. 회원 앱 공유와 영상 기능은 준비 중입니다.',
            style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
