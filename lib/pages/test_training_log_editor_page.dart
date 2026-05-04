import 'package:flutter/material.dart';

class _CategoryExerciseGroup {
  String main;
  String part;
  final List<String> exercises;
  final Map<String, int> setCounts;
  final Map<String, int> repCounts;
  final Map<String, int> assistCounts;
  final Map<String, String> noteByExercise;

  _CategoryExerciseGroup({
    required this.main,
    required this.part,
    List<String>? exercises,
    Map<String, int>? setCounts,
    Map<String, int>? repCounts,
    Map<String, int>? assistCounts,
    Map<String, String>? noteByExercise,
  })  : exercises = exercises ?? [],
        setCounts = setCounts ?? {},
        repCounts = repCounts ?? {},
        assistCounts = assistCounts ?? {},
        noteByExercise = noteByExercise ?? {};
}

class TestTrainingLogEditorPage extends StatefulWidget {
  final String? initialName;
  final String? initialTitle;
  final String? initialMemo;
  final String? initialType;
  final String? initialEditorMode;
  final List<String>? initialIssueChips;
  final String? initialHomeworkStatus;
  final String? initialNextLessonCheckpoint;

  final String? initialPreCondition;
  final String? initialPreMeal;
  final String? initialPreSleep;
  final String? initialPrePain;
  final String? initialPreStretching;

  final List<String>? initialDuringGoals;
  final List<String>? initialDuringFocusParts;
  final List<String>? initialDuringReactions;

  final String? initialPostPainChange;
  final String? initialPostPerformance;
  final String? initialPostNextAction;
  final String? initialPostHomework;

  final String? initialInternalMemo;
  final String? initialPublicSummary;
  final String? initialPublicGood;
  final String? initialPublicHomeworkNote;
  final String? initialPublicCaution;

  const TestTrainingLogEditorPage({
    super.key,
    this.initialName,
    this.initialTitle,
    this.initialMemo,
    this.initialType,
    this.initialEditorMode,
    this.initialIssueChips,
    this.initialHomeworkStatus,
    this.initialNextLessonCheckpoint,

    this.initialPreCondition,
    this.initialPreMeal,
    this.initialPreSleep,
    this.initialPrePain,
    this.initialPreStretching,

    this.initialDuringGoals,
    this.initialDuringFocusParts,
    this.initialDuringReactions,

    this.initialPostPainChange,
    this.initialPostPerformance,
    this.initialPostNextAction,
    this.initialPostHomework,

    this.initialInternalMemo,
    this.initialPublicSummary,
    this.initialPublicGood,
    this.initialPublicHomeworkNote,
    this.initialPublicCaution,

  });

  @override
  State<TestTrainingLogEditorPage> createState() =>
      _TestTrainingLogEditorPageState();
}

class _TestTrainingLogEditorPageState extends State<TestTrainingLogEditorPage> {
  final TextEditingController _titleC = TextEditingController();
  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _memoC = TextEditingController();


  String _type = '개인PT';
  bool _usedVoiceDraft = false;
  String _rawVoiceText = '';
  String _editorMode = 'text';
  String _currentCategoryMain = '';
  String _currentCategoryPart = '';
  final List<_CategoryExerciseGroup> _categoryGroups = [];
  final Map<String, bool> _memoPanelOpen = {};

  final List<String> _issueChipOptions = [
    '통증',
    '피로',
    '공복',
    '결혼준비',
    '수면부족',
    'PMS',
  ];

  late Set<String> _selectedIssueChips;
  late String _homeworkStatus;
  late TextEditingController _nextCheckpointController;

  late String _preCondition;
  late String _preMeal;
  late String _preSleep;
  late String _prePain;
  late String _preStretching;

  late Set<String> _duringGoals;
  late Set<String> _duringFocusParts;
  late Set<String> _duringReactions;

  late String _postPainChange;
  late String _postPerformance;
  late String _postNextAction;
  late String _postHomework;

  late TextEditingController _internalMemoController;
  late TextEditingController _publicSummaryController;
  late TextEditingController _publicGoodController;
  late TextEditingController _publicHomeworkController;
  late TextEditingController _publicCautionController;

