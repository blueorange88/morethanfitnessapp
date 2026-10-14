import 'package:flutter/material.dart';

import '../../../widgets/aifc_interaction.dart';
import 'package:flutter/services.dart';

import '../models/anatomy_location_chips.dart';
import '../models/anatomy_log.dart';
import '../models/anatomy_trend.dart';
import '../models/body_part.dart';
import '../models/exercise_muscles.dart';

String anatomyRecordTypeLabel(AnatomyRecordType type) => switch (type) {
  AnatomyRecordType.exercise => '운동',
  AnatomyRecordType.pain => '통증',
  AnatomyRecordType.caution => '주의',
  AnatomyRecordType.mobility => '가동성',
};

IconData anatomyRecordTypeIcon(AnatomyRecordType type) => switch (type) {
  AnatomyRecordType.exercise => Icons.fitness_center_rounded,
  AnatomyRecordType.pain => Icons.local_fire_department_rounded,
  AnatomyRecordType.caution => Icons.warning_amber_rounded,
  AnatomyRecordType.mobility => Icons.accessibility_new_rounded,
};

/// 기록 종류별 색. 운동은 테마 기본색, 통증은 오류색.
Color anatomyRecordTypeColor(AnatomyRecordType type, ColorScheme colors) =>
    switch (type) {
      AnatomyRecordType.exercise => colors.primary,
      AnatomyRecordType.pain => colors.error,
      AnatomyRecordType.caution => const Color(0xFFD97706),
      AnatomyRecordType.mobility => const Color(0xFF16A34A),
    };

/// 입력 창이 만든 기록 초안. 페이지가 신원·시각 필드를 붙여 기록으로 만든다.
class AnatomyRecordDraft {
  const AnatomyRecordDraft({
    required this.type,
    required this.exerciseName,
    required this.sets,
    required this.painLevel,
    required this.memo,
    required this.side,
    required this.partId,
    this.relatedPartIds = const <String>[],
    this.pin,
    this.mobilityResult,
  });

  final AnatomyRecordType type;
  final String exerciseName;
  final List<AnatomySet> sets;
  final int painLevel;
  final String memo;
  final BodySide side;

  /// 이번 수업의 목표(주) 부위. 입력 창에서 바꿀 수 있어 처음 누른 부위와 다를 수 있다.
  final String partId;

  /// 함께 쓴 보조 부위.
  final List<String> relatedPartIds;

  /// 통증·주의·가동성을 찍은 점. 없으면 구역 전체에 표시한다.
  final AnatomyPin? pin;

  /// 가동성 검사 결과(선택).
  final MobilityResult? mobilityResult;
}

/// 입력 창이 닫히며 돌려주는 결과.
class AnatomySheetOutcome {
  const AnatomySheetOutcome({this.drafts = const [], this.edited, this.delete});

  /// 새로 추가한 기록들(추가 모드).
  final List<AnatomyRecordDraft> drafts;

  /// 수정한 내용(수정 모드).
  final AnatomyRecordDraft? edited;

  /// 수정 모드에서 삭제를 눌렀는지.
  final bool? delete;
}

/// 부위를 눌렀을 때 올라오는 입력 창. 추가 모드는 여러 기록을 연달아 넣을 수
/// 있고, [editing] 이 있으면 그 기록 하나를 수정·삭제한다.
Future<AnatomySheetOutcome?> showAnatomyRecordSheet(
  BuildContext context, {
  required BodyPart part,
  required BodySide initialSide,
  AnatomyLogRecord? editing,
  List<String> customExercises = const <String>[],
  ValueChanged<String>? onCustomExerciseAdded,
  AnatomyPin? pin,
  BodySide? pinSide,
  Map<String, List<String>> customChips = const <String, List<String>>{},
  void Function(String key, String text)? onCustomChipAdded,
  bool Function(AnatomyRecordDraft draft)? isDuplicate,
  AnatomyMemberHistory? history,
  String? currentLessonLogId,
  ValueChanged<String>? onOpenTrend,
}) {
  return showModalBottomSheet<AnatomySheetOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder:
        (context) => AnatomyRecordSheet(
          part: part,
          initialSide: initialSide,
          editing: editing,
          customExercises: customExercises,
          onCustomExerciseAdded: onCustomExerciseAdded,
          pin: pin,
          pinSide: pinSide,
          customChips: customChips,
          onCustomChipAdded: onCustomChipAdded,
          isDuplicate: isDuplicate,
          history: history,
          currentLessonLogId: currentLessonLogId,
          onOpenTrend: onOpenTrend,
        ),
  );
}

