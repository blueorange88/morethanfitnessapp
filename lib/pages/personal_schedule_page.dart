import 'dart:async';

import 'package:flutter/material.dart';

import '../models/personal_schedule.dart';
import '../services/personal_schedule_repository.dart';
import '../services/personal_schedule_widget_sync_service.dart';
import 'personal_training_log_workspace_page.dart';

class PersonalSchedulePage extends StatefulWidget {
  const PersonalSchedulePage({
    super.key,
    required this.uid,
    this.repository,
    this.widgetSync,
  });

  final String uid;
  final PersonalScheduleRepository? repository;
  final PersonalScheduleWidgetSyncService? widgetSync;

  @override
  State<PersonalSchedulePage> createState() => _PersonalSchedulePageState();
}

class _PersonalSchedulePageState extends State<PersonalSchedulePage> {
  late final PersonalScheduleRepository _repository;
  late final PersonalScheduleWidgetSyncService _widgetSync;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 28));
    _rangeEnd = _rangeStart.add(const Duration(days: 126));
    _repository = widget.repository ??
        PersonalScheduleRepository(
          uid: widget.uid,
          dataSource: FirebasePersonalScheduleDataSource(),
        );
    _widgetSync =
        widget.widgetSync ?? PersonalScheduleWidgetSyncService(uid: widget.uid);
  }

  Future<void> _openEditor([PersonalScheduleRecord? record]) async {
    final drafts = await showDialog<List<PersonalScheduleDraft>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PersonalScheduleEditor(record: record),
    );
    if (drafts == null || drafts.isEmpty) return;
    try {
      if (record == null) {
        await _repository.createMany(drafts);
      } else {
        await _repository.update(record.scheduleId, drafts.single);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('레슨일정을 저장하지 못했어요. 입력 내용을 확인해주세요.')),
      );
    }
  }

  Future<void> _delete(PersonalScheduleRecord record) async {
    try {
      await _repository.delete(record.scheduleId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('확정된 레슨이거나 삭제할 수 없는 일정이에요.')),
      );
    }
  }

  Future<void> _copyCurrentWeek(List<PersonalScheduleRecord> schedules) async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final end = monday.add(const Duration(days: 7));
    final current = schedules
        .where(
          (schedule) =>
              !schedule.startAt.isBefore(monday) &&
              schedule.startAt.isBefore(end),
        )
        .toList();
    if (current.isEmpty) return;
    try {
      await _repository.copyToWeek(
        source: current,
        targetMonday: monday.add(const Duration(days: 7)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다음 주로 복사하지 못했어요.')),
      );
    }
  }

  Future<void> _openQuickLog(PersonalScheduleRecord schedule) async {
    final memberId = (schedule.memberId ?? '').trim();
    if (memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결된 회원이 있는 일정에서만 레슨일지를 작성할 수 있어요.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogWorkspacePage(
          uid: widget.uid,
          memberId: memberId,
          memberName: schedule.name,
          scheduleDocId: schedule.scheduleId,
          initialStartAt: schedule.startAt,
          initialEndAt: schedule.endAt,
          initialLessonType: schedule.type,
          initialSource: 'home_quick_sign',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('레슨일정')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_personal_schedule'),
        onPressed: _openEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('일정 등록'),
      ),
      body: StreamBuilder<List<PersonalScheduleRecord>>(
        stream: _repository.watchRange(
          start: _rangeStart,
          endExclusive: _rangeEnd,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('레슨일정을 불러오지 못했어요.'));
          }
          final schedules = snapshot.data ?? const [];
          if (snapshot.hasData) {
            unawaited(_widgetSync.sync(schedules));
          }
          if (schedules.isEmpty) {
            return const Center(child: Text('첫 레슨일정을 등록해보세요.'));
          }
          return Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('copy_personal_schedule_week'),
                  onPressed: () => _copyCurrentWeek(schedules),
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('이번 주를 다음 주로 복사'),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return ListTile(
                      key: Key('personal_schedule_${schedule.scheduleId}'),
                      title: Text(schedule.name),
                      subtitle: Text(
                        '${_date(schedule.startAt)} ${_time(schedule.startAt)}'
                        '–${_time(schedule.endAt)} · ${schedule.type}',
                      ),
                      onTap: () => _openEditor(schedule),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '빠른 레슨일지',
                            onPressed: () => _openQuickLog(schedule),
                            icon: const Icon(Icons.edit_note_rounded),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            onPressed: () => _delete(schedule),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _date(DateTime value) => '${value.month}.${value.day}';

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _PersonalScheduleEditor extends StatefulWidget {
  const _PersonalScheduleEditor({this.record});

  final PersonalScheduleRecord? record;

  @override
  State<_PersonalScheduleEditor> createState() =>
      _PersonalScheduleEditorState();
}

class _PersonalScheduleEditorState extends State<_PersonalScheduleEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late DateTime _startAt;
  int _durationMinutes = 50;
  bool _repeatNextTwoWeeks = false;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.record?.startAt ?? DateTime.now().add(const Duration(hours: 1));
    _startAt = DateTime(
      initial.year,
      initial.month,
      initial.day,
      initial.hour,
      initial.minute < 30 ? 0 : 30,
    );
    _durationMinutes = widget.record == null
        ? 50
        : widget.record!.endAt.difference(widget.record!.startAt).inMinutes;
    _nameController = TextEditingController(text: widget.record?.name ?? '');
    _typeController = TextEditingController(text: widget.record?.type ?? 'PT');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        _startAt.hour,
        _startAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null) return;
    setState(() {
      _startAt = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final type = _typeController.text.trim();
    if (name.isEmpty || type.isEmpty) return;
    final count = widget.record == null && _repeatNextTwoWeeks ? 3 : 1;
    Navigator.of(context).pop([
      for (var index = 0; index < count; index++)
        PersonalScheduleDraft(
          startAt: _startAt.add(Duration(days: index * 7)),
          endAt: _startAt
              .add(Duration(days: index * 7, minutes: _durationMinutes)),
          name: name,
          type: type,
          memberId: widget.record?.memberId,
          phone: widget.record?.phone,
          remainingSessions: widget.record?.remainingSessions,
          totalSessions: widget.record?.totalSessions,
          memo: widget.record?.memo ?? '',
          typeColorHex: widget.record?.typeColorHex ?? '',
          status: widget.record?.status ?? 'scheduled',
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.record == null ? '레슨일정 등록' : '레슨일정 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('personal_schedule_name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: '이름 또는 임시 대상'),
            ),
            TextField(
              key: const Key('personal_schedule_type'),
              controller: _typeController,
              decoration: const InputDecoration(labelText: '레슨 종류'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _pickDate,
                    child: Text(
                        '${_startAt.year}.${_startAt.month}.${_startAt.day}'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _pickTime,
                    child:
                        Text(TimeOfDay.fromDateTime(_startAt).format(context)),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              decoration: const InputDecoration(labelText: '레슨 시간'),
              items: const [30, 40, 50, 60, 90]
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes분'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _durationMinutes = value ?? 50),
            ),
            if (widget.record == null)
              CheckboxListTile(
                key: const Key('personal_schedule_repeat'),
                contentPadding: EdgeInsets.zero,
                value: _repeatNextTwoWeeks,
                onChanged: (value) =>
                    setState(() => _repeatNextTwoWeeks = value == true),
                title: const Text('같은 요일로 3주 등록'),
              ),
            const Text(
              '이름만 입력한 일정은 회원카드를 자동 생성하지 않습니다.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }
}
