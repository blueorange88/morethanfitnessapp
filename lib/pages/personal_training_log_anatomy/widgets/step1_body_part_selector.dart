import 'package:flutter/material.dart';
import '../models/anatomy_log.dart';
import '../models/body_map_data.dart';
import '../models/body_part.dart';
import '../models/exercise_muscles.dart';
import 'anatomy_record_sheet.dart';
import 'body_map_canvas.dart';

/// 1단계: 바디맵에서 부위를 눌러 기록한다. 기록한 부위는 그림에 칠해지고,
/// 아래에 부위별 기록 목록이 쌓인다.
class Step1BodyPartSelector extends StatefulWidget {
  const Step1BodyPartSelector({
    super.key,
    required this.selectedView,
    required this.records,
    required this.partSides,
    required this.onViewChanged,
    required this.onPartChipTapped,
    required this.onMapTapped,
    required this.onRecordTapped,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.singleSide,
    required this.onSingleSideChanged,
    this.showGenderChips = true,
  });

  final BodyView selectedView;
  final List<AnatomyLogRecord> records;

  /// 기록이 있는 부위 id → 좌우(그림에 칠할 상태).
  final Map<String, BodySide> partSides;

  final ValueChanged<BodyView> onViewChanged;

  /// 부위 목록(칩)에서 부위를 골랐을 때.
  final ValueChanged<String> onPartChipTapped;

  /// 바디맵을 눌렀을 때(구역·구역 밖의 몸·기존 점).
  final ValueChanged<AnatomyMapTap> onMapTapped;

  /// 기록 목록의 한 줄을 눌렀을 때(수정).
  final ValueChanged<AnatomyLogRecord> onRecordTapped;
  final BodyGender selectedGender;
  final ValueChanged<BodyGender> onGenderChanged;

  /// true 면 한쪽씩 선택, false 면 좌우를 함께 선택.
  final bool singleSide;
  final ValueChanged<bool> onSingleSideChanged;

  /// 회원카드에서 성별을 알면 false(고르지 않고 그 몸으로 보여준다).
  final bool showGenderChips;

  @override
  State<Step1BodyPartSelector> createState() => _Step1BodyPartSelectorState();
}

class _Step1BodyPartSelectorState extends State<Step1BodyPartSelector> {
  late final Future<BodyMapData> _mapFuture = BodyMapData.load();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleParts = kBodyParts.where(
      (p) => !p.legacy && p.visibleIn(widget.selectedView),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showGenderChips) ...[
          const Text(
            '바디 기준',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                BodyGender.values.map((value) {
                  final labels = {
                    BodyGender.male: '남성',
                    BodyGender.female: '여성',
                    BodyGender.unspecified: '미지정',
                  };
                  return ChoiceChip(
                    label: Text(labels[value]!),
                    selected: widget.selectedGender == value,
                    onSelected: (_) => widget.onGenderChanged(value),
                  );
                }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            '회원카드에 성별이 없어 직접 골라요. 미지정은 남성 몸으로 보여줘요.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Text(
              '좌우 선택',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              key: const ValueKey<String>('side_mode_both'),
              label: const Text('양쪽 함께'),
              selected: !widget.singleSide,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => widget.onSingleSideChanged(false),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              key: const ValueKey<String>('side_mode_single'),
              label: const Text('한쪽씩'),
              selected: widget.singleSide,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => widget.onSingleSideChanged(true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 앞면 / 뒷면 토글
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _ViewToggleChip(
                label: '앞면',
                icon: Icons.person_outline_rounded,
                isSelected: widget.selectedView == BodyView.front,
                onTap: () => widget.onViewChanged(BodyView.front),
              ),
              const SizedBox(width: 4),
              _ViewToggleChip(
                label: '뒷면',
                icon: Icons.person_rounded,
                isSelected: widget.selectedView == BodyView.back,
                onTap: () => widget.onViewChanged(BodyView.back),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 바디맵
        FutureBuilder<BodyMapData>(
          future: _mapFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) {
              return Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.outline),
                ),
                child:
                    snapshot.hasError
                        ? Text(
                          '바디 그림을 불러오지 못했어요. 아래 부위 목록에서 선택해주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                        : const CircularProgressIndicator(),
              );
            }
            return BodyMapCanvas(
              scene: data.sceneFor(widget.selectedGender, widget.selectedView),
              viewBox: data.viewBox,
              records: widget.records,
              onTapped: widget.onMapTapped,
            );
          },
        ),
        const SizedBox(height: 10),
        const BodyMapLegend(),
        const SizedBox(height: 8),
        Text(
          '부위를 누르면 기록할 수 있어요. 통증·주의·가동성은 누른 자리에 점으로 남아요.',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // 기록 목록
        _RecordList(records: widget.records, onTap: widget.onRecordTapped),

        // 그림에서 누르기 어려운 부위를 위한 목록
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey<String>('part_list_tile'),
            tilePadding: EdgeInsets.zero,
            title: const Text(
              '부위 목록에서 선택',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedAlignment: Alignment.centerLeft,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final part in visibleParts)
                    _PartChip(
                      label: part.label,
                      isSelected: widget.partSides.containsKey(part.id),
                      onTap: () => widget.onPartChipTapped(part.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({required this.records, required this.onTap});

  final List<AnatomyLogRecord> records;
  final ValueChanged<AnatomyLogRecord> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outline),
        ),
        child: Text(
          '아직 기록이 없어요. 부위를 눌러 오늘 한 운동을 기록해보세요.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      );
    }

    // 부위(+좌우)별로 묶어 처음 나온 순서대로 보여준다.
    final groups = <String, List<AnatomyLogRecord>>{};
    for (final record in records) {
      groups
          .putIfAbsent('${record.bodyPartId}|${record.bodySide.name}', () => [])
          .add(record);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기록 ${records.length}개',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final entry in groups.entries)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                  child: Text(
                    '${entry.value.first.bodyPartLabel}'
                    '${bodySideSuffix(entry.value.first.bodySide)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (final record in entry.value) ...[
                  InkWell(
                    key: ValueKey<String>('record_${record.anatomyLogId}'),
                    onTap: () => onTap(record),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            anatomyRecordTypeIcon(record.recordType),
                            size: 16,
                            color: anatomyRecordTypeColor(
                              record.recordType,
                              colors,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _title(record),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _detail(record),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  record.recordType == AnatomyRecordType.pain
                                      ? colors.error
                                      : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (record.relatedPartIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(38, 0, 14, 6),
                      child: Text(
                        '함께 쓴 부위 · ${bodyPartLabels(record.relatedPartIds).join(' · ')}',
                        key: ValueKey<String>('related_${record.anatomyLogId}'),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
      ],
    );
  }

  static String _title(AnatomyLogRecord record) {
    if (record.exerciseName.isNotEmpty) return record.exerciseName;
    return anatomyRecordTypeLabel(record.recordType);
  }

  static String _detail(AnatomyLogRecord record) {
    if (record.recordType == AnatomyRecordType.pain) {
      return '${record.painLevel} / 10';
    }
    if (record.recordType == AnatomyRecordType.mobility &&
        record.mobilityResult != null) {
      return switch (record.mobilityResult!) {
        MobilityResult.normal => '○ 정상',
        MobilityResult.mild => '△ 보상',
        MobilityResult.severe => '× 제한',
      };
    }
    if (record.sets.isNotEmpty) return anatomySetsSummary(record.sets);
    return record.memo;
  }
}

class _ViewToggleChip extends StatelessWidget {
  const _ViewToggleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.5);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? colors.primary : colors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? colors.onPrimary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}
