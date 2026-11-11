import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/my_header_business_card.dart';

// 1×1 투명 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _host({Uint8List? bytes, String? url}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 360,
        child: MyHeaderBusinessCard(
          name: '김트레이너',
          nameEn: 'Kim',
          gymName: '모어짐',
          specialty: 'PT',
          phone: '010-1234-5678',
          address: '서울',
          photoBytes: bytes,
          photoUrl: url,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('폰 글자 크기를 크게 해도 명함 글자가 칸 밖으로 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진을 받지 못하면 실패 표시가 보인다(빈 칸으로 두지 않는다)', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(_host(bytes: Uint8List.fromList([1, 2, 3, 4])));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('business_card_photo_error')), findsOneWidget);
  });

  testWidgets('정상 사진은 실패·로딩 표시 없이 나타난다', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(_host(bytes: _png));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('business_card_photo_error')), findsNothing);
    expect(find.byKey(const Key('business_card_photo_loading')), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  test('저장·업로드·공유 경로는 사진이 사라지거나 비지 않도록 처리한다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();
    // 업로드 실패를 알리고 사진을 버리지 않는다.
    expect(source, contains('businessCardPhotoUploadFailed = true'));
    expect(source, contains('명함 사진을 올리지 못했어요'));
    // 저장 직후 서버 사진이 준비될 때까지 방금 올린 사진으로 계속 보여 준다.
    expect(source, contains('_businessCardPhotoShownBytes'));
    expect(source, contains('_swapBusinessCardPhotoToServer('));
    expect(
      source,
      contains('_businessCardPhotoBytes ?? _businessCardPhotoShownBytes'),
    );
    // 공유 이미지를 만들기 전에 서버 사진을 받아 둔다.
    expect(source, contains('precacheImage('));
    // 사진은 1200px·화질 85로 줄여서 고른다.
    expect(source, contains('maxWidth: 1200'));
    expect(source, isNot(contains('maxWidth: 1600')));
    final edit =
        File('lib/pages/business_card_photo_edit_page.dart').readAsStringSync();
    expect(edit, contains('maxWidth: 1200'));
    expect(edit, isNot(contains('maxWidth: 1600')));
  });
}
