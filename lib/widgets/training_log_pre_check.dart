import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// 레슨일지 "레슨 전 체크": 한 줄 요약 카드 + 한 번에 고르는 체크리스트 카드(팝업).
// 컨디션·식사·수면·통증·스트레칭과 특이사항(칩 + 한 줄 메모)을 다룬다.

const List<String> kPreConditionOptions = ['좋음', '보통', '나쁨'];
const List<String> kPreMealOptions = ['1시간 이내', '1~3시간 전', '4시간 이상(공복)'];
const List<String> kPreSleepOptions = ['부족', '보통', '충분'];
const List<String> kPrePainOptions = ['없음', '있음'];
const List<String> kPreStretchingOptions = ['안 함', '조금 함', '충분히 함'];

const String kPreMealFasting = '4시간 이상(공복)';
const String kPreMealDefault = '1~3시간 전';

// 이전 버전이 저장한 식사 값. 새 선택지에는 없지만 읽을 때 그대로 보여준다.
const Set<String> _legacyFastingMeals = {'공복'};

// 체크 값에서 자동으로 만들어지는 특이사항 이름. 기존 특이사항 칩 이름을 그대로 써서
// 이전 일지·요약과 호환된다.
const String kAutoIssuePain = '통증';
const String kAutoIssueSleep = '수면부족';
const String kAutoIssueFasting = '공복';
const Set<String> kAutoIssueNames = {
  kAutoIssuePain,
  kAutoIssueSleep,
  kAutoIssueFasting,
};

// 특이사항에 새로 보여줄 기본 칩. 통증·수면부족·공복은 체크에서 자동으로 잡힌다.
const List<String> kDefaultManualIssueOptions = ['피로', '결혼준비', 'PMS'];

/// 레슨 전 체크 값. 카드·팝업이 직접 바꾸고 onChanged로 부모에게 알린다.
class TrainingLogPreCheckData {
  TrainingLogPreCheckData({
    this.condition = '보통',
    this.meal = kPreMealDefault,
    this.sleep = '보통',
    this.pain = '없음',
    this.painDetail = '',
    this.stretching = '안 함',
    this.note = '',
    this.inbodySummary = '',
    Set<String>? issueChips,
  }) : issueChips = issueChips ?? <String>{};

  String condition;
  String meal;
  String sleep;
  String pain;
  String painDetail;
  String stretching;
  String note;

  /// 이번 레슨 전에 측정·기록한 인바디 요약(화면 표시용, 일지에는 저장하지 않는다).
  /// 측정값 자체는 회원 건강정보(서버)에 기록된다.
  String inbodySummary;

  /// 사용자가 직접 고른 특이사항(자동 항목 제외가 아니라, 저장된 칩 전체).
  final Set<String> issueChips;

  /// 저장된 특이사항 칩 중 지금 체크 값에서 자동으로 만들어지는 것(통증·수면부족·공복)은
  /// 직접 고른 칩과 겹쳐 보이지 않게 뺀다. 저장할 때 [savedIssueChips]가 다시 합친다.
  void dropImpliedAutoChips() => issueChips.removeAll(autoIssueChips);

  bool get isFasting =>
      meal == kPreMealFasting || _legacyFastingMeals.contains(meal);

  /// 체크 값에서 자동으로 잡힌 확인 항목(요약 카드·시트에서 강조).
  List<String> get autoFlags => [
    if (condition == '나쁨') '컨디션 나쁨',
    if (sleep == '부족') '수면 부족',
    if (pain == '있음') '통증',
    if (isFasting) '4시간 이상 공복',
  ];

  /// 저장할 때 특이사항 칩에 합칠 자동 항목(기존 칩 이름).
  Set<String> get autoIssueChips => {
    if (pain == '있음') kAutoIssuePain,
    if (sleep == '부족') kAutoIssueSleep,
    if (isFasting) kAutoIssueFasting,
  };

  /// 저장용 특이사항: 직접 고른 칩 + 자동 항목.
  List<String> get savedIssueChips =>
      <String>{...issueChips, ...autoIssueChips}.toList();

  /// 요약 카드 "확인 필요" 개수: 자동 항목 + 자동 항목이 아닌 직접 고른 칩 + 메모.
  int get attentionCount {
    final manual =
        issueChips.where((chip) => !kAutoIssueNames.contains(chip)).length;
    return autoFlags.length + manual + (note.trim().isEmpty ? 0 : 1);
  }
}

MtfThemeTokens _tokens(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<MtfThemeTokens>() ??
      (theme.brightness == Brightness.dark
          ? MtfThemeTokens.dark
          : MtfThemeTokens.light);
}

