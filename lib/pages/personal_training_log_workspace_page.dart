import 'dart:async';

import 'package:flutter/material.dart';

import '../models/personal_training_log.dart';
import '../services/personal_training_log_repository.dart';

class PersonalTrainingLogWorkspacePage extends StatefulWidget {
  const PersonalTrainingLogWorkspacePage({
    super.key,
    required this.uid,
    required this.memberId,
    required this.memberName,
    this.scheduleDocId,
    this.initialStartAt,
    this.initialEndAt,
    this.initialLessonType,
    this.initialSource = 'formal',
    this.repository,
  });

  final String uid;
  final String memberId;
  final String memberName;
  final String? scheduleDocId;
  final DateTime? initialStartAt;
  final DateTime? initialEndAt;
  final String? initialLessonType;
  final String initialSource;
  final PersonalTrainingLogRepository? repository;

  @override
  State<PersonalTrainingLogWorkspacePage> createState() =>
      _PersonalTrainingLogWorkspacePageState();
}

class _PersonalTrainingLogWorkspacePageState
    extends State<PersonalTrainingLogWorkspacePage> {
  late final PersonalTrainingLogRepository _repository;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeStart = DateTime(now.year - 2, 1, 1);
    _rangeEnd = DateTime(now.year + 2, 1, 1);
    _repository = widget.repository ??
        PersonalTrainingLogRepository.firebase(uid: widget.uid);
  }

  Future<void> _create() async {
    final start = widget.initialStartAt ?? DateTime.now();
    final draft = PersonalTrainingLogDraft(
      memberId: widget.memberId,
      scheduleDocId: widget.scheduleDocId,
      lessonDate: DateTime(start.year, start.month, start.day),
      startAt: start,
      endAt: widget.initialEndAt ?? start.add(const Duration(minutes: 50)),
      lessonType: widget.initialLessonType ?? 'PT',
      source: widget.initialSource,
    );
    try {
      final id = await _repository.createDraft(draft);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _PersonalTrainingLogEditorPage(
            repository: _repository,
            lessonLogId: id,
            initialDraft: draft,
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _open(PersonalTrainingLogRecord record) async {
    final draft = PersonalTrainingLogDraft(
      memberId: record.memberId,
      scheduleDocId: record.scheduleDocId,
      lessonDate: record.lessonDate,
      startAt: record.startAt,
      endAt: record.endAt,
      lessonType: record.lessonType,
      memo: record.memo,
      source: record.source,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PersonalTrainingLogEditorPage(
          repository: _repository,
          lessonLogId: record.lessonLogId,
          initialDraft: draft,
          initialStatus: record.status,
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(personalTrainingLogErrorMessage(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.memberName} · 레슨일지')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_personal_training_log'),
        onPressed: _create,
        icon: const Icon(Icons.note_add_rounded),
        label: Text(
            widget.initialSource == 'home_quick_sign' ? '빠른 레슨일지' : '레슨일지 작성'),
      ),
      body: StreamBuilder<List<PersonalTrainingLogRecord>>(
        stream: _repository.watchMemberRange(
          memberId: widget.memberId,
          start: _rangeStart,
          endExclusive: _rangeEnd,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('레슨일지를 불러오지 못했어요.'));
          }
          final records = (snapshot.data ?? const [])
              .where((record) => _filter == 'all' || record.status == _filter)
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: DropdownButtonFormField<String>(
                  key: const Key('personal_training_log_filter'),
                  initialValue: _filter,
                  decoration: const InputDecoration(labelText: '상태'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('전체')),
                    DropdownMenuItem(value: 'draft', child: Text('작성 중')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('레슨 완료'),
                    ),
                    DropdownMenuItem(
                      value: 'no_show_deducted',
                      child: Text('노쇼 차감'),
                    ),
                    DropdownMenuItem(
                      value: 'no_show_not_deducted',
                      child: Text('노쇼 미차감'),
                    ),
                    DropdownMenuItem(value: 'service', child: Text('서비스')),
                    DropdownMenuItem(
                      value: 'confirm_cancelled',
                      child: Text('확정취소 보관함'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filter = value ?? 'all'),
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('저장된 레슨일지가 없어요.'))
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return ListTile(
                            key: Key(
                              'personal_training_log_${record.lessonLogId}',
                            ),
                            title: Text(
                              '${_date(record.startAt)} · ${record.lessonType}',
                            ),
                            subtitle: Text(
                              '${_statusLabel(record.status)}\n${record.memo}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: record.memo.isNotEmpty,
                            onTap: () => _open(record),
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

  String _date(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  String _statusLabel(String status) => switch (status) {
        'completed' => '레슨 완료',
        'no_show_deducted' => '노쇼 차감',
        'no_show_not_deducted' => '노쇼 미차감',
        'service' => '서비스',
        'confirm_cancelled' => '확정취소',
        _ => '작성 중',
      };
}

class _PersonalTrainingLogEditorPage extends StatefulWidget {
  const _PersonalTrainingLogEditorPage({
    required this.repository,
    required this.lessonLogId,
    required this.initialDraft,
    this.initialStatus = 'draft',
  });

  final PersonalTrainingLogRepository repository;
  final String lessonLogId;
  final PersonalTrainingLogDraft initialDraft;
  final String initialStatus;

  @override
  State<_PersonalTrainingLogEditorPage> createState() =>
      _PersonalTrainingLogEditorPageState();
}

class _PersonalTrainingLogEditorPageState
    extends State<_PersonalTrainingLogEditorPage> {
  late final TextEditingController _lessonTypeController;
  late final TextEditingController _memoController;
  Timer? _autosaveTimer;
  late String _status;
  bool _saving = false;
  String _saveLabel = '자동저장 준비';

  bool get _isDraft => _status == PersonalTrainingLogStatus.draft;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _lessonTypeController =
        TextEditingController(text: widget.initialDraft.lessonType);
    _memoController = TextEditingController(text: widget.initialDraft.memo);
    _lessonTypeController.addListener(_scheduleAutosave);
    _memoController.addListener(_scheduleAutosave);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _lessonTypeController
      ..removeListener(_scheduleAutosave)
      ..dispose();
    _memoController
      ..removeListener(_scheduleAutosave)
      ..dispose();
    super.dispose();
  }

  PersonalTrainingLogDraft get _currentDraft => widget.initialDraft.copyWith(
        lessonType: _lessonTypeController.text.trim(),
        memo: _memoController.text.trim(),
      );

  void _scheduleAutosave() {
    if (!_isDraft || _saving) return;
    _autosaveTimer?.cancel();
    setState(() => _saveLabel = '입력 중');
    _autosaveTimer = Timer(const Duration(milliseconds: 600), _autosave);
  }

  Future<void> _autosave() async {
    if (!_isDraft || _saving) return;
    try {
      await widget.repository.autosave(widget.lessonLogId, _currentDraft);
      if (mounted) setState(() => _saveLabel = '자동저장 완료');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveLabel = '자동저장 실패');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(personalTrainingLogErrorMessage(error))),
      );
    }
  }

  Future<void> _finalize(String status) async {
    if (_saving || !_isDraft) return;
    _autosaveTimer?.cancel();
    setState(() => _saving = true);
    try {
      await widget.repository.autosave(widget.lessonLogId, _currentDraft);
      await widget.repository.finalize(widget.lessonLogId, status);
      if (!mounted) return;
      setState(() {
        _status = status;
        _saving = false;
        _saveLabel = '확정 완료';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(personalTrainingLogErrorMessage(error))),
      );
    }
  }

  Future<void> _cancelFinalize() async {
    if (_saving || _isDraft || _status == 'confirm_cancelled') return;
    setState(() => _saving = true);
    try {
      await widget.repository.cancelFinalize(widget.lessonLogId);
      if (!mounted) return;
      setState(() {
        _status = 'confirm_cancelled';
        _saving = false;
        _saveLabel = '확정취소 완료';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(personalTrainingLogErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('레슨일지 작성')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            key: const Key('personal_training_log_type'),
            controller: _lessonTypeController,
            enabled: _isDraft && !_saving,
            decoration: const InputDecoration(labelText: '레슨 종류'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('personal_training_log_memo'),
            controller: _memoController,
            enabled: _isDraft && !_saving,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(labelText: '레슨 메모'),
          ),
          const SizedBox(height: 8),
          Text(_saveLabel, key: const Key('personal_training_log_save_state')),
          const SizedBox(height: 20),
          if (_isDraft) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () => _finalize(PersonalTrainingLogStatus.completed),
                  child: const Text('레슨 완료'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () =>
                          _finalize(PersonalTrainingLogStatus.noShowDeducted),
                  child: const Text('노쇼 차감'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _finalize(
                            PersonalTrainingLogStatus.noShowNotDeducted,
                          ),
                  child: const Text('노쇼 미차감'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _finalize(PersonalTrainingLogStatus.service),
                  child: const Text('서비스'),
                ),
              ],
            ),
          ] else if (_status != 'confirm_cancelled')
            FilledButton.tonalIcon(
              key: const Key('cancel_personal_training_log_finalize'),
              onPressed: _saving ? null : _cancelFinalize,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('확정취소'),
            )
          else
            const Text('확정취소 보관함에 저장된 레슨일지입니다.'),
        ],
      ),
    );
  }
}