  @override
  void initState() {
    super.initState();

    _titleC.text = widget.initialTitle ?? '';
    _nameC.text = widget.initialName ?? '';
    _memoC.text = widget.initialMemo ?? '';
    _type = widget.initialType ?? '개인PT';
    _editorMode = widget.initialEditorMode ?? 'text';

    _selectedIssueChips = {...?widget.initialIssueChips};
    _homeworkStatus = widget.initialHomeworkStatus ?? '없음';

    _nextCheckpointController = TextEditingController(
      text: widget.initialNextLessonCheckpoint ?? '',
    );

    _preCondition = widget.initialPreCondition ?? '보통';
    _preMeal = widget.initialPreMeal ?? '가볍게 먹음';
    _preSleep = widget.initialPreSleep ?? '보통';
    _prePain = widget.initialPrePain ?? '없음';
    _preStretching = widget.initialPreStretching ?? '안 함';

    _duringGoals = {...?widget.initialDuringGoals};
    _duringFocusParts = {...?widget.initialDuringFocusParts};
    _duringReactions = {...?widget.initialDuringReactions};

    _postPainChange = widget.initialPostPainChange ?? '없음';
    _postPerformance = widget.initialPostPerformance ?? '보통';
    _postNextAction = widget.initialPostNextAction ?? '유지';
    _postHomework = widget.initialPostHomework ?? '없음';

    _internalMemoController =
        TextEditingController(text: widget.initialInternalMemo ?? '');
    _publicSummaryController =
        TextEditingController(text: widget.initialPublicSummary ?? '');
    _publicGoodController =
        TextEditingController(text: widget.initialPublicGood ?? '');
    _publicHomeworkController =
        TextEditingController(text: widget.initialPublicHomeworkNote ?? '');
    _publicCautionController =
        TextEditingController(text: widget.initialPublicCaution ?? '');
  }

  final List<String> _mainCategories = [
    '웨이트 트레이닝',
    '필라테스',
    '기능성 운동',
    '재활 운동',
  ];

  final Map<String, List<String>> _partCategories = {
    '웨이트 트레이닝': ['상체', '하체', '코어', '전신'],
    '필라테스': ['호흡', '코어', '골반', '전신'],
    '기능성 운동': ['밸런스', '가동성', '코어', '전신'],
    '재활 운동': ['목/어깨', '허리', '무릎', '고관절'],
  };

  final Map<String, List<String>> _exerciseCategories = {
    '상체': ['벤치프레스', '랫풀다운', '숄더프레스', '시티드로우'],
    '하체': ['스쿼트', '레그익스텐션', '레그컬', '브릿지'],
    '코어': ['플랭크', '데드버그', '버드독', '크런치'],
    '전신': ['런지', '케틀벨스윙', '스텝업', '월슬라이드'],
    '호흡': ['호흡 패턴', '브리딩', '흉곽 열기'],
    '골반': ['골반 중립', '브릿지', '클램쉘'],
    '밸런스': ['싱글레그 밸런스', '밴드 워크', '스텝 컨트롤'],
    '가동성': ['흉추 회전', '고관절 모빌리티', '햄스트링 스트레칭'],
    '목/어깨': ['견갑 안정화', '월슬라이드', '밴드 풀어파트'],
    '허리': ['맥길 컬업', '버드독', '브릿지'],
    '무릎': ['터미널 니 익스텐션', '레그익스텐션', '스텝다운'],
    '고관절': ['클램쉘', '힙어브덕션', '브릿지'],
  };

  @override
  void dispose() {
    _titleC.dispose();
    _nameC.dispose();
    _memoC.dispose();
    _nextCheckpointController.dispose();

    _internalMemoController.dispose();
    _publicSummaryController.dispose();
    _publicGoodController.dispose();
    _publicHomeworkController.dispose();
    _publicCautionController.dispose();

    super.dispose();
  }

  _CategoryExerciseGroup? _findCategoryGroup(String main, String part) {
    for (final group in _categoryGroups) {
      if (group.main == main && group.part == part) {
        return group;
      }
    }
    return null;
  }

  _CategoryExerciseGroup _getOrCreateCategoryGroup(String main, String part) {
    final found = _findCategoryGroup(main, part);
    if (found != null) return found;

    final created = _CategoryExerciseGroup(main: main, part: part);
    _categoryGroups.add(created);
    return created;
  }

  _CategoryExerciseGroup? get _currentCategoryGroup {
    if (_currentCategoryMain.isEmpty || _currentCategoryPart.isEmpty)
      return null;
    return _findCategoryGroup(_currentCategoryMain, _currentCategoryPart);
  }

  int get _totalSelectedExerciseCount {
    int count = 0;
    for (final group in _categoryGroups) {
      count += group.exercises.length;
    }
    return count;
  }

  String _memoPanelKey(String main, String part, String exercise) {
    return '$main|$part|$exercise';
  }

  void _insertVoiceDraftSample() {
    const sampleVoiceText =
        '오늘은 하체 위주로 진행했고 스쿼트 20kg 12회 3세트, 레그컬 15회 3세트 진행. 무릎 통증은 지난주보다 감소함.';

    const sampleDraft =
        '하체 위주 진행\n- 스쿼트 20kg 12회 3세트\n- 레그컬 15회 3세트\n- 무릎 통증 지난주 대비 감소';

    setState(() {
      _usedVoiceDraft = true;
      _rawVoiceText = sampleVoiceText;

      if (_titleC.text
          .trim()
          .isEmpty) {
        _titleC.text = '음성 초안 기록';
      }

      if (_memoC.text
          .trim()
          .isEmpty) {
        _memoC.text = sampleDraft;
      } else {
        _memoC.text = '${_memoC.text.trim()}\n\n$sampleDraft';
      }
    });
  }

