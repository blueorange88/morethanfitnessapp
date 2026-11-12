import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_same_name_schedule_link_sheet.dart';

void main() {
  Map<String, dynamic> schedule({
    required String id,
    required String name,
    required DateTime startAt,
    String memberId = '',
  }) {
    return <String, dynamic>{
      'docId': id,
      'name': name,
      'startAt': startAt,
      if (memberId.isNotEmpty) 'memberId': memberId,
    };
  }

  test('현재 주의 같은 이름 미연결 일정만 시간순으로 추천한다', () {
    final candidates = homeSameNameUnlinkedScheduleCandidates(
      schedules: <Map<String, dynamic>>[
        schedule(id: 'current', name: '홍길동', startAt: DateTime(2026, 8, 28, 7)),
        schedule(
          id: 'wednesday',
          name: ' 홍길동 ',
          startAt: DateTime(2026, 8, 26, 7),
        ),
        schedule(id: 'monday', name: '홍길동', startAt: DateTime(2026, 8, 24, 18)),
        schedule(
          id: 'already-linked',
          name: '홍길동',
          startAt: DateTime(2026, 8, 25, 7),
          memberId: 'member-a',
        ),
        schedule(
          id: 'other-name',
          name: '홍길순',
          startAt: DateTime(2026, 8, 27, 7),
        ),
        schedule(
          id: 'next-week',
          name: '홍길동',
          startAt: DateTime(2026, 8, 31, 7),
        ),
      ],
      currentScheduleDocId: 'current',
      memberName: '홍길동',
    );

    expect(candidates.map((candidate) => candidate.scheduleDocId), <String>[
      'monday',
      'wednesday',
    ]);
    expect(candidates.first.label, '월요일 오후 6시 홍길동 님');
    expect(candidates.last.label, '수요일 오전 7시 홍길동 님');
  });

  test('이름 비교는 trim·연속 공백 축약·대소문자 무시 정책을 따른다', () {
    expect(normalizeHomeScheduleLinkName(' TEST회원 '), 'test회원');
    expect(normalizeHomeScheduleLinkName('TEST   회원'), 'test 회원');
    expect(normalizeHomeScheduleLinkName('test\t회원'), 'test 회원');
    expect(
      normalizeHomeScheduleLinkName('TEST회원'),
      isNot(normalizeHomeScheduleLinkName('TEST 회원')),
    );
  });

  testWidgets('다른 같은 이름 일정은 기본 체크되고 선택 해제 후 확정한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Set<String>? result;
    final candidates = <HomeSameNameScheduleLinkCandidate>[
      HomeSameNameScheduleLinkCandidate(
        scheduleDocId: 'monday',
        memberName: '홍길동',
        startAt: DateTime(2026, 8, 24, 18),
      ),
      HomeSameNameScheduleLinkCandidate(
        scheduleDocId: 'wednesday',
        memberName: '홍길동',
        startAt: DateTime(2026, 8, 26, 7),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await HomeSameNameScheduleLinkSheet.show(
                      context: context,
                      memberName: '홍길동',
                      candidates: candidates,
                    );
                  },
                  child: const Text('열기'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('같은 이름의 일정도 연결할까요?'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    for (final checkbox in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    )) {
      expect(checkbox.value, isTrue);
    }
    expect(find.text('3개 일정 연결'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('same_name_schedule_wednesday')),
    );
    await tester.pump();
    expect(find.text('2개 일정 연결'), findsOneWidget);

    await tester.tap(find.byKey(const Key('same_name_schedule_link_confirm')));
    await tester.pumpAndSettle();

    expect(result, <String>{'monday'});
  });

  for (final themeEntry
      in <String, ThemeData>{
        'light': lightTheme(),
        'dark': darkTheme(),
        'lululala': lululalaTheme(),
      }.entries) {
    for (final width in <double>[320, 360, 384, 411]) {
      testWidgets(
        '${themeEntry.key} ${width.toInt()}dp에서 기본 체크·목록·CTA가 overflow 없이 보인다',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 720));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            MaterialApp(
              theme: themeEntry.value,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(viewPadding: const EdgeInsets.only(bottom: 24)),
                  child: child!,
                );
              },
              home: Builder(
                builder:
                    (context) => Scaffold(
                      body: Center(
                        child: FilledButton(
                          onPressed:
                              () => HomeSameNameScheduleLinkSheet.show(
                                context: context,
                                memberName: '화면 검증 회원',
                                candidates: <HomeSameNameScheduleLinkCandidate>[
                                  HomeSameNameScheduleLinkCandidate(
                                    scheduleDocId: 'tuesday',
                                    memberName: '화면 검증 회원',
                                    startAt: DateTime(2026, 8, 25, 6, 20),
                                  ),
                                  HomeSameNameScheduleLinkCandidate(
                                    scheduleDocId: 'wednesday',
                                    memberName: '화면 검증 회원',
                                    startAt: DateTime(2026, 8, 26, 18, 30),
                                  ),
                                  HomeSameNameScheduleLinkCandidate(
                                    scheduleDocId: 'friday',
                                    memberName: '화면 검증 회원',
                                    startAt: DateTime(2026, 8, 28, 7, 40),
                                  ),
                                ],
                              ),
                          child: const Text('열기'),
                        ),
                      ),
                    ),
              ),
            ),
          );

          await tester.tap(find.text('열기'));
          await tester.pumpAndSettle();

          expect(find.text('같은 이름의 일정도 연결할까요?'), findsOneWidget);
          expect(find.byType(CheckboxListTile), findsNWidgets(3));
          expect(find.text('4개 일정 연결'), findsOneWidget);
          for (final checkbox in tester.widgetList<CheckboxListTile>(
            find.byType(CheckboxListTile),
          )) {
            expect(checkbox.value, isTrue);
          }
          expect(
            tester
                .getBottomRight(
                  find.byKey(const Key('same_name_schedule_link_confirm')),
                )
                .dy,
            lessThanOrEqualTo(720 - 24),
          );
          final actions = tester.widget<Padding>(
            find.byKey(const Key('same_name_schedule_link_actions')),
          );
          expect(actions.padding, const EdgeInsets.only(bottom: 24));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final candidateCount in <int>[1, 10]) {
    testWidgets('$candidateCount개 후보에서 CTA는 고정되고 목록만 스크롤된다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewPadding: const EdgeInsets.only(bottom: 32)),
              child: child!,
            );
          },
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => HomeSameNameScheduleLinkSheet.show(
                            context: context,
                            memberName: '화면 검증 회원',
                            candidates: List<
                              HomeSameNameScheduleLinkCandidate
                            >.generate(
                              candidateCount,
                              (index) => HomeSameNameScheduleLinkCandidate(
                                scheduleDocId: 'candidate-$index',
                                memberName: '화면 검증 회원',
                                startAt: DateTime(2026, 8, 24 + index, 7),
                              ),
                            ),
                          ),
                      child: const Text('열기'),
                    ),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.childrenDelegate.estimatedChildCount,
        candidateCount * 2 - 1,
      );
      expect(find.byType(CheckboxListTile), findsAtLeast(1));
      expect(
        tester
            .getBottomRight(
              find.byKey(const Key('same_name_schedule_link_confirm')),
            )
            .dy,
        lessThanOrEqualTo(640 - 32),
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('Home 연결은 owner 검증 transaction과 일괄 doc 집합을 사용한다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();

    expect(source, contains('Future<int> _applyMemberLinkToSchedules'));
    expect(source, contains('await firestore.runTransaction'));
    expect(source, contains("memberData?['trainerId'] == _personalOwnerUid"));
    expect(source, contains("schedule?['trainerId'] == _personalOwnerUid"));
    expect(source, contains('HomeSameNameScheduleLinkSheet.show'));
    expect(source, contains('<String>{cleanDocId, ...additionalScheduleIds}'));
  });
}
