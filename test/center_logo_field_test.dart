import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_settings.dart';
import 'package:mtf_app/services/personal_contract_gateway.dart';
import 'package:mtf_app/widgets/center_logo_field.dart';

class _Gateway extends PersonalContractGateway {
  _Gateway({this.fail = false})
    : super(callable: (name, parameters) async => throw UnimplementedError());

  final bool fail;
  final List<String> saved = [];

  @override
  Future<void> saveCenterLogo(String path) async {
    if (fail) throw StateError('boom');
    saved.add(path);
  }
}

// 1x1 PNG
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _pump(
  WidgetTester tester, {
  required _Gateway gateway,
  String initialPath = '',
  Future<Uint8List?> Function()? pick,
  List<String>? toasts,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CenterLogoField(
            uid: 'trainer-a',
            initialPath: initialPath,
            gateway: gateway,
            pickLogo: pick ?? () async => null,
            prepareLogo: (bytes) async => bytes,
            uploadLogo: (data) async => 'contract_logos/trainer-a/logo_1.png',
            loadPreview: (path) async => null,
            onToast: toasts?.add,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('로고가 없으면 올리기만 보인다', (tester) async {
    await _pump(tester, gateway: _Gateway());
    expect(find.text('올리기'), findsOneWidget);
    expect(find.byKey(const ValueKey('center_logo_remove')), findsNothing);
    expect(find.textContaining('센터 로고'), findsOneWidget);
  });

  testWidgets('이미 올린 로고는 바꾸기와 지우기를 보여 준다', (tester) async {
    await _pump(
      tester,
      gateway: _Gateway(),
      initialPath: 'contract_logos/trainer-a/logo_1.png',
    );
    expect(find.text('바꾸기'), findsOneWidget);
    expect(find.byKey(const ValueKey('center_logo_remove')), findsOneWidget);
  });

  testWidgets('선택을 취소하면 아무것도 저장하지 않는다', (tester) async {
    final gateway = _Gateway();
    await _pump(tester, gateway: gateway);
    await tester.tap(find.byKey(const ValueKey('center_logo_pick')));
    await tester.pumpAndSettle();
    expect(gateway.saved, isEmpty);
  });

  testWidgets('사진을 고르면 올리고 바로 저장하며 지우기를 누르면 빈 값으로 저장한다', (tester) async {
    final gateway = _Gateway();
    final toasts = <String>[];
    await _pump(
      tester,
      gateway: gateway,
      pick: () async => _png,
      toasts: toasts,
    );
    await tester.tap(find.byKey(const ValueKey('center_logo_pick')));
    await tester.pumpAndSettle();
    expect(gateway.saved, ['contract_logos/trainer-a/logo_1.png']);
    expect(toasts, contains('센터 로고를 저장했어요.'));
    expect(find.byKey(const ValueKey('center_logo_preview')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('center_logo_remove')));
    await tester.pumpAndSettle();
    expect(gateway.saved.last, '');
    expect(toasts.last, '센터 로고를 지웠어요.');
    expect(find.byKey(const ValueKey('center_logo_preview')), findsNothing);
  });

  testWidgets('저장이 실패하면 로고를 바꾸지 않고 안내한다', (tester) async {
    final gateway = _Gateway(fail: true);
    final toasts = <String>[];
    await _pump(
      tester,
      gateway: gateway,
      pick: () async => _png,
      toasts: toasts,
    );
    await tester.tap(find.byKey(const ValueKey('center_logo_pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('center_logo_preview')), findsNothing);
    expect(toasts.single, contains('저장하지 못했어요'));
  });

  test('프로필의 센터 로고가 계약 당사자 로고로 쓰인다', () {
    final settings = ContractSettings.fromProfile({
      'contractParty': {
        'kind': 'individual',
        'name': '김트레이너',
        'trainerName': '김트레이너',
        'phone': '010-1234-5678',
        'place': '서울',
        'logoPath': 'contract_logos/trainer-a/logo_old.png',
      },
      'centerLogoPath': 'contract_logos/trainer-a/logo_new.png',
    });
    expect(settings.party?.logoPath, 'contract_logos/trainer-a/logo_new.png');
    // 마이페이지에서 지웠다면 예전 저장값을 쓰지 않는다.
    final cleared = ContractSettings.fromProfile({
      'contractParty': {
        'kind': 'individual',
        'name': '김트레이너',
        'trainerName': '김트레이너',
        'phone': '010-1234-5678',
        'place': '서울',
        'logoPath': 'contract_logos/trainer-a/logo_old.png',
      },
      'centerLogoPath': '',
    });
    expect(cleared.party?.logoPath, '');
    // 센터 로고 값이 없는 예전 프로필은 저장된 값을 그대로 쓴다.
    final legacy = ContractSettings.fromProfile({
      'contractParty': {
        'kind': 'individual',
        'name': '김트레이너',
        'trainerName': '김트레이너',
        'phone': '010-1234-5678',
        'place': '서울',
        'logoPath': 'contract_logos/trainer-a/logo_old.png',
      },
    });
    expect(legacy.party?.logoPath, 'contract_logos/trainer-a/logo_old.png');
  });
}
