import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/pages/lesson_contract/lesson_contract_settings_page.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';

class _FakeGateway extends PersonalContractGateway {
  _FakeGateway(this.profile, {this.failSave = false})
    : super(
        callable: (name, parameters) async {
          throw UnimplementedError(name);
        },
      );

  final Map<String, dynamic>? profile;
  final bool failSave;
  final List<Map<String, Object?>> saved = [];

  @override
  Future<Map<String, dynamic>?> loadProfile(String uid) async => profile;

  @override
  Future<void> saveSettings({
    ContractParty? party,
    ContractDefaults? defaults,
    List<ContractProductPreset>? products,
  }) async {
    if (failSave) throw StateError('boom');
    saved.add({
      if (party != null) 'contractParty': party.toCallable(),
      if (defaults != null) 'contractDefaults': defaults.toCallable(),
    });
  }
}

Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
}

/// 빈칸을 눌러 키보드 위 빠른 선택 막대를 띄운 뒤 칩을 누른다.
Future<void> _tapQuick(WidgetTester tester, String blank, String chip) async {
  await tester.tap(find.byKey(ValueKey<String>(blank)));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey<String>(chip));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, _FakeGateway gateway) async {
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: LessonContractSettingsPage(
        personalOwnerUid: 'trainer-a',
        gateway: gateway,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ContractParty', () {
    test('필수 칸이 비면 칸별 오류가 나온다', () {
      const party = ContractParty(
        kind: ContractPartyKind.individual,
        name: '',
        trainerName: '김',
        phone: 'abc',
        place: '',
        businessNo: '123',
      );
      expect(party.validate().keys.toSet(), {
        'name',
        'trainerName',
        'phone',
        'place',
        'businessNo',
      });
      expect(party.isComplete, isFalse);
    });

    test('올바른 값이면 서버 형식으로 변환된다', () {
      const party = ContractParty(
        kind: ContractPartyKind.center,
        name: ' 모어짐 ',
        trainerName: '김트레이너',
        phone: '010-1234-5678',
        place: '서울 강남구',
        businessNo: '123-45-67890',
      );
      expect(party.isComplete, isTrue);
      expect(party.toCallable()['name'], '모어짐');
      expect(party.toCallable()['kind'], 'center');
    });

    test('프로필에서 센터 소속이면 센터, 아니면 개인으로 제안하고 기본 센터명은 없다', () {
      final center = ContractSettings.suggestParty({
        'affiliationType': 'center',
        'gymName': '모어짐 강남',
        'centerLocation': '서울 강남구',
        'realName': '김트레이너',
        'phone': '010-1111-2222',
      });
      expect(center.kind, ContractPartyKind.center);
      expect(center.name, '모어짐 강남');
      expect(center.place, '서울 강남구');

      final freelancer = ContractSettings.suggestParty({
        'affiliationType': 'freelancer',
        'gymName': '남은 센터명',
        'realName': '김트레이너',
      });
      expect(freelancer.kind, ContractPartyKind.individual);
      expect(freelancer.name, '김트레이너');
      expect(freelancer.place, '');

      final empty = ContractSettings.suggestParty(null);
      expect(empty.name, '');
      expect(empty.isComplete, isFalse);
    });
  });

  group('ContractDefaults', () {
    test('기본안은 24시간·위약금 10%·3영업일·조건부 양도', () {
      const base = ContractDefaults.standard;
      expect(base.cancelDeadline.hours, 24);
      expect(base.penaltyPercent, 10);
      expect(base.refundBusinessDays, 3);
      expect(base.transferPolicy, ContractTransferPolicy.conditional);
      expect(base.differencesFromStandard(), isEmpty);
    });

    test('서버 상한을 넘는 저장값은 읽을 때 상한으로 맞춘다', () {
      final defaults = ContractDefaults.fromMap({
        'penaltyPercent': 50,
        'refundBusinessDays': 500,
        'cancelDeadline': {'mode': 'hours_before', 'hours': 500},
        'transfer': {'policy': 'denied', 'feeType': 'percent', 'feeValue': 5},
      });
      expect(defaults.penaltyPercent, 10);
      expect(defaults.refundBusinessDays, 130);
      expect(defaults.cancelDeadline.hours, 24);
      expect(defaults.transferFeePercent, 0);
    });

    test('서버 전송 형식: 수수료 없음/비율, 양도 불허면 수수료 0', () {
      final withFee =
          const ContractDefaults(transferFeePercent: 5).toCallable();
      expect(withFee['transfer'], {
        'policy': 'conditional',
        'feeType': 'percent',
        'feeValue': 5,
      });
      final denied =
          const ContractDefaults(
            transferPolicy: ContractTransferPolicy.denied,
            transferFeePercent: 5,
          ).toCallable();
      expect(denied['transfer'], {
        'policy': 'denied',
        'feeType': 'none',
        'feeValue': 0,
      });
      final same = ContractDefaults.standard.copyWith(
        cancelDeadline: const ContractCancelDeadline.sameDay(),
      );
      expect(same.toCallable()['cancelDeadline'], {
        'mode': 'same_day',
        'hours': 0,
      });
      expect(same.differencesFromStandard(), ['취소 마감 시간']);
    });

    test('저장된 설정 읽기: 없으면 기본안, 있으면 그 값', () {
      expect(ContractSettings.fromProfile(null).party, isNull);
      final settings = ContractSettings.fromProfile({
        'contractParty': {
          'kind': 'center',
          'name': '모어짐',
          'trainerName': '김트레이너',
          'phone': '010-1234-5678',
          'place': '서울',
        },
        'contractDefaults': {'penaltyPercent': 5, 'lateNoShowMinutes': 15},
      });
      expect(settings.party?.name, '모어짐');
      expect(settings.defaults.penaltyPercent, 5);
      expect(settings.defaults.lateNoShowMinutes, 15);
    });
  });

  group('contractErrorMessage', () {
    test('알 수 없는 오류는 일반 문구', () {
      expect(contractErrorMessage(StateError('x')), contains('저장하지 못했어요'));
    });
  });

  group('LessonContractSettingsPage', () {
    testWidgets('저장된 값이 없으면 프로필로 채우고 필수 칸이 비면 저장하지 않는다', (tester) async {
      final gateway = _FakeGateway({
        'affiliationType': 'freelancer',
        'realName': '김트레이너',
      });
      await _pump(tester, gateway);

      // 연락처·장소가 비어 있어 저장되지 않는다.
      await tester.tap(find.byKey(const ValueKey('contract_settings_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.saved, isEmpty);
      expect(find.text('연락처를 숫자로 입력해 주세요.'), findsOneWidget);
      expect(find.text('수업 장소를 2~100자로 입력해 주세요.'), findsOneWidget);
    });

    testWidgets('값을 채워 저장하면 서버 형식으로 전달하고 기본안과 다른 항목을 보여준다', (tester) async {
      final gateway = _FakeGateway({
        'affiliationType': 'freelancer',
        'realName': '김트레이너',
      });
      await _pump(tester, gateway);

      await tester.enterText(
        find.byKey(const ValueKey('contract_party_phone')),
        '010-1234-5678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contract_party_place')),
        '서울 강남구 테스트로 1',
      );
      await _tapQuick(
        tester,
        'contract_deadline_hours',
        'contract_deadline_12',
      );
      await _tapQuick(
        tester,
        'contract_refund_days_value',
        'contract_refund_days_2',
      );
      expect(
        find.byKey(const ValueKey('contract_differences')),
        findsOneWidget,
      );
      expect(find.textContaining('취소 마감 시간'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('contract_settings_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);

      expect(gateway.saved, hasLength(1));
      final saved = gateway.saved.single;
      final party = saved['contractParty']! as Map;
      final defaults = saved['contractDefaults']! as Map;
      expect(party['name'], '김트레이너');
      expect(party['kind'], 'individual');
      expect(defaults['cancelDeadline'], {'mode': 'hours_before', 'hours': 12});
      expect(defaults['refundBusinessDays'], 2);
      expect(defaults['penaltyPercent'], 10);
    });

    testWidgets('직접 입력한 마감 시간이 범위를 벗어나면 저장하지 않는다', (tester) async {
      final gateway = _FakeGateway({
        'contractParty': {
          'kind': 'individual',
          'name': '김트레이너',
          'trainerName': '김트레이너',
          'phone': '010-1234-5678',
          'place': '서울',
        },
      });
      await _pump(tester, gateway);
      await tester.enterText(
        find.byKey(const ValueKey('contract_deadline_hours')),
        '100',
      );
      await tester.tap(find.byKey(const ValueKey('contract_settings_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.saved, isEmpty);
    });

    testWidgets('고정 기준 안내가 보이고 환불불가·카드수수료 입력 칸은 없다', (tester) async {
      await _pump(tester, _FakeGateway(null));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('contract_fixed_terms')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('contract_fixed_terms')),
        findsOneWidget,
      );
      final card = find.byKey(const ValueKey('contract_fixed_terms'));
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('레슨 1회가 차감됩니다'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('보강합니다')),
        findsOneWidget,
      );
      expect(find.textContaining('환불불가'), findsNothing);
      expect(find.textContaining('카드수수료'), findsNothing);
    });

    testWidgets('저장 실패 시 화면에 남고 다시 저장할 수 있다', (tester) async {
      final gateway = _FakeGateway({
        'contractParty': {
          'kind': 'individual',
          'name': '김트레이너',
          'trainerName': '김트레이너',
          'phone': '010-1234-5678',
          'place': '서울',
        },
      }, failSave: true);
      await _pump(tester, gateway);
      await tester.tap(find.byKey(const ValueKey('contract_settings_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(
        find.byKey(const ValueKey('contract_settings_save')),
        findsOneWidget,
      );
    });
  });
}
