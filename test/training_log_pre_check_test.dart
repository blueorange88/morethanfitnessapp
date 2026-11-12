import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_category_page.dart';
import 'package:mtf_app/widgets/training_log_pre_check.dart';

Widget _host({
  required TrainingLogPreCheckData data,
  required VoidCallback onChanged,
  Future<String?> Function()? onAddIssue,
}) {
  final painC = TextEditingController(text: data.painDetail);
  final noteC = TextEditingController(text: data.note);
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          body: ListView(
            children: [
              TrainingLogPreCheckCard(
                data: data,
                onEdit:
                    () => showTrainingLogPreCheckDialog(
                      context,
                      data: data,
                      painDetailController: painC,
                      noteController: noteC,
                      issueOptions: const ['피로', '결혼준비', 'PMS'],
                      onAddIssue: onAddIssue ?? () async => null,
                      onChanged: () {
                        onChanged();
                        setState(() {});
                      },
                    ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void main() {
  group('시작 전 체크 값', () {
    test('기본값은 이상 없음이다', () {
      final data = TrainingLogPreCheckData();
      expect(data.autoFlags, isEmpty);
      expect(data.attentionCount, 0);
      expect(data.savedIssueChips, isEmpty);
      expect(data.meal, '1~3시간 전');
    });

    test('컨디션·수면·통증·공복에서 자동 확인 항목과 특이사항 칩이 만들어진다', () {
      final data = TrainingLogPreCheckData(
        condition: '나쁨',
        meal: '4시간 이상(공복)',
        sleep: '부족',
        pain: '있음',
        issueChips: {'피로'},
      );
      expect(data.autoFlags, ['컨디션 나쁨', '수면 부족', '통증', '4시간 이상 공복']);
      expect(data.savedIssueChips.toSet(), {'피로', '통증', '수면부족', '공복'});
      // 자동 4 + 직접 고른 칩 1
      expect(data.attentionCount, 5);
    });

    test('이전 버전의 식사 값 공복도 공복으로 취급하고 값은 그대로 둔다', () {
      final legacy = TrainingLogPreCheckData(meal: '공복');
      expect(legacy.isFasting, isTrue);
      expect(legacy.meal, '공복');
      expect(legacy.autoIssueChips, {'공복'});

      expect(TrainingLogPreCheckData(meal: '가볍게 먹음').isFasting, isFalse);
    });

    test('직접 고른 통증 칩과 자동 통증이 겹쳐도 저장 칩은 한 번만 들어간다', () {
      final data = TrainingLogPreCheckData(pain: '있음', issueChips: {'통증'});
      expect(data.savedIssueChips, ['통증']);
    });

    test('메모가 있으면 확인 필요에 포함된다', () {
      expect(TrainingLogPreCheckData(note: '어깨 당김').attentionCount, 1);
      expect(TrainingLogPreCheckData(note: '  ').attentionCount, 0);
    });
  });

  group('요약 카드', () {
    testWidgets('이상 없으면 한 줄 요약과 이상 없음 표시를 보여준다', (tester) async {
      await tester.pumpWidget(
        _host(data: TrainingLogPreCheckData(), onChanged: () {}),
      );
      expect(find.text('이상 없음'), findsOneWidget);
      expect(find.text('컨디션 보통'), findsOneWidget);
      expect(find.text('식사 1~3시간 전'), findsOneWidget);
      expect(find.text('수면 보통'), findsOneWidget);
      expect(find.text('통증 없음'), findsOneWidget);
      expect(find.text('스트레칭 안 함'), findsOneWidget);
      expect(find.text('수정하기'), findsOneWidget);
    });

    testWidgets('이상이 있으면 확인 필요 개수와 특이사항·메모를 보여준다', (tester) async {
      await tester.pumpWidget(
        _host(
          data: TrainingLogPreCheckData(
            pain: '있음',
            painDetail: '오른쪽 어깨',
            note: '어깨 당김',
            issueChips: {'피로'},
          ),
          onChanged: () {},
        ),
      );
      expect(find.text('확인 필요 3'), findsOneWidget);
      expect(find.text('통증 있음 · 오른쪽 어깨'), findsOneWidget);
      expect(find.text('피로'), findsOneWidget);
      expect(find.text('어깨 당김'), findsOneWidget);
    });
  });

  group('빠른 체크 시트', () {
    testWidgets('한 화면에서 모든 질문을 고르고 값이 바뀐다', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = TrainingLogPreCheckData();
      var changed = 0;
      await tester.pumpWidget(_host(data: data, onChanged: () => changed++));

      await tester.tap(find.byKey(const Key('pre_check_edit_button')));
      await tester.pumpAndSettle();

      expect(find.text('컨디션'), findsOneWidget);
      expect(find.text('마지막 식사'), findsOneWidget);
      expect(find.text('수면'), findsOneWidget);
      expect(find.text('통증'), findsOneWidget);
      expect(find.text('사전 스트레칭'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pre_condition_나쁨')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pre_meal_4시간 이상(공복)')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pre_sleep_부족')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pre_stretching_조금 함')));
      await tester.pump();

      expect(data.condition, '나쁨');
      expect(data.meal, '4시간 이상(공복)');
      expect(data.sleep, '부족');
      expect(data.stretching, '조금 함');
      expect(changed, 4);
      expect(find.byKey(const Key('pre_pain_detail')), findsNothing);

      await tester.tap(find.byKey(const Key('pre_pain_있음')));
      await tester.pump();
      expect(find.byKey(const Key('pre_pain_detail')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('pre_pain_detail')),
        '오른쪽 어깨',
      );
      expect(data.painDetail, '오른쪽 어깨');

      await tester.tap(find.byKey(const Key('pre_check_done')));
      await tester.pumpAndSettle();
      expect(find.text('확인 필요 4'), findsOneWidget);
    });

    testWidgets('특이사항은 접혀 있다가 탭하면 펼쳐져 칩·직접 추가·메모를 쓸 수 있다', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = TrainingLogPreCheckData(pain: '있음');
      await tester.pumpWidget(
        _host(data: data, onChanged: () {}, onAddIssue: () async => '어지러움'),
      );
      await tester.tap(find.byKey(const Key('pre_check_edit_button')));
      await tester.pumpAndSettle();

      // 접힘: 칩과 메모칸이 보이지 않는다.
      expect(find.byKey(const Key('pre_issue_피로')), findsNothing);
      expect(find.byKey(const Key('pre_note')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('pre_issue_toggle')));
      await tester.tap(find.byKey(const Key('pre_issue_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('통증 · 자동'), findsOneWidget);
      // 통증·수면부족·공복 칩은 자동 항목이라 직접 고르는 칩에 없다.
      expect(find.byKey(const Key('pre_issue_통증')), findsNothing);

      await tester.tap(find.byKey(const Key('pre_issue_피로')));
      await tester.pump();
      expect(data.issueChips, {'피로'});

      await tester.ensureVisible(find.byKey(const Key('pre_issue_add')));
      await tester.tap(find.byKey(const Key('pre_issue_add')));
      await tester.pumpAndSettle();
      expect(data.issueChips, {'피로', '어지러움'});

      await tester.ensureVisible(find.byKey(const Key('pre_note')));
      await tester.enterText(
        find.byKey(const Key('pre_note')),
        '오늘 어깨가 당긴다고 함',
      );
      expect(data.note, '오늘 어깨가 당긴다고 함');
    });

    testWidgets('이전에 저장한 식사 값이 새 선택지에 없어도 시트에서 그대로 보인다', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = TrainingLogPreCheckData(meal: '가볍게 먹음');
      await tester.pumpWidget(_host(data: data, onChanged: () {}));
      await tester.tap(find.byKey(const Key('pre_check_edit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pre_meal_가볍게 먹음')), findsOneWidget);
      expect(data.meal, '가볍게 먹음');
    });
  });

  group('카테고리 레슨일지 구성', () {
    Future<void> openPage(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalTrainingLogCategoryPage(
            initialName: '테스트 회원',
            autoOpenPreCheck: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('시작 전 체크는 요약 카드이고 수업 중 체크·수업 체크사항은 없다', (tester) async {
      await openPage(tester);

      expect(find.byKey(const Key('pre_check_card')), findsOneWidget);
      expect(find.text('수업 중 체크'), findsNothing);
      expect(find.text('수업 체크사항'), findsNothing);
      expect(find.text('레슨 전 체크'), findsOneWidget);
      expect(find.text('종료 후 체크'), findsOneWidget);
      expect(find.text('내부 메모'), findsOneWidget);
      expect(find.text('회원 공개 메모'), findsOneWidget);
    });

    testWidgets('종료 후 체크에 숙제와 다음 수업 체크포인트가 모여 있다', (tester) async {
      await openPage(tester);

      expect(find.text('오늘 낸 숙제'), findsOneWidget);
      expect(find.text('지난 숙제 수행'), findsOneWidget);
      expect(find.text('다음 수업 체크포인트'), findsOneWidget);
    });

    testWidgets('수정하기를 누르면 빠른 체크 시트가 열린다', (tester) async {
      await openPage(tester);

      await tester.tap(find.byKey(const Key('pre_check_edit_button')));
      await tester.pumpAndSettle();

      expect(find.text('마지막 식사'), findsOneWidget);
      expect(find.byKey(const Key('pre_check_done')), findsOneWidget);
    });
  });
}
