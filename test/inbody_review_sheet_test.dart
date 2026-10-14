import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/inbody_scan.dart';
import 'package:mtf_app/widgets/inbody_review_sheet.dart';

InbodyReviewOutcome? _outcome;
var _closed = false;

Future<void> _open(
  WidgetTester tester, {
  required InbodyScanResult scan,
  DateTime? birth,
  String? gender,
  bool showRaw = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _outcome = null;
  _closed = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () async {
                    _outcome = await showInbodyReviewSheet(
                      context,
                      scan: scan,
                      memberName: '지나',
                      cardBirthDate: birth,
                      cardGender: gender,
                      showRawText: showRaw,
                    );
                    _closed = true;
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
}

// 측정일 기준으로 나이가 정해지므로 오늘 기준 만 나이가 맞는 생일을 만든다.
DateTime _birthForAge(int age) {
  final now = DateTime.now();
  return DateTime(now.year - age, now.month, now.day);
}

const _sheetScan = InbodyScanResult(
  date: '2026.10.01',
  height: '171',
  weight: '70.4',
  skeletalMuscle: '31.2',
  bodyFatPercent: '23.4',
  bodyFatKg: '16.5',
  age: 35,
  gender: 'male',
  rawText: '인식된 글자 원문',
);

void main() {
  testWidgets('나이·성별이 맞으면 확인 없이 값을 반영한다', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(35), gender: '남');

    expect(find.text('지나님 용지가 맞아요'), findsOneWidget);
    expect(find.byKey(const Key('inbody_confirm_member')), findsNothing);

    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pumpAndSettle();

    expect(_closed, isTrue);
    expect(_outcome, isNotNull);
    expect(_outcome!.date, '2026-10-01');
    expect(_outcome!.height, '171');
    expect(_outcome!.weight, '70.4');
    expect(_outcome!.skeletalMuscle, '31.2');
    expect(_outcome!.bodyFatPercent, '23.4');
    expect(_outcome!.bodyFatKg, '16.5');
    expect(_outcome!.updateGender, isFalse);
  });

  testWidgets('읽은 값을 고쳐서 반영할 수 있다', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(35), gender: '남');

    await tester.enterText(find.byKey(const Key('inbody_weight')), '71.0');
    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pumpAndSettle();

    expect(_outcome!.weight, '71.0');
  });

  testWidgets('나이가 크게 다르면 다른 회원일 수 있다고 알리고 확인해야 반영한다', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(26), gender: '남');

    expect(find.text('다른 회원의 용지일 수 있어요'), findsOneWidget);
    expect(find.text('회원카드  만 26세 · 남성'), findsOneWidget);
    expect(find.text('인바디 용지  만 35세 · 남성'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pump();
    expect(find.byKey(const Key('inbody_error')), findsOneWidget);
    expect(_closed, isFalse);

    await tester.tap(find.byKey(const Key('inbody_confirm_member')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pumpAndSettle();

    expect(_closed, isTrue);
    expect(_outcome, isNotNull);
    expect(_outcome!.checkBirthDate, isTrue);
    expect(_outcome!.updateGender, isFalse);
  });

  testWidgets('성별이 다르면 카드 성별 수정 여부를 묻고 선택대로 돌려준다', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(35), gender: '여');

    expect(find.text('다른 회원의 용지일 수 있어요'), findsOneWidget);
    expect(find.byKey(const Key('inbody_update_gender')), findsOneWidget);
    // 나이는 같으므로 생년월일 확인 안내는 없다.
    expect(find.byKey(const Key('inbody_check_birth')), findsNothing);

    await tester.tap(find.byKey(const Key('inbody_confirm_member')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbody_update_gender')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pumpAndSettle();

    expect(_outcome!.updateGender, isTrue);
    expect(_outcome!.checkBirthDate, isFalse);
  });

  testWidgets('성별을 고치지 않기로 하면 updateGender는 false', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(35), gender: '여');

    await tester.tap(find.byKey(const Key('inbody_confirm_member')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pumpAndSettle();

    expect(_outcome!.updateGender, isFalse);
  });

  testWidgets('나이·성별을 비교할 수 없으면 직접 확인을 요구한다', (tester) async {
    await _open(
      tester,
      scan: const InbodyScanResult(weight: '60'),
      birth: _birthForAge(30),
      gender: '여',
    );

    expect(find.text('나이·성별을 확인하지 못했어요'), findsOneWidget);
    await tester.tap(find.byKey(const Key('inbody_apply')));
    await tester.pump();
    expect(find.byKey(const Key('inbody_error')), findsOneWidget);
    expect(_closed, isFalse);
  });

  testWidgets('취소하면 아무것도 반영하지 않는다', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(35), gender: '남');

    await tester.tap(find.byKey(const Key('inbody_cancel')));
    await tester.pumpAndSettle();

    expect(_closed, isTrue);
    expect(_outcome, isNull);
  });

  testWidgets('측정값을 못 읽었다고 안내하고, DEV에서는 인식 원문을 볼 수 있다', (tester) async {
    await _open(
      tester,
      scan: const InbodyScanResult(
        age: 35,
        gender: 'male',
        rawText: '인식된 글자 원문',
      ),
      birth: _birthForAge(35),
      gender: '남',
      showRaw: true,
    );

    expect(find.text('측정값을 읽지 못했어요. 직접 입력하거나 다시 촬영해 주세요.'), findsOneWidget);
    expect(find.byKey(const Key('inbody_raw_text')), findsOneWidget);
  });

  testWidgets('DEV가 아니면 인식 원문 영역이 없다', (tester) async {
    await _open(tester, scan: _sheetScan, birth: _birthForAge(35), gender: '남');
    expect(find.byKey(const Key('inbody_raw_text')), findsNothing);
  });
}
