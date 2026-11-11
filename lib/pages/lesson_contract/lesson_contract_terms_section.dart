import 'package:flutter/material.dart';

import '../../models/lesson_contract/lesson_contract_form.dart';
import '../../models/lesson_contract/lesson_contract_settings.dart';
import '../../utils/lesson_contract/lesson_contract_document.dart';
import '../../utils/lesson_contract/lesson_contract_rules.dart';
import '../../widgets/aifc_interaction.dart';

/// 계약 조건을 조항 문장으로 보여 주고, 문장 안의 빈칸(시간·분·%·영업일)에 직접 입력한다.
/// 칩은 빈칸 아래의 빠른 선택 보조로만 쓴다.
///
/// - [keyPrefix]: 위젯 키 접두어(`form` 입력 화면, `contract` 설정 화면).
/// - [perContract]: true면 이 계약에서만 정하는 항목(정상가 기준·정액 수수료·추가 특약)을
///   보여 준다. 설정 화면의 `내 기본 조건`에서는 false.
class LessonContractTermsSection extends StatefulWidget {
  const LessonContractTermsSection({
    super.key,
    required this.form,
    required this.errors,
    required this.onChanged,
    this.keyPrefix = 'form',
    this.perContract = true,
  });

  final LessonContractForm form;
  final Map<String, String> errors;
  final ValueChanged<LessonContractForm> onChanged;
  final String keyPrefix;
  final bool perContract;

  @override
  State<LessonContractTermsSection> createState() =>
      LessonContractTermsSectionState();
}