class AnatomyRecordSheet extends StatefulWidget {
  const AnatomyRecordSheet({
    super.key,
    required this.part,
    required this.initialSide,
    this.editing,
    this.customExercises = const <String>[],
    this.onCustomExerciseAdded,
    this.pin,
    this.pinSide,
    this.customChips = const <String, List<String>>{},
    this.onCustomChipAdded,
    this.isDuplicate,
    this.history,
    this.currentLessonLogId,
    this.onOpenTrend,
  });

  final BodyPart part;
  final BodySide initialSide;
  final AnatomyLogRecord? editing;
  final List<String> customExercises;
  final ValueChanged<String>? onCustomExerciseAdded;

  /// 새로 찍은 점(추가 모드)과 그 자리의 좌우.
  final AnatomyPin? pin;
  final BodySide? pinSide;

  /// 내가 추가한 위치·검사 칩(키: [locationChipKey], [kMobilityChipKey]).
  final Map<String, List<String>> customChips;
  final void Function(String key, String text)? onCustomChipAdded;

  /// 같은 기록이 이미 있는지(있으면 추가하지 않는다).
  final bool Function(AnatomyRecordDraft draft)? isDuplicate;

  /// 이 회원의 지난 기록(최근 운동·지난번 세트·보조 부위 기억·추이).
  final AnatomyMemberHistory? history;
  final String? currentLessonLogId;

  /// 추이 화면을 연다(운동 이름).
  final ValueChanged<String>? onOpenTrend;

  @override
  State<AnatomyRecordSheet> createState() => _AnatomyRecordSheetState();
}

/// 운동을 고르면 첫 세트에 미리 채워 두는 횟수. 필요하면 고치면 된다.
const int kDefaultReps = 12;

class _SetRow {
  _SetRow({double? weight, int? reps, int? assist})
    : weight = TextEditingController(text: _fmt(weight)),
      reps = TextEditingController(text: reps == null ? '' : '$reps'),
      assist = TextEditingController(
        text: assist == null || assist <= 0 ? '' : '$assist',
      );

  final TextEditingController weight;
  final TextEditingController reps;

  /// 트레이너가 도운 횟수(선택).
  final TextEditingController assist;

  static String _fmt(double? v) {
    if (v == null || v <= 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
    assist.dispose();
  }
}

class _AnatomyRecordSheetState extends State<AnatomyRecordSheet> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _memo = TextEditingController();
  final List<_SetRow> _rows = <_SetRow>[];
  final List<AnatomyRecordDraft> _added = <AnatomyRecordDraft>[];
  late final List<String> _custom = List<String>.of(widget.customExercises);

  late AnatomyRecordType _type;
  late BodySide _side;
  String _exercise = '';
  MobilityResult? _mobility;
  final Map<String, List<String>> _chips = <String, List<String>>{};

  /// 통증 정도(1~10). 0(통증 없음)은 기록할 이유가 없어 1부터 시작한다.
  double _pain = 1;
  late String _mainId;
  List<String> _related = <String>[];
  String? _error;

  bool get _editing => widget.editing != null;
  bool get _sideFixed => widget.initialSide == BodySide.center;

  /// 이 입력이 점을 가지는지(새로 찍은 점이 있거나 점이 있는 기록을 수정 중).
  AnatomyPin? get _pin => widget.editing?.pin ?? widget.pin;

  /// 점이 있고 통증·주의·가동성이면 좌우는 점 자리로 정해져 따로 고르지 않는다.
  bool get _pinnedNote => _pin != null && _type != AnatomyRecordType.exercise;

  BodySide get _pinSide =>
      widget.editing?.bodySide ?? widget.pinSide ?? widget.initialSide;

  BodySide get _effectiveSide => _pinnedNote ? _pinSide : _side;

