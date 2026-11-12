import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/inbody_scan.dart';

/// 인바디 용지 확인 화면에서 사용자가 확정한 값과 카드 수정 선택.
class InbodyReviewOutcome {
  const InbodyReviewOutcome({
    required this.date,
    required this.height,
    required this.weight,
    required this.skeletalMuscle,
    required this.bodyFatPercent,
    required this.bodyFatKg,
    this.updateGender = false,
    this.checkBirthDate = false,
    this.memberVerified = false,
  });

  final String date;
  final String height;
  final String weight;
  final String skeletalMuscle;
  final String bodyFatPercent;
  final String bodyFatKg;

  /// 카드의 성별을 용지에 적힌 성별로 고칠지.
  final bool updateGender;

  /// 저장 후 카드의 생년월일을 직접 확인할지(나이 차이가 클 때).
  final bool checkBirthDate;

  /// 용지가 이 회원 것임을 나이·성별로 확인했거나 사용자가 직접 확인했는지.
  final bool memberVerified;
}

String _genderLabel(String? key) =>
    key == 'male' ? '남성' : (key == 'female' ? '여성' : '알 수 없음');

String _ageLabel(int? age) => age == null ? '알 수 없음' : '만 $age세';

/// 인바디 용지 확인 화면(바텀시트). 취소하면 null.
///
/// 읽은 값을 고칠 수 있고, 용지의 나이·성별을 회원카드와 비교해 다른 회원 용지가 아닌지
/// 확인한다. 어긋나거나 확인할 수 없으면 "이 회원 용지가 맞아요"를 직접 눌러야 반영된다.
Future<InbodyReviewOutcome?> showInbodyReviewSheet(
  BuildContext context, {
  required InbodyScanResult scan,
  required String memberName,
  required DateTime? cardBirthDate,
  required String? cardGender,
  bool showRawText = false,
  bool manualEntry = false,
}) {
  return showModalBottomSheet<InbodyReviewOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder:
        (sheetContext) => _InbodyReviewBody(
          scan: scan,
          memberName: memberName,
          cardBirthDate: cardBirthDate,
          cardGender: cardGender,
          showRawText: showRawText,
          manualEntry: manualEntry,
        ),
  );
}

class _InbodyReviewBody extends StatefulWidget {
  const _InbodyReviewBody({
    required this.scan,
    required this.memberName,
    required this.cardBirthDate,
    required this.cardGender,
    required this.showRawText,
    required this.manualEntry,
  });

  final bool manualEntry;
  final InbodyScanResult scan;
  final String memberName;
  final DateTime? cardBirthDate;
  final String? cardGender;
  final bool showRawText;

  @override
  State<_InbodyReviewBody> createState() => _InbodyReviewBodyState();
}

class _InbodyReviewBodyState extends State<_InbodyReviewBody> {
  late final TextEditingController _dateC;
  late final TextEditingController _heightC;
  late final TextEditingController _weightC;
  late final TextEditingController _skeletalC;
  late final TextEditingController _fatPctC;
  late final TextEditingController _fatKgC;
  late final InbodyMemberCheck _check;