/// 운동 구성 위에 두는 한 줄 요약 카드.
class TrainingLogPreCheckCard extends StatelessWidget {
  const TrainingLogPreCheckCard({
    super.key,
    required this.data,
    required this.onEdit,
    this.confirmed = true,
  });

  final TrainingLogPreCheckData data;
  final VoidCallback onEdit;

  /// 새 일지에서 레슨 전 체크를 아직 확인(완료)하지 않았으면 false.
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = _tokens(context);
    final flags = data.autoFlags;
    final attention = data.attentionCount;

    Widget chip(String label, {bool flagged = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: flagged ? scheme.tertiaryContainer : tokens.trainingLogSetRow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: flagged ? FontWeight.w800 : FontWeight.w600,
            color:
                flagged ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final manualChips =
        data.issueChips.where((c) => !kAutoIssueNames.contains(c)).toList();

    return Container(
      key: const Key('pre_check_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.trainingLogSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.trainingLogSetDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '레슨 전 체크',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Container(
                key: const Key('pre_check_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      !confirmed
                          ? scheme.surfaceContainerHighest
                          : attention == 0
                          ? scheme.secondaryContainer
                          : scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  !confirmed
                      ? '아직 체크 안 함'
                      : attention == 0
                      ? '이상 없음'
                      : '확인 필요 $attention',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color:
                        !confirmed
                            ? scheme.onSurfaceVariant
                            : attention == 0
                            ? scheme.onSecondaryContainer
                            : scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip('컨디션 ${data.condition}', flagged: data.condition == '나쁨'),
              chip('식사 ${data.meal}', flagged: data.isFasting),
              chip('수면 ${data.sleep}', flagged: data.sleep == '부족'),
              chip(
                data.pain == '있음' && data.painDetail.trim().isNotEmpty
                    ? '통증 있음 · ${data.painDetail.trim()}'
                    : '통증 ${data.pain}',
                flagged: data.pain == '있음',
              ),
              chip('스트레칭 ${data.stretching}'),
            ],
          ),
          if (data.inbodySummary.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            chip('인바디 ${data.inbodySummary.trim()}'),
          ],
          if (manualChips.isNotEmpty || data.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in manualChips) chip(c, flagged: true),
                if (data.note.trim().isNotEmpty)
                  chip(data.note.trim(), flagged: true),
              ],
            ),
          ],
          if (flags.isEmpty && manualChips.isEmpty && data.note.trim().isEmpty)
            const SizedBox(height: 0),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child:
                confirmed
                    ? OutlinedButton(
                      key: const Key('pre_check_edit_button'),
                      onPressed: onEdit,
                      child: const Text('수정하기'),
                    )
                    : FilledButton(
                      key: const Key('pre_check_edit_button'),
                      onPressed: onEdit,
                      child: const Text('체크하기'),
                    ),
          ),
        ],
      ),
    );
  }
}

/// 레슨 전 체크리스트 카드의 한 질문: 아이콘 배지 + 라벨 + 알약 선택지.
class _PreCheckQuestion extends StatelessWidget {
  const _PreCheckQuestion({
    required this.keyPrefix,
    required this.icon,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.flaggedValues = const {},
    this.flaggedIcon,
  });

