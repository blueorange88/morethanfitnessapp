import 'dart:async';

import 'package:flutter/material.dart';

import '../services/personal_custom_exercise_service.dart';
import '../services/training_log_preferences.dart';
import '../widgets/training_log_pre_check.dart';
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
  }) : exercises = exercises ?? [],
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

  final String? personalOwnerUid;

  // 저장된 일지를 다시 열 때 복원하는 값
  final List<Map<String, dynamic>>? initialExercises;
  final String? initialPrePainDetail;
  final String? initialDuringPainDetail;
  final String? initialPostPainDetail;
  final String? initialPreNote;
  final String? initialInbodySummary;

  // null이면 설정(새 일지에서 레슨 전 체크 자동 열기)을 따른다.
  final bool? autoOpenPreCheck;

  // 레슨 전 체크리스트의 인바디 측정 줄. 회원이 정해진 일지에서만 넘어온다.
  final Future<String?> Function()? onMeasureInbody;

  // 레슨 전 체크를 이미 마쳤는지(레슨일지 목록 화면에서 먼저 열었을 때). null이면 새 일지만 미확인.
  final bool? initialPreCheckConfirmed;
  final String? initialCognitiveResponse;
  final String? initialPerformanceResponse;

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
    this.personalOwnerUid,
    this.initialExercises,
    this.initialPrePainDetail,
    this.initialDuringPainDetail,
    this.initialPostPainDetail,
    this.initialPreNote,
    this.initialInbodySummary,
    this.autoOpenPreCheck,
    this.onMeasureInbody,
    this.initialPreCheckConfirmed,
    this.initialCognitiveResponse,
    this.initialPerformanceResponse,
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
  final TextEditingController _preNoteC = TextEditingController();
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

  // 서버(트레이너 프로필)에 저장되는 부위별 "추가 운동". Personal이 아니면 앱 실행 동안만 유지한다.
  Map<String, List<String>> _customExercisesByPart = {};
  PersonalCustomExerciseService? _exerciseService;
  bool _savingCustomExercises = false;
  final TextEditingController _exerciseSearchC = TextEditingController();

  final Map<String, bool> _memoOpen = {};
  String _lastAutoSummary = '';
  bool _isApplyingAutoSummary = false;

  bool _categoryExpanded = true;
  bool _postExpanded = true;
  bool _internalExpanded = false;
  bool _publicExpanded = false;

  late TrainingLogPreCheckData _preCheck;
  bool _preCheckConfirmed = true;
  late String _homeworkStatus;

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

  // 통증·수면부족·공복은 시작 전 체크에서 자동으로 잡히므로 직접 고르는 칩에서 뺐다.
  final List<String> _issueChipOptions = [...kDefaultManualIssueOptions];

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

    _homeworkStatus = widget.initialHomeworkStatus ?? '없음';
    _nextCheckpointC.text = widget.initialNextLessonCheckpoint ?? '';

    _preCheck = TrainingLogPreCheckData(
      condition: widget.initialPreCondition ?? '보통',
      meal: widget.initialPreMeal ?? kPreMealDefault,
      sleep: widget.initialPreSleep ?? '보통',
      pain: widget.initialPrePain ?? '없음',
      painDetail: widget.initialPrePainDetail ?? '',
      stretching: widget.initialPreStretching ?? '안 함',
      note: widget.initialPreNote ?? '',
      inbodySummary: widget.initialInbodySummary ?? '',
      issueChips: {...?widget.initialIssueChips},
    );
    _prePainDetailC.text = _preCheck.painDetail;
    _preNoteC.text = _preCheck.note;
    // 저장된 일지를 다시 열 때는 이미 확인한 것으로 보고, 새 일지만 확인 전 상태로 시작한다.
    _preCheckConfirmed = widget.initialPreCheckConfirmed ?? !_isNewLog;
    _preCheck.dropImpliedAutoChips();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAutoOpenPreCheck());
    });
    _duringPainDetailC.text = widget.initialDuringPainDetail ?? '';
    _postPainDetailC.text = widget.initialPostPainDetail ?? '';
    for (final chip in _preCheck.issueChips) {
      if (!_issueChipOptions.contains(chip) &&
          !kAutoIssueNames.contains(chip)) {
        _issueChipOptions.add(chip);
      }
    }

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

    final ownerUid = (widget.personalOwnerUid ?? '').trim();
    if (ownerUid.isNotEmpty) {
      _exerciseService = PersonalCustomExerciseService(uid: ownerUid);
      unawaited(_loadCustomExercises());
    }

    _cognitiveResponse = widget.initialCognitiveResponse ?? '보통';
    _performanceResponse = widget.initialPerformanceResponse ?? '보통';
    _restoreExerciseGroups(widget.initialExercises);

    // 저장된 공개 요약이 있으면 자동 요약으로 덮어쓰지 않는다.
    _applyAutoSummary(force: _publicSummaryC.text.trim().isEmpty);

    _exerciseSearchC.addListener(() {
      if (mounted) setState(() {});
    });

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
    _exerciseSearchC.dispose();
    _memoC.dispose();
    _nextCheckpointC.dispose();
    _internalMemoC.dispose();
    _publicSummaryC.dispose();
    _publicGoodC.dispose();
    _publicHomeworkC.dispose();
    _publicCautionC.dispose();
    _prePainDetailC.dispose();
    _preNoteC.dispose();
    _duringPainDetailC.dispose();
    _postPainDetailC.dispose();
    super.dispose();
  }

  List<String> _customExercisesFor(String part) {
    if (_exerciseService == null) {
      return _CategoryExerciseMemory.customExercisesByPart[part] ?? const [];
    }
    return _customExercisesByPart[part] ?? const [];
  }

  Future<void> _loadCustomExercises() async {
    final service = _exerciseService;
    if (service == null) return;
    try {
      final loaded = await service.load();
      if (!mounted) return;
      setState(() {
        // 불러오는 동안 추가한 운동이 있으면 합친다.
        final merged = <String, List<String>>{...loaded};
        for (final entry in _customExercisesByPart.entries) {
          final list = [...(merged[entry.key] ?? const <String>[])];
          for (final item in entry.value) {
            final key = customExerciseComparisonKey(item);
            if (!list.any((e) => customExerciseComparisonKey(e) == key)) {
              list.add(item);
            }
          }
          merged[entry.key] = list;
        }
        _customExercisesByPart = merged;
      });
    } catch (_) {
      // 목록을 못 불러와도 기본 운동으로 계속 작성할 수 있다.
    }
  }

  void _showExerciseMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // 선택한 부위의 "추가 운동" 목록을 바꾸고 서버에 저장한다. 실패하면 되돌리고 false를 돌려준다.
  Future<bool> _commitCustomExercises(String part, List<String> next) async {
    final service = _exerciseService;
    if (service == null) {
      setState(() {
        if (next.isEmpty) {
          _CategoryExerciseMemory.customExercisesByPart.remove(part);
        } else {
          _CategoryExerciseMemory.customExercisesByPart[part] = next;
        }
      });
      return true;
    }
    if (_savingCustomExercises) {
      _showExerciseMessage('저장 중이에요. 잠시 후 다시 시도해주세요.');
      return false;
    }
    final previous = {
      for (final e in _customExercisesByPart.entries) e.key: [...e.value],
    };
    final updated = {
      for (final e in _customExercisesByPart.entries) e.key: [...e.value],
    };
    if (next.isEmpty) {
      updated.remove(part);
    } else {
      updated[part] = next;
    }
    setState(() {
      _customExercisesByPart = updated;
      _savingCustomExercises = true;
    });
    try {
      final saved = await service.save(updated);
      if (!mounted) return true;
      setState(() {
        _customExercisesByPart = saved;
        _savingCustomExercises = false;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _customExercisesByPart = previous;
        _savingCustomExercises = false;
      });
      _showExerciseMessage('추가 운동을 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
      return false;
    }
  }

  // 검색창에 입력한 이름을 "추가 운동"으로 저장하고 바로 선택한다.
  Future<void> _addCustomExerciseFromSearch() async {
    final part = _currentCategoryPart;
    final name = normalizeCustomExerciseName(_exerciseSearchC.text);
    if (part.isEmpty) return;

    final current = _customExercisesFor(part);
    final error = validateNewCustomExercise(
      name: name,
      builtInExercises: _exerciseCategories[part] ?? const <String>[],
      currentCustomExercises: current,
    );
    if (error != null) {
      _showExerciseMessage(error);
      return;
    }
    final saved = await _commitCustomExercises(part, [...current, name]);
    if (!saved || !mounted) return;
    _exerciseSearchC.clear();
    if (!(_currentGroup?.exercises.contains(name) ?? false)) {
      _toggleExerciseChip(name);
    }
  }

  Future<void> _confirmRemoveCustomExercise(String exercise) async {
    final part = _currentCategoryPart;
    if (part.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('추가 운동 삭제'),
            content: Text(
              "'$exercise'를 추가 운동 목록에서 삭제할까요?\n이미 작성한 레슨일지에는 영향이 없어요.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    final key = customExerciseComparisonKey(exercise);
    await _commitCustomExercises(
      part,
      _customExercisesFor(
        part,
      ).where((item) => customExerciseComparisonKey(item) != key).toList(),
    );
  }

  Widget _buildExercisePicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final part = _currentCategoryPart;
    final query = normalizeCustomExerciseName(_exerciseSearchC.text);
    final queryKey = customExerciseComparisonKey(query);

    final custom = _customExercisesFor(part);
    final customKeys = custom.map(customExerciseComparisonKey).toSet();
    final options = <({String name, bool isCustom})>[
      for (final name in _exerciseCategories[part] ?? const <String>[])
        (name: name, isCustom: false),
      for (final name in custom) (name: name, isCustom: true),
    ]..sort((a, b) => a.name.compareTo(b.name));

    final filtered =
        queryKey.isEmpty
            ? options
            : options
                .where(
                  (o) => customExerciseComparisonKey(o.name).contains(queryKey),
                )
                .toList();
    final exactExists = options.any(
      (o) => customExerciseComparisonKey(o.name) == queryKey,
    );
    final canAdd =
        queryKey.isNotEmpty &&
        !exactExists &&
        !customKeys.contains(queryKey) &&
        query.length <= kCustomExerciseMaxLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('category_exercise_search'),
          controller: _exerciseSearchC,
          textInputAction: TextInputAction.search,
          maxLength: kCustomExerciseMaxLength,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          decoration: InputDecoration(
            hintText: '운동 검색 또는 추가',
            isDense: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon:
                _exerciseSearchC.text.isEmpty
                    ? null
                    : IconButton(
                      tooltip: '지우기',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _exerciseSearchC.clear,
                    ),
          ),
        ),
        if (canAdd)
          InkWell(
            key: const Key('category_exercise_add_row'),
            onTap: _addCustomExerciseFromSearch,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$query"을(를) 추가 운동으로 저장',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Text(
              queryKey.isEmpty ? '운동이 없어요.' : '일치하는 운동이 없어요.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              key: const Key('category_exercise_list'),
              shrinkWrap: true,
              primary: false,
              physics: const ClampingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final option = filtered[index];
                return _exerciseRow(option.name, isCustom: option.isCustom);
              },
            ),
          ),
      ],
    );
  }

  Widget _exerciseRow(String name, {required bool isCustom}) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _currentGroup?.exercises.contains(name) ?? false;
    return InkWell(
      key: Key('category_exercise_row_$name'),
      onTap: () => _toggleExerciseChip(name),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        selected
                            ? colorScheme.primary
                            : _themeTokens.trainingLogSetDivider,
                    width: 1.5,
                  ),
                ),
                child:
                    selected
                        ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colorScheme.onPrimary,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (isCustom) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '추가',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '추가 운동 삭제',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () => _confirmRemoveCustomExercise(name),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 저장된 운동 구성(exercises)을 선택 상태로 되돌린다. 메모 문자열은 이미 저장돼 있으므로
  // 다시 만들지 않는다(선택을 바꿀 때 _syncCategoryDraftToFields가 다시 만든다).
  void _restoreExerciseGroups(List<Map<String, dynamic>>? saved) {
    if (saved == null) return;
    for (final item in saved) {
      final name = (item['name'] ?? '').toString().trim();
      final main = (item['main'] ?? '').toString().trim();
      final part = (item['part'] ?? '').toString().trim();
      if (name.isEmpty || main.isEmpty || part.isEmpty) continue;
      final group = _getOrCreateGroup(main, part);
      if (group.exercises.contains(name)) continue;
      group.exercises.add(name);
      group.setCounts[name] = (item['sets'] as num?)?.toInt() ?? 3;
      group.repCounts[name] = (item['reps'] as num?)?.toInt() ?? 12;
      group.assistCounts[name] = (item['assist'] as num?)?.toInt() ?? 0;
      group.noteByExercise[name] = (item['note'] ?? '').toString();
    }
  }

  List<Map<String, dynamic>> _exercisesForSave() {
    return [
      for (final group in _categoryGroups)
        for (final exercise in group.exercises)
          {
            'main': group.main,
            'part': group.part,
            'name': exercise,
            'sets': group.setCounts[exercise] ?? 3,
            'reps': group.repCounts[exercise] ?? 12,
            'assist': group.assistCounts[exercise] ?? 0,
            'note': (group.noteByExercise[exercise] ?? '').trim(),
          },
    ];
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

    final modifier =
        _titleModifier.isNotEmpty
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
    final lines =
        _memoC.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    if (lines.isEmpty) return '';

    final cleaned =
        lines
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
    String main,
    String part,
    String exercise,
    int delta,
  ) {
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
    final title =
        sessionLabel.isEmpty
            ? '$_memberName 님 수업일지'
            : '$_memberName 님 $sessionLabel 수업일지';
    final gradient = context.mtfHeaderGradient;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
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
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
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
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
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

  Widget _section({required String title, required Widget child}) {
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
      children:
          options.map((value) {
            final selected = selectedValue == value;
            return InkWell(
              onTap: () => onChanged(value),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? colorScheme.secondaryContainer
                          : _themeTokens.trainingLogSetRow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        selected
                            ? const Color(0xFF4F46E5)
                            : _themeTokens.trainingLogSetDivider,
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color:
                        selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // 특이사항 직접 추가 입력창. 입력한 이름을 돌려주고, 시트가 선택 상태로 만든다.
  Future<String?> _askCustomIssue() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('특이사항 추가'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 40,
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

    final value = (result ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return null;
    if (!_issueChipOptions.contains(value) &&
        !kAutoIssueNames.contains(value)) {
      setState(() => _issueChipOptions.add(value));
    }
    return value;
  }

  bool get _isNewLog =>
      (widget.initialTitle ?? '').trim().isEmpty &&
      (widget.initialMemo ?? '').trim().isEmpty &&
      (widget.initialExercises ?? const []).isEmpty;

  Future<void> _maybeAutoOpenPreCheck() async {
    if (!_isNewLog) return;
    final enabled =
        widget.autoOpenPreCheck ??
        await TrainingLogPreferences.autoOpenPreCheck(
          (widget.personalOwnerUid ?? '').trim(),
        );
    if (!enabled || !mounted) return;
    await _openPreCheckSheet();
  }

  Future<void> _openPreCheckSheet() async {
    _prePainDetailC.text = _preCheck.painDetail;
    _preNoteC.text = _preCheck.note;
    final done = await showTrainingLogPreCheckDialog(
      context,
      memberName: widget.initialName ?? '',
      data: _preCheck,
      painDetailController: _prePainDetailC,
      noteController: _preNoteC,
      issueOptions: _issueChipOptions,
      onAddIssue: _askCustomIssue,
      onMeasureInbody: widget.onMeasureInbody,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    if (done && mounted) setState(() => _preCheckConfirmed = true);
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
    final name =
        (widget.initialName ?? '').trim().isEmpty
            ? '회원 미지정'
            : (widget.initialName ?? '').trim();
    final memo = _memoC.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수업일지 제목을 입력해주세요.')));
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
      'issueChips': _preCheck.savedIssueChips,
      'homeworkStatus': _homeworkStatus,
      'nextLessonCheckpoint': _nextCheckpointC.text.trim(),
      'preCondition': _preCheck.condition,
      'preMeal': _preCheck.meal,
      'preSleep': _preCheck.sleep,
      'prePain': _preCheck.pain,
      'prePainDetail': _preCheck.painDetail.trim(),
      'preStretching': _preCheck.stretching,
      'preNote': _preCheck.note.trim(),
      'inbodySummary': _preCheck.inbodySummary,
      'preCheckConfirmed': _preCheckConfirmed,
      'duringGoals': _duringGoals.toList(),
      'duringFocusParts': _duringFocusParts.toList(),
      'duringReactions': _duringReactions.toList(),
      'duringPainDetail': _duringPainDetailC.text.trim(),
      'postPainChange': _postPainChange,
      'postPainDetail': _postPainDetailC.text.trim(),
      'postPerformance': _postPerformance,
      'focusResponse': _focusResponse,
      'cognitiveResponse': _cognitiveResponse,
      'performanceResponse': _performanceResponse,
      'exercises': _exercisesForSave(),
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
                        TrainingLogPreCheckCard(
                          data: _preCheck,
                          onEdit: _openPreCheckSheet,
                          confirmed: _preCheckConfirmed,
                        ),
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '카테고리형 작성',
                          expanded: _categoryExpanded,
                          onToggle:
                              () => setState(
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
                                children:
                                    _mainCategories.map((item) {
                                      final selected =
                                          _currentCategoryMain == item;
                                      return ChoiceChip(
                                        label: Text(item),
                                        selected: selected,
                                        onSelected: (_) {
                                          setState(() {
                                            _currentCategoryMain = item;
                                            _currentCategoryPart = '';
                                            _exerciseSearchC.clear();
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
                                                  _exerciseSearchC.clear();
                                                });
                                              },
                                            );
                                          })
                                          .toList(),
                                ),
                              ],
                              if (_currentCategoryPart.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  '3) 운동 선택',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildExercisePicker(),
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
                                  children:
                                      _categoryGroups.map((group) {
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                _themeTokens.trainingLogSetRow,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  _themeTokens
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
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed:
                                                        () => _removeGroup(
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
                                                children:
                                                    group.exercises.map((
                                                      exercise,
                                                    ) {
                                                      final sets =
                                                          group
                                                              .setCounts[exercise] ??
                                                          3;
                                                      final reps =
                                                          group
                                                              .repCounts[exercise] ??
                                                          12;
                                                      final assists =
                                                          group
                                                              .assistCounts[exercise] ??
                                                          0;
                                                      final note =
                                                          group
                                                              .noteByExercise[exercise] ??
                                                          '';
                                                      final memoKey =
                                                          '${group.main}|${group.part}|$exercise';
                                                      final memoOpen =
                                                          _memoOpen[memoKey] ??
                                                          false;

                                                      return Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _themeTokens
                                                                  .trainingLogSurface,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                _themeTokens
                                                                    .trainingLogSetDivider,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    exercise,
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          12.5,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 6,
                                                                ),
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        assists ==
                                                                                0
                                                                            ? colorScheme.surfaceContainerHighest
                                                                            : const Color(
                                                                              0xFFFEE2E2,
                                                                            ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          999,
                                                                        ),
                                                                    border: Border.all(
                                                                      color:
                                                                          assists ==
                                                                                  0
                                                                              ? _themeTokens.trainingLogSetDivider
                                                                              : const Color(
                                                                                0xFFFECACA,
                                                                              ),
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      assists ==
                                                                              0
                                                                          ? InkWell(
                                                                            onTap:
                                                                                () => _changeAssistCount(
                                                                                  group.main,
                                                                                  group.part,
                                                                                  exercise,
                                                                                  1,
                                                                                ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              999,
                                                                            ),
                                                                            child: Text(
                                                                              '서포트',
                                                                              style: TextStyle(
                                                                                fontSize:
                                                                                    11,
                                                                                fontWeight:
                                                                                    FontWeight.w800,
                                                                                color:
                                                                                    colorScheme.onSurfaceVariant,
                                                                              ),
                                                                            ),
                                                                          )
                                                                          : Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children: [
                                                                              InkWell(
                                                                                onTap:
                                                                                    () => _changeAssistCount(
                                                                                      group.main,
                                                                                      group.part,
                                                                                      exercise,
                                                                                      -1,
                                                                                    ),
                                                                                child: const Padding(
                                                                                  padding: EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                        4,
                                                                                  ),
                                                                                  child: Icon(
                                                                                    Icons.remove,
                                                                                    size:
                                                                                        14,
                                                                                    color: Color(
                                                                                      0xFFB91C1C,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                '서포트 $assists회',
                                                                                style: const TextStyle(
                                                                                  fontSize:
                                                                                      11,
                                                                                  fontWeight:
                                                                                      FontWeight.w800,
                                                                                  color: Color(
                                                                                    0xFFB91C1C,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              InkWell(
                                                                                onTap:
                                                                                    () => _changeAssistCount(
                                                                                      group.main,
                                                                                      group.part,
                                                                                      exercise,
                                                                                      1,
                                                                                    ),
                                                                                child: const Padding(
                                                                                  padding: EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                        4,
                                                                                  ),
                                                                                  child: Icon(
                                                                                    Icons.add,
                                                                                    size:
                                                                                        14,
                                                                                    color: Color(
                                                                                      0xFFB91C1C,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                IconButton(
                                                                  visualDensity:
                                                                      VisualDensity
                                                                          .compact,
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        minWidth:
                                                                            30,
                                                                        minHeight:
                                                                            30,
                                                                      ),
                                                                  onPressed:
                                                                      () => _removeExercise(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                      ),
                                                                  icon: const Icon(
                                                                    Icons.close,
                                                                    size: 18,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 6,
                                                            ),
                                                            Row(
                                                              children: [
                                                                _miniCounter(
                                                                  label: '세트',
                                                                  value: sets,
                                                                  onMinus:
                                                                      () => _changeSetCount(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                        -1,
                                                                      ),
                                                                  onPlus:
                                                                      () => _changeSetCount(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                        1,
                                                                      ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                _miniCounter(
                                                                  label: '횟수',
                                                                  value: reps,
                                                                  onMinus:
                                                                      () => _changeRepCount(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                        -1,
                                                                      ),
                                                                  onPlus:
                                                                      () => _changeRepCount(
                                                                        group
                                                                            .main,
                                                                        group
                                                                            .part,
                                                                        exercise,
                                                                        1,
                                                                      ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                ActionChip(
                                                                  label: Text(
                                                                    note.trim().isEmpty
                                                                        ? '메모'
                                                                        : '메모 있음',
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                                  ),
                                                                  onPressed: () {
                                                                    setState(() {
                                                                      _memoOpen[memoKey] =
                                                                          !memoOpen;
                                                                    });
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                            if (memoOpen) ...[
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              TextField(
                                                                controller:
                                                                    TextEditingController(
                                                                      text:
                                                                          group
                                                                              .noteByExercise[exercise] ??
                                                                          '',
                                                                    ),
                                                                maxLines: 1,
                                                                decoration: const InputDecoration(
                                                                  hintText:
                                                                      '예: 허리 뜨지 않게 / 오른쪽 복압 더 신경쓰기',
                                                                  border:
                                                                      OutlineInputBorder(),
                                                                  isDense: true,
                                                                ),
                                                                onChanged: (
                                                                  value,
                                                                ) {
                                                                  group.noteByExercise[exercise] =
                                                                      value;
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
                                        children:
                                            [
                                              '교정',
                                              '통증관리',
                                              '근력',
                                              '가동성',
                                              '체형',
                                            ].map((modifier) {
                                              final selected =
                                                  _titleModifier == modifier;
                                              return ChoiceChip(
                                                label: Text(modifier),
                                                selected: selected,
                                                onSelected:
                                                    (_) => _applyTitleModifier(
                                                      modifier,
                                                    ),
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
                          title: '종료 후 체크',
                          expanded: _postExpanded,
                          onToggle:
                              () => setState(
                                () => _postExpanded = !_postExpanded,
                              ),
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
                                onChanged:
                                    (v) => setState(() => _postPainChange = v),
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
                                onChanged:
                                    (v) => setState(() => _postPerformance = v),
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
                                onChanged:
                                    (v) => setState(() => _postNextAction = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '오늘 낸 숙제',
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
                                  '영상확인',
                                ],
                                selectedValue: _postHomework,
                                onChanged:
                                    (v) => setState(() => _postHomework = v),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '지난 숙제 수행',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _singleSelect(
                                options: const ['없음', '완료', '일부', '미수행'],
                                selectedValue: _homeworkStatus,
                                onChanged:
                                    (v) => setState(() => _homeworkStatus = v),
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
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '내부 메모',
                          expanded: _internalExpanded,
                          onToggle:
                              () => setState(
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
                          onToggle:
                              () => setState(
                                () => _publicExpanded = !_publicExpanded,
                              ),
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
                                    icon: const Icon(
                                      Icons.auto_awesome,
                                      size: 16,
                                    ),
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