  bool _confirmedMember = false;
  bool _updateGender = false;
  bool _checkBirthDate = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final scan = widget.scan;
    _dateC = TextEditingController(text: scan.date.replaceAll('.', '-'));
    _heightC = TextEditingController(text: scan.height);
    _weightC = TextEditingController(text: scan.weight);
    _skeletalC = TextEditingController(text: scan.skeletalMuscle);
    _fatPctC = TextEditingController(text: scan.bodyFatPercent);
    _fatKgC = TextEditingController(text: scan.bodyFatKg);
    _check = verifyInbodyAgainstMember(
      scan: scan,
      cardBirthDate: widget.cardBirthDate,
      cardGender: widget.cardGender,
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _dateC,
      _heightC,
      _weightC,
      _skeletalC,
      _fatPctC,
      _fatKgC,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get manual => widget.manualEntry;

  bool get _needsConfirm =>
      !manual &&
      (_check.status == InbodyMemberMatch.mismatch ||
          _check.status == InbodyMemberMatch.unknown);

  void _apply() {
    if (_needsConfirm && !_confirmedMember) {
      setState(() => _error = '이 회원 용지가 맞는지 확인해 주세요.');
      return;
    }
    Navigator.of(context).pop(
      InbodyReviewOutcome(
        date: _dateC.text.trim(),
        height: _heightC.text.trim(),
        weight: _weightC.text.trim(),
        skeletalMuscle: _skeletalC.text.trim(),
        bodyFatPercent: _fatPctC.text.trim(),
        bodyFatKg: _fatKgC.text.trim(),
        updateGender: _updateGender && _check.genderMismatch,
        checkBirthDate:
            _checkBirthDate &&
            _check.ageDifference != null &&
            _check.ageDifference! >= 2,
        memberVerified: !manual && (!_needsConfirm || _confirmedMember),
      ),
    );
  }

  Widget _identityBox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name =
        widget.memberName.trim().isEmpty ? '이 회원' : widget.memberName.trim();
    final status = _check.status;

    final Color background;
    final Color foreground;
    final IconData icon;
    final String title;
    switch (status) {
      case InbodyMemberMatch.match:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.check_circle_rounded;
        title = '$name님 용지가 맞아요';
      case InbodyMemberMatch.nearMatch:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        icon = Icons.info_rounded;
        title = '나이가 1살 달라요 (생일 전후일 수 있어요)';
      case InbodyMemberMatch.mismatch:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        icon = Icons.warning_amber_rounded;
        title = '다른 회원의 용지일 수 있어요';
      case InbodyMemberMatch.unknown:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        icon = Icons.help_outline_rounded;
        title = '나이·성별을 확인하지 못했어요';
    }

    return Container(
      key: const Key('inbody_identity_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '회원카드  ${_ageLabel(_check.ageOnCard)} · ${_genderLabel(_check.genderOnCard)}',
            style: TextStyle(fontSize: 12.5, color: foreground),
          ),
          Text(
            '인바디 용지  ${_ageLabel(_check.ageOnSheet)} · ${_genderLabel(_check.genderOnSheet)}',
            style: TextStyle(fontSize: 12.5, color: foreground),
          ),
          if (status == InbodyMemberMatch.unknown) ...[
            const SizedBox(height: 6),
            Text(
              '용지에서 나이나 성별을 읽지 못했거나 회원카드에 생년월일·성별이 없어요. 용지의 이름을 직접 확인해 주세요.',
              style: TextStyle(fontSize: 12, height: 1.4, color: foreground),
            ),
          ],
          if (_needsConfirm) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('inbody_confirm_member'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmedMember,
              onChanged:
                  (value) => setState(() {
                    _confirmedMember = value == true;
                    _error = null;
                  }),
              title: Text(
                '이 회원 용지가 맞아요',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ),
          ],
          if (_check.genderMismatch)
            CheckboxListTile(
              key: const Key('inbody_update_gender'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _updateGender,
              onChanged:
                  (value) => setState(() => _updateGender = value == true),
              title: Text(
                '카드 성별도 용지에 맞게 고칠게요 (${_genderLabel(_check.genderOnCard)} → ${_genderLabel(_check.genderOnSheet)})',
                style: TextStyle(fontSize: 12.5, color: foreground),
              ),
            ),
          if (_check.ageDifference != null && _check.ageDifference! >= 2)
            CheckboxListTile(
              key: const Key('inbody_check_birth'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checkBirthDate,
              onChanged:
                  (value) => setState(() => _checkBirthDate = value == true),
              title: Text(
                '나이만으로 생년월일을 알 수 없어요. 반영 후 생년월일을 직접 확인할게요',
                style: TextStyle(fontSize: 12.5, color: foreground),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    String? suffix,
    bool numeric = true,
  }) {
    return TextField(
      key: Key(key),
      controller: controller,
      keyboardType:
          numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              manual ? '인바디 직접 입력' : '인바디 용지 확인',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              manual ? '측정한 값을 입력해 주세요.' : '읽은 값이 맞는지 확인하고 틀린 값은 고쳐주세요.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!manual) ...[_identityBox(context), const SizedBox(height: 14)],
            _field(
              'inbody_date',
              _dateC,
              '측정일',
              suffix: 'YYYY-MM-DD',
              numeric: false,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field('inbody_height', _heightC, '키', suffix: 'cm'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field('inbody_weight', _weightC, '체중', suffix: 'kg'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'inbody_skeletal',
                    _skeletalC,
                    '골격근량',
                    suffix: 'kg',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    'inbody_fat_pct',
                    _fatPctC,
                    '체지방률',
                    suffix: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _field('inbody_fat_kg', _fatKgC, '체지방량', suffix: 'kg'),
            if (widget.scan.hasAnyMeasurement == false) ...[
              const SizedBox(height: 10),
              Text(
                '측정값을 읽지 못했어요. 직접 입력하거나 다시 촬영해 주세요.',
                style: TextStyle(fontSize: 12.5, color: scheme.error),
              ),
            ],
            if (widget.showRawText) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                key: const Key('inbody_raw_text'),
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  '인식된 원문 보기 (DEV)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      widget.scan.rawText,
                      style: const TextStyle(fontSize: 11.5, height: 1.4),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          () => Clipboard.setData(
                            ClipboardData(text: widget.scan.rawText),
                          ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('원문 복사'),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const Key('inbody_error'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
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
                      key: const Key('inbody_cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const Key('inbody_apply'),
                      onPressed: _apply,
                      child: const Text('반영하기'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