class LessonContractTermsSectionState
    extends State<LessonContractTermsSection> {
  static const List<int> _hourChoices = [1, 3, 12, 24, 48];
  static const List<int> _lateChoices = [10, 15, 20, 30, 45, 60];
  static const List<int> _penaltyChoices = [0, 5, 10];
  static const List<int> _refundChoices = [1, 2, 3];

  late final TextEditingController _hours;
  late final TextEditingController _late;
  late final TextEditingController _penalty;
  late final TextEditingController _refundDays;
  late final TextEditingController _fee;
  late final TextEditingController _extra;

  final FocusNode _hoursFocus = FocusNode();
  final FocusNode _lateFocus = FocusNode();
  final FocusNode _penaltyFocus = FocusNode();
  final FocusNode _refundFocus = FocusNode();
  final FocusNode _feeFocus = FocusNode();
  final FocusNode _extraFocus = FocusNode();
  OverlayEntry? _quickEntry;
  bool _quickSyncScheduled = false;
  String? _shownBlank;

  LessonContractForm get _form => widget.form;
  String get _p => widget.keyPrefix;

  @override
  void initState() {
    super.initState();
    final deadline = _form.cancelDeadline;
    _hours = TextEditingController(
      text: deadline.sameDay ? '' : '${deadline.hours}',
    );
    _late = TextEditingController(text: _text(_form.lateNoShowMinutes));
    _penalty = TextEditingController(text: '${_form.penaltyPercent}');
    _refundDays = TextEditingController(text: '${_form.refundBusinessDays}');
    _fee = TextEditingController(
      text: _form.transferFeeValue > 0 ? '${_form.transferFeeValue}' : '',
    );
    _extra = TextEditingController(text: _form.extraTerms);
    for (final node in _blankNodes) {
      node.addListener(_scheduleQuickSync);
    }
    _refundFocus.addListener(_onRefundFocusChanged);
  }

  /// 오류가 난 칸(`lateNoShowMinutes` 등)에 커서를 놓는다. 글자 입력 칸이 아니면 false.
  bool focusError(String errorKey) {
    final node = switch (errorKey) {
      'cancelDeadline' => _hoursFocus,
      'lateNoShowMinutes' => _lateFocus,
      'penaltyPercent' => _penaltyFocus,
      'refundBusinessDays' => _refundFocus,
      'transferFee' => _feeFocus,
      'extraTerms' => _extraFocus,
      _ => null,
    };
    if (node == null || node.context == null) return false;
    node.requestFocus();
    return true;
  }

  List<FocusNode> get _blankNodes => [
    _hoursFocus,
    _lateFocus,
    _penaltyFocus,
    _refundFocus,
  ];

  /// 지금 입력 중인 빈칸 이름. 없으면 null.
  String? get _activeBlank {
    if (_hoursFocus.hasFocus) return 'deadline';
    if (_lateFocus.hasFocus) return 'late';
    if (_penaltyFocus.hasFocus) return 'penalty';
    if (_refundFocus.hasFocus) return 'refund';
    return null;
  }

  FocusNode? _nodeOf(String blank) => switch (blank) {
    'deadline' => _hoursFocus,
    'late' => _lateFocus,
    'penalty' => _penaltyFocus,
    'refund' => _refundFocus,
    _ => null,
  };

  void _scheduleQuickSync() {
    if (_quickSyncScheduled) return;
    _quickSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quickSyncScheduled = false;
      if (!mounted) return;
      _syncQuickBar();
    });
  }

  void _syncQuickBar() {
    final blank = _activeBlank;
    if (blank == null) {
      _quickEntry?.remove();
      _quickEntry = null;
      _shownBlank = null;
      return;
    }
    if (_quickEntry == null) {
      _quickEntry = OverlayEntry(builder: _buildQuickBar);
      Overlay.of(context).insert(_quickEntry!);
    } else {
      _quickEntry!.markNeedsBuild();
    }
    // 다른 빈칸으로 옮겼을 때만 그 칸이 막대에 가리지 않게 화면을 맞춘다.
    if (blank != _shownBlank) {
      _shownBlank = blank;
      final target = _nodeOf(blank)?.context;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 200),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant LessonContractTermsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 빌드 중에는 오버레이를 다시 그릴 수 없으므로 프레임이 끝난 뒤에 갱신한다.
    if (_quickEntry != null) _scheduleQuickSync();
  }

  /// 선택한 빈칸의 빠른 선택 값. 키보드 바로 위에 막대로 보여 준다.
  List<Widget> _quickChoices(String blank) {
    switch (blank) {
      case 'deadline':
        return [
          _quickChip(
            key: '${_p}_deadline_same_day',
            label: '당일 취소 불가',
            selected: _form.cancelDeadline.sameDay,
            onTap: () {
              _hours.clear();
              _update(
                _form.copyWith(
                  cancelDeadline: const ContractCancelDeadline.sameDay(),
                ),
              );
            },
          ),
          for (final hours in _hourChoices)
            _quickChip(
              key: '${_p}_deadline_$hours',
              label: '$hours시간 전',
              selected:
                  !_form.cancelDeadline.sameDay &&
                  _form.cancelDeadline.hours == hours,
              onTap: () {
                _hours.text = '$hours';
                _update(
                  _form.copyWith(
                    cancelDeadline: ContractCancelDeadline.hoursBefore(hours),
                  ),
                );
              },
            ),
        ];
      case 'late':
        return [
          _quickChip(
            key: '${_p}_late_none',
            label: '기준 없음',
            selected: _form.lateNoShowMinutes == null,
            onTap: () {
              _late.clear();
              _update(_form.copyWith(clearLateNoShow: true));
            },
          ),
          for (final minutes in _lateChoices)
            _quickChip(
              key: '${_p}_late_$minutes',
              label: '$minutes분',
              selected: _form.lateNoShowMinutes == minutes,
              onTap: () {
                _late.text = '$minutes';
                _update(_form.copyWith(lateNoShowMinutes: minutes));
              },
            ),
        ];
      case 'penalty':
        return [
          for (final percent in _penaltyChoices)
            _quickChip(
              key: '${_p}_penalty_$percent',
              label: '$percent%',
              selected: _form.penaltyPercent == percent,
              onTap: () {
                _penalty.text = '$percent';
                _update(_form.copyWith(penaltyPercent: percent));
              },
            ),
        ];
      case 'refund':
        return [
          for (final day in _refundChoices)
            _quickChip(
              key: '${_p}_refund_days_$day',
              label: '$day영업일',
              selected: _form.refundBusinessDays == day,
              onTap: () {
                _refundDays.text = '$day';
                _update(_form.copyWith(refundBusinessDays: day));
              },
            ),
        ];
    }
    return const [];
  }

  Widget _buildQuickBar(BuildContext overlayContext) {
    final blank = _activeBlank;
    final inset = MediaQuery.viewInsetsOf(overlayContext).bottom;
    final scheme = Theme.of(overlayContext).colorScheme;
    final chips = blank == null ? const <Widget>[] : _quickChoices(blank);
    return Positioned(
      left: 0,
      right: 0,
      bottom: inset,
      child: TextFieldTapRegion(
        child: Material(
          key: ValueKey<String>('${_p}_quick_bar'),
          color: scheme.surfaceContainerHighest,
          elevation: 6,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 48,
              child: ListView(
                key: ValueKey<String?>(blank),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final chip in chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(child: chip),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refundFocus.removeListener(_onRefundFocusChanged);
    for (final node in _blankNodes) {
      node.removeListener(_scheduleQuickSync);
      node.dispose();
    }
    _feeFocus.dispose();
    _extraFocus.dispose();
    _quickEntry?.remove();
    _quickEntry = null;
    for (final controller in [
      _hours,
      _late,
      _penalty,
      _refundDays,
      _fee,
      _extra,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _text(int? value) => value == null ? '' : '$value';

  void _update(LessonContractForm next) => widget.onChanged(next);

  int _intOf(String value) => int.tryParse(value.trim()) ?? 0;

  /// 환급 영업일 칸을 누르면 환불 문구 제한의 근거를 토스트로 알린다.
  void _onRefundFocusChanged() {
    if (_refundFocus.hasFocus) {
      _showNotice(kRefundLegalNotice);
    }
  }

  void _onRefundDaysChanged(String value) {
    _update(_form.copyWith(refundBusinessDays: _intOf(value)));
  }

  void _showNotice(String message) {
    // 키보드 위 빠른 선택 막대(48dp)를 가리지 않도록 그 위에 띄운다.
    AifcInteraction.toast(
      context: context,
      message: message,
      duration: const Duration(seconds: 7),
      keyboardGap: 64,
    );
  }

  @override
  Widget build(BuildContext context) {
    final errors = widget.errors;
    final theme = Theme.of(context);
    final differences = _form.differencesFromStandard();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _article(context, '제1조', '예약 변경 및 취소', [
          _sentence(context, [
            if (_form.cancelDeadline.sameDay)
              const TextSpan(text: kCancelSameDay)
            else ...[
              const TextSpan(text: kCancelHoursBefore),
              _blank(
                key: '${_p}_deadline_hours',
                controller: _hours,
                focusNode: _hoursFocus,
                width: 48,
                hasError: errors['cancelDeadline'] != null,
                onChanged:
                    (value) => _update(
                      _form.copyWith(
                        cancelDeadline: ContractCancelDeadline.hoursBefore(
                          _intOf(value),
                        ),
                      ),
                    ),
              ),
              const TextSpan(text: kCancelHoursAfter),
            ],
            if (_form.lateNoShowMinutes != null) ...[
              const TextSpan(text: ' $kLateBefore'),
              _blank(
                key: '${_p}_late_minutes',
                controller: _late,
                focusNode: _lateFocus,
                width: 48,
                hasError: errors['lateNoShowMinutes'] != null,
                onChanged:
                    (value) => _update(
                      _form.copyWith(lateNoShowMinutes: _intOf(value)),
                    ),
              ),
              const TextSpan(text: kLateAfter),
            ],
          ]),
          _error(context, errors['cancelDeadline']),
          _error(context, errors['lateNoShowMinutes']),
          if (_form.cancelDeadline.sameDay)
            _linkButton(
              key: '${_p}_deadline_set_hours',
              label: '취소 가능 시간 지정하기',
              onTap: () {
                _hours.text = '$kContractDefaultCancelHours';
                _update(
                  _form.copyWith(
                    cancelDeadline: const ContractCancelDeadline.hoursBefore(
                      kContractDefaultCancelHours,
                    ),
                  ),
                );
              },
            ),
          if (_form.lateNoShowMinutes == null)
            _linkButton(
              key: '${_p}_late_set',
              label: '레슨 진행 불가 시간 지정하기',
              onTap: () {
                _late.text = '$kContractDefaultLateLimitMinutes';
                _update(
                  _form.copyWith(
                    lateNoShowMinutes: kContractDefaultLateLimitMinutes,
                  ),
                );
              },
            ),
        ]),
        _article(context, '제2조', '위약금 및 환불', [
          _sentence(context, [
            const TextSpan(text: kPenaltyBefore),
            _blank(
              key: '${_p}_penalty_percent',
              controller: _penalty,
              focusNode: _penaltyFocus,
              width: 44,
              hasError: errors['penaltyPercent'] != null,
              onChanged:
                  (value) => _update(
                    _form.copyWith(
                      penaltyPercent: int.tryParse(value.trim()) ?? -1,
                    ),
                  ),
            ),
            const TextSpan(text: kPenaltyAfter),
            _blank(
              key: '${_p}_refund_days_value',
              controller: _refundDays,
              focusNode: _refundFocus,
              width: 44,
              hasError: errors['refundBusinessDays'] != null,
              onChanged: _onRefundDaysChanged,
            ),
            const TextSpan(text: kRefundDaysAfter),
          ]),
          _error(context, errors['penaltyPercent']),
          _error(context, errors['refundBusinessDays']),
        ]),
        if (widget.perContract)
          _article(context, '제3조', '계약해지 환불 시 이용분 계산 기준', [
            if (_form.canUseListPriceBasis)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _basisTile(
                    context,
                    key: '${_p}_refund_by_discount',
                    selected: !_form.refundByListPrice,
                    title: '1회 금액을 할인가 기준으로 이용분 계산합니다',
                    formula: '할인가 ÷ 총 레슨 진행 횟수',
                    onSelect:
                        () => _update(_form.copyWith(refundByListPrice: false)),
                  ),
                  _basisTile(
                    context,
                    key: '${_p}_refund_by_list_price',
                    selected: _form.refundByListPrice,
                    title: '1회 금액을 정상가 기준으로 이용분 계산합니다',
                    formula: '할인 전 정상가 ÷ 총 레슨 진행 횟수',
                    onSelect:
                        () => _update(_form.copyWith(refundByListPrice: true)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '※ 이용분과 위약금의 합계는 낸 금액을 넘지 않습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            else
              KeyedSubtree(
                key: ValueKey<String>('${_p}_refund_basis_contract_unit'),
                child: _sentence(context, const [
                  TextSpan(text: kBasisContractUnit),
                ]),
              ),
            _error(context, errors['refundBasis']),
          ]),
        _article(context, widget.perContract ? '제4조' : '제3조', '양도', [
          _sentence(context, [
            const TextSpan(text: kTransferBefore),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _dropdown<ContractTransferPolicy>(
                key: '${_p}_transfer_policy',
                value: _form.transferPolicy,
                items: {
                  for (final policy in ContractTransferPolicy.values)
                    policy: policy.label,
                },
                onChanged: (policy) {
                  if (policy == ContractTransferPolicy.denied) {
                    _fee.clear();
                    _update(
                      _form.copyWith(
                        transferPolicy: policy,
                        transferFeeType: ContractTransferFeeType.none,
                        transferFeeValue: 0,
                      ),
                    );
                  } else {
                    _update(_form.copyWith(transferPolicy: policy));
                  }
                },
              ),
            ),
            if (_form.transferPolicy == ContractTransferPolicy.denied)
              const TextSpan(text: kTransferDeniedAfter)
            else ...[
              const TextSpan(text: kTransferAllowedAfter),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _dropdown<ContractTransferFeeType>(
                  key: '${_p}_transfer_fee_type',
                  value: _form.transferFeeType,
                  items: {
                    ContractTransferFeeType.none: '없음',
                    if (widget.perContract)
                      ContractTransferFeeType.amount: '정액(원)',
                    ContractTransferFeeType.percent: '비율(%)',
                  },
                  onChanged: (type) {
                    if (type == ContractTransferFeeType.none) {
                      _fee.clear();
                      _update(
                        _form.copyWith(
                          transferFeeType: type,
                          transferFeeValue: 0,
                        ),
                      );
                    } else {
                      _update(_form.copyWith(transferFeeType: type));
                    }
                  },
                ),
              ),
              if (_form.transferFeeType != ContractTransferFeeType.none) ...[
                const TextSpan(text: ' '),
                _blank(
                  key: '${_p}_transfer_fee_value',
                  controller: _fee,
                  focusNode: _feeFocus,
                  width: 80,
                  hasError: errors['transferFee'] != null,
                  onChanged:
                      (value) => _update(
                        _form.copyWith(transferFeeValue: _intOf(value)),
                      ),
                ),
                TextSpan(
                  text:
                      _form.transferFeeType == ContractTransferFeeType.amount
                          ? ' 원'
                          : ' %',
                ),
              ],
              const TextSpan(text: ' 입니다.'),
            ],
          ]),
          _error(context, errors['transferFee']),
        ]),
        _article(
          context,
          widget.perContract ? '제5조' : '제4조',
          '기타 사항',
          [
            CheckboxListTile(
              key: ValueKey<String>('${_p}_extension_clause'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(kExtensionClause, style: theme.textTheme.bodyLarge),
              value: _form.expiryExtensionClause,
              onChanged:
                  (value) => _update(
                    _form.copyWith(expiryExtensionClause: value ?? false),
                  ),
            ),
            CheckboxListTile(
              key: ValueKey<String>('${_p}_unavoidable_refund_clause'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                kUnavoidableRefundClause,
                style: theme.textTheme.bodyLarge,
              ),
              value: _form.unavoidableRefundClause,
              onChanged:
                  (value) => _update(
                    _form.copyWith(unavoidableRefundClause: value ?? false),
                  ),
            ),
          ],
          last: !widget.perContract,
        ),
        if (widget.perContract)
          _article(context, '제6조', '특약', [
            TextField(
              key: ValueKey<String>('${_p}_extra_terms'),
              controller: _extra,
              focusNode: _extraFocus,
              maxLines: 3,
              maxLength: 500,
              onChanged: (value) => _update(_form.copyWith(extraTerms: value)),
              decoration: InputDecoration(
                labelText: '추가 특약 (선택)',
                helperText: '환불·책임·수수료를 제한하는 문구는 저장되지 않습니다.',
                errorText: errors['extraTerms'],
              ),
            ),
          ], last: true),
        if (differences.isNotEmpty)
          Padding(
            key: ValueKey<String>('${_p}_differences'),
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '앱 기본안과 다른 항목: ${differences.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // ---- 조각 위젯 ----
  /// 둘 중 하나만 고르는 계산 기준 줄(체크박스 모양). 이미 고른 줄을 다시 눌러도 해제되지 않는다.
  Widget _basisTile(
    BuildContext context, {
    required String key,
    required bool selected,
    required String title,
    required String formula,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      key: ValueKey<String>(key),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        formula,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: selected,
      onChanged: (_) {
        if (!selected) onSelect();
      },
    );
  }

  Widget _article(
    BuildContext context,
    String number,
    String title,
    List<Widget> children, {
    bool last = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$number $title',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _sentence(BuildContext context, List<InlineSpan> spans) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 2.0);
    return Text.rich(TextSpan(style: style, children: spans));
  }

  Widget _error(BuildContext context, String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  /// 문장 안에 들어가는 밑줄 빈칸.
  WidgetSpan _blank({
    required String key,
    required TextEditingController controller,
    FocusNode? focusNode,
    required double width,
    required bool hasError,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final line = hasError ? scheme.error : scheme.onSurface;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(
        width: width,
        child: TextField(
          key: ValueKey<String>(key),
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          onChanged: onChanged,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            border: UnderlineInputBorder(borderSide: BorderSide(color: line)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: line),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: hasError ? scheme.error : scheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String key,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButton<T>(
      key: ValueKey<String>(key),
      value: value,
      isDense: true,
      underline: Container(
        height: 1,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: [
        for (final entry in items.entries)
          DropdownMenuItem<T>(
            value: entry.key,
            child: Text(
              entry.value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  Widget _linkButton({
    required String key,
    required String label,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: ValueKey<String>(key),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _quickChip({
    required String key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      key: ValueKey<String>(key),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onSelected: (_) {
        final node = _activeBlank == null ? null : _nodeOf(_activeBlank!);
        onTap();
        node?.requestFocus();
      },
    );
  }
}

/// 환불 계산 예시. 입력값으로 바로 계산하고, 서명 전 고지 화면과 PDF에도 같은 계산을 쓴다.
class LessonContractRefundExample extends StatelessWidget {
  const LessonContractRefundExample({super.key, required this.form});

  final LessonContractForm form;

  @override
  Widget build(BuildContext context) {
    final paid = form.paidAmount;
    final count = form.sessionCount;
    final scheme = Theme.of(context).colorScheme;
    final valid =
        paid != null &&
        count != null &&
        paid >= 1 &&
        count >= 1 &&
        count <= 200 &&
        form.penaltyPercent >= 0 &&
        form.penaltyPercent <= kContractMaxPenaltyPercent;
    if (!valid) {
      return _frame(
        context,
        child: Text(
          '금액과 횟수를 입력하면 환불 계산 예시가 나옵니다.',
          key: const ValueKey<String>('refund_example_empty'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final used = refundExampleUsedSessions(count);
    final before = computeRefund(
      kind: RefundKind.beforeFirstLesson,
      paidAmount: paid,
      sessionCount: count,
      usedSessions: 0,
      listPrice: form.listPrice,
      listPriceBasis: false,
      penaltyPercent: form.penaltyPercent,
    );
    final contractBasis =
        used == 0
            ? null
            : computeRefund(
              kind: RefundKind.memberReason,
              paidAmount: paid,
              sessionCount: count,
              usedSessions: used,
              listPrice: form.listPrice,
              listPriceBasis: false,
              penaltyPercent: form.penaltyPercent,
            );
    final listBasis =
        used == 0 || !form.canUseListPriceBasis
            ? null
            : computeRefund(
              kind: RefundKind.memberReason,
              paidAmount: paid,
              sessionCount: count,
              usedSessions: used,
              listPrice: form.listPrice,
              listPriceBasis: true,
              penaltyPercent: form.penaltyPercent,
            );
    final effectiveIsList = form.usesListPriceBasis;
    return _frame(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '결제 ${formatWon(paid)}원 · $count회 · 위약금 ${form.penaltyPercent}%',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _row(
            context,
            key: 'refund_example_before',
            title: '첫 수업 전 해지',
            detail: '위약금 ${formatWon(before.penalty)}원',
            amount: before.refund,
          ),
          if (contractBasis != null)
            _row(
              context,
              key: 'refund_example_contract',
              title:
                  '$used회 소진 · 회당 금액 ${formatWon(contractBasis.unitPrice)}원'
                  '${effectiveIsList ? ' (참고)' : ''}',
              detail:
                  '소진 ${formatWon(contractBasis.consumed)}원 + 위약금 '
                  '${formatWon(contractBasis.penalty)}원',
              amount: contractBasis.refund,
              emphasize: !effectiveIsList,
            ),
          if (listBasis != null)
            _row(
              context,
              key: 'refund_example_list',
              title:
                  '$used회 소진 · 정상가 회당 금액 ${formatWon(listBasis.unitPrice)}원'
                  '${effectiveIsList ? '' : ' (참고)'}',
              detail:
                  '소진 ${formatWon(listBasis.consumed)}원 + 위약금 '
                  '${formatWon(listBasis.penalty)}원',
              amount: listBasis.refund,
              emphasize: effectiveIsList,
            ),
          const SizedBox(height: 6),
          Text(
            '카드수수료는 공제하지 않습니다. 소진분과 위약금 합계가 결제금액을 넘으면 환불은 0원이고 추가 청구는 없습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String key,
    required String title,
    required String detail,
    required int amount,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey<String>(key),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '환불 ${formatWon(amount)}원',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _frame(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('refund_example_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