  final String keyPrefix;
  final IconData icon;
  final IconData? flaggedIcon;
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Set<String> flaggedValues;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = _tokens(context);
    // 저장돼 있던 옛 값이 새 선택지에 없으면 맨 뒤에 따로 보여 값이 사라지지 않게 한다.
    final shown =
        options.contains(value) || value.isEmpty
            ? options
            : [...options, value];
    final rowFlagged = flaggedValues.contains(value);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.trainingLogSetDivider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  rowFlagged
                      ? scheme.tertiaryContainer
                      : tokens.trainingLogSetRow,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              rowFlagged && flaggedIcon != null ? flaggedIcon : icon,
              size: 19,
              color:
                  rowFlagged
                      ? scheme.onTertiaryContainer
                      : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final option = shown[i];
                            final selected = option == value;
                            final flagged = flaggedValues.contains(option);
                            final background =
                                selected
                                    ? (flagged
                                        ? scheme.tertiaryContainer
                                        : scheme.primary)
                                    : Colors.transparent;
                            final foreground =
                                selected
                                    ? (flagged
                                        ? scheme.onTertiaryContainer
                                        : scheme.onPrimary)
                                    : scheme.onSurface;
                            return InkWell(
                              key: Key('${keyPrefix}_$option'),
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => onChanged(option),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                constraints: const BoxConstraints(
                                  minHeight: 42,
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: background,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? (flagged
                                                ? scheme.onTertiaryContainer
                                                    .withValues(alpha: 0.35)
                                                : background)
                                            : tokens.trainingLogSetDivider,
                                  ),
                                ),
                                child: Text(
                                  option,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.2,
                                    fontWeight:
                                        selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color: foreground,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 레슨 전 체크리스트 카드(팝업)를 연다. 값이 바뀔 때마다 [onChanged]로 부모가 화면을 다시 그리게 한다.
/// `완료`로 닫으면 true, `나중에`나 바깥을 눌러 닫으면 false를 돌려준다.
Future<bool> showTrainingLogPreCheckDialog(
  BuildContext context, {
  required TrainingLogPreCheckData data,
  required TextEditingController painDetailController,
  required TextEditingController noteController,
  required List<String> issueOptions,
  required Future<String?> Function() onAddIssue,
  required VoidCallback onChanged,
  String memberName = '',

  /// 인바디 측정 흐름을 여는 콜백(회원 정보가 있을 때만 넘긴다). 측정 요약을 돌려준다.
  Future<String?> Function()? onMeasureInbody,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '레슨 전 체크리스트 닫기',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (dialogContext, animation, secondary) {
      var issuesOpen =
          data.issueChips.any((c) => !kAutoIssueNames.contains(c)) ||
          data.note.trim().isNotEmpty;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                key: const Key('pre_check_dialog'),
                color: _tokens(dialogContext).sheetBackground,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    final scheme = Theme.of(context).colorScheme;
                    final tokens = _tokens(context);
                    void update(VoidCallback change) {
                      change();
                      setDialogState(() {});
                      onChanged();
                    }

                    final manualOptions = <String>[
                      ...issueOptions.where(
                        (o) => !kAutoIssueNames.contains(o),
                      ),
                      ...data.issueChips.where(
                        (c) =>
                            !issueOptions.contains(c) &&
                            !kAutoIssueNames.contains(c),
                      ),
                    ];
                    // 이전 버전에서 직접 고른 통증·수면부족·공복 칩은 그대로 보여 해제할 수 있게 한다.
                    final legacyAutoSelected =
                        data.issueChips
                            .where(kAutoIssueNames.contains)
                            .toList();
                    final autoFlags = data.autoFlags;
                    final attention = data.attentionCount;
                    final name = memberName.trim();

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.86,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: scheme.secondaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.health_and_safety_rounded,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isEmpty
                                              ? '레슨 전 체크리스트'
                                              : '$name님 레슨 전 체크리스트',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '수업 시작 전에 한 번 확인해요',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _PreCheckQuestion(
                                keyPrefix: 'pre_condition',
                                icon: Icons.mood_rounded,
                                flaggedIcon: Icons.mood_bad_rounded,
                                label: '컨디션',
                                options: kPreConditionOptions,
                                value: data.condition,
                                flaggedValues: const {'나쁨'},
                                onChanged:
                                    (v) => update(() => data.condition = v),
                              ),
                              _PreCheckQuestion(
                                keyPrefix: 'pre_meal',
                                icon: Icons.restaurant_rounded,
                                label: '마지막 식사',
                                options: kPreMealOptions,
                                value: data.meal,
                                flaggedValues: {
                                  kPreMealFasting,
                                  ..._legacyFastingMeals,
                                },
                                onChanged: (v) => update(() => data.meal = v),
                              ),
                              _PreCheckQuestion(
                                keyPrefix: 'pre_sleep',
                                icon: Icons.bedtime_rounded,
                                label: '수면',
                                options: kPreSleepOptions,
                                value: data.sleep,
                                flaggedValues: const {'부족'},
                                onChanged: (v) => update(() => data.sleep = v),
                              ),
                              _PreCheckQuestion(
                                keyPrefix: 'pre_pain',
                                icon: Icons.healing_rounded,
                                label: '통증',
                                options: kPrePainOptions,
                                value: data.pain,
                                flaggedValues: const {'있음'},
                                onChanged: (v) => update(() => data.pain = v),
                              ),
                              if (data.pain == '있음')
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 10,
                                    left: 44,
                                  ),
                                  child: TextField(
                                    key: const Key('pre_pain_detail'),
                                    controller: painDetailController,
                                    maxLines: 2,
                                    onChanged: (v) {
                                      data.painDetail = v;
                                      onChanged();
                                    },
                                    decoration: const InputDecoration(
                                      labelText: '통증 상세',
                                      hintText: '예: 오른쪽 어깨 전면이 팔 올릴 때 걸리는 느낌',
                                      border: OutlineInputBorder(),
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                ),
                              _PreCheckQuestion(
                                keyPrefix: 'pre_stretching',
                                icon: Icons.self_improvement_rounded,
                                label: '사전 스트레칭',
                                options: kPreStretchingOptions,
                                value: data.stretching,
                                onChanged:
                                    (v) => update(() => data.stretching = v),
                              ),
                              if (onMeasureInbody != null)
                                Container(
                                  key: const Key('pre_inbody_row'),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: tokens.trainingLogSetDivider,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: tokens.trainingLogSetRow,
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.monitor_weight_outlined,
                                          size: 19,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '인바디 측정',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              key: const Key(
                                                'pre_inbody_summary',
                                              ),
                                              data.inbodySummary.trim().isEmpty
                                                  ? '이번 레슨에 측정하지 않았어요'
                                                  : data.inbodySummary.trim(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        key: const Key('pre_inbody_measure'),
                                        onPressed: () async {
                                          final summary =
                                              await onMeasureInbody();
                                          if (summary == null) return;
                                          update(
                                            () => data.inbodySummary = summary,
                                          );
                                        },
                                        child: Text(
                                          data.inbodySummary.trim().isEmpty
                                              ? '측정하기'
                                              : '다시 측정',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: tokens.trainingLogSetDivider,
                                    ),
                                  ),
                                ),
                                child: InkWell(
                                  key: const Key('pre_issue_toggle'),
                                  borderRadius: BorderRadius.circular(10),
                                  onTap:
                                      () => setDialogState(
                                        () => issuesOpen = !issuesOpen,
                                      ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            attention == 0
                                                ? '특이사항'
                                                : '특이사항 · 확인 필요 $attention',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          issuesOpen
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons
                                                  .keyboard_arrow_down_rounded,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (issuesOpen) ...[
                                if (autoFlags.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final flag in autoFlags)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '$flag · 자동',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: scheme.onTertiaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final option in [
                                      ...manualOptions,
                                      ...legacyAutoSelected,
                                    ])
                                      Builder(
                                        builder: (context) {
                                          final selected = data.issueChips
                                              .contains(option);
                                          return InkWell(
                                            key: Key('pre_issue_$option'),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            onTap:
                                                () => update(() {
                                                  if (selected) {
                                                    data.issueChips.remove(
                                                      option,
                                                    );
                                                  } else {
                                                    data.issueChips.add(option);
                                                  }
                                                }),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 40,
                                              ),
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    selected
                                                        ? scheme
                                                            .secondaryContainer
                                                        : tokens
                                                            .trainingLogSetRow,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color:
                                                      selected
                                                          ? scheme.primary
                                                          : tokens
                                                              .trainingLogSetDivider,
                                                ),
                                              ),
                                              child: Text(
                                                option,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      selected
                                                          ? scheme
                                                              .onSecondaryContainer
                                                          : scheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    InkWell(
                                      key: const Key('pre_issue_add'),
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () async {
                                        final added = await onAddIssue();
                                        if (added == null || added.isEmpty) {
                                          return;
                                        }
                                        update(
                                          () => data.issueChips.add(added),
                                        );
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 40,
                                        ),
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.trainingLogSetRow,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: tokens.trainingLogSetDivider,
                                          ),
                                        ),
                                        child: Text(
                                          '+ 추가',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  key: const Key('pre_note'),
                                  controller: noteController,
                                  maxLines: 2,
                                  maxLength: 300,
                                  onChanged: (v) {
                                    data.note = v;
                                    onChanged();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: '특이사항 메모',
                                    hintText: '예: 오늘 어깨가 당긴다고 함',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                              if (attention > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  key: const Key('pre_check_attention'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: scheme.onTertiaryContainer,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          autoFlags.isEmpty
                                              ? '확인 필요 $attention'
                                              : '확인 필요 $attention · ${autoFlags.join(', ')}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onTertiaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: OutlinedButton(
                                        key: const Key('pre_check_later'),
                                        onPressed:
                                            () => Navigator.of(
                                              dialogContext,
                                            ).pop(false),
                                        child: const Text('나중에'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: SizedBox(
                                      height: 48,
                                      child: FilledButton(
                                        key: const Key('pre_check_done'),
                                        onPressed:
                                            () => Navigator.of(
                                              dialogContext,
                                            ).pop(true),
                                        child: Text(
                                          attention == 0 ? '이상 없음 · 완료' : '완료',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return confirmed == true;
}

/// 특이사항을 직접 추가하는 입력창. 입력한 이름을 돌려주고 취소·빈 값이면 null.
Future<String?> showTrainingLogCustomIssueDialog(BuildContext context) async {
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
  if (value.isEmpty || kAutoIssueNames.contains(value)) return null;
  return value;
}
