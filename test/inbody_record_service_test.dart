import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/inbody_record_service.dart';
import 'package:mtf_app/services/inbody_scan.dart';
import 'package:mtf_app/widgets/inbody_review_sheet.dart';
import 'package:mtf_app/widgets/training_log_pre_check.dart';

InbodyReviewOutcome _outcome({
  String date = '2026-10-01',
  String height = '170',
  String weight = '62.3',
  String skeletal = '24.8',
  String fatPct = '23.4',
  String fatKg = '',
}) => InbodyReviewOutcome(
  date: date,
  height: height,
  weight: weight,
  skeletalMuscle: skeletal,
  bodyFatPercent: fatPct,
  bodyFatKg: fatKg,
);

void main() {
  group('확인 화면 결과 → 서버 입력', () {
    test('입력한 값만 보내고 측정일·출처·확인 여부를 담는다', () {
      final input =
          inbodyInputFromOutcome(
            _outcome(),
            source: 'scan',
            memberConfirmed: true,
          )!;

      expect(input.toCallableMap('member-1'), {
        'memberId': 'member-1',
        'measuredAt': '2026-10-01',
        'heightCm': 170.0,
        'weightKg': 62.3,
        'bodyFatPct': 23.4,
        'skeletalMuscleKg': 24.8,
        'source': 'scan',
        'memberConfirmed': true,
      });
      expect(input.toCallableMap('m').containsKey('bodyFatKg'), isFalse);
    });

    test('측정일이 점·공백 형식이어도 읽고, 비어 있으면 오늘로 한다', () {
      expect(
        inbodyInputFromOutcome(
          _outcome(date: '2026.10.01'),
          source: 'manual',
          memberConfirmed: false,
        )!.measuredAt,
        DateTime(2026, 10, 1),
      );
      expect(
        inbodyInputFromOutcome(
          _outcome(date: ''),
          source: 'manual',
          memberConfirmed: false,
          today: DateTime(2026, 11, 5, 14, 30),
        )!.measuredAt,
        DateTime(2026, 11, 5),
      );
    });

    test('잘못된 측정일이거나 값이 하나도 없으면 null', () {
      expect(
        inbodyInputFromOutcome(
          _outcome(date: '2026-13-40'),
          source: 'manual',
          memberConfirmed: false,
        ),
        isNull,
      );
      expect(
        inbodyInputFromOutcome(
          _outcome(height: '', weight: '', skeletal: '', fatPct: '', fatKg: ''),
          source: 'manual',
          memberConfirmed: false,
        ),
        isNull,
      );
    });

    test('0·음수·글자 값은 버린다', () {
      final input =
          inbodyInputFromOutcome(
            _outcome(
              height: '0',
              weight: '-3',
              skeletal: 'abc',
              fatPct: '23,4',
            ),
            source: 'manual',
            memberConfirmed: false,
          )!;

      expect(input.heightCm, isNull);
      expect(input.weightKg, isNull);
      expect(input.skeletalMuscleKg, isNull);
      expect(input.bodyFatPct, 23.4);
    });

    test('체크리스트 요약은 체중·골격근·체지방률·키를 짧게 보여준다', () {
      final input =
          inbodyInputFromOutcome(
            _outcome(),
            source: 'scan',
            memberConfirmed: true,
          )!;
      expect(
        inbodySummaryText(input),
        '체중 62.3kg · 골격근 24.8kg · 체지방률 23.4% · 키 170cm',
      );
    });
  });

  test('직접 입력용 빈 결과는 오늘 날짜만 채운다', () {
    final scan = manualInbodyScan(DateTime(2026, 3, 7));
    expect(scan.date, '2026-03-07');
    expect(scan.hasAnyMeasurement, isFalse);
  });

  test('서비스는 인바디 기록과 성별 수정에 서버 함수를 쓴다', () {
    final source =
        File('lib/services/inbody_record_service.dart').readAsStringSync();
    expect(source, contains("'recordManagedMemberInbody'"));
    expect(source, contains("'updateManagedMember'"));
    expect(source, contains("'gender': genderKey"));
  });

  group('측정 흐름 연결', () {
    final flow =
        File('lib/widgets/inbody_measure_flow.dart').readAsStringSync();

    test('사진 원본은 저장하지 않고 본인 확인 후 서버에 기록한다', () {
      expect(flow, isNot(contains('FirebaseStorage')));
      expect(flow, isNot(contains('putFile')));
      expect(flow, contains('showInbodyReviewSheet('));
      expect(flow, contains('memberConfirmed: outcome.memberVerified'));
      expect(flow, contains('recorder.record('));
    });

    test('성별은 사용자가 고른 경우에만 고치고 생년월일은 건드리지 않는다', () {
      expect(
        flow,
        contains('if (outcome.updateGender && scan.gender != null)'),
      );
      expect(flow, isNot(contains('birthDate')));
    });

    test('회원 나이·성별은 members 문서에서 읽는다', () {
      expect(flow, contains(".collection('members')"));
      expect(flow, contains("data?['birth']"));
      expect(flow, contains("data?['gender']"));
    });
  });

  group('레슨일지 화면 연결', () {
    final page =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    test('인바디 콜백은 개인 워크스페이스·회원이 있을 때만 만든다', () {
      expect(
        RegExp(
          r'Future<String\?> Function\(\)\? _inbodyMeasureCallback\(\) \{\s*'
          r"final memberId = \(widget\.memberId \?\? ''\)\.trim\(\);\s*"
          r'if \(!_isPersonalWorkspace \|\| memberId\.isEmpty\) return null;',
        ).hasMatch(page),
        isTrue,
      );
    });

    test('목록 화면 체크리스트와 두 에디터에 같은 콜백을 넘긴다', () {
      expect(
        RegExp(
          r'onMeasureInbody: _inbodyMeasureCallback\(\),',
        ).allMatches(page).length,
        3,
      );
      expect(page, contains('initialInbodySummary: log.inbodySummary,'));
    });
  });

  test('체크리스트 값은 인바디 요약을 화면 표시용으로만 들고 있다', () {
    final data = TrainingLogPreCheckData(inbodySummary: '체중 62kg');
    expect(data.inbodySummary, '체중 62kg');
    // 일지에 저장하는 칩·특이사항 계산에는 영향이 없다.
    expect(data.attentionCount, 0);
    expect(data.savedIssueChips, isEmpty);
  });

  testWidgets('직접 입력 확인 화면은 본인 확인 박스를 숨기고 확인 없이 반영한다', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    InbodyReviewOutcome? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () async {
                      result = await showInbodyReviewSheet(
                        context,
                        scan: manualInbodyScan(DateTime(2026, 10, 1)),
                        memberName: '지나',
                        cardBirthDate: DateTime(1999, 11, 11),
                        cardGender: '여',
                        manualEntry: true,
                      );
                    },
                    child: const Text('열기'),
                  ),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('인바디 직접 입력'), findsOneWidget);
    expect(find.byKey(const Key('inbody_identity_box')), findsNothing);

    await tester.enterText(find.byKey(const Key('inbody_weight')), '61.5');
    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.weight, '61.5');
    expect(result!.date, '2026-10-01');
    expect(result!.memberVerified, isFalse);
  });
}
