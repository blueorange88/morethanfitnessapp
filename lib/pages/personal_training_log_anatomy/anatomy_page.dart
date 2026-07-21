import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/anatomy_log_service.dart';
import 'models/anatomy_log.dart';
import 'models/body_part.dart';
import 'widgets/anatomy_step_indicator.dart';
import 'widgets/step1_body_part_selector.dart';
import 'widgets/step2_exercise_form.dart';
import 'widgets/step3_video_memo.dart';
import 'widgets/step4_confirm.dart';

class PersonalTrainingLogAnatomyPage extends StatefulWidget {
  const PersonalTrainingLogAnatomyPage({
    super.key,
    required this.lessonLogId,
    required this.recordedAt,
    this.memberId,
    this.memberName,
    this.lessonType,
    this.trainerId,
    this.scheduleDocId,
    this.service,
  });

  final String lessonLogId;
  final DateTime recordedAt;
  final String? memberId;
  final String? memberName;
  final String? lessonType;
  final String? trainerId;
  final String? scheduleDocId;
  final AnatomyLogService? service;

  @override
  State<PersonalTrainingLogAnatomyPage> createState() =>
      _PersonalTrainingLogAnatomyPageState();
}

class _PersonalTrainingLogAnatomyPageState
    extends State<PersonalTrainingLogAnatomyPage> {
  late final AnatomyLogService _service;
  int _currentStep = 0;
  bool _loading = true;
  bool _saving = false;
  bool _hadPersistedRecords = false;
  String? _loadError;
  String? _saveError;
  final Set<String> _deletedRecordIds = <String>{};

  BodyGender _selectedGender = BodyGender.unspecified;
  BodyView _selectedView = BodyView.front;
  BodySide _selectedSide = BodySide.both;
  bool _genderChanged = false;
  bool _sideChanged = false;
  List<String> _selectedPartIds = <String>[];
  List<AnatomyLogRecord> _records = <AnatomyLogRecord>[];

  static const _stepLabels = <String>[
    '부위 선택',
    '기록 입력',
    '영상·음성',
    '확인·저장',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnatomyLogService();
    _load();
  }

  Future<void> _load() async {
    final missing = _saveContext.missingFields;
    if (missing.isNotEmpty) {
      setState(() {
        _loadError = '필수 연결 정보가 없습니다: ${missing.join(', ')}';
        _loading = false;
      });
      return;
    }
    try {
      final records = await _service.load(
        lessonLogId: widget.lessonLogId,
        trainerId: _trainerId,
        memberId: (widget.memberId ?? '').trim(),
        scheduleDocId: (widget.scheduleDocId ?? '').trim(),
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _hadPersistedRecords = records.isNotEmpty;
        _selectedPartIds = records.map((e) => e.bodyPartId).toSet().toList();
        if (records.isNotEmpty) {
          _selectedGender = records.first.bodyGender;
          _selectedView = records.first.bodyView;
          _selectedSide = records.first.bodySide;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _failureMessage(error, saving: false);
        _loading = false;
      });
    }
  }

  String get _trainerId =>
      (widget.trainerId ?? FirebaseAuth.instance.currentUser?.uid ?? '').trim();

  AnatomyLogSaveContext get _saveContext => AnatomyLogSaveContext(
        lessonLogId: widget.lessonLogId,
        trainerId: _trainerId,
        memberId: (widget.memberId ?? '').trim(),
        scheduleDocId: (widget.scheduleDocId ?? '').trim(),
      );

  bool get _canProceed => switch (_currentStep) {
        0 => _selectedPartIds.isNotEmpty,
        1 => _records.isNotEmpty || _hadPersistedRecords,
        _ => true,
      };

  BodyPart? _partById(String id) {
    for (final part in kBodyParts) {
      if (part.id == id) return part;
    }
    return null;
  }

  void _togglePart(String id) {
    setState(() {
      if (_selectedPartIds.contains(id)) {
        _selectedPartIds.remove(id);
        _deletedRecordIds.addAll(
          _records
              .where((record) => record.bodyPartId == id)
              .map((record) => record.anatomyLogId),
        );
        _records.removeWhere((record) => record.bodyPartId == id);
      } else {
        _selectedPartIds.add(id);
      }
    });
  }

  void _addRecord(String partId, AnatomyRecordType type, String name) {
    final now = DateTime.now();
    final part = _partById(partId);
    if (part == null) return;
    setState(() {
      _records = AnatomyRecordCollection.upsert(
        _records,
        AnatomyLogRecord(
          anatomyLogId: _service.newRecordId(widget.lessonLogId),
          trainerId: _trainerId,
          memberId: (widget.memberId ?? '').trim(),
          lessonLogId: widget.lessonLogId,
          scheduleDocId: (widget.scheduleDocId ?? '').trim(),
          recordedAt: widget.recordedAt,
          bodyGender: _selectedGender,
          bodyView: part.view,
          bodySide: _selectedSide,
          bodyPartId: part.id,
          bodyPartLabel: part.label,
          recordType: type,
          exerciseName: name,
          painLevel: 0,
          memo: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  void _updateRecord(AnatomyLogRecord updated) {
    setState(() {
      _records = AnatomyRecordCollection.upsert(
        _records,
        updated.copyWith(
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  void _removeRecord(String id) {
    setState(() {
      _deletedRecordIds.add(id);
      _records = AnatomyRecordCollection.remove(_records, id);
    });
  }

  Future<void> _goNext() async {
    if (_currentStep < _stepLabels.length - 1) {
      setState(() => _currentStep++);
      return;
    }
    await _save();
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).maybePop(false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final missing = _saveContext.missingFields;
    if (missing.isNotEmpty) {
      setState(() {
        _saveError = '필수 연결 정보가 없어 저장할 수 없습니다: ${missing.join(', ')}';
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final normalized = _records.map((record) {
      final part = _partById(record.bodyPartId);
      return record.copyWith(
        recordedAt: widget.recordedAt,
        bodyGender: _genderChanged ? _selectedGender : record.bodyGender,
        bodyView: part?.view ?? record.bodyView,
        bodySide: _sideChanged ? _selectedSide : record.bodySide,
        bodyPartLabel: part?.label ?? record.bodyPartLabel,
      );
    }).toList();

    try {
      await _service.save(
        lessonLogId: widget.lessonLogId,
        trainerId: _trainerId,
        memberId: (widget.memberId ?? '').trim(),
        scheduleDocId: (widget.scheduleDocId ?? '').trim(),
        records: normalized,
        deletedRecordIds: _deletedRecordIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해부학 레슨일지가 저장되었어요.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = _failureMessage(error, saving: true);
      setState(() {
        _saving = false;
        _saveError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _failureMessage(Object error, {required bool saving}) {
    if (error is! AnatomyLogException) {
      return saving ? '저장하지 못했어요. 잠시 후 다시 시도해주세요.' : '기존 해부학 기록을 불러오지 못했어요.';
    }
    return switch (error.code) {
      AnatomyLogErrorCode.unauthenticated => '로그인 상태를 확인한 뒤 다시 시도해주세요.',
      AnatomyLogErrorCode.trainerMismatch => '현재 계정으로 이 레슨일지를 수정할 수 없어요.',
      AnatomyLogErrorCode.parentNotFound => '먼저 일반 레슨일지를 저장한 뒤 해부학 기록을 작성해주세요.',
      AnatomyLogErrorCode.legacyParentMissingIdentity =>
        '이전 레슨일지의 연결 정보 보강이 필요해 지금은 저장할 수 없어요.',
      AnatomyLogErrorCode.memberMismatch ||
      AnatomyLogErrorCode.scheduleMismatch ||
      AnatomyLogErrorCode.pathLessonLogMismatch ||
      AnatomyLogErrorCode.immutableIdentityChange =>
        '레슨일지 연결 정보가 일치하지 않아 저장할 수 없어요.',
      AnatomyLogErrorCode.recordNotFound => '기록이 이미 변경되었어요. 화면을 새로 열어 확인해주세요.',
      AnatomyLogErrorCode.permissionDenied => '현재 저장 권한이 없어 처리하지 못했습니다.',
      AnatomyLogErrorCode.unknown =>
        saving ? '저장하지 못했어요. 잠시 후 다시 시도해주세요.' : '기존 해부학 기록을 불러오지 못했어요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text((widget.memberName ?? '').trim().isEmpty
            ? '해부학 레슨일지'
            : '${widget.memberName} 님 · 해부학 레슨일지'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _LoadError(
                  message: _loadError!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _loadError = null;
                    });
                    _load();
                  })
              : Column(
                  children: [
                    Container(
                      color: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                      child: AnatomyStepIndicator(
                        currentStep: _currentStep,
                        totalSteps: _stepLabels.length,
                        labels: _stepLabels,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: _stepContent(),
                      ),
                    ),
                    if (_saveError != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (_currentStep > 0) ...[
                      OutlinedButton(
                          onPressed: _saving ? null : _goBack,
                          child: const Text('이전')),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _canProceed && !_saving ? _goNext : null,
                        child: Text(_saving
                            ? '저장 중...'
                            : _currentStep == _stepLabels.length - 1
                                ? '저장하기'
                                : '다음'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _stepContent() => switch (_currentStep) {
        0 => Step1BodyPartSelector(
            selectedView: _selectedView,
            selectedPartIds: _selectedPartIds,
            onViewChanged: (value) => setState(() => _selectedView = value),
            onPartToggled: _togglePart,
            selectedGender: _selectedGender,
            selectedSide: _selectedSide,
            onGenderChanged: (value) => setState(() {
              _selectedGender = value;
              _genderChanged = true;
            }),
            onSideChanged: (value) => setState(() {
              _selectedSide = value;
              _sideChanged = true;
            }),
          ),
        1 => Step2ExerciseForm(
            selectedPartIds: _selectedPartIds,
            records: _records,
            onAdd: _addRecord,
            onUpdate: _updateRecord,
            onRemove: _removeRecord,
          ),
        2 => const Step3VideoMemo(),
        3 =>
          Step4Confirm(memberName: widget.memberName ?? '', records: _records),
        _ => const SizedBox.shrink(),
      };
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      );
}
