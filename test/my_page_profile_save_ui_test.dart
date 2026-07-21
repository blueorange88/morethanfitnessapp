import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/my_page.dart';
import 'package:mtf_app/utils/personal_tier_parser.dart';
import 'package:mtf_app/widgets/mtf_floating_more_menu.dart';

void main() {
  test('MyPage 헤더 부제목 제거와 고정 저장·dirty back 구조를 유지한다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();
    expect(source, isNot(contains('내 정보와 활동 현황을 관리합니다')));
    expect(source, contains('bottomNavigationBar:'));
    expect(source, contains('resizeToAvoidBottomInset: true'));
    expect(source, contains('PopScope('));
    expect(source, contains('임시로 보관하고 나가기'));
  });

  test('소속별 선택 UI와 활동 지역 3곳 UI를 기존 MyPage 안에서 제공한다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();
    expect(source, contains("label: '직책 (선택)'"));
    expect(source, contains("Text('입력하기 ›'"));
    expect(source, contains("Text('센터 정보 추가 (선택)'"));
    expect(source, contains("Text('최대 3곳'"));
    expect(source, contains("Text('대표 · '"));
    expect(source, contains("title: const Text('대표 지역으로 설정')"));
    expect(source, contains("title: const Text('지역 변경')"));
  });

  test('영문 이름과 지역 배열을 canonical callable payload로 보낸다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();
    expect(source, contains('validator: validateTrainerEnglishName'));
    expect(source, contains('activityRegions: activityRegions'));
    expect(source, contains('nameEn: nameEn'));
  });

  group('직업 AI FC 문구', () {
    test('nickname을 직책이나 호칭으로 사용하지 않는다', () {
      expect(myPageJobPrompt('김트레이너'), '어떤 직업으로 회원님들께 안내할까요?');
      expect(myPageJobPrompt(''), '회원님들께 어떤 직업으로 안내할까요?');
    });
  });

  group('계약서 담당강사명 source', () {
    test('저장된 nickname 선택은 realName 존재와 무관하게 유지한다', () {
      expect(
        myPageContractNameSourceFromProfile(
          const {
            'contractTrainerNameSource': 'displayName',
            'nickname': '남트',
            'realName': '남명구',
          },
        ),
        'displayName',
      );
    });

    test('저장된 realName과 manual 선택도 다른 이름 변경으로 바뀌지 않는다', () {
      expect(
        myPageContractNameSourceFromProfile(
          const {'contractTrainerNameSource': 'realName', 'nickname': '새닉'},
        ),
        'realName',
      );
      expect(
        myPageContractNameSourceFromProfile(
          const {
            'contractTrainerNameSource': 'manual',
            'nickname': '새닉',
            'realName': '새실명',
          },
        ),
        'manual',
      );
    });

    test('source가 없는 과거 문서는 이름 존재 여부로 추론하지 않는다', () {
      expect(
        myPageContractNameSourceFromProfile(
          const {'nickname': '남트', 'realName': '남명구'},
        ),
        'manual',
      );
    });

    test('선택 source의 값만 검증하고 다른 source로 자동 전환하지 않는다', () {
      expect(
        myPageContractNameValidationMessage(
          source: 'displayName',
          nickname: '',
          realName: '남명구',
          customName: '',
        ),
        '계약서에 반영할 닉네임을 입력해주세요.',
      );
      expect(
        myPageContractNameValidationMessage(
          source: 'realName',
          nickname: '남트',
          realName: '',
          customName: '',
        ),
        '계약서에 반영할 실명을 입력해주세요.',
      );
      expect(
        myPageContractNameValidationMessage(
          source: 'manual',
          nickname: '남트',
          realName: '남명구',
          customName: '',
        ),
        '계약서에 반영할 이름을 입력해주세요.',
      );
    });
  });

  group('personal MyPage canonical field read', () {
    const profile = <String, dynamic>{
      'realName': 'canonical real',
      'displayName': 'legacy display',
      'name': 'legacy name',
      'jobTitle': 'canonical job',
      'position': 'stale position',
      'affiliationType': 'freelancer',
      'primaryActivity': 'canonical lesson',
      'lessonSpecialty': 'stale lesson',
    };

    test('realName은 displayName이나 name fallback을 사용하지 않는다', () {
      expect(
        myPageRealNameFromProfile(profile, personalWorkspace: true),
        'canonical real',
      );
      expect(
        myPageRealNameFromProfile(
          const {'displayName': 'legacy display', 'name': 'legacy name'},
          personalWorkspace: true,
        ),
        isEmpty,
      );
    });

    test('jobTitle과 primaryActivity가 오래된 UI 필드보다 우선한다', () {
      expect(
        myPageJobTitleFromProfile(profile, personalWorkspace: true),
        'canonical job',
      );
      expect(
        myPageLessonFieldsFromProfile(profile, personalWorkspace: true),
        'canonical lesson',
      );
      expect(
        myPageJobTitleFromProfile(
          const {'affiliationType': 'freelancer'},
          personalWorkspace: true,
        ),
        isEmpty,
      );
    });
  });

  group('personal tier parser', () {
    test('서버 tier의 대소문자와 표기 변형을 canonical label로 읽는다', () {
      expect(parsePersonalTierLabel('Beginner'), 'Beginner');
      expect(parsePersonalTierLabel('semi_pro'), 'Semi-Pro');
      expect(parsePersonalTierLabel('GRAND PRIX'), 'Grand Prix');
    });

    test('빈 값과 알 수 없는 값은 Beginner로 낮추지 않는다', () {
      expect(parsePersonalTierLabel(null), isNull);
      expect(parsePersonalTierLabel(''), isNull);
      expect(parsePersonalTierLabel('unknown'), isNull);
    });
  });

  group('마이페이지 anchored 더보기 메뉴', () {
    for (final width in <double>[320, 360, 412]) {
      for (final scale in <double>[1, 1.3, 1.8]) {
        testWidgets('${width.toInt()}dp / textScale $scale에서 overflow가 없다',
            (tester) async {
          await _pumpMyPageMoreMenu(
            tester,
            width: width,
            textScale: scale,
          );
          await tester.tap(find.byKey(const Key('test_my_page_more_menu')));
          await tester.pumpAndSettle();

          expect(find.text('인사이트'), findsOneWidget);
          expect(find.text('계약서 관리'), findsOneWidget);
          expect(find.text('설정'), findsOneWidget);
          expect(find.text('비밀번호 변경'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('선택·바깥 탭·뒤로가기로 메뉴를 한 번만 닫는다', (tester) async {
      MyPageMoreMenuAction? selected;
      await _pumpMyPageMoreMenu(tester, onSelected: (value) {
        selected = value;
      });

      await tester.tap(find.byKey(const Key('test_my_page_more_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('인사이트'));
      await tester.pumpAndSettle();
      expect(selected, MyPageMoreMenuAction.stats);
      expect(find.text('계약서 관리'), findsNothing);

      await tester.tap(find.byKey(const Key('test_my_page_more_menu')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(12, 300));
      await tester.pumpAndSettle();
      expect(find.text('계약서 관리'), findsNothing);

      await tester.tap(find.byKey(const Key('test_my_page_more_menu')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('test_my_page_more_menu')), findsOneWidget);
      expect(find.text('계약서 관리'), findsNothing);
    });
  });
}

Future<void> _pumpMyPageMoreMenu(
  WidgetTester tester, {
  double width = 360,
  double textScale = 1,
  ValueChanged<MyPageMoreMenuAction>? onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 700),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: MtfFloatingMoreMenuButton<MyPageMoreMenuAction>(
              key: const Key('test_my_page_more_menu'),
              iconColor: Colors.black,
              items: myPageMoreMenuItems,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
