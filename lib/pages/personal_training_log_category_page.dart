import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class _CategoryExerciseMemory {
  static final Map<String, List<String>> customExercisesByPart = {};
}

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

class PersonalTrainingLogCategoryPage extends StatefulWidget {
  final String? initialName;
  final String? initialTitle;
  final String? initialMemo;
  final String? initialType;
  final List<String>? initialIssueChips;
  final String? initialHomeworkStatus;
  final String? initialNextLessonCheckpoint;

  final String? initialSessionLabel;
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

  const PersonalTrainingLogCategoryPage({
    super.key,
    this.initialName,
    this.initialTitle,
    this.initialMemo,
    this.initialType,
    this.initialIssueChips,
    this.initialHomeworkStatus,
    this.initialNextLessonCheckpoint,
    this.initialSessionLabel,
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
  State<PersonalTrainingLogCategoryPage> createState() =>
      _PersonalTrainingLogCategoryPageState();
}

class _PersonalTrainingLogCategoryPageState
    extends State<PersonalTrainingLogCategoryPage> {
  MtfThemeTokens get _themeTokens {
    final theme = Theme.of(context);
    return theme.extension<MtfThemeTokens>() ??
        (theme.brightness == Brightness.dark
            ? MtfThemeTokens.dark
            : MtfThemeTokens.light);
  }

  final TextEditingController _titleC = TextEditingController();
  final TextEditingController _memoC = TextEditingController();
  final TextEditingController _prePainDetailC = TextEditingController();
  final TextEditingController _duringPainDetailC = TextEditingController();
  final TextEditingController _postPainDetailC = TextEditingController();
  final TextEditingController _nextCheckpointC = TextEditingController();
  final TextEditingController _internalMemoC = TextEditingController();
  final TextEditingController _publicSummaryC = TextEditingController();
  final TextEditingController _publicGoodC = TextEditingController();
  final TextEditingController _publicHomeworkC = TextEditingController();
  final TextEditingController _publicCautionC = TextEditingController();

  late String _type;
  String _currentCategoryMain = '';
  String _currentCategoryPart = '';
  final List<_CategoryExerciseGroup> _categoryGroups = [];

  final Map<String, bool> _memoOpen = {};
  String _lastAutoSummary = '';
  bool _isApplyingAutoSummary = false;

  bool _preExpanded = true;
  bool _categoryExpanded = true;
  bool _duringExpanded = false;
  bool _postExpanded = false;
  bool _internalExpanded = false;
  bool _publicExpanded = false;
  bool _lessonEtcExpanded = false;

  late Set<String> _selectedIssueChips;
  late String _homeworkStatus;

  late String _preCondition;
  late String _preMeal;
  late String _preSleep;
  late String _prePain;
  late String _preStretching;

  late Set<String> _duringGoals;
  late Set<String> _duringFocusParts;
  late Set<String> _duringReactions;

  String _lastAutoTitle = '';
  String _titleModifier = '';
  String _cognitiveResponse = '보통';
  String _performanceResponse = '보통';
  String _focusResponse = '보통';

  late String _postPainChange;
  late String _postPerformance;
  late String _postNextAction;
  late String _postHomework;

  final List<String> _issueChipOptions = [
    '통증',
    '피로',
    '공복',
    '결혼준비',
    '수면부족',
    'PMS',
  ];

  final List<String> _mainCategories = const [
    '웨이트 트레이닝',
    '필라테스',
    '기능성 운동',
    '재활 운동',
  ];

  final Map<String, List<String>> _partCategories = const {
    '웨이트 트레이닝': ['상체', '하체', '코어', '전신'],
    '필라테스': ['호흡', '코어', '골반', '전신'],
    '기능성 운동': ['밸런스', '가동성', '코어', '전신'],
    '재활 운동': ['목/어깨', '허리', '무릎', '고관절'],
  };

  final Map<String, List<String>> _exerciseCategories = const {
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
  void initState() {
    super.initState();

    _titleC.text = widget.initialTitle ?? '';
    _memoC.text = widget.initialMemo ?? '';
    _type = widget.initialType ?? '개인PT';

    _selectedIssueChips = {...?widget.initialIssueChips};
    _homeworkStatus = widget.initialHomeworkStatus ?? '없음';
    _nextCheckpointC.text = widget.initialNextLessonCheckpoint ?? '';

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

    _internalMemoC.text = widget.initialInternalMemo ?? '';
    _publicSummaryC.text = widget.initialPublicSummary ?? '';
    _publicGoodC.text = widget.initialPublicGood ?? '';
    _publicHomeworkC.text = widget.initialPublicHomeworkNote ?? '';
    _publicCautionC.text = widget.initialPublicCaution ?? '';

    _applyAutoSummary(force: true);

    _memoC.addListener(() {
      if (!mounted) return;
      _applyAutoSummary();
      setState(() {});
    });

    _publicSummaryC.addListener(() {
      if (_isApplyingAutoSummary) return;
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleC.dispose();
    _memoC.dispose();
    _nextCheckpointC.dispose();
    _internalMemoC.dispose();
    _publicSummaryC.dispose();
    _publicGoodC.dispose();
    _publicHomeworkC.dispose();
    _publicCautionC.dispose();
    _prePainDetailC.dispose();
    _duringPainDetailC.dispose();
    _postPainDetailC.dispose();
    super.dispose();
  }

  String _guessGoalFromCategoryGroup(_CategoryExerciseGroup group) {
    if (group.main == '재활 운동') return '통증관리';
    if (group.main == '기능성 운동') return '교정';
    if (group.main == '웨이트 트레이닝') return '근력';
    if (group.main == '필라테스') return '코어 안정화';
    return '';
  }

  void _updateAutoTitleFromCategory({bool force = false}) {
    if (_categoryGroups.isEmpty) {
      _titleC.clear();
      _lastAutoTitle = '';
      return;
    }

    final parts = <String>[];
    final goals = <String>[];
    final painKeywords = <String>[];

    for (final group in _categoryGroups) {
      if (group.exercises.isEmpty) continue;

      if (!parts.contains(group.part)) {
        parts.add(group.part);
      }

      final goal = _guessGoalFromCategoryGroup(group);
      if (goal.isNotEmpty && !goals.contains(goal)) {
        goals.add(goal);
      }

      if (group.part == '무릎' && !painKeywords.contains('무릎통증')) {
        painKeywords.add('무릎통증');
      }
      if (group.part == '허리' && !painKeywords.contains('허리통증')) {
        painKeywords.add('허리통증');
      }
      if (group.part == '목/어깨' && !painKeywords.contains('어깨통증')) {
        painKeywords.add('어깨통증');
      }
      if (group.part == '고관절' && !painKeywords.contains('고관절통증')) {
        painKeywords.add('고관절통증');
      }
    }

    final titleParts = <String>[];

    for (final part in parts) {
      titleParts.add('$part운동');
    }

    for (final pain in painKeywords) {
      if (!titleParts.contains(pain)) {
        titleParts.add(pain);
      }
    }

    final modifier = _titleModifier.isNotEmpty
        ? _titleModifier
        : goals.isNotEmpty
            ? goals.first
            : '';

    if (modifier.isNotEmpty && !titleParts.contains(modifier)) {
      titleParts.add(modifier);
    }

    final nextTitle = titleParts.join(' + ');
    if (nextTitle.isEmpty) return;

    final current = _titleC.text.trim();
    if (force || current.isEmpty || current == _lastAutoTitle) {
      _titleC.text = nextTitle;
      _lastAutoTitle = nextTitle;
    }
  }

  void _applyTitleModifier(String modifier) {
    setState(() {
      _titleModifier = _titleModifier == modifier ? '' : modifier;
      _updateAutoTitleFromCategory(force: true);
    });
  }

  String _buildAutoSummaryFromMemo() {
    final lines = _memoC.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';

    final cleaned = lines
        .map((e) => e.startsWith('- ') ? e.substring(2).trim() : e)
        .toList();

    if (cleaned.length == 1) return cleaned.first;
    return '${cleaned.first} 외 ${cleaned.length - 1}개 진행';
  }

  void _applyAutoSummary({bool force = false}) {
    final generated = _buildAutoSummaryFromMemo();
    if (generated.isEmpty) return;

    final current = _publicSummaryC.text.trim();
    final shouldReplace =
        force || current.isEmpty || current == _lastAutoSummary;

    if (!shouldReplace) return;

    _isApplyingAutoSummary = true;
    _publicSummaryC.text = generated;
    _publicSummaryC.selection = TextSelection.collapsed(
      offset: _publicSummaryC.text.length,
    );
    _lastAutoSummary = generated;
    _isApplyingAutoSummary = false;
  }

  String get _memberName {
    final name = (widget.initialName ?? '').trim();
    return name.isEmpty ? '회원' : name;
  }

  _CategoryExerciseGroup? _findGroup(String main, String part) {
    for (final group in _categoryGroups) {
      if (group.main == main && group.part == part) {
        return group;
      }
    }
    return null;
  }

  _CategoryExerciseGroup _getOrCreateGroup(String main, String part) {
    final found = _findGroup(main, part);
    if (found != null) return found;

    final created = _CategoryExerciseGroup(main: main, part: part);
    _categoryGroups.add(created);
    return created;
  }

  _CategoryExerciseGroup? get _currentGroup {
    if (_currentCategoryMain.isEmpty || _currentCategoryPart.isEmpty) {
      return null;
    }
    return _findGroup(_currentCategoryMain, _currentCategoryPart);
  }

  int get _totalSelectedExerciseCount {
    int count = 0;
    for (final group in _categoryGroups) {
      count += group.exercises.length;
    }
    return count;
  }

  void _toggleExerciseChip(String exercise) {
    if (_currentCategoryMain.isEmpty || _currentCategoryPart.isEmpty) return;

    setState(() {
      final group = _getOrCreateGroup(
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
        group.noteByExercise[exercise] = '';
      }

      _syncCategoryDraftToFields();
    });
  }

  void _changeSetCount(String main, String part, String exercise, int delta) {
    final group = _findGroup(main, part);
    if (group == null) return;

    final current = group.setCounts[exercise] ?? 3;
    final next = (current + delta).clamp(1, 10);

    setState(() {
      group.setCounts[exercise] = next;
      _syncCategoryDraftToFields();
    });
  }

  void _changeRepCount(String main, String part, String exercise, int delta) {
    final group = _findGroup(main, part);
    if (group == null) return;

    final current = group.repCounts[exercise] ?? 12;
    final next = (current + delta).clamp(1, 30);

    setState(() {
      group.repCounts[exercise] = next;
      _syncCategoryDraftToFields();
    });
  }

  void _changeAssistCount(
      String main, String part, String exercise, int delta) {
    final group = _findGroup(main, part);
    if (group == null) return;

    final currentAssist = group.assistCounts[exercise] ?? 0;
    final nextAssist = (currentAssist + delta).clamp(0, 10);

    setState(() {
      group.assistCounts[exercise] = nextAssist;
      _syncCategoryDraftToFields();
    });
  }

  void _removeExercise(String main, String part, String exercise) {
    final group = _findGroup(main, part);
    if (group == null) return;

    setState(() {
      group.exercises.remove(exercise);
      group.setCounts.remove(exercise);
      group.repCounts.remove(exercise);
      group.assistCounts.remove(exercise);

      if (group.exercises.isEmpty) {
        _categoryGroups.remove(group);
      }

      _syncCategoryDraftToFields();
    });
  }

  void _removeGroup(String main, String part) {
    setState(() {
      _categoryGroups.removeWhere(
        (group) => group.main == main && group.part == part,
      );
      _syncCategoryDraftToFields();
    });
  }

  void _clearAllGroups() {
    setState(() {
      _categoryGroups.clear();
      _currentCategoryMain = '';
      _currentCategoryPart = '';
      _titleC.clear();
      _memoC.clear();
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

    _memoC.text = lines.join('\n');

    if (_categoryGroups.isEmpty) {
      _titleC.clear();
      _lastAutoTitle = '';
    } else {
      _updateAutoTitleFromCategory();
    }
  }

  Widget _buildBlueHeader() {
    final sessionLabel = (widget.initialSessionLabel ?? '').trim();
    final title = sessionLabel.isEmpty
        ? '$_memberName 님 수업일지'
        : '$_memberName 님 $sessionLabel 수업일지';
    final gradient = context.mtfHeaderGradient;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: 18,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _themeTokens.trainingLogSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeTokens.trainingLogSetDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _themeTokens.trainingLogSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeTokens.trainingLogSetDivider),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _singleSelect({
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
              color: selected
                  ? colorScheme.secondaryContainer
                  : _themeTokens.trainingLogSetRow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : _themeTokens.trainingLogSetDivider,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _multiSelect({
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
              color: selected
                  ? colorScheme.secondaryContainer
                  : _themeTokens.trainingLogSetRow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : _themeTokens.trainingLogSetDivider,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _addCustomIssueChip() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('특이사항 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '예: 어지러움 / 컨디션 저하 / 생리통',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    final value = result.trim();

    setState(() {
      if (!_issueChipOptions.contains(value)) {
        _issueChipOptions.add(value);
      }
      _selectedIssueChips.add(value);
    });
  }

  Widget _miniCounter({
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
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '$value',
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

  void _save() {
    final title = _titleC.text.trim();
    final name = (widget.initialName ?? '').trim().isEmpty
        ? '회원 미지정'
        : (widget.initialName ?? '').trim();
    final memo = _memoC.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수업일지 제목을 입력해주세요.')),
      );
      return;
    }

    if (_totalSelectedExerciseCount == 0) {
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
      'inputMethod': 'category',
      'rawVoiceText': '',
      'issueChips': _selectedIssueChips.toList(),
      'homeworkStatus': _homeworkStatus,
      'nextLessonCheckpoint': _nextCheckpointC.text.trim(),
      'preCondition': _preCondition,
      'preMeal': _preMeal,
      'preSleep': _preSleep,
      'prePain': _prePain,
      'prePainDetail': _prePainDetailC.text.trim(),
      'preStretching': _preStretching,
      'duringGoals': _duringGoals.toList(),
      'duringFocusParts': _duringFocusParts.toList(),
      'duringReactions': _duringReactions.toList(),
      'duringPainDetail': _duringPainDetailC.text.trim(),
      'postPainChange': _postPainChange,
      'postPainDetail': _postPainDetailC.text.trim(),
      'postPerformance': _postPerformance,
      'focusResponse': _focusResponse,
      'postNextAction': _postNextAction,
      'postHomework': _postHomework,
      'internalMemo': _internalMemoC.text.trim(),
      'publicSummary': _publicSummaryC.text.trim(),
      'publicGood': _publicGoodC.text.trim(),
      'publicHomeworkNote': _publicHomeworkC.text.trim(),
      'publicCaution': _publicCautionC.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildBlueHeader(),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _themeTokens.trainingLogSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _themeTokens.trainingLogSetDivider,
                            ),
                          ),
                          child: Text(
                            '운동 선택과 구성 입력에 집중할 수 있도록 필요한 정보만 남겼습니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '시작 전 체크',
                          expanded: _preExpanded,
                          onToggle: () =>
                              setState(() => _preExpanded = !_preExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '오늘 컨디션',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['좋음', '보통', '나쁨'],
                                selectedValue: _preCondition,
                                onChanged: (v) =>
                                    setState(() => _preCondition = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '식사 상태',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['공복', '가볍게 먹음', '충분히 먹음'],
                                selectedValue: _preMeal,
                                onChanged: (v) => setState(() => _preMeal = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '수면 상태',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['부족', '보통', '충분'],
                                selectedValue: _preSleep,
                                onChanged: (v) => setState(() => _preSleep = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '통증 상태',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['없음', '있음'],
                                selectedValue: _prePain,
                                onChanged: (v) => setState(() => _prePain = v),
                              ),
                              if (_prePain == '있음') ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _prePainDetailC,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: '통증 상세',
                                    hintText: '예: 오른쪽 어깨 전면이 팔 올릴 때 걸리는 느낌',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Text(
                                '사전 스트레칭',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['안 함', '조금 함', '충분히 함'],
                                selectedValue: _preStretching,
                                onChanged: (v) =>
                                    setState(() => _preStretching = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '카테고리형 작성',
                          expanded: _categoryExpanded,
                          onToggle: () => setState(
                            () => _categoryExpanded = !_categoryExpanded,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '1) 운동유형 선택',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_categoryGroups.isNotEmpty)
                                    TextButton(
                                      onPressed: _clearAllGroups,
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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      (_partCategories[_currentCategoryMain] ??
                                              [])
                                          .map((item) {
                                    final selected =
                                        _currentCategoryPart == item;
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
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '3) 운동 선택',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () async {
                                        final controller =
                                            TextEditingController();
                                        final result = await showDialog<String>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('운동 추가'),
                                            content: TextField(
                                              controller: controller,
                                              decoration: const InputDecoration(
                                                hintText: '예: 데드 버그 / 힙힌지',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('취소'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  controller.text.trim(),
                                                ),
                                                child: const Text('추가'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (result == null ||
                                            result.trim().isEmpty) return;

                                        final part = _currentCategoryPart;
                                        final list = _CategoryExerciseMemory
                                            .customExercisesByPart
                                            .putIfAbsent(part, () => []);
                                        if (!list.contains(result.trim())) {
                                          setState(() {
                                            list.add(result.trim());
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.add_rounded,
                                          size: 16),
                                      label: const Text('운동추가'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...(_exerciseCategories[
                                            _currentCategoryPart] ??
                                        []),
                                    ...(_CategoryExerciseMemory
                                                .customExercisesByPart[
                                            _currentCategoryPart] ??
                                        []),
                                  ].map((item) {
                                    final selected = _currentGroup?.exercises
                                            .contains(item) ??
                                        false;
                                    return FilterChip(
                                      label: Text(item),
                                      selected: selected,
                                      onSelected: (_) =>
                                          _toggleExerciseChip(item),
                                    );
                                  }).toList(),
                                ),
                              ],
                              if (_categoryGroups.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  '4) 선택된 운동 구성',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: _categoryGroups.map((group) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _themeTokens.trainingLogSetRow,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _themeTokens
                                              .trainingLogSetDivider,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                onPressed: () => _removeGroup(
                                                  group.main,
                                                  group.part,
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Column(
                                            children: group.exercises.map((
                                              exercise,
                                            ) {
                                              final sets =
                                                  group.setCounts[exercise] ??
                                                      3;
                                              final reps =
                                                  group.repCounts[exercise] ??
                                                      12;
                                              final assists = group
                                                      .assistCounts[exercise] ??
                                                  0;
                                              final note = group.noteByExercise[
                                                      exercise] ??
                                                  '';
                                              final memoKey =
                                                  '${group.main}|${group.part}|$exercise';
                                              final memoOpen =
                                                  _memoOpen[memoKey] ?? false;

                                              return Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _themeTokens
                                                      .trainingLogSurface,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: _themeTokens
                                                        .trainingLogSetDivider,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            exercise,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: assists == 0
                                                                ? colorScheme
                                                                    .surfaceContainerHighest
                                                                : const Color(
                                                                    0xFFFEE2E2),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                            border: Border.all(
                                                              color: assists ==
                                                                      0
                                                                  ? _themeTokens
                                                                      .trainingLogSetDivider
                                                                  : const Color(
                                                                      0xFFFECACA),
                                                            ),
                                                          ),
                                                          child: assists == 0
                                                              ? InkWell(
                                                                  onTap: () =>
                                                                      _changeAssistCount(
                                                                    group.main,
                                                                    group.part,
                                                                    exercise,
                                                                    1,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              999),
                                                                  child: Text(
                                                                    '서포트',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      color: colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                )
                                                              : Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    InkWell(
                                                                      onTap: () =>
                                                                          _changeAssistCount(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                        -1,
                                                                      ),
                                                                      child:
                                                                          const Padding(
                                                                        padding:
                                                                            EdgeInsets.symmetric(horizontal: 4),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .remove,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              Color(0xFFB91C1C),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      '서포트 $assists회',
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                        color: Color(
                                                                            0xFFB91C1C),
                                                                      ),
                                                                    ),
                                                                    InkWell(
                                                                      onTap: () =>
                                                                          _changeAssistCount(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                        1,
                                                                      ),
                                                                      child:
                                                                          const Padding(
                                                                        padding:
                                                                            EdgeInsets.symmetric(horizontal: 4),
                                                                        child:
                                                                            Icon(
                                                                          Icons
                                                                              .add,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              Color(0xFFB91C1C),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        IconButton(
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(
                                                            minWidth: 30,
                                                            minHeight: 30,
                                                          ),
                                                          onPressed: () =>
                                                              _removeExercise(
                                                            group.main,
                                                            group.part,
                                                            exercise,
                                                          ),
                                                          icon: const Icon(
                                                              Icons.close,
                                                              size: 18),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        _miniCounter(
                                                          label: '세트',
                                                          value: sets,
                                                          onMinus: () =>
                                                              _changeSetCount(
                                                            group.main,
                                                            group.part,
                                                            exercise,
                                                            -1,
                                                          ),
                                                          onPlus: () =>
                                                              _changeSetCount(
                                                            group.main,
                                                            group.part,
                                                            exercise,
                                                            1,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        _miniCounter(
                                                          label: '횟수',
                                                          value: reps,
                                                          onMinus: () =>
                                                              _changeRepCount(
                                                            group.main,
                                                            group.part,
                                                            exercise,
                                                            -1,
                                                          ),
                                                          onPlus: () =>
                                                              _changeRepCount(
                                                            group.main,
                                                            group.part,
                                                            exercise,
                                                            1,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        ActionChip(
                                                          label: Text(
                                                            note.trim().isEmpty
                                                                ? '메모'
                                                                : '메모 있음',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              _memoOpen[
                                                                      memoKey] =
                                                                  !memoOpen;
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    if (memoOpen) ...[
                                                      const SizedBox(height: 8),
                                                      TextField(
                                                        controller:
                                                            TextEditingController(
                                                          text: group.noteByExercise[
                                                                  exercise] ??
                                                              '',
                                                        ),
                                                        maxLines: 1,
                                                        decoration:
                                                            const InputDecoration(
                                                          hintText:
                                                              '예: 허리 뜨지 않게 / 오른쪽 복압 더 신경쓰기',
                                                          border:
                                                              OutlineInputBorder(),
                                                          isDense: true,
                                                        ),
                                                        onChanged: (value) {
                                                          group.noteByExercise[
                                                              exercise] = value;
                                                          _syncCategoryDraftToFields();
                                                        },
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
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _themeTokens.trainingLogSetRow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _themeTokens.trainingLogSetDivider,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '자동 생성 초안',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _memoC.text.trim().isEmpty
                                            ? '선택한 내용이 여기에 자동 정리됩니다.'
                                            : _memoC.text,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _themeTokens.trainingLogSetRow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _themeTokens.trainingLogSetDivider,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '자동으로 오늘 수업일지명을 작성해드려요',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '운동 선택 내용을 바탕으로 만들어지며, 필요하면 직접 수정할 수 있어요.',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _titleC,
                                        decoration: const InputDecoration(
                                          hintText: '예: 하체운동 + 무릎통증 + 가슴운동',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          '교정',
                                          '통증관리',
                                          '근력',
                                          '가동성',
                                          '체형'
                                        ].map((modifier) {
                                          final selected =
                                              _titleModifier == modifier;
                                          return ChoiceChip(
                                            label: Text(modifier),
                                            selected: selected,
                                            onSelected: (_) =>
                                                _applyTitleModifier(modifier),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '수업 중 체크',
                          expanded: _duringExpanded,
                          onToggle: () => setState(
                              () => _duringExpanded = !_duringExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '집중력',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['집중 잘됨', '보통', '낮음'],
                                selectedValue: _focusResponse,
                                onChanged: (v) =>
                                    setState(() => _focusResponse = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '인지 반응',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['인지 잘됨', '보통', '어려움'],
                                selectedValue: _cognitiveResponse,
                                onChanged: (v) =>
                                    setState(() => _cognitiveResponse = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '수행 반응',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const [
                                  '수행 좋음',
                                  '보통',
                                  '어려움',
                                  '통증으로 제한'
                                ],
                                selectedValue: _performanceResponse,
                                onChanged: (v) =>
                                    setState(() => _performanceResponse = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '특이 반응',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _multiSelect(
                                options: const ['통증', '밸런스', '호흡', '자세'],
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
                              if (_duringReactions.contains('통증')) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _duringPainDetailC,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: '수업 중 통증 메모',
                                    hintText:
                                        '예: 스텝다운 시 무릎 안쪽 불편 / 브릿지에서 허리 압박감',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '종료 후 체크',
                          expanded: _postExpanded,
                          onToggle: () =>
                              setState(() => _postExpanded = !_postExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '통증 변화',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['없음', '감소', '유지', '증가'],
                                selectedValue: _postPainChange,
                                onChanged: (v) =>
                                    setState(() => _postPainChange = v),
                              ),
                              if (_postPainChange == '감소' ||
                                  _postPainChange == '유지' ||
                                  _postPainChange == '증가') ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _postPainDetailC,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: '종료 후 통증 메모',
                                    hintText:
                                        '예: 왼쪽 고관절 뻐근함은 남아있지만 허리 압박감은 줄어듦',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Text(
                                '수행도',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['낮음', '보통', '좋음'],
                                selectedValue: _postPerformance,
                                onChanged: (v) =>
                                    setState(() => _postPerformance = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '다음 수업 포인트',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['유지', '진도업', '통증재체크', '숙제확인'],
                                selectedValue: _postNextAction,
                                onChanged: (v) =>
                                    setState(() => _postNextAction = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '숙제',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const [
                                  '없음',
                                  '스트레칭',
                                  '복습운동',
                                  '걷기',
                                  '영상확인'
                                ],
                                selectedValue: _postHomework,
                                onChanged: (v) =>
                                    setState(() => _postHomework = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '내부 메모',
                          expanded: _internalExpanded,
                          onToggle: () => setState(
                            () => _internalExpanded = !_internalExpanded,
                          ),
                          child: TextField(
                            controller: _internalMemoC,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: '강사용 내부 기록',
                              hintText: '통증/자세 반응/지도 포인트/다음 수업 판단 메모',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '회원 공개 메모',
                          expanded: _publicExpanded,
                          onToggle: () => setState(
                              () => _publicExpanded = !_publicExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '짧은 수업 요약',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _applyAutoSummary(force: true);
                                      });
                                    },
                                    icon: const Icon(Icons.auto_awesome,
                                        size: 16),
                                    label: const Text('자동 요약'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _publicSummaryC,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText:
                                      '운동 내용을 기반으로 자동 요약되며, 직접 수정할 수 있어요.',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '수업 체크사항',
                          expanded: _lessonEtcExpanded,
                          onToggle: () => setState(
                            () => _lessonEtcExpanded = !_lessonEtcExpanded,
                          ),
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
                                  final selected =
                                      _selectedIssueChips.contains(chip);
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? colorScheme.secondaryContainer
                                            : _themeTokens.trainingLogSetRow,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFF4F46E5)
                                              : _themeTokens
                                                  .trainingLogSetDivider,
                                        ),
                                      ),
                                      child: Text(
                                        chip,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: selected
                                              ? colorScheme.onSecondaryContainer
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList()
                                  ..add(
                                    InkWell(
                                      onTap: _addCustomIssueChip,
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _themeTokens.trainingLogSetRow,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: _themeTokens
                                                .trainingLogSetDivider,
                                          ),
                                        ),
                                        child: Text(
                                          '+ 추가',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
                                children:
                                    ['없음', '완료', '일부', '미수행'].map((value) {
                                  final selected = _homeworkStatus == value;
                                  return InkWell(
                                    onTap: () =>
                                        setState(() => _homeworkStatus = value),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? colorScheme.secondaryContainer
                                            : _themeTokens.trainingLogSetRow,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFF4F46E5)
                                              : _themeTokens
                                                  .trainingLogSetDivider,
                                        ),
                                      ),
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: selected
                                              ? colorScheme.onSecondaryContainer
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _nextCheckpointC,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: '다음 수업 체크포인트',
                                  hintText: '예: 무릎 통증 확인, 스쿼트 숙제 확인',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: BoxDecoration(
                      color: _themeTokens.trainingLogSurface,
                      border: Border(
                        top: BorderSide(
                          color: _themeTokens.trainingLogSetDivider,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          child: const Text('수업일지 저장하기'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
