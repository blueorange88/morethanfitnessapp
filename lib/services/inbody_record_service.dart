import 'package:cloud_functions/cloud_functions.dart';

import '../widgets/inbody_review_sheet.dart';
import 'inbody_scan.dart';
import 'mtf_firebase_functions.dart';

/// 서버(`recordManagedMemberInbody`)에 기록할 인바디 측정값. 값이 있는 항목만 보낸다.
class InbodyMeasurementInput {
  const InbodyMeasurementInput({
    required this.measuredAt,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.skeletalMuscleKg,
    this.bodyFatKg,
    this.source = 'manual',
    this.memberConfirmed = false,
  });

  final DateTime measuredAt;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final double? skeletalMuscleKg;
  final double? bodyFatKg;

  /// `scan`(용지를 읽음) 또는 `manual`(직접 입력).
  final String source;

  /// 용지가 이 회원 것인지 사용자가 직접 확인했는지(불일치·확인 불가일 때 필수).
  final bool memberConfirmed;

  bool get hasAnyValue =>
      heightCm != null ||
      weightKg != null ||
      bodyFatPct != null ||
      skeletalMuscleKg != null ||
      bodyFatKg != null;

  Map<String, dynamic> toCallableMap(String memberId) => {
    'memberId': memberId,
    'measuredAt': _dateText(measuredAt),
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
    if (skeletalMuscleKg != null) 'skeletalMuscleKg': skeletalMuscleKg,
    if (bodyFatKg != null) 'bodyFatKg': bodyFatKg,
    'source': source,
    'memberConfirmed': memberConfirmed,
  };

  static String _dateText(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

double? _positiveNumber(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  return value != null && value.isFinite && value > 0 ? value : null;
}

DateTime? _parseMeasuredDate(String raw) {
  final match = RegExp(
    r'^(\d{4})[.\-/\s]+(\d{1,2})[.\-/\s]+(\d{1,2})$',
  ).firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

/// 확인 화면에서 확정한 값을 서버 입력으로 바꾼다. 측정일이 없으면 오늘, 값이 하나도 없으면 null.
InbodyMeasurementInput? inbodyInputFromOutcome(
  InbodyReviewOutcome outcome, {
  required String source,
  required bool memberConfirmed,
  DateTime? today,
}) {
  final date =
      outcome.date.trim().isEmpty
          ? (today ?? DateTime.now())
          : _parseMeasuredDate(outcome.date);
  if (date == null) return null;
  final input = InbodyMeasurementInput(
    measuredAt: DateTime(date.year, date.month, date.day),
    heightCm: _positiveNumber(outcome.height),
    weightKg: _positiveNumber(outcome.weight),
    bodyFatPct: _positiveNumber(outcome.bodyFatPercent),
    skeletalMuscleKg: _positiveNumber(outcome.skeletalMuscle),
    bodyFatKg: _positiveNumber(outcome.bodyFatKg),
    source: source,
    memberConfirmed: memberConfirmed,
  );
  return input.hasAnyValue ? input : null;
}

/// 체크리스트 줄에 보여줄 한 줄 요약. 예: `체중 62.3kg · 체지방률 23.4%`
String inbodySummaryText(InbodyMeasurementInput input) {
  String number(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  return [
    if (input.weightKg != null) '체중 ${number(input.weightKg!)}kg',
    if (input.skeletalMuscleKg != null)
      '골격근 ${number(input.skeletalMuscleKg!)}kg',
    if (input.bodyFatPct != null) '체지방률 ${number(input.bodyFatPct!)}%',
    if (input.heightCm != null) '키 ${number(input.heightCm!)}cm',
  ].join(' · ');
}

class InbodyRecordService {
  InbodyRecordService({FirebaseFunctions? functions})
    : _functions = functions ?? MtfFirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// 인바디 측정값을 회원 건강정보(최신 값 + 이력)에 기록한다. 이력 개수를 돌려준다.
  Future<int> record({
    required String memberId,
    required InbodyMeasurementInput input,
  }) async {
    final response = await MtfFirebaseFunctions.call(
      'recordManagedMemberInbody',
      functions: _functions,
      parameters: input.toCallableMap(memberId.trim()),
    );
    return (response is Map
            ? (response['historyCount'] as num?)?.toInt()
            : null) ??
        0;
  }

  /// 용지의 성별에 맞게 회원카드 성별을 고친다(`male`/`female`).
  Future<void> updateMemberGender({
    required String memberId,
    required String genderKey,
  }) async {
    await MtfFirebaseFunctions.call(
      'updateManagedMember',
      functions: _functions,
      parameters: {'memberId': memberId.trim(), 'gender': genderKey},
    );
  }
}

/// 용지에서 읽은 값을 확인 화면의 초기값으로 쓰기 위한 헬퍼(직접 입력용 빈 결과).
InbodyScanResult manualInbodyScan(DateTime today) => InbodyScanResult(
  date:
      '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}',
);
