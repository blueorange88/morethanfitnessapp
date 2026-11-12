import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/contract_product_input.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/pages/lesson_contract/my_contract_products_section.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';

class _FakeGateway extends PersonalContractGateway {
  _FakeGateway(this.products, {this.failLoad = false, this.failSaveWith})
    : super(
        callable: (name, parameters) async {
          throw UnimplementedError(name);
        },
      );

  List<ContractProductPreset> products;
  bool failLoad;
  final Object? failSaveWith;
  final List<List<ContractProductPreset>> saves = [];

  @override
  Future<Map<String, dynamic>?> loadProfile(String uid) async {
    if (failLoad) throw StateError('load failed');
    return {
      'contractProducts': [for (final item in products) item.toCallable()],
    };
  }

  @override
  Future<void> saveSettings({
    ContractParty? party,
    ContractDefaults? defaults,
    List<ContractProductPreset>? products,
  }) async {
    if (failSaveWith != null) throw failSaveWith!;
    saves.add(products!);
    this.products = products;
  }
}

ContractProductPreset _product(
  String name, {
  int count = 10,
  int paid = 1000000,
  int? list,
}) => buildContractProductPreset(
  name: name,
  sessionCount: count,
  sessionMinutes: 50,
  paidAmount: paid,
  listPrice: list,
);

Future<void> _pump(WidgetTester tester, _FakeGateway gateway) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MyContractProductsSection(
            personalOwnerUid: 'trainer-a',
            gateway: gateway,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key('my_product_field_$key')), text);
  await tester.pump();
}