  /// 구역 밖(기타 부위)은 운동 기록을 할 수 없다.
  List<AnatomyRecordType> get _types =>
      widget.part.id == 'other'
          ? const [
            AnatomyRecordType.pain,
            AnatomyRecordType.caution,
            AnatomyRecordType.mobility,
          ]
          : AnatomyRecordType.values;

  @override
  void initState() {
    super.initState();
    final record = widget.editing;
    _side = widget.initialSide;
    _mainId = widget.part.id;
    _type =
        widget.part.id == 'other'
            ? AnatomyRecordType.pain
            : AnatomyRecordType.exercise;
    _chips.addAll({
      for (final entry in widget.customChips.entries)
        entry.key: List<String>.of(entry.value),
    });
    if (record != null) {
      _type = record.recordType;
      _side = record.bodySide;
      _exercise =
          record.recordType == AnatomyRecordType.exercise
              ? record.exerciseName
              : '';
      _title.text =
          record.recordType == AnatomyRecordType.exercise
              ? ''
              : record.exerciseName;
      // 예전에 0으로 저장된 통증 기록도 1부터 다시 고르게 된다.
      _pain = record.painLevel.clamp(1, 10).toDouble();
      _mobility = record.mobilityResult;
      _mainId = record.bodyPartId;
      _related = List<String>.of(record.relatedPartIds);
      _memo.text = record.memo;
      for (final set in record.sets) {
        _rows.add(
          _SetRow(weight: set.weightKg, reps: set.reps, assist: set.assist),
        );
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _memo.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<String> get _suggestions {
    final query = _search.text.trim().toLowerCase();
    final all = <String>[
      ..._custom,
      ...widget.part.recommendedExercises.where((e) => !_custom.contains(e)),
    ];
    if (query.isEmpty) return all;
    return all.where((e) => e.toLowerCase().contains(query)).toList();
  }

  void _pick(String name) {
    setState(() {
      _exercise = name;
      _related = _relatedFor(name);
      _error = null;
      _search.clear();
      if (_rows.isEmpty) _rows.add(_SetRow(reps: kDefaultReps));
    });
  }

  /// 운동의 보조 부위 기본값. 기본 사용 부위가 없는 운동(내 운동)은 이 회원에게
  /// 지난번 기록한 부위를 다시 불러온다.
  List<String> _relatedFor(String name) {
    final defaults = relatedPartsFor(name, _mainId);
    if (defaults.isNotEmpty) return defaults;
    final remembered = widget.history?.lastRelatedFor(name);
    if (remembered == null) return const <String>[];
    return [
      if (remembered.mainPartId != _mainId) remembered.mainPartId,
      ...remembered.related.where((id) => id != _mainId),
    ];
  }

  ExerciseSession? get _lastSession {
    final history = widget.history;
    if (history == null || _exercise.isEmpty) return null;
    return history.lastSession(
      _exercise,
      excludeLessonLogId: widget.currentLessonLogId,
    );
  }

  /// 지난번 레슨의 세트를 그대로 채운다.
  void _copyLastSets() {
    final last = _lastSession;
    if (last == null) return;
    setState(() {
      for (final row in _rows) {
        row.dispose();
      }
      _rows
        ..clear()
        ..addAll([
          for (final set in last.sets.take(AnatomySet.maxSets))
            _SetRow(weight: set.weightKg, reps: set.reps, assist: set.assist),
        ]);
    });
  }

  Widget _lastSessionStrip(ColorScheme colors) {
    final last = _lastSession;
    if (last == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey<String>('record_last_session'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '지난번 ${formatAnatomyDate(last.date)} · ${last.summary}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            key: const ValueKey<String>('record_copy_last'),
            onPressed: _copyLastSets,
            child: const Text('같게 입력'),
          ),
          if (widget.onOpenTrend != null)
            TextButton(
              key: const ValueKey<String>('record_open_trend'),
              onPressed: () => widget.onOpenTrend!(_exercise),
              child: const Text('추이'),
            ),
        ],
      ),
    );
  }

  Widget _recentChips(ColorScheme colors) {
    final names =
        widget.history?.recentExerciseNames(limit: 5) ?? const <String>[];
    if (names.isEmpty || _search.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '최근',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.onSurfaceVariant,
            ),
          ),
          for (final name in names)
            ActionChip(
              key: ValueKey<String>('record_recent_$name'),
              label: Text(name, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onPressed: () => _pick(name),
            ),
        ],
      ),
    );
  }

  void _addSearchAsExercise() {
    final name = _search.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return;
    if (name.length > 40) {
      setState(() => _error = '운동 이름은 40자 이하로 입력해주세요.');
      return;
    }
    if (!_custom.contains(name) &&
        !widget.part.recommendedExercises.contains(name)) {
      _custom.insert(0, name);
      widget.onCustomExerciseAdded?.call(name);
    }
    _pick(name);
  }

  void _addSetRow() {
    final last = _rows.isEmpty ? null : _rows.last;
    setState(() {
      _rows.add(
        _SetRow(
          weight: double.tryParse(last?.weight.text.replaceAll(',', '.') ?? ''),
          reps: int.tryParse(last?.reps.text ?? ''),
        ),
      );
    });
  }

  /// 입력한 세트를 읽는다. 잘못된 줄이 있으면 null 과 함께 오류를 보여준다.
  List<AnatomySet>? _readSets() {
    final sets = <AnatomySet>[];
    for (final row in _rows) {
      final weightText = row.weight.text.trim().replaceAll(',', '.');
      final repsText = row.reps.text.trim();
      final assistText = row.assist.text.trim();
      if (weightText.isEmpty && repsText.isEmpty && assistText.isEmpty) {
        continue;
      }
      final weight = weightText.isEmpty ? 0.0 : double.tryParse(weightText);
      final reps = int.tryParse(repsText);
      final assist = assistText.isEmpty ? 0 : int.tryParse(assistText);
      if (assist == null || assist < 0 || assist > AnatomySet.maxAssist) {
        setState(
          () => _error = '보조 횟수는 ${AnatomySet.maxAssist}회까지 숫자로 입력해주세요.',
        );
        return null;
      }
      if (weight == null ||
          weight < 0 ||
          weight > AnatomySet.maxWeightKg ||
          reps == null ||
          reps <= 0 ||
          reps > AnatomySet.maxReps) {
        setState(() => _error = '세트의 무게와 횟수를 확인해주세요. 횟수는 꼭 필요해요.');
        return null;
      }
      sets.add(AnatomySet(weightKg: weight, reps: reps, assist: assist));
    }
    if (sets.length > AnatomySet.maxSets) {
      setState(() => _error = '세트는 ${AnatomySet.maxSets}개까지 입력할 수 있어요.');
      return null;
    }
    return sets;
  }

  AnatomyRecordDraft? _buildDraft() {
    final isExercise = _type == AnatomyRecordType.exercise;
    if (isExercise && _exercise.isEmpty) {
      setState(() => _error = '운동을 선택하거나 이름을 입력해주세요.');
      return null;
    }
    if (!isExercise && !_hasLetter(_title.text)) {
      setState(
        () =>
            _error = switch (_type) {
              AnatomyRecordType.pain => '아픈 곳·증상을 입력해주세요. 칩을 눌러도 돼요.',
              AnatomyRecordType.caution => '주의할 점을 입력해주세요.',
              _ => '확인한 것을 입력해주세요. 칩을 눌러도 돼요.',
            },
      );
      return null;
    }
    final sets = isExercise ? _readSets() : const <AnatomySet>[];
    if (sets == null) return null;
    return AnatomyRecordDraft(
      type: _type,
      exerciseName: isExercise ? _exercise : _title.text.trim(),
      sets: sets,
      painLevel: _type == AnatomyRecordType.pain ? _pain.round() : 0,
      memo: _memo.text.trim(),
      side: _effectiveSide,
      partId: _mainId,
      relatedPartIds: isExercise ? List<String>.of(_related) : const <String>[],
      pin: isExercise ? null : _pin,
      mobilityResult: _type == AnatomyRecordType.mobility ? _mobility : null,
    );
  }

  /// 글자(한글·영문 등)가 하나라도 있는지. 숫자나 기호만 있는 입력은 걸러낸다.
  static bool _hasLetter(String text) =>
      RegExp(r'\p{L}', unicode: true).hasMatch(text);

  void _resetForm() {
    _exercise = '';
    _title.clear();
    _memo.clear();
    _search.clear();
    _pain = 1;
    _mobility = null;
    _mainId = widget.part.id;
    _related = <String>[];
    _error = null;
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
  }

  void _submit() {
    final draft = _buildDraft();
    if (draft == null) return;
    if (widget.isDuplicate?.call(draft) == true) {
      setState(() => _error = '이미 같은 기록이 있어요. 목록이나 그림의 점을 눌러 수정해주세요.');
      return;
    }
    if (_added.any((d) => _sameDraft(d, draft))) {
      setState(() => _error = '방금 같은 기록을 추가했어요.');
      return;
    }
    if (_editing) {
      Navigator.of(context).pop(AnatomySheetOutcome(edited: draft));
      return;
    }
    setState(() {
      _added.add(draft);
      _resetForm();
    });
  }

  static String _norm(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _sameDraft(AnatomyRecordDraft a, AnatomyRecordDraft b) =>
      a.type != AnatomyRecordType.exercise &&
      a.type == b.type &&
      a.partId == b.partId &&
      a.side == b.side &&
      _norm(a.exerciseName) == _norm(b.exerciseName);

  void _finish() {
    Navigator.of(context).pop(AnatomySheetOutcome(drafts: _added));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isExercise = _type == AnatomyRecordType.exercise;
    // 키보드가 없을 때는 시스템 내비게이션 바 높이만큼 비워 버튼이 가려지지 않게 한다.
    final media = MediaQuery.of(context);
    final bottomInset =
        media.viewInsets.bottom > media.viewPadding.bottom
            ? media.viewInsets.bottom
            : media.viewPadding.bottom;

    return PopScope(
      canPop: _editing || _added.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        // 연달아 추가한 기록이 있으면 창을 내려도 잃지 않게 결과로 돌려준다.
        if (!didPop && _added.isNotEmpty) _finish();
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titleText(),
                    key: const ValueKey<String>('record_sheet_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_pinnedNote && _pinSide != BodySide.both)
                  Container(
                    key: const ValueKey<String>('record_pin_side'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      switch (_pinSide) {
                        BodySide.left => '왼쪽',
                        BodySide.right => '오른쪽',
                        _ => '중앙',
                      },
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: colors.primary,
                      ),
                    ),
                  )
                else if (!_sideFixed && !_pinnedNote) ...[
                  for (final side in const [
                    BodySide.left,
                    BodySide.both,
                    BodySide.right,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        key: ValueKey<String>('record_side_${side.name}'),
                        label: Text(switch (side) {
                          BodySide.left => '왼쪽',
                          BodySide.right => '오른쪽',
                          _ => '양쪽',
                        }),
                        selected: _side == side,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _side = side),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _TypeSelector(
              type: _type,
              types: _types,
              onChanged:
                  _editing ? null : (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isExercise) ..._exerciseSection(colors),
                    if (!isExercise) ..._noteSection(colors),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey<String>('record_memo'),
                      controller: _memo,
                      maxLength: 200,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '메모 (선택)',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          key: const ValueKey<String>('record_error'),
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (_added.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '이번에 추가한 기록 ${_added.length}개',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final draft in _added)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                draft.exerciseName.isEmpty
                                    ? anatomyRecordTypeLabel(draft.type)
                                    : draft.exerciseName,
                              ),
                              onDeleted:
                                  () => setState(() => _added.remove(draft)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_editing)
                  TextButton(
                    key: const ValueKey<String>('record_delete'),
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pop(const AnatomySheetOutcome(delete: true)),
                    child: Text('삭제', style: TextStyle(color: colors.error)),
                  ),
                if (!_editing && _added.isNotEmpty)
                  TextButton(
                    key: const ValueKey<String>('record_finish'),
                    onPressed: _finish,
                    child: const Text('완료'),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey<String>('record_submit'),
                  onPressed: _submit,
                  child: Text(_editing ? '저장' : '기록 추가'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BodyPart _partOf(String id) {
    for (final part in kBodyParts) {
      if (part.id == id) return part;
    }
    return widget.part;
  }

  /// 목표 부위를 [id] 로 바꾼다. 이전 목표 부위는 보조 부위로 남는다.
  void _setMain(String id) {
    if (id == _mainId) return;
    setState(() {
      _related = [_mainId, ..._related.where((e) => e != id)];
      _mainId = id;
    });
  }

  void _toggleRelated(String id) {
    setState(() {
      _error = null;
      if (_related.contains(id)) {
        _related = _related.where((e) => e != id).toList();
      } else if (_related.length >= AnatomyLogRecord.maxRelatedParts) {
        _error = '함께 쓴 부위는 ${AnatomyLogRecord.maxRelatedParts}개까지 고를 수 있어요.';
      } else {
        _related = [..._related, id];
      }
    });
  }

  /// 보조 부위 후보: 이 운동의 기본 사용 부위 + 이미 고른 부위(목표 부위는 제외).
  List<String> get _relatedCandidates {
    final defaults = relatedPartsFor(_exercise, _mainId);
    return [
      ...defaults,
      ..._related.where((id) => !defaults.contains(id) && id != _mainId),
    ];
  }

  Widget _targetSection(ColorScheme colors) {
    final main = _partOf(_mainId);
    final selectable = [_mainId, ..._related];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '이번 수업의 목표 부위',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              key: const ValueKey<String>('record_target'),
              enabled: selectable.length > 1,
              tooltip: '목표 부위 바꾸기',
              onSelected: _setMain,
              itemBuilder:
                  (context) => [
                    for (final id in selectable)
                      PopupMenuItem<String>(
                        key: ValueKey<String>('record_target_$id'),
                        value: id,
                        child: Text(_partOf(id).label),
                      ),
                  ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      main.label,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    if (selectable.length > 1)
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: colors.onPrimary,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '함께 쓴 부위',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // 4열 격자: 칩 폭을 같게 맞춰 줄 수를 줄이고, 긴 이름은 말줄임으로 둔다.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 6.0;
            final cell = (constraints.maxWidth - gap * 3) / 4;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final id in _relatedCandidates)
                  SizedBox(
                    width: cell,
                    child: FilterChip(
                      key: ValueKey<String>('record_related_$id'),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          _partOf(id).label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                      showCheckmark: false,
                      selected: _related.contains(id),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      labelPadding: EdgeInsets.zero,
                      onSelected: (_) => _toggleRelated(id),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        InkWell(
          key: const ValueKey<String>('record_related_add'),
          borderRadius: BorderRadius.circular(10),
          onTap: _openPartPicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 4),
                Text(
                  '부위 추가',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 무게·횟수 칸에 숫자가 아닌 글자를 넣으려 할 때 알려준다.
  void _numbersOnlyToast() {
    AifcInteraction.toast(context: context, message: '숫자만 입력할 수 있어요.');
  }

  /// 모든 부위를 4열 격자로 보여준다(3행이 보이고 위아래로 스크롤). 누르면
  /// 함께 쓴 부위에 넣거나 뺀다.
  Future<void> _openPartPicker() {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              final colors = Theme.of(context).colorScheme;
              return AlertDialog(
                title: const Text(
                  '함께 쓴 부위',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 3 * 38.0 + 2 * 6.0 + 4,
                  child: GridView.builder(
                    key: const ValueKey<String>('record_part_picker'),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisExtent: 38,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: selectableRelatedParts.length,
                    itemBuilder: (context, index) {
                      final part = selectableRelatedParts[index];
                      final isMain = part.id == _mainId;
                      return FilterChip(
                        key: ValueKey<String>('record_pick_${part.id}'),
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            part.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        showCheckmark: false,
                        selected: isMain || _related.contains(part.id),
                        selectedColor:
                            isMain
                                ? colors.primary.withValues(alpha: 0.5)
                                : null,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        labelPadding: EdgeInsets.zero,
                        onSelected:
                            isMain
                                ? null
                                : (_) {
                                  _toggleRelated(part.id);
                                  setDialogState(() {});
                                },
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    key: const ValueKey<String>('record_part_picker_done'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('완료'),
                  ),
                ],
              );
            },
          ),
    );
  }

  List<Widget> _exerciseSection(ColorScheme colors) {
    final suggestions = _suggestions;
    final query = _search.text.trim();
    final hasExact = suggestions.any((e) => e == query);
    return [
      if (_exercise.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _exercise,
                  key: const ValueKey<String>('record_exercise'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
              if (!_editing)
                InkWell(
                  onTap: () => setState(() => _exercise = ''),
                  child: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
        )
      else ...[
        TextField(
          key: const ValueKey<String>('record_search'),
          controller: _search,
          onChanged: (_) => setState(() => _error = null),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '운동 검색 또는 직접 입력',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        _recentChips(colors),
        for (final name in suggestions.take(8))
          ListTile(
            key: ValueKey<String>('record_option_$name'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            trailing:
                _custom.contains(name)
                    ? Text(
                      '내 운동',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                    : null,
            onTap: () => _pick(name),
          ),
        if (query.isNotEmpty && !hasExact)
          ListTile(
            key: const ValueKey<String>('record_add_custom'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_circle_outline, color: colors.primary),
            title: Text("'$query' 내 운동으로 추가"),
            onTap: _addSearchAsExercise,
          ),
      ],
      if (_exercise.isNotEmpty) ...[
        _lastSessionStrip(colors),
        const SizedBox(height: 10),
        _targetSection(colors),
        const SizedBox(height: 10),
        Text(
          '세트',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: TextField(
                    key: ValueKey<String>('set_weight_$i'),
                    controller: _rows[i].weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      _NumberOnlyFormatter(
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        _numbersOnlyToast,
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '무게(kg)',
                      hintText: '맨몸은 비워요',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: TextField(
                    key: ValueKey<String>('set_reps_$i'),
                    controller: _rows[i].reps,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _NumberOnlyFormatter(
                        FilteringTextInputFormatter.digitsOnly,
                        _numbersOnlyToast,
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '횟수',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: ValueKey<String>('set_assist_$i'),
                    controller: _rows[i].assist,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _NumberOnlyFormatter(
                        FilteringTextInputFormatter.digitsOnly,
                        _numbersOnlyToast,
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '보조',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '세트 삭제',
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed:
                      () => setState(() {
                        _rows.removeAt(i).dispose();
                      }),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey<String>('record_add_set'),
            onPressed: _addSetRow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('세트 추가'),
          ),
        ),
      ],
    ];
  }

  String _titleText() {
    final label = _partOf(_mainId).label;
    return switch (_type) {
      AnatomyRecordType.pain => '아픈 곳 · $label',
      AnatomyRecordType.caution => '주의 · $label',
      AnatomyRecordType.mobility => '가동성 · $label',
      _ => label,
    };
  }

  /// 칩을 누르면 글자 칸에 단어를 넣는다. 이미 글자가 있으면 뒤에 이어 붙인다.
  void _applyChip(String chip) {
    final text = _title.text.trim();
    setState(() {
      _error = null;
      if (text.isEmpty) {
        _title.text = chip;
      } else if (!text.contains(chip)) {
        _title.text = '$text $chip';
      }
      _title.selection = TextSelection.collapsed(offset: _title.text.length);
    });
  }

  Future<void> _addChip(String key) async {
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _ChipInputDialog(),
    );
    final chip = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (chip.isEmpty || !_hasLetter(chip)) return;
    final defaults =
        key == kMobilityChipKey
            ? kMobilityTestChips
            : locationChipsFor(_mainId);
    final current = _chips[key] ?? const <String>[];
    if (!defaults.contains(chip) && !current.contains(chip)) {
      _chips[key] = [chip, ...current];
      widget.onCustomChipAdded?.call(key, chip);
    }
    _applyChip(chip);
  }

  List<Widget> _noteSection(ColorScheme colors) {
    final isMobility = _type == AnatomyRecordType.mobility;
    final chipKey = isMobility ? kMobilityChipKey : locationChipKey(_mainId);
    final defaults =
        isMobility ? kMobilityTestChips : locationChipsFor(_mainId);
    final custom = _chips[chipKey] ?? const <String>[];
    final chips = [...custom, ...defaults.where((c) => !custom.contains(c))];
    final label = switch (_type) {
      AnatomyRecordType.pain => '아픈 곳·증상 (필수)',
      AnatomyRecordType.caution => '주의할 점 (필수)',
      _ => '확인한 것 (필수)',
    };
    return [
      if (_type == AnatomyRecordType.pain) ...[
        Row(
          children: [
            const Text('불편 정도', style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(
              '${_pain.round()} / 10',
              key: const ValueKey<String>('record_pain_value'),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colors.error,
              ),
            ),
          ],
        ),
        Slider(
          key: const ValueKey<String>('record_pain'),
          value: _pain,
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: (value) => setState(() => _pain = value),
        ),
      ],
      TextField(
        key: const ValueKey<String>('record_title'),
        controller: _title,
        maxLength: 60,
        onChanged: (_) => setState(() => _error = null),
        decoration: InputDecoration(
          labelText: label,
          hintText: switch (_type) {
            AnatomyRecordType.pain => '예: 무릎 안쪽 당기는 통증',
            AnatomyRecordType.caution => '예: 머리 위로 들 때 조심',
            _ => '예: 토마스 테스트',
          },
          counterText: '',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final chip in chips)
            ActionChip(
              key: ValueKey<String>('record_chip_$chip'),
              label: Text(chip, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onPressed: () => _applyChip(chip),
            ),
          ActionChip(
            key: const ValueKey<String>('record_chip_add'),
            avatar: const Icon(Icons.add_rounded, size: 16),
            label: const Text('추가', style: TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            onPressed: () => _addChip(chipKey),
          ),
        ],
      ),
      if (isMobility) ...[
        const SizedBox(height: 12),
        const Text('결과 (선택)', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final result in MobilityResult.values) ...[
              Expanded(
                child: ChoiceChip(
                  key: ValueKey<String>('record_mobility_${result.name}'),
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(switch (result) {
                      MobilityResult.normal => '○ 정상',
                      MobilityResult.mild => '△ 보상',
                      MobilityResult.severe => '× 제한',
                    }, textAlign: TextAlign.center),
                  ),
                  selected: _mobility == result,
                  onSelected:
                      (selected) =>
                          setState(() => _mobility = selected ? result : null),
                ),
              ),
              if (result != MobilityResult.severe) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '○ 정상 / △ 보상(다른 곳을 써서 움직임) / × 제한(움직임이 막힘)',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
      ],
    ];
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.type,
    required this.types,
    required this.onChanged,
  });

  final AnatomyRecordType type;
  final List<AnatomyRecordType> types;
  final ValueChanged<AnatomyRecordType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final value in types)
            Expanded(
              child: InkWell(
                key: ValueKey<String>('record_type_${value.name}'),
                borderRadius: BorderRadius.circular(10),
                onTap: onChanged == null ? null : () => onChanged!(value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: value == type ? colors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        anatomyRecordTypeIcon(value),
                        size: 15,
                        color:
                            value == type
                                ? anatomyRecordTypeColor(value, colors)
                                : colors.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        anatomyRecordTypeLabel(value),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color:
                              value == type
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 칩 이름을 입력받는 창. 입력 컨트롤러를 창이 직접 들고 있어, 닫히는 동안에도
/// 안전하게 쓰이고 함께 정리된다.
class _ChipInputDialog extends StatefulWidget {
  const _ChipInputDialog();

  @override
  State<_ChipInputDialog> createState() => _ChipInputDialogState();
}

class _ChipInputDialogState extends State<_ChipInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('칩 추가', style: TextStyle(fontSize: 16)),
      content: TextField(
        key: const ValueKey<String>('record_chip_input'),
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        decoration: const InputDecoration(
          hintText: '예: 무릎 안쪽, L.trap',
          counterText: '',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          key: const ValueKey<String>('record_chip_input_done'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

/// 허용하지 않는 글자를 걸러내고, 걸러졌으면 [onRejected] 로 알린다.
class _NumberOnlyFormatter extends TextInputFormatter {
  _NumberOnlyFormatter(this.allow, this.onRejected);

  final TextInputFormatter allow;
  final VoidCallback onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final result = allow.formatEditUpdate(oldValue, newValue);
    if (result.text != newValue.text) onRejected();
    return result;
  }
}
