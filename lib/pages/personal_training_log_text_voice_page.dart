import 'package:flutter/material.dart';

class PersonalTrainingLogTextVoicePage extends StatefulWidget {
  final String? initialName;
  final String? initialTitle;
  final String? initialMemo;
  final String? initialType;
  final List<String>? initialIssueChips;
  final String? initialHomeworkStatus;
  final String? initialNextLessonCheckpoint;

  final String? initialPreCondition;
  final String? initialPreMeal;
  final String? initialPreSleep;
  final String? initialPrePain;
  final String? initialPreStretching;
  final String? initialSessionLabel;

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

  const PersonalTrainingLogTextVoicePage({
    super.key,
    this.initialName,
    this.initialTitle,
    this.initialMemo,
    this.initialType,
    this.initialIssueChips,
    this.initialHomeworkStatus,
    this.initialNextLessonCheckpoint,
    this.initialPreCondition,
    this.initialPreMeal,
    this.initialPreSleep,
    this.initialPrePain,
    this.initialPreStretching,
    this.initialSessionLabel,
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
  State<PersonalTrainingLogTextVoicePage> createState() =>
      _PersonalTrainingLogTextVoicePageState();
}

class _PersonalTrainingLogTextVoicePageState
    extends State<PersonalTrainingLogTextVoicePage> {
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

  bool _usedVoiceDraft = false;
  String _rawVoiceText = '';
  late String _type;

  String _lastAutoSummary = '';
  bool _isApplyingAutoSummary = false;
  bool _preExpanded = true;
  bool _contentExpanded = true;
  bool _duringExpanded = true;
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

  late String _postPainChange;
  late String _postPerformance;
  late String _postNextAction;
  late String _postHomework;

  final List<String> _issueChipOptions = const [
    '통증',
    '피로',
    '공복',
    '결혼준비',
    '수면부족',
    'PMS',
  ];

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

    if (cleaned.length == 1) {
      return cleaned.first;
    }

    final first = cleaned.first;
    return '$first 외 ${cleaned.length - 1}개 진행';
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

  void _insertVoiceDraftSample() {
    const sampleVoiceText =
        '오늘은 하체 근력 위주로 시작했는데 스쿼트 중 오른쪽 무릎 안쪽 통증을 이야기해서 깊이를 줄였고, 런지는 제외했습니다. 이후 체스트프레스와 로우로 상체 운동을 진행했고 마지막에 고관절 스트레칭을 했습니다.';

    const sampleDraft =
        '하체 운동 중 무릎 통증 확인\n'
        '- 스쿼트 깊이 조절\n'
        '- 런지 제외\n'
        '- 상체 운동으로 전환\n'
        '- 마무리 고관절 스트레칭';

    const samplePublicSummary =
        '하체 운동 중 무릎 통증으로 강도를 조절하고 상체 운동으로 전환했습니다.';

    setState(() {
      _usedVoiceDraft = true;
      _rawVoiceText = sampleVoiceText;

      if (_titleC.text.trim().isEmpty) {
        _titleC.text = '하체운동 + 무릎통증 + 상체운동';
      }

      if (_memoC.text.trim().isEmpty) {
        _memoC.text = sampleDraft;
      } else {
        _memoC.text = '${_memoC.text.trim()}\n\n$sampleDraft';
      }

      if (_publicSummaryC.text.trim().isEmpty ||
          _publicSummaryC.text.trim() == _lastAutoSummary) {
        _isApplyingAutoSummary = true;
        _publicSummaryC.text = samplePublicSummary;
        _lastAutoSummary = samplePublicSummary;
        _isApplyingAutoSummary = false;
      }
    });
  }

  Widget _buildBlueHeader() {
    final sessionLabel = (widget.initialSessionLabel ?? '').trim();
    final title = sessionLabel.isEmpty
        ? '$_memberName 님 수업일지'
        : '$_memberName 님 $sessionLabel 수업일지';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: 18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                  Icons.mic_none_rounded,
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

  Widget _buildCollapsibleSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black45,
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
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
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

  Widget _multiSelect({
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

  void _save() {
    final title = _titleC.text.trim();
    final name = (widget.initialName ?? '').trim().isEmpty
        ? '회원 미지정'
        : (widget.initialName ?? '').trim();
    final memo = _memoC.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록 제목을 입력해주세요.')),
      );
      return;
    }

    Navigator.pop(context, {
      'title': title,
      'name': name,
      'memo': memo,
      'type': _type,
      'inputMethod': _usedVoiceDraft ? 'voice_draft' : 'text',
      'rawVoiceText': _rawVoiceText,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
                        _section(
                          title: '기록 제목',
                          child: TextField(
                            controller: _titleC,
                            decoration: const InputDecoration(
                              labelText: '기록 제목',
                              hintText: '예: 하체 패턴 교정',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: const Text(
                            '음성은 편하게 길게 말해도 괜찮아요. 저장 시에는 핵심 내용만 짧게 정리하고, 원문은 따로 보관됩니다.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
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
                                onChanged: (v) =>
                                    setState(() => _preMeal = v),
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
                                onChanged: (v) =>
                                    setState(() => _preSleep = v),
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
                                onChanged: (v) =>
                                    setState(() => _prePain = v),
                              ),
                              if (_prePain == '있음') ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _prePainDetailC,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: '통증 상세',
                                    hintText: '예: 오른쪽 무릎 안쪽이 계단 내려갈 때 찌릿함',
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
                          title: '수업 내용 작성',
                          expanded: _contentExpanded,
                          onToggle: () =>
                              setState(() => _contentExpanded = !_contentExpanded),
                          child: Column(
                            children: [
                              TextField(
                                controller: _memoC,
                                maxLines: 8,
                                decoration: InputDecoration(
                                  labelText: '수업 내용 / 메모',
                                  hintText:
                                  '텍스트로 직접 입력하거나 오른쪽 마이크 버튼으로 초안을 넣어요.',
                                  alignLabelWithHint: true,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: IconButton(
                                      tooltip: '음성 초안 넣기',
                                      onPressed: _insertVoiceDraftSample,
                                      icon: Icon(
                                        _usedVoiceDraft
                                            ? Icons.mic
                                            : Icons.mic_none,
                                      ),
                                    ),
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                ),
                              ),
                              if (_usedVoiceDraft) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                        const SizedBox(height: 12),
                        _buildCollapsibleSection(
                          title: '수업 중 체크',
                          expanded: _duringExpanded,
                          onToggle: () =>
                              setState(() => _duringExpanded = !_duringExpanded),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '오늘 목표',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _multiSelect(
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
                              if (_duringReactions.contains('통증')) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _duringPainDetailC,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: '수업 중 통증 메모',
                                    hintText: '예: 런지 시 왼쪽 무릎 전면 압박감 / 스쿼트 하강구간 불편',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Text(
                                '핵심 부위',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _multiSelect(
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
                              const Text(
                                '특이 반응',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _multiSelect(
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
                                    hintText: '예: 허리는 편해졌지만 오른쪽 고관절 당김은 남아있음',
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
                                options: const ['없음', '스트레칭', '복습운동', '걷기', '영상확인'],
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
                          onToggle: () =>
                              setState(() => _publicExpanded = !_publicExpanded),
                          child:                               Column(
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
                                    icon: const Icon(Icons.auto_awesome, size: 16),
                                    label: const Text('자동 요약'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _publicSummaryC,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText: '운동 내용을 기반으로 자동 요약되며, 직접 수정할 수 있어요.',
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
                                            ? const Color(0xFFEEF2FF)
                                            : Colors.white,
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
                                '필요 피드백 체크',
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
                                            ? const Color(0xFFEEF2FF)
                                            : Colors.white,
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
                          onPressed: _save,
                          child: Text(
                            _usedVoiceDraft ? '확인 후 저장하기' : '저장하고 돌아가기',
                          ),
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