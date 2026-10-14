import 'package:flutter/material.dart';

import '../models/anatomy_log.dart';
import '../models/body_map_data.dart';
import '../models/body_part.dart';
import '../models/exercise_muscles.dart';
import 'anatomy_record_sheet.dart';
import 'body_map_canvas.dart';

/// 마지막 확인 단계. 몸 그림에 기록(구역·점)을 보여주고, 점을 누르면 적어 둔
/// 내용을 읽을 수 있다.
class Step4Confirm extends StatefulWidget {
  const Step4Confirm({
    super.key,
    required this.memberName,
    required this.records,
    this.gender = BodyGender.unspecified,
  });

  final String memberName;
  final List<AnatomyLogRecord> records;
  final BodyGender gender;

  @override
  State<Step4Confirm> createState() => _Step4ConfirmState();
}

class _Step4ConfirmState extends State<Step4Confirm> {
  late final Future<BodyMapData> _mapFuture = BodyMapData.load();
  BodyView _view = BodyView.front;

  String _typeLabel(AnatomyRecordType value) => switch (value) {
    AnatomyRecordType.exercise => '운동',
    AnatomyRecordType.pain => '통증·불편',
    AnatomyRecordType.caution => '주의',
    AnatomyRecordType.mobility => '가동성',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.memberName.trim().isEmpty
              ? '해부학 기록 확인'
              : '${widget.memberName} 님 해부학 기록',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              key: const ValueKey<String>('confirm_view_front'),
              label: const Text('앞면'),
              selected: _view == BodyView.front,
              onSelected: (_) => setState(() => _view = BodyView.front),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const ValueKey<String>('confirm_view_back'),
              label: const Text('뒷면'),
              selected: _view == BodyView.back,
              onSelected: (_) => setState(() => _view = BodyView.back),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<BodyMapData>(
          future: _mapFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const SizedBox(height: 120);
            return BodyMapCanvas(
              key: const ValueKey<String>('confirm_map'),
              scene: data.sceneFor(widget.gender, _view),
              viewBox: data.viewBox,
              records: widget.records,
              pinsOnly: true,
              onTapped: (tap) {
                final record = tap.pinRecord;
                if (record != null) showAnatomyPinDetails(context, record);
              },
            );
          },
        ),
        const SizedBox(height: 10),
        const BodyMapLegend(),
        const SizedBox(height: 4),
        Text(
          '점을 누르면 적어 둔 내용을 볼 수 있어요.',
          style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ...widget.records.map(
          (record) => Card(
            child: ListTile(
              title: Text(
                '${record.bodyPartLabel}${bodySideSuffix(record.bodySide)} · '
                '${_typeLabel(record.recordType)}',
              ),
              subtitle: Text(
                [
                  if (record.exerciseName.isNotEmpty) record.exerciseName,
                  if (record.recordType == AnatomyRecordType.pain)
                    '불편 ${record.painLevel}/10',
                  if (record.recordType == AnatomyRecordType.mobility &&
                      record.mobilityResult != null)
                    switch (record.mobilityResult!) {
                      MobilityResult.normal => '○ 정상',
                      MobilityResult.mild => '△ 보상',
                      MobilityResult.severe => '× 제한',
                    },
                  if (record.relatedPartIds.isNotEmpty)
                    '함께 ${bodyPartLabels(record.relatedPartIds).join('·')}',
                  if (record.memo.isNotEmpty) record.memo,
                ].join(' · '),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
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

/// 점(기록) 하나의 내용을 읽기 전용으로 보여주는 창.
Future<void> showAnatomyPinDetails(
  BuildContext context,
  AnatomyLogRecord record,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      final media = MediaQuery.of(context);
      final symbol = anatomyPinSymbol(record);
      final detail = switch (record.recordType) {
        AnatomyRecordType.pain => '불편 정도 ${record.painLevel} / 10',
        AnatomyRecordType.mobility => switch (record.mobilityResult) {
          MobilityResult.normal => '결과 ○ 정상',
          MobilityResult.mild => '결과 △ 보상',
          MobilityResult.severe => '결과 × 제한',
          null => '결과 없음',
        },
        _ => '',
      };
      return Padding(
        key: const ValueKey<String>('pin_details'),
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + media.viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: anatomyMarkColor(
                      anatomyPinMark(record),
                      dark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                  child: Text(
                    symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${anatomyRecordTypeLabel(record.recordType)} · '
                    '${record.bodyPartLabel}${bodySideSuffix(record.bodySide)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.exerciseName.isNotEmpty)
              Text(
                record.exerciseName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(detail, style: TextStyle(color: colors.onSurfaceVariant)),
            ],
            if (record.memo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(record.memo, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      );
    },
  );
}