void main() {
  group('입력 검사·상품 만들기', () {
    Map<String, String> check({
      String name = 'PT 10회',
      int? count = 10,
      int? minutes = 50,
      int? paid = 1000000,
      int? list,
      List<String> others = const [],
    }) => validateContractProductInput(
      name: name,
      sessionCount: count,
      sessionMinutes: minutes,
      paidAmount: paid,
      listPrice: list,
      otherNames: others,
    );

    test('정상 입력은 통과한다', () {
      expect(check(), isEmpty);
      expect(check(list: 1500000), isEmpty);
    });

    test('서버와 같은 상한을 막는다', () {
      expect(check(name: '  ')['name'], isNotNull);
      expect(check(name: 'a' * 41)['name'], isNotNull);
      expect(check(name: '환불 불가 상품')['name'], isNotNull);
      expect(check(count: 0)['sessionCount'], isNotNull);
      expect(check(count: 201)['sessionCount'], isNotNull);
      expect(check(count: null)['sessionCount'], isNotNull);
      expect(check(minutes: 9)['sessionMinutes'], isNotNull);
      expect(check(minutes: 181)['sessionMinutes'], isNotNull);
      expect(check(paid: 0)['paidAmount'], isNotNull);
      expect(check(paid: 100000001)['paidAmount'], isNotNull);
      expect(check(list: 1000000)['listPrice'], isNotNull);
      expect(check(list: 900000)['listPrice'], isNotNull);
    });

    test('같은 이름은 대소문자·공백을 무시하고 중복으로 본다', () {
      expect(check(name: 'pt 10회', others: ['PT 10회'])['name'], isNotNull);
      expect(check(name: 'PT 20회', others: ['PT 10회']), isEmpty);
    });

    test('서비스 내용은 계약서 입력 화면과 같은 문구로 자동 작성한다', () {
      final preset = _product(' PT 10회 ');
      expect(preset.name, 'PT 10회');
      expect(preset.serviceContent, 'PT 10회 (총 10회, 1회 50분)');
    });
  });

  group('마이페이지 내 수업 상품', () {
    testWidgets('상품이 없으면 안내를 보여 주고 추가 버튼이 있다', (tester) async {
      await _pump(tester, _FakeGateway(const []));
      expect(find.byKey(const Key('my_products_empty')), findsOneWidget);
      expect(find.byKey(const Key('my_product_add')), findsOneWidget);
    });

    testWidgets('저장된 상품의 횟수·시간·금액·회당 금액·정상가를 보여 준다', (tester) async {
      await _pump(tester, _FakeGateway([_product('PT 10회', list: 1500000)]));
      expect(find.text('PT 10회'), findsOneWidget);
      expect(find.textContaining('총 10회 · 1회 50분'), findsOneWidget);
      expect(find.textContaining('1,000,000원 (회당 100,000원)'), findsOneWidget);
      expect(find.textContaining('정상가 1,500,000원'), findsOneWidget);
    });

    testWidgets('상품을 추가하면 서비스 내용이 자동 작성되어 서버로 저장된다', (tester) async {
      final gateway = _FakeGateway([_product('기존')]);
      await _pump(tester, gateway);

      await tester.tap(find.byKey(const Key('my_product_add')));
      await tester.pumpAndSettle();
      await _type(tester, 'name', 'PT 20회');
      await _type(tester, 'sessionCount', '20');
      await _type(tester, 'paidAmount', '1800000');
      await _type(tester, 'listPrice', '2400000');
      await tester.tap(find.byKey(const Key('my_product_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);

      expect(gateway.saves, hasLength(1));
      final saved = gateway.saves.single;
      expect(saved.map((p) => p.name), ['기존', 'PT 20회']);
      final added = saved.last;
      expect(added.serviceContent, 'PT 20회 (총 20회, 1회 50분)');
      expect(added.sessionMinutes, 50, reason: '1회 시간 기본값은 50분');
      expect(added.paidAmount, 1800000);
      expect(added.listPrice, 2400000);
      // 화면에도 바로 보인다.
      expect(find.text('PT 20회'), findsOneWidget);
    });

    testWidgets('필수 칸이 비면 저장하지 않고 첫 빈 칸으로 커서를 옮긴다', (tester) async {
      final gateway = _FakeGateway(const []);
      await _pump(tester, gateway);
      await tester.tap(find.byKey(const Key('my_product_add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('my_product_save')));
      await tester.pumpAndSettle();
      expect(gateway.saves, isEmpty);
      TextField field(String key) =>
          tester.widget<TextField>(find.byKey(Key('my_product_field_$key')));
      expect(field('name').focusNode!.hasFocus, isTrue);
      expect(find.text('상품 이름을 입력해 주세요.'), findsOneWidget);

      await _type(tester, 'name', 'PT');
      await tester.tap(find.byKey(const Key('my_product_save')));
      await tester.pumpAndSettle();
      expect(field('sessionCount').focusNode!.hasFocus, isTrue);
      expect(gateway.saves, isEmpty);
    });

    testWidgets('같은 이름은 저장하지 못하지만 수정할 때 자기 이름은 그대로 둘 수 있다', (tester) async {
      final gateway = _FakeGateway([_product('PT 10회'), _product('PT 20회')]);
      await _pump(tester, gateway);

      // 다른 상품과 같은 이름으로 바꾸면 막는다.
      await tester.tap(find.byKey(const Key('my_product_edit_1')));
      await tester.pumpAndSettle();
      await _type(tester, 'name', 'pt 10회');
      await tester.tap(find.byKey(const Key('my_product_save')));
      await tester.pumpAndSettle();
      expect(find.text('같은 이름의 수업 상품이 이미 있어요.'), findsOneWidget);
      expect(gateway.saves, isEmpty);

      // 자기 이름은 그대로 두고 금액만 고치면 저장된다.
      await _type(tester, 'name', 'PT 20회');
      await _type(tester, 'paidAmount', '1700000');
      await tester.tap(find.byKey(const Key('my_product_save')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.saves, hasLength(1));
      expect(gateway.saves.single[1].paidAmount, 1700000);
      expect(gateway.saves.single[0].name, 'PT 10회');
    });

    testWidgets('삭제는 확인한 뒤에만 한다', (tester) async {
      final gateway = _FakeGateway([_product('PT 10회'), _product('PT 20회')]);
      await _pump(tester, gateway);

      await tester.tap(find.byKey(const Key('my_product_delete_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('my_product_delete_cancel')));
      await tester.pumpAndSettle();
      expect(gateway.saves, isEmpty);

      await tester.tap(find.byKey(const Key('my_product_delete_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('my_product_delete_confirm')));
      await tester.pumpAndSettle();
      await _flushToast(tester);
      expect(gateway.saves.single.map((p) => p.name), ['PT 20회']);
      expect(find.text('PT 10회'), findsNothing);
    });

    testWidgets('20개가 차면 추가를 막는다', (tester) async {
      final gateway = _FakeGateway([
        for (var i = 1; i <= kContractProductMaxCount; i++) _product('상품$i'),
      ]);
      await _pump(tester, gateway);
      final add = tester.widget<OutlinedButton>(
        find.byKey(const Key('my_product_add')),
      );
      expect(add.onPressed, isNull);
      expect(find.textContaining('최대 20개'), findsOneWidget);
    });

    testWidgets('서버가 거부하면 안내하고 화면 목록은 그대로 둔다', (tester) async {
      final gateway = _FakeGateway([
        _product('PT 10회'),
      ], failSaveWith: StateError('boom'));
      await _pump(tester, gateway);
      await tester.tap(find.byKey(const Key('my_product_delete_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('my_product_delete_confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
      await _flushToast(tester);
      expect(find.text('PT 10회'), findsOneWidget);
    });

    testWidgets('불러오기에 실패하면 다시 불러올 수 있다', (tester) async {
      final gateway = _FakeGateway([_product('PT 10회')], failLoad: true);
      await _pump(tester, gateway);
      expect(find.text('내 수업 상품을 불러오지 못했어요.'), findsOneWidget);

      gateway.failLoad = false;
      await tester.tap(find.byKey(const Key('my_products_retry')));
      await tester.pumpAndSettle();
      expect(find.text('PT 10회'), findsOneWidget);
    });
  });
}
