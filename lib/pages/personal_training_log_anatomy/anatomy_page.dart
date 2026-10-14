import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/anatomy_exercise_store.dart';
import '../../services/anatomy_history_service.dart';
import '../../services/anatomy_log_service.dart';
import '../../services/personal_custom_exercise_service.dart';
import 'anatomy_history_page.dart';
import 'anatomy_trend_page.dart';
import 'models/anatomy_log.dart';
import 'models/anatomy_trend.dart';
import 'models/body_map_data.dart';
import 'models/body_part.dart';
import 'widgets/anatomy_header.dart';
import 'widgets/anatomy_record_sheet.dart';
import 'widgets/anatomy_step_indicator.dart';
import 'widgets/body_map_canvas.dart';
import 'widgets/step1_body_part_selector.dart';
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
    this.memberGender,
    this.service,
    this.exerciseStore,
    this.historyStore,
  });

  final String lessonLogId;
  final DateTime recordedAt;
  final String? memberId;
  final String? memberName;
  final String? lessonType;
  final String? trainerId;
  final String? scheduleDocId;

  /// 회원카드의 성별 값(`male`/`female`). 알면 그 몸으로 보여주고 고르지 않는다.
  final String? memberGender;
  final AnatomyLogService? service;

  /// 부위별 내 운동 목록 저장소. 없으면 추천 운동만 보여준다.
  final AnatomyExerciseStore? exerciseStore;

  /// 이 회원의 지난 기록 조회(최근 운동·지난번 세트·추이·이력). 없으면 이력 기능이 꺼진다.
  final AnatomyHistoryStore? historyStore;

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
  bool _genderChanged = false;
  late final bool _memberGenderKnown;

  /// true 면 바디맵에서 한쪽씩 선택하고, false 면 좌우를 함께 선택한다.
  bool _singleSide = false;
  List<AnatomyLogRecord> _records = <AnatomyLogRecord>[];

  /// 부위별 내 운동(키는 `a:부위id`). 서버에 저장된 목록을 불러와 쓴다.
  Map<String, List<String>> _customExercises = <String, List<String>>{};

  static const _stepLabels = <String>['기록', '영상·음성', '확인·저장'];

  /// 서버에서 읽은 이 회원의 지난 기록(이번 레슨 포함). 화면에서 편집 중인 기록과
  /// 합쳐서 [_history] 를 만든다.
  List<AnatomyLogRecord> _fetchedRecords = const <AnatomyLogRecord>[];

  AnatomyMemberHistory get _history => AnatomyMemberHistory.merge(
    fetched: _fetchedRecords,
    current: _records,
    lessonLogId: widget.lessonLogId,
  );

  /// 점의 좌우를 계산하는 데 쓰는 바디맵 데이터.
  BodyMapData? _mapData;

  BodyMapScene? get _scene =>
      _mapData?.sceneFor(_selectedGender, _selectedView);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnatomyLogService();
    _selectedGender = bodyGenderFromMemberValue(widget.memberGender);
    _memberGenderKnown = _selectedGender != BodyGender.unspecified;
    _load();
    _loadCustomExercises();
    _loadHistory();
    BodyMapData.load()
        .then((data) {
          if (mounted) setState(() => _mapData = data);
        })
        .catchError((_) {});
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
        if (records.isNotEmpty) {
          if (!_memberGenderKnown) _selectedGender = records.first.bodyGender;
          _selectedView = records.first.bodyView;
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

  Future<void> _loadHistory() async {
    final store = widget.historyStore;
    final memberId = (widget.memberId ?? '').trim();
    if (store == null || memberId.isEmpty || _trainerId.isEmpty) return;
    try {
      final records = await store.loadMemberRecords(
        trainerId: _trainerId,
        memberId: memberId,
      );
      if (!mounted) return;
      setState(() => _fetchedRecords = records);
    } catch (_) {
      // 이력을 못 불러와도 기록은 그대로 할 수 있다(최근·지난번·추이만 빠진다).
    }
  }

  Future<void> _openTrend(String exercise) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                AnatomyExerciseTrendPage(exercise: exercise, history: _history),
      ),
    );
  }

  Future<void> _openHistory() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => AnatomyHistoryPage(
              memberName: widget.memberName ?? '',
              history: _history,
            ),
      ),
    );
  }

  Future<void> _loadCustomExercises() async {
    final store = widget.exerciseStore;
    if (store == null) return;
    try {
      final loaded = await store.load();
      if (!mounted) return;
      setState(() => _customExercises = loaded);
    } catch (_) {
      // 내 운동을 못 불러와도 추천 운동으로 기록할 수 있다.
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
    0 => _records.isNotEmpty || _hadPersistedRecords,
    _ => true,
  };

  BodyPart? _partById(String id) {
    for (final part in kBodyParts) {
      if (part.id == id) return part;
    }
    return null;
  }

  /// 좌우 구분이 없는 부위는 `center`, 나머지는 기본 `both`.
  BodySide _defaultSideFor(String id) =>
      id == 'abs' ? BodySide.center : BodySide.both;

  /// 기록이 있는 부위의 좌우. 바디맵에 칠할 상태이며, 같은 부위의 기록이
  /// 서로 다른 좌우면 양쪽으로 합친다.
  Map<String, BodySide> get _partSides {
    final result = <String, BodySide>{};
    for (final record in _records) {
      final known = result[record.bodyPartId];
      result[record.bodyPartId] =
          known == null || known == record.bodySide
              ? record.bodySide
              : BodySide.both;
    }
    return result;
  }

  /// 부위 목록(칩)에서 부위를 골랐을 때.
  void _onPartChipTapped(String id) {
    final part = _partById(id);
    if (part == null) return;
    _openRecordSheet(part, _defaultSideFor(id));
  }

  /// 바디맵을 눌렀을 때. 점을 누르면 그 기록을 수정하고, 구역을 누르면 그 부위의
  /// 입력 창을, 구역 밖의 몸을 누르면 기타 부위 입력 창을 연다. 누른 자리는
  /// 통증·주의·가동성 점의 위치가 된다.
  void _onMapTapped(AnatomyMapTap tap) {
    final pinned = tap.pinRecord;
    if (pinned != null) {
      _editRecord(pinned);
      return;
    }
    final zone = tap.zone;
    final part = _partById(zone?.part ?? 'other');
    if (part == null) return;
    // 운동의 좌우: 양쪽 함께 모드는 부위 전체, 한쪽씩 모드는 누른 쪽.
    final side =
        zone != null &&
                _singleSide &&
                (zone.side == BodySide.left || zone.side == BodySide.right)
            ? zone.side
            : _defaultSideFor(part.id);
    double round1(double v) => (v * 10).roundToDouble() / 10;
    _openRecordSheet(
      part,
      side,
      pin: AnatomyPin(x: round1(tap.point.dx), y: round1(tap.point.dy)),
      pinSide: _scene?.sideForPoint(tap.point, zone) ?? BodySide.center,
    );
  }

  String _customKey(BodyPart part) => 'a:${part.id}';

  static String _norm(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// 같은 부위·좌우·종류·글자의 통증·주의·가동성 기록이 이미 있는지
  /// ([exceptId] 는 수정 중인 기록). 운동은 같은 기록을 여러 번 넣을 수 있다.
  bool _isDuplicate(AnatomyRecordDraft draft, {String? exceptId}) {
    if (draft.type == AnatomyRecordType.exercise) return false;
    return _records.any(
      (r) =>
          r.anatomyLogId != exceptId &&
          r.recordType == draft.type &&
          r.bodyPartId == draft.partId &&
          r.bodySide == draft.side &&
          _norm(r.exerciseName) == _norm(draft.exerciseName),
    );
  }

  Future<void> _openRecordSheet(
    BodyPart part,
    BodySide side, {
    AnatomyPin? pin,
    BodySide? pinSide,
  }) async {
    final outcome = await showAnatomyRecordSheet(
      context,
      part: part,
      initialSide: side,
      customExercises: _customExercises[_customKey(part)] ?? const <String>[],
      onCustomExerciseAdded: (name) => _rememberCustomExercise(part, name),
      pin: pin,
      pinSide: pinSide,
      customChips: _customExercises,
      onCustomChipAdded: _rememberCustomChip,
      isDuplicate: _isDuplicate,
      history: widget.historyStore == null ? null : _history,
      currentLessonLogId: widget.lessonLogId,
      onOpenTrend: widget.historyStore == null ? null : _openTrend,
    );
    if (!mounted || outcome == null) return;
    setState(() {
      for (final draft in outcome.drafts) {
        _records = [..._records, _newRecord(part, draft)];
      }
    });
  }

  Future<void> _editRecord(AnatomyLogRecord record) async {
    final part = _partById(record.bodyPartId);
    if (part == null) return;
    final outcome = await showAnatomyRecordSheet(
      context,
      part: part,
      initialSide: record.bodySide,
      editing: record,
      customExercises: _customExercises[_customKey(part)] ?? const <String>[],
      onCustomExerciseAdded: (name) => _rememberCustomExercise(part, name),
      customChips: _customExercises,
      onCustomChipAdded: _rememberCustomChip,
      isDuplicate:
          (draft) => _isDuplicate(draft, exceptId: record.anatomyLogId),
      history: widget.historyStore == null ? null : _history,
      currentLessonLogId: widget.lessonLogId,
      onOpenTrend: widget.historyStore == null ? null : _openTrend,
    );
    if (!mounted || outcome == null) return;
    if (outcome.delete == true) {
      _removeRecord(record.anatomyLogId);
      return;
    }
    final draft = outcome.edited;
    if (draft == null) return;
    final target = _partById(draft.partId) ?? part;
    _updateRecord(
      record.copyWith(
        bodyPartId: target.id,
        bodyPartLabel: target.label,
        bodyView:
            target.visibleIn(record.bodyView) ? record.bodyView : target.view,
        relatedPartIds: draft.relatedPartIds,
        bodySide: draft.side,
        recordType: draft.type,
        exerciseName: draft.exerciseName,
        sets: draft.sets,
        painLevel: draft.painLevel,
        memo: draft.memo,
        mobilityResult: draft.mobilityResult,
        clearMobilityResult: draft.mobilityResult == null,
      ),
    );
  }

  AnatomyLogRecord _newRecord(BodyPart tapped, AnatomyRecordDraft draft) {
    // 입력 창에서 목표 부위를 바꿨을 수 있어 초안의 부위를 따른다.
    final part = _partById(draft.partId) ?? tapped;
    final now = DateTime.now();
    return AnatomyLogRecord(
      anatomyLogId: _service.newRecordId(widget.lessonLogId),
      trainerId: _trainerId,
      memberId: (widget.memberId ?? '').trim(),
      lessonLogId: widget.lessonLogId,
      scheduleDocId: (widget.scheduleDocId ?? '').trim(),
      recordedAt: widget.recordedAt,
      bodyGender: _selectedGender,
      bodyView: part.visibleIn(_selectedView) ? _selectedView : part.view,
      bodySide: draft.side,
      bodyPartId: part.id,
      bodyPartLabel: part.label,
      recordType: draft.type,
      exerciseName: draft.exerciseName,
      painLevel: draft.painLevel,
      memo: draft.memo,
      sets: draft.sets,
      relatedPartIds: draft.relatedPartIds,
      pin: draft.pin,
      mobilityResult: draft.mobilityResult,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 새로 쓴 운동 이름을 내 운동 목록에 넣고 서버에 저장한다(실패해도 기록은 계속).
  Future<void> _rememberCustomExercise(BodyPart part, String name) async {
    final key = _customKey(part);
    final next = Map<String, List<String>>.of(_customExercises);
    final list = <String>[name, ...(next[key] ?? const <String>[])];
    next[key] = list.take(kCustomExerciseMaxPerPart).toList();
    _customExercises = next;
    final store = widget.exerciseStore;
    if (store == null) return;
    try {
      await store.save(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내 운동을 저장하지 못했어요. 이번 기록에는 그대로 쓸 수 있어요.')),
      );
    }
  }

  /// 내가 추가한 위치·검사 칩을 서버에 저장한다(실패해도 이번 기록은 계속).
  Future<void> _rememberCustomChip(String key, String text) async {
    final next = Map<String, List<String>>.of(_customExercises);
    final list = <String>[text, ...(next[key] ?? const <String>[])];
    next[key] = list.take(kCustomExerciseMaxPerPart).toList();
    _customExercises = next;
    final store = widget.exerciseStore;
    if (store == null) return;
    try {
      await store.save(next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('칩을 저장하지 못했어요. 이번 기록에는 그대로 쓸 수 있어요.')),
      );
    }
  }

  void _updateRecord(AnatomyLogRecord updated) {
    setState(() {
      _records = AnatomyRecordCollection.upsert(
        _records,
        updated.copyWith(updatedAt: DateTime.now()),
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
    final normalized =
        _records.map((record) {
          final part = _partById(record.bodyPartId);
          return record.copyWith(
            recordedAt: widget.recordedAt,
            bodyGender:
                _genderChanged || _memberGenderKnown
                    ? _selectedGender
                    : record.bodyGender,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('해부학 레슨일지가 저장되었어요.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = _failureMessage(error, saving: true);
      setState(() {
        _saving = false;
        _saveError = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
      AnatomyLogErrorCode
          .immutableIdentityChange => '레슨일지 연결 정보가 일치하지 않아 저장할 수 없어요.',
      AnatomyLogErrorCode.recordNotFound => '기록이 이미 변경되었어요. 화면을 새로 열어 확인해주세요.',
      AnatomyLogErrorCode.permissionDenied => '현재 저장 권한이 없어 처리하지 못했습니다.',
      AnatomyLogErrorCode.unknown =>
        saving ? '저장하지 못했어요. 잠시 후 다시 시도해주세요.' : '기존 해부학 기록을 불러오지 못했어요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          AnatomyHeader(
            title:
                (widget.memberName ?? '').trim().isEmpty
                    ? '아나토미 레슨일지'
                    : '${widget.memberName!.trim()} 님 아나토미 레슨일지',
            trailing:
                widget.historyStore == null
                    ? null
                    : IconButton(
                      key: const ValueKey<String>('anatomy_history_button'),
                      tooltip: '변화 보기',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: _openHistory,
                    ),
          ),
          Expanded(
            child:
                _loading
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
                      },
                    )
                    : Column(
                      children: [
                        Container(
                          color: colors.surface,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
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
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.error),
                            ),
                            child: Text(
                              _saveError!,
                              style: TextStyle(
                                color: colors.onErrorContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
          ),
        ],
      ),
      bottomNavigationBar:
          _loading || _loadError != null
              ? null
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (_currentStep > 0) ...[
                        OutlinedButton(
                          onPressed: _saving ? null : _goBack,
                          child: const Text('이전'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _canProceed && !_saving ? _goNext : null,
                          child: Text(
                            _saving
                                ? '저장 중...'
                                : _currentStep == _stepLabels.length - 1
                                ? '저장하기'
                                : '다음',
                          ),
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
      records: _records,
      partSides: _partSides,
      onViewChanged: (value) => setState(() => _selectedView = value),
      onPartChipTapped: _onPartChipTapped,
      onMapTapped: _onMapTapped,
      onRecordTapped: _editRecord,
      selectedGender: _selectedGender,
      onGenderChanged:
          (value) => setState(() {
            _selectedGender = value;
            _genderChanged = true;
          }),
      singleSide: _singleSide,
      onSingleSideChanged: (value) => setState(() => _singleSide = value),
      showGenderChips: !_memberGenderKnown,
    ),
    1 => const Step3VideoMemo(),
    2 => Step4Confirm(
      memberName: widget.memberName ?? '',
      records: _records,
      gender: _selectedGender,
    ),
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
