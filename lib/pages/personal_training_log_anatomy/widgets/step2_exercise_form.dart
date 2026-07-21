import 'package:flutter/material.dart';

import '../models/anatomy_log.dart';
import '../models/body_part.dart';

class Step2ExerciseForm extends StatefulWidget {
  const Step2ExerciseForm({
    super.key,
    required this.selectedPartIds,
    required this.records,
    required this.onAdd,
    required this.onUpdate,
    required this.onRemove,
  });

  final List<String> selectedPartIds;
  final List<AnatomyLogRecord> records;
  final void Function(String partId, AnatomyRecordType type, String name) onAdd;
  final ValueChanged<AnatomyLogRecord> onUpdate;
  final ValueChanged<String> onRemove;

  @override
  State<Step2ExerciseForm> createState() => _Step2ExerciseFormState();
}

class _Step2ExerciseFormState extends State<Step2ExerciseForm> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedPartId = '';
  AnatomyRecordType _recordType = AnatomyRecordType.exercise;

  @override
  void initState() {
    super.initState();
    _selectedPartId =
        widget.selectedPartIds.isEmpty ? '' : widget.selectedPartIds.first;
  }

  @override
  void didUpdateWidget(covariant Step2ExerciseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectedPartIds.contains(_selectedPartId)) {
      _selectedPartId =
          widget.selectedPartIds.isEmpty ? '' : widget.selectedPartIds.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  BodyPart? _part(String id) {
    for (final part in kBodyParts) {
      if (part.id == id) return part;
    }
    return null;
  }

  String _typeLabel(AnatomyRecordType value) => switch (value) {
        AnatomyRecordType.exercise => '운동',
        AnatomyRecordType.pain => '통증',
        AnatomyRecordType.caution => '주의',
        AnatomyRecordType.mobility => '가동성',
      };

  void _add([String? recommendedName]) {
    if (_selectedPartId.isEmpty) return;
    final name = (recommendedName ?? _nameController.text).trim();
    if (_recordType == AnatomyRecordType.exercise && name.isEmpty) return;
    widget.onAdd(_selectedPartId, _recordType, name);
    _nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentPart = _part(_selectedPartId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selectedPartIds.map((id) {
            return ChoiceChip(
              label: Text(_part(id)?.label ?? id),
              selected: id == _selectedPartId,
              onSelected: (_) => setState(() => _selectedPartId = id),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AnatomyRecordType.values.map((type) {
            return ChoiceChip(
              label: Text(_typeLabel(type)),
              selected: type == _recordType,
              onSelected: (_) => setState(() => _recordType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        if (_recordType == AnatomyRecordType.exercise &&
            currentPart != null) ...[
          const Text('추천 운동',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentPart.recommendedExercises.map((name) {
              return ActionChip(label: Text(name), onPressed: () => _add(name));
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _recordType == AnatomyRecordType.exercise
                      ? '운동 이름'
                      : '짧은 제목 (선택)',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _add, child: const Text('추가')),
          ],
        ),
        const SizedBox(height: 20),
        if (widget.records.isEmpty)
          const _EmptyRecords()
        else
          ...widget.records.map(
            (record) => _RecordCard(
              key: ValueKey(record.anatomyLogId),
              record: record,
              partLabel:
                  _part(record.bodyPartId)?.label ?? record.bodyPartLabel,
              typeLabel: _typeLabel(record.recordType),
              onUpdate: widget.onUpdate,
              onRemove: () => widget.onRemove(record.anatomyLogId),
            ),
          ),
      ],
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    super.key,
    required this.record,
    required this.partLabel,
    required this.typeLabel,
    required this.onUpdate,
    required this.onRemove,
  });

  final AnatomyLogRecord record;
  final String partLabel;
  final String typeLabel;
  final ValueChanged<AnatomyLogRecord> onUpdate;
  final VoidCallback onRemove;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  late final TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: widget.record.memo);
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${widget.partLabel} · ${widget.typeLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(record.exerciseName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  tooltip: '기록 삭제',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (record.recordType == AnatomyRecordType.pain) ...[
              Text('통증 ${record.painLevel} / 10'),
              Slider(
                value: record.painLevel.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '${record.painLevel}',
                onChanged: (value) => widget.onUpdate(
                  record.copyWith(painLevel: value.round()),
                ),
              ),
            ],
            TextField(
              controller: _memoController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  widget.onUpdate(record.copyWith(memo: value)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('선택한 부위에 운동 또는 통증 기록을 추가해주세요.'),
      );
}