  void _toggleExerciseChip(String exercise) {
    if (_currentCategoryMain.isEmpty || _currentCategoryPart.isEmpty) return;

    setState(() {
      final group = _getOrCreateCategoryGroup(
        _currentCategoryMain,
        _currentCategoryPart,
      );

      if (group.exercises.contains(exercise)) {
        group.exercises.remove(exercise);
        group.setCounts.remove(exercise);
        group.repCounts.remove(exercise);
        group.assistCounts.remove(exercise);
        group.noteByExercise.remove(exercise);

        if (group.exercises.isEmpty) {
          _categoryGroups.remove(group);
        }
      } else {
        group.exercises.add(exercise);
        group.setCounts[exercise] = 3;
        group.repCounts[exercise] = 12;
        group.assistCounts[exercise] = 0;
        group.noteByExercise.putIfAbsent(exercise, () => '');
      }

      _syncCategoryDraftToFields();
    });
  }

  void _changeExerciseSetCount(String main,
      String part,
      String exercise,
      int delta,) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    final current = group.setCounts[exercise] ?? 3;
    final next = (current + delta).clamp(1, 10);

    setState(() {
      group.setCounts[exercise] = next;
      _syncCategoryDraftToFields();
    });
  }

  void _changeExerciseRepCount(String main,
      String part,
      String exercise,
      int delta,) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    final current = group.repCounts[exercise] ?? 12;
    final next = (current + delta).clamp(1, 30);

    setState(() {
      group.repCounts[exercise] = next;
      _syncCategoryDraftToFields();
    });
  }

  void _changeExerciseAssistCount(
      String main,
      String part,
      String exercise,
      int delta,
      ) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    final currentAssist = group.assistCounts[exercise] ?? 0;
    final nextAssist = (currentAssist + delta).clamp(0, 10);

    final currentRep = group.repCounts[exercise] ?? 12;
    final repDelta = nextAssist - currentAssist;
    final nextRep = (currentRep + repDelta).clamp(1, 30);

    setState(() {
      group.assistCounts[exercise] = nextAssist;
      group.repCounts[exercise] = nextRep;
      _syncCategoryDraftToFields();
    });
  }

  void _toggleExerciseAssist(String main, String part, String exercise) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    setState(() {
      final current = group.assistCounts[exercise] ?? 0;
      group.assistCounts[exercise] = current == 0 ? 1 : 0;
      _syncCategoryDraftToFields();
    });
  }

  void _toggleMemoPanel(String main, String part, String exercise) {
    final key = _memoPanelKey(main, part, exercise);

    setState(() {
      _memoPanelOpen[key] = !(_memoPanelOpen[key] ?? false);
    });
  }

  Future<void> _openExerciseMemoDialog(
      String main,
      String part,
      String exercise,
      ) async {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    final controller = TextEditingController(
      text: group.noteByExercise[exercise] ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$exercise 메모'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '예: 무릎 안쪽 말림 / 호흡 끊김 / 골반 흔들림',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('메모 삭제'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() {
      group.noteByExercise[exercise] = result;
      _syncCategoryDraftToFields();
    });
  }

  String _exerciseMemo(String main, String part, String exercise) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return '';
    return (group.noteByExercise[exercise] ?? '').trim();
  }

  String _relatedExerciseHint(String main, String part, String exercise) {
    for (final group in _categoryGroups) {
      if (group.main == main && group.part == part) continue;

      final sameExerciseNote = (group.noteByExercise[exercise] ?? '').trim();
      if (sameExerciseNote.isNotEmpty) {
        return sameExerciseNote;
      }

      if (group.part == part) {
        for (final note in group.noteByExercise.values) {
          final trimmed = note.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
      }
    }
    return '';
  }

  String _sameExerciseHint(String main, String part, String exercise) {
    for (final group in _categoryGroups.reversed) {
      final note = (group.noteByExercise[exercise] ?? '').trim();
      if (note.isNotEmpty) {
        return note;
      }
    }
    return '';
  }

  String _samePartHint(String main, String part, String exercise) {
    for (final group in _categoryGroups.reversed) {
      if (group.part != part) continue;

      for (final note in group.noteByExercise.values) {
        final trimmed = note.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return '';
  }

  List<String> _memoSuggestions(String main, String part, String exercise) {
    final sameExercise = <String>[];
    final samePart = <String>[];

    for (final group in _categoryGroups) {
      final sameExerciseNote = (group.noteByExercise[exercise] ?? '').trim();
      if (sameExerciseNote.isNotEmpty && !sameExercise.contains(sameExerciseNote)) {
        sameExercise.add(sameExerciseNote);
      }
    }

    for (final group in _categoryGroups) {
      if (group.part != part) continue;

      for (final note in group.noteByExercise.values) {
        final trimmed = note.trim();
        if (trimmed.isEmpty) continue;
        if (sameExercise.contains(trimmed)) continue;
        if (samePart.contains(trimmed)) continue;
        samePart.add(trimmed);
      }
    }

    final merged = [...sameExercise, ...samePart];
    return merged.take(5).toList();
  }
  void _applyMemoSuggestion(
      String main,
      String part,
      String exercise,
      String suggestion,
      ) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    setState(() {
      if (suggestion.trim().isEmpty) {
        group.noteByExercise[exercise] = '';
        _syncCategoryDraftToFields();
        return;
      }

      final current = (group.noteByExercise[exercise] ?? '').trim();
      if (current.isEmpty) {
        group.noteByExercise[exercise] = suggestion;
      } else if (!current.contains(suggestion)) {
        group.noteByExercise[exercise] = '$current / $suggestion';
      }
      _syncCategoryDraftToFields();
    });
  }
  String _shortSuggestionLabel(String text) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= 16) return normalized;
    return '${normalized.substring(0, 16)}...';
  }

  void _removeExerciseFromGroup(String main, String part, String exercise) {
    final group = _findCategoryGroup(main, part);
    if (group == null) return;

    setState(() {
      group.exercises.remove(exercise);
      group.setCounts.remove(exercise);
      group.repCounts.remove(exercise);
      group.assistCounts.remove(exercise);
      group.noteByExercise.remove(exercise);
      _memoPanelOpen.remove(_memoPanelKey(main, part, exercise));

      if (group.exercises.isEmpty) {
        _categoryGroups.remove(group);
      }

      _syncCategoryDraftToFields();
    });
  }

  void _removeCategoryGroup(String main, String part) {
    setState(() {
      _categoryGroups.removeWhere(
            (group) => group.main == main && group.part == part,
      );
      _syncCategoryDraftToFields();
    });
  }

  void _clearAllCategoryGroups() {
    setState(() {
      _categoryGroups.clear();
      _currentCategoryMain = '';
      _currentCategoryPart = '';
      _titleC.clear();
      _memoC.clear();
      _memoPanelOpen.clear();
    });
  }

  void _syncCategoryDraftToFields() {
    final lines = <String>[];

    final uniqueParts = <String>[];
    for (final group in _categoryGroups) {
      if (group.exercises.isEmpty) continue;
      if (!uniqueParts.contains(group.part)) {
        uniqueParts.add(group.part);
      }

      lines.add('운동유형: ${group.main}');
      lines.add('부위: ${group.part}');
      lines.add('운동 구성:');

      for (final exercise in group.exercises) {
        final sets = group.setCounts[exercise] ?? 3;
        final reps = group.repCounts[exercise] ?? 12;
        final assists = group.assistCounts[exercise] ?? 0;
        final memo = (group.noteByExercise[exercise] ?? '').trim();

        final assistText = assists > 0 ? ' · 서포트 ${assists}회' : '';
        final memoText = memo.isNotEmpty ? ' · 메모: $memo' : '';

        lines.add('- $exercise ${sets}세트 · ${reps}회$assistText$memoText');
      }

      lines.add('');
    }

    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }

    if (uniqueParts.isNotEmpty) {
      _titleC.text = uniqueParts.join(' • ');
    }

    _memoC.text = lines.join('\n');

    if (_categoryGroups.isEmpty) {
      _titleC.clear();
    }
  }

  Widget _buildMemoField() {
    return TextField(
      controller: _memoC,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: '운동 내용 / 메모',
        hintText: '텍스트로 직접 입력하거나 오른쪽 마이크 버튼으로 초안을 넣습니다.',
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            tooltip: '음성 초안 넣기',
            onPressed: _insertVoiceDraftSample,
            icon: Icon(
              _usedVoiceDraft ? Icons.mic : Icons.mic_none,
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
      ),
    );
  }

  String _topStatusText() {
    final name = _nameC.text.trim();
    final modeLabel = _editorMode == 'category' ? '카테고리형' : '텍스트 입력형';

    if (_editorMode == 'category') {
      final parts = <String>[];
      for (final group in _categoryGroups) {
        if (!parts.contains(group.part)) {
          parts.add(group.part);
        }
      }

      if (name.isNotEmpty && parts.isNotEmpty) {
        return '$name · $modeLabel · ${parts.join(' • ')}';
      }
      if (name.isNotEmpty) {
        return '$name · $modeLabel';
      }
      if (parts.isNotEmpty) {
        return '$modeLabel · ${parts.join(' • ')}';
      }
      return modeLabel;
    }

    if (name.isNotEmpty) {
      return '$name · $modeLabel';
    }

    return modeLabel;
  }

  String _previewPartsText() {
    if (_editorMode != 'category') return '-';

    final parts = <String>[];
    for (final group in _categoryGroups) {
      if (group.exercises.isEmpty) continue;
      if (!parts.contains(group.part)) {
        parts.add(group.part);
      }
    }

    return parts.isEmpty ? '-' : parts.join(' • ');
  }

  String _previewExerciseText() {
    if (_editorMode != 'category') return '-';

    final exercises = <String>[];
    for (final group in _categoryGroups) {
      for (final exercise in group.exercises) {
        if (!exercises.contains(exercise)) {
          exercises.add(exercise);
        }
      }
    }

    if (exercises.isEmpty) return '-';
    if (exercises.length == 1) return exercises.first;
    return '${exercises.first} 외 ${exercises.length - 1}개';
  }

  String _previewMemoStateText() {
    final memo = _memoC.text.trim();
    if (memo.isEmpty) return '없음';
    if (memo.length <= 24) return memo;
    return '${memo.substring(0, 24)}...';
  }

  Widget _buildTopGuideCard() {
    final statusText = _topStatusText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _editorMode == 'category'
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _editorMode == 'category' ? '카테고리형' : '텍스트 입력형',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _editorMode == 'category'
                        ? const Color(0xFF047857)
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              if (_usedVoiceDraft) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '음성 초안 사용중',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '기록 작성에 집중할 수 있도록 상단 정보는 최소화했습니다.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMiniCounter({
    required String label,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onMinus,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 1, horizontal: 4),
              child: Icon(Icons.remove, size: 14),
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          InkWell(
            onTap: onPlus,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 1, horizontal: 4),
              child: Icon(Icons.add, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSelectWrap({
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((value) {
        final selected = selectedValue == value;
        return InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEEF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFF4338CA) : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectWrap({
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((value) {
        final selected = selectedValues.contains(value);
        return InkWell(
          onTap: () => onToggle(value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEEF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFF4338CA) : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '저장 전 확인',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _buildPreviewRow('제목', _titleC.text.trim().isEmpty ? '-' : _titleC.text.trim()),
          const SizedBox(height: 6),
          _buildPreviewRow('회원/세션', _nameC.text.trim().isEmpty ? '-' : _nameC.text.trim()),
          const SizedBox(height: 6),
          _buildPreviewRow(
            '작성방식',
            _editorMode == 'category'
                ? '카테고리형'
                : (_usedVoiceDraft ? '텍스트 + 음성초안' : '텍스트 입력형'),
          ),
          const SizedBox(height: 6),
          _buildPreviewRow('수업유형', _type),
          if (_editorMode == 'category') ...[
            const SizedBox(height: 6),
            _buildPreviewRow('부위', _previewPartsText()),
            const SizedBox(height: 6),
            _buildPreviewRow('운동', _previewExerciseText()),
          ],
          const SizedBox(height: 6),
          _buildPreviewRow('메모', _previewMemoStateText()),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black45,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveDraft,
            child: Text(
              _editorMode == 'category'
                  ? '기록 저장하기'
                  : (_usedVoiceDraft ? '확인 후 저장하기' : '저장하고 돌아가기'),
            ),
          ),
        ),
      ),
    );
  }

  void _saveDraft() {
    final title = _titleC.text.trim();
    final name = _nameC.text.trim();
    final memo = _memoC.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모 제목을 입력해주세요.')),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 이름 또는 세션명을 입력해주세요.')),
      );
      return;
    }

    if (_editorMode == 'category' && _totalSelectedExerciseCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리형에서는 최소 1개 운동을 선택해주세요.')),
      );
      return;
    }

    Navigator.pop(context, {
      'title': title,
      'name': name,
      'memo': memo,
      'type': _type,
      'inputMethod': _editorMode == 'category'
          ? 'category'
          : (_usedVoiceDraft ? 'voice_draft' : 'text'),
      'rawVoiceText': _rawVoiceText,
      'issueChips': _selectedIssueChips.toList(),
      'homeworkStatus': _homeworkStatus,
      'nextLessonCheckpoint': _nextCheckpointController.text.trim(),

      'preCondition': _preCondition,
      'preMeal': _preMeal,
      'preSleep': _preSleep,
      'prePain': _prePain,
      'preStretching': _preStretching,

      'duringGoals': _duringGoals.toList(),
      'duringFocusParts': _duringFocusParts.toList(),
      'duringReactions': _duringReactions.toList(),

      'postPainChange': _postPainChange,
      'postPerformance': _postPerformance,
      'postNextAction': _postNextAction,
      'postHomework': _postHomework,

      'internalMemo': _internalMemoController.text.trim(),
      'publicSummary': _publicSummaryController.text.trim(),
      'publicGood': _publicGoodController.text.trim(),
      'publicHomeworkNote': _publicHomeworkController.text.trim(),
      'publicCaution': _publicCautionController.text.trim(),

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('운동일지 작성'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTopGuideCard(),
                  const SizedBox(height: 12),
                  _buildPreviewCard(),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '작성 방식',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('텍스트 입력형'),
                              selected: _editorMode == 'text',
                              onSelected: (_) {
                                setState(() {
                                  _editorMode = 'text';
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('카테고리형'),
                              selected: _editorMode == 'category',
                              onSelected: (_) {
                                setState(() {
                                  _editorMode = 'category';
                                  _usedVoiceDraft = false;
                                  _rawVoiceText = '';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            _editorMode == 'text'
                                ? '메모 입력과 음성 초안으로 기록합니다.'
                                : '운동유형, 부위, 운동을 선택해 기록합니다.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_editorMode == 'text') ...[
                    _buildSectionCard(
                      title: '기록 정보',
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleC,
                            decoration: const InputDecoration(
                              labelText: '기록 제목',
                              hintText: '예: 하체 패턴 교정',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameC,
                            decoration: const InputDecoration(
                              labelText: '회원 이름 / 세션명',
                              hintText: '예: 홍길동',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSectionCard(
                      title: '수업 유형',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('개인PT'),
                              selected: _type == '개인PT',
                              onSelected: (_) => setState(() => _type = '개인PT'),
                            ),
                            ChoiceChip(
                              label: const Text('그룹/자율'),
                              selected: _type == '그룹/자율',
                              onSelected: (_) =>
                                  setState(() => _type = '그룹/자율'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSectionCard(
                      title: '운동 내용 작성',
                      child: Column(
                        children: [
                          _buildMemoField(),
                          if (_usedVoiceDraft) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '음성 초안 기반 작성중',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '음성 원문',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _rawVoiceText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (_editorMode == 'category') ...[
                    _buildSectionCard(
                      title: '카테고리형 작성',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '1) 운동유형 선택',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              if (_categoryGroups.isNotEmpty)
                                TextButton(
                                  onPressed: _clearAllCategoryGroups,
                                  child: const Text('전체 초기화'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _mainCategories.map((item) {
                              final selected = _currentCategoryMain == item;
                              return ChoiceChip(
                                label: Text(item),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _currentCategoryMain = item;
                                    _currentCategoryPart = '';
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          if (_currentCategoryMain.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              '2) 부위 선택',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_partCategories[_currentCategoryMain] ??
                                  []).map((item) {
                                final selected = _currentCategoryPart == item;
                                return ChoiceChip(
                                  label: Text(item),
                                  selected: selected,
                                  onSelected: (_) {
                                    setState(() {
                                      _currentCategoryPart = item;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                          if (_currentCategoryPart.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              '3) 운동 선택',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_exerciseCategories[_currentCategoryPart] ??
                                  []).map((item) {
                                final selected = _currentCategoryGroup
                                    ?.exercises.contains(item) ?? false;
                                return FilterChip(
                                  label: Text(item),
                                  selected: selected,
                                  onSelected: (_) => _toggleExerciseChip(item),
                                );
                              }).toList(),
                            ),
                          ],
                          if (_categoryGroups.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                             '4) 선택된 운동 구성',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: _categoryGroups.map((group) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${group.main} > ${group.part}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '이 묶음 삭제',
                                            onPressed: () =>
                                                _removeCategoryGroup(
                                                    group.main, group.part),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        children: group.exercises.map((
                                            exercise) {
                                          final sets = group
                                              .setCounts[exercise] ?? 4;
                                          final reps = group
                                              .repCounts[exercise] ?? 12;
                                          final assists = group
                                              .assistCounts[exercise] ?? 0;

                                          final note = _exerciseMemo(group.main, group.part, exercise);
                                          final sameExerciseHint = _sameExerciseHint(group.main, group.part, exercise);
                                          final samePartHint = _samePartHint(group.main, group.part, exercise);
                                          final recentHint = sameExerciseHint.isNotEmpty ? sameExerciseHint : samePartHint;
                                          final recentHintTitle = sameExerciseHint.isNotEmpty
                                              ? '같은 운동 최근 참고'
                                              : samePartHint.isNotEmpty
                                              ? '같은 부위 최근 참고'
                                              : '';
                                          final memoSuggestions = _memoSuggestions(group.main, group.part, exercise);
                                          final isMemoPanelOpen =
                                              _memoPanelOpen[_memoPanelKey(group.main, group.part, exercise)] ?? false;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFE5E7EB)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Spacer(),
                                                    ActionChip(
                                                      label: Text(
                                                        note.isEmpty ? '+ 메모' : '메모/추천',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      backgroundColor: note.isEmpty
                                                          ? const Color(0xFFF3F4F6)
                                                          : const Color(0xFFEFF6FF),
                                                      onPressed: () => _toggleMemoPanel(
                                                        group.main,
                                                        group.part,
                                                        exercise,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    if (assists == 0)
                                                      ActionChip(
                                                        label: const Text(
                                                          '서포트 추가',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                        backgroundColor: const Color(0xFFF3F4F6),
                                                        onPressed: () => _toggleExerciseAssist(
                                                          group.main,
                                                          group.part,
                                                          exercise,
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEE2E2),
                                                          borderRadius: BorderRadius.circular(999),
                                                          border: Border.all(color: const Color(0xFFFECACA)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Text(
                                                              '서포트',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w700,
                                                                color: Color(0xFFB91C1C),
                                                              ),
                                                            ),
                                                            InkWell(
                                                              onTap: () => _changeExerciseAssistCount(
                                                                group.main,
                                                                group.part,
                                                                exercise,
                                                                -1,
                                                              ),
                                                              child: const Padding(
                                                                padding: EdgeInsets.symmetric(horizontal: 4),
                                                                child: Icon(Icons.remove, size: 14, color: Color(0xFFB91C1C)),
                                                              ),
                                                            ),
                                                            Text(
                                                              '$assists회',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w800,
                                                                color: Color(0xFFB91C1C),
                                                              ),
                                                            ),
                                                            InkWell(
                                                              onTap: () => _changeExerciseAssistCount(
                                                                group.main,
                                                                group.part,
                                                                exercise,
                                                                1,
                                                              ),
                                                              child: const Padding(
                                                                padding: EdgeInsets.symmetric(horizontal: 4),
                                                                child: Icon(Icons.add, size: 14, color: Color(0xFFB91C1C)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    const SizedBox(width: 6),
                                                    IconButton(
                                                      tooltip: '운동 삭제',
                                                      constraints: const BoxConstraints(
                                                        minWidth: 28,
                                                        minHeight: 28,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      onPressed: () => _removeExerciseFromGroup(
                                                        group.main,
                                                        group.part,
                                                        exercise,
                                                      ),
                                                      icon: const Icon(Icons.close, size: 18),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        exercise,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _buildMiniCounter(
                                                      label: '세트',
                                                      value: sets,
                                                      onMinus: () => _changeExerciseSetCount(
                                                        group.main,
                                                        group.part,
                                                        exercise,
                                                        -1,
                                                      ),
                                                      onPlus: () => _changeExerciseSetCount(
                                                        group.main,
                                                        group.part,
                                                        exercise,
                                                        1,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    _buildMiniCounter(
                                                      label: '횟수',
                                                      value: reps,
                                                      onMinus: () => _changeExerciseRepCount(
                                                        group.main,
                                                        group.part,
                                                        exercise,
                                                        -1,
                                                      ),
                                                      onPlus: () => _changeExerciseRepCount(
                                                        group.main,
                                                        group.part,
                                                        exercise,
                                                        1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (isMemoPanelOpen) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (memoSuggestions.isNotEmpty) ...[
                                                          const Text(
                                                            '추천문구',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.black45,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Wrap(
                                                            spacing: 6,
                                                            runSpacing: 6,
                                                            children: memoSuggestions.map((suggestion) {
                                                              return ActionChip(
                                                                label: Text(
                                                                  _shortSuggestionLabel(suggestion),
                                                                  style: const TextStyle(
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                                backgroundColor: const Color(0xFFF3F4F6),
                                                                onPressed: () => _applyMemoSuggestion(
                                                                  group.main,
                                                                  group.part,
                                                                  exercise,
                                                                  suggestion,
                                                                ),
                                                              );
                                                            }).toList(),
                                                          ),
                                                          const SizedBox(height: 8),
                                                        ],
                                                        Row(
                                                          children: [
                                                            OutlinedButton(
                                                              onPressed: () => _openExerciseMemoDialog(
                                                                group.main,
                                                                group.part,
                                                                exercise,
                                                              ),
                                                              child: Text(note.isEmpty ? '직접 입력' : '메모 수정'),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            if (note.isNotEmpty)
                                                              OutlinedButton(
                                                                onPressed: () => _applyMemoSuggestion(
                                                                  group.main,
                                                                  group.part,
                                                                  exercise,
                                                                  '',
                                                                ),
                                                                child: const Text('메모 비우기'),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                if (note.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                                    ),
                                                    child: Text(
                                                      note,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        height: 1.4,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (note.isEmpty && recentHint.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFFBEB),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          recentHintTitle,
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w800,
                                                            color: Color(0xFF92400E),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          recentHint,
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            height: 1.4,
                                                            color: Color(0xFF92400E),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '자동 생성 초안',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _memoC.text
                                      .trim()
                                      .isEmpty
                                      ? '선택한 내용이 여기에 자동 정리됩니다.'
                                      : _memoC.text,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildSectionCard(
                      title: '기록 정보',
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleC,
                            decoration: const InputDecoration(
                              labelText: '기록 제목',
                              hintText: '자동 생성되며 필요시 수정 가능',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameC,
                            decoration: const InputDecoration(
                              labelText: '회원 이름 / 세션명',
                              hintText: '예: 홍길동',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('개인PT'),
                                  selected: _type == '개인PT',
                                  onSelected: (_) =>
                                      setState(() => _type = '개인PT'),
                                ),
                                ChoiceChip(
                                  label: const Text('그룹/자율'),
                                  selected: _type == '그룹/자율',
                                  onSelected: (_) =>
                                      setState(() => _type = '그룹/자율'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '시작 전 체크',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('오늘 컨디션',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['좋음', '보통', '나쁨'],
                          selectedValue: _preCondition,
                          onChanged: (v) => setState(() => _preCondition = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('식사 상태',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['공복', '가볍게 먹음', '충분히 먹음'],
                          selectedValue: _preMeal,
                          onChanged: (v) => setState(() => _preMeal = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('수면 상태',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['부족', '보통', '충분'],
                          selectedValue: _preSleep,
                          onChanged: (v) => setState(() => _preSleep = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('통증 상태',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['없음', '있음'],
                          selectedValue: _prePain,
                          onChanged: (v) => setState(() => _prePain = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('사전 스트레칭',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['안 함', '조금 함', '충분히 함'],
                          selectedValue: _preStretching,
                          onChanged: (v) => setState(() => _preStretching = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '레슨 중 체크',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('오늘 목표',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildMultiSelectWrap(
                          options: const ['교정', '통증관리', '근력', '가동성', '체형'],
                          selectedValues: _duringGoals,
                          onToggle: (v) {
                            setState(() {
                              if (_duringGoals.contains(v)) {
                                _duringGoals.remove(v);
                              } else {
                                _duringGoals.add(v);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        const Text('핵심 부위',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildMultiSelectWrap(
                          options: const ['하체', '코어', '어깨', '허리', '전신'],
                          selectedValues: _duringFocusParts,
                          onToggle: (v) {
                            setState(() {
                              if (_duringFocusParts.contains(v)) {
                                _duringFocusParts.remove(v);
                              } else {
                                _duringFocusParts.add(v);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        const Text('특이 반응',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildMultiSelectWrap(
                          options: const ['통증', '집중도', '밸런스', '호흡', '자세'],
                          selectedValues: _duringReactions,
                          onToggle: (v) {
                            setState(() {
                              if (_duringReactions.contains(v)) {
                                _duringReactions.remove(v);
                              } else {
                                _duringReactions.add(v);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '종료 후 체크',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('통증 변화',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['없음', '감소', '유지', '증가'],
                          selectedValue: _postPainChange,
                          onChanged: (v) => setState(() => _postPainChange = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('수행도',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['낮음', '보통', '좋음'],
                          selectedValue: _postPerformance,
                          onChanged: (v) => setState(() => _postPerformance = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('다음 수업 포인트',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['유지', '진도업', '통증재체크', '숙제확인'],
                          selectedValue: _postNextAction,
                          onChanged: (v) => setState(() => _postNextAction = v),
                        ),
                        const SizedBox(height: 14),

                        const Text('숙제',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildSingleSelectWrap(
                          options: const ['없음', '스트레칭', '복습운동', '걷기', '영상확인'],
                          selectedValue: _postHomework,
                          onChanged: (v) => setState(() => _postHomework = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '내부 메모',
                    child: TextField(
                      controller: _internalMemoController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '트레이너용 내부 기록',
                        hintText: '통증/자세 반응/지도 포인트/다음 수업 판단 메모',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '회원 공개 메모',
                    child: Column(
                      children: [
                        TextField(
                          controller: _publicSummaryController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '짧은 수업 요약',
                            hintText: '오늘 진행한 핵심 내용을 짧게 정리',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _publicGoodController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '오늘 잘한 점',
                            hintText: '회원에게 보여줄 긍정 피드백',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _publicHomeworkController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '숙제',
                            hintText: '스트레칭, 복습운동, 걷기 등',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _publicCautionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '주의할 점',
                            hintText: '회원에게 전달할 주의사항',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSectionCard(
                    title: '레슨 체크사항',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '특이사항',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _issueChipOptions.map((chip) {
                            final selected = _selectedIssueChips.contains(chip);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedIssueChips.remove(chip);
                                  } else {
                                    _selectedIssueChips.add(chip);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFFEEF2FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text(
                                  chip,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? const Color(0xFF4338CA)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '숙제 수행 체크',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['없음', '완료', '일부', '미수행'].map((value) {
                            final selected = _homeworkStatus == value;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _homeworkStatus = value;
                                });
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFFEEF2FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? const Color(0xFF4338CA)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nextCheckpointController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '다음 레슨 체크포인트',
                            hintText: '예: 무릎 통증 확인, 스쿼트 숙제 확인',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                ],
              ),
            ),
            _buildBottomSaveBar(),
          ],
        ),
      ),
    );
  }
}
