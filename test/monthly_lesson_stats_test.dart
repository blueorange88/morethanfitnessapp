import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/monthly_lesson_record.dart';
import 'package:mtf_app/pages/stats_page.dart';
import 'package:mtf_app/pages/monthly_lesson_history_page.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';
import 'package:mtf_app/services/monthly_lesson_stats_repository.dart';
import 'package:mtf_app/widgets/monthly_lesson_calendar.dart';

MonthlyLessonRecord record({
  required String id,
  required String status,
  DateTime? startAt,
  String trainerId = 'uid-a',
  String workspaceType = 'personal',
  String memberId = 'member-a',
  String memberName = '김회원',
}) {
  final start = startAt ?? DateTime(2026, 7, 20, 8);
  return MonthlyLessonRecord(
    lessonLogId: id,
    trainerId: trainerId,
    workspaceType: workspaceType,
    memberId: memberId,
    memberNameSnapshot: memberName,
    startAt: start,
    endAt: start.add(const Duration(minutes: 50)),
    lessonType: 'PT',
    status: status,
    sessionTotalSnapshot: 30,
    lessonNumberSnapshot: 4,
  );
}

class FakeMonthlyDataSource implements MonthlyLessonStatsDataSource {
  FakeMonthlyDataSource(this.records, {this.currentUid = 'uid-a'});

  final List<MonthlyLessonRecord> records;

  @override
  final String? currentUid;

  DateTime? requestedStart;
  DateTime? requestedEnd;
  String? requestedUid;

  @override
  Future<List<MonthlyLessonRecord>> loadMonth({
    required String uid,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    requestedUid = uid;
    requestedStart = start;
    requestedEnd = endExclusive;
    return records;
  }
}

void main() {
  test('Personal 레슨 인사이트는 Pro·Master·Grand Prix만 허용한다', () {
    const tiers = <String, bool>{
      'Beginner': false,
      'Amateur': false,
      'Semi-Pro': false,
      'Pro': true,
      'Master': true,
      'Grand Prix': true,
    };
    for (final entry in tiers.entries) {
      final access = AppTierAccessService.personalSnapshotFromProfile({
        'tier': entry.key,
      });
      expect(
        AppTierAccessService.canUseFeature(
          access,
          AppTierFeatureKey.lessonInsights,
        ),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      AppTierAccessService.featureInfo(AppTierFeatureKey.lessonInsights)
          .requiredRank,
      3,
    );
  });

  test('Personal 레슨 인사이트 전체는 Pro 미만에서 직접 route도 차단한다', () {
    expect(
      blocksEntireStatsPage(
        isPersonalWorkspace: true,
        canUseAdvancedInsights: false,
      ),
      isTrue,
    );
    expect(
      blocksEntireStatsPage(
        isPersonalWorkspace: true,
        canUseAdvancedInsights: true,
      ),
      isFalse,
    );
    expect(
      blocksEntireStatsPage(
        isPersonalWorkspace: false,
        canUseAdvancedInsights: false,
      ),
      isTrue,
    );
  });

  test('월간 query는 StatsPage가 아니라 별도 월간 기록 화면에서만 시작한다', () {
    final statsPage = File('lib/pages/stats_page.dart').readAsStringSync();
    final monthlyPage = File(
      'lib/pages/monthly_lesson_history_page.dart',
    ).readAsStringSync();

    expect(statsPage, isNot(contains('PersonalMonthlyLessonStatsRepository(')));
    expect(statsPage, contains("label: '월간 레슨 기록'"));
    expect(monthlyPage, contains('PersonalMonthlyLessonStatsRepository'));
    expect(monthlyPage, contains('_loadMonth();'));
  });

  test('Home 하단·Drawer와 MyPage는 같은 canonical 레슨 인사이트 gate를 사용한다', () {
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    final myPage = File('lib/pages/my_page.dart').readAsStringSync();
    final drawer =
        File('lib/widgets/mtf_animated_drawer.dart').readAsStringSync();
    final bottomNav = File(
      'lib/widgets/home/sections/home_bottom_nav_bar.dart',
    ).readAsStringSync();

    expect(home, contains('AppTierFeatureKey.lessonInsights'));
    expect(myPage, contains('AppTierFeatureKey.lessonInsights'));
    expect(drawer, contains("label: '인사이트'"));
    expect(bottomNav, contains("label: '인사이트'"));
  });

  testWidgets('월간 기록 직접 route도 Pro 미만에서는 query를 시작하지 않는다', (tester) async {
    final dataSource = FakeMonthlyDataSource([]);
    final repository = PersonalMonthlyLessonStatsRepository(
      uid: 'uid-a',
      dataSource: dataSource,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyLessonHistoryPage(
          personalOwnerUid: 'uid-a',
          repository: repository,
          accessLoader: () async =>
              AppTierAccessService.personalSnapshotFromProfile({
            'tier': 'Beginner',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.requestedUid, isNull);
    expect(find.text('인사이트는 Pro부터 사용할 수 있어요.'), findsOneWidget);
  });

  testWidgets('월간 기록은 Pro access 확인 뒤에만 query를 시작한다', (tester) async {
    final dataSource = FakeMonthlyDataSource([]);
    final repository = PersonalMonthlyLessonStatsRepository(
      uid: 'uid-a',
      dataSource: dataSource,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyLessonHistoryPage(
          personalOwnerUid: 'uid-a',
          repository: repository,
          accessLoader: () async =>
              AppTierAccessService.personalSnapshotFromProfile({
            'tier': 'Pro',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataSource.requestedUid, 'uid-a');
    expect(find.text('월간 레슨 기록'), findsOneWidget);
  });

  test('Home과 서명 확정 경로는 동일 snapshot 필드를 기록한다', () {
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    final direct = File(
      'lib/services/lesson_confirmation_service.dart',
    ).readAsStringSync();
    final quickSign = File(
      'lib/pages/personal_training_log_quick_sign_page.dart',
    ).readAsStringSync();

    expect(home, contains('PersonalTrainingLogRepository.firebase'));
    for (final source in [direct, quickSign]) {
      expect(source, contains("'memberNameSnapshot'"));
      expect(source, contains("'sessionSnapshotLessonNumber'"));
    }
  });

  test('확정 상태를 상태별로 집계하고 취소 기록을 총계에서 제외한다', () {
    final records = <MonthlyLessonRecord>[
      for (var index = 0; index < 3; index++)
        record(id: 'completed-$index', status: 'completed'),
      for (var index = 0; index < 2; index++)
        record(id: 'service-$index', status: 'service'),
      record(id: 'deducted', status: 'no_show_deducted'),
      record(id: 'not-deducted', status: 'no_show_not_deducted'),
      record(id: 'cancelled', status: 'confirm_cancelled'),
    ];
    final summary = MonthlyLessonSummary(records: records);

    expect(summary.totalConfirmed, 7);
    expect(summary.completed, 3);
    expect(summary.service, 2);
    expect(summary.noShowDeducted, 1);
    expect(summary.noShowNotDeducted, 1);
    expect(summary.recordsForDay(DateTime(2026, 7, 20)), hasLength(8));
  });

  test('실제 회원 수는 memberId 중복을 제거하고 수기 빈 ID는 제외한다', () {
    final summary = MonthlyLessonSummary(
      records: [
        record(id: 'a1', status: 'completed', memberId: 'member-a'),
        record(id: 'a2', status: 'service', memberId: 'member-a'),
        record(id: 'b', status: 'completed', memberId: 'member-b'),
        record(id: 'manual', status: 'completed', memberId: ''),
      ],
    );
    expect(summary.totalConfirmed, 4);
    expect(summary.actualMemberCount, 2);
  });

  test('선택 월 경계와 owner workspace 격리를 강제한다', () async {
    final dataSource = FakeMonthlyDataSource([
      record(
        id: 'first',
        status: 'completed',
        startAt: DateTime(2026, 7, 1),
      ),
      record(
        id: 'last',
        status: 'completed',
        startAt: DateTime(2026, 7, 31, 23, 59, 59),
      ),
      record(
        id: 'next',
        status: 'completed',
        startAt: DateTime(2026, 8, 1),
      ),
      record(
        id: 'other',
        status: 'completed',
        trainerId: 'uid-b',
      ),
      record(
        id: 'legacy',
        status: 'completed',
        workspaceType: 'legacy',
      ),
    ]);
    final summary = await PersonalMonthlyLessonStatsRepository(
      uid: 'uid-a',
      dataSource: dataSource,
    ).loadMonth(DateTime(2026, 7));

    expect(summary.records.map((item) => item.lessonLogId), ['first', 'last']);
    expect(dataSource.requestedUid, 'uid-a');
    expect(dataSource.requestedStart, DateTime(2026, 7, 1));
    expect(dataSource.requestedEnd, DateTime(2026, 8, 1));
  });

  test('12월과 윤년 2월의 다음 달 경계를 계산한다', () {
    expect(monthlyLessonNextMonthStart(DateTime(2026, 12)), DateTime(2027, 1));
    expect(monthlyLessonNextMonthStart(DateTime(2028, 2)), DateTime(2028, 3));
  });

  test('현재 Auth UID가 owner와 다르면 조회하지 않는다', () {
    final repository = PersonalMonthlyLessonStatsRepository(
      uid: 'uid-a',
      dataSource: FakeMonthlyDataSource(const [], currentUid: 'uid-b'),
    );
    expect(
      () => repository.loadMonth(DateTime(2026, 7)),
      throwsStateError,
    );
  });

  testWidgets('달력에서 날짜별 횟수와 상세 snapshot을 표시한다', (tester) async {
    final summary = MonthlyLessonSummary(
      records: [record(id: 'a', status: 'completed')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyLessonCalendar(
              month: DateTime(2026, 7),
              state: MonthlyLessonViewState.success,
              summary: summary,
              selectedDay: DateTime(2026, 7, 20),
              onPreviousMonth: () {},
              onNextMonth: () {},
              onCurrentMonth: () {},
              onDaySelected: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('총 확정 1'), findsOneWidget);
    expect(find.text('1회'), findsOneWidget);
    expect(find.textContaining('08:00 김회원 · PT'), findsOneWidget);
    expect(find.text('소진 · 4/30회차'), findsOneWidget);
  });

  testWidgets('이전 달·다음 달·이번 달 callback을 구분한다', (tester) async {
    var previous = 0;
    var next = 0;
    var current = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyLessonCalendar(
            month: DateTime(2026, 7),
            state: MonthlyLessonViewState.empty,
            summary: MonthlyLessonSummary(records: const []),
            selectedDay: null,
            onPreviousMonth: () => previous++,
            onNextMonth: () => next++,
            onCurrentMonth: () => current++,
            onDaySelected: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('monthly_lesson_previous')));
    await tester.tap(find.byKey(const Key('monthly_lesson_next')));
    await tester.tap(find.byKey(const Key('monthly_lesson_current')));
    expect((previous, next, current), (1, 1, 1));
  });

  testWidgets('빈 달과 네트워크 오류를 구분한다', (tester) async {
    Widget app(MonthlyLessonViewState state) => MaterialApp(
          home: Scaffold(
            body: MonthlyLessonCalendar(
              month: DateTime(2026, 7),
              state: state,
              summary: MonthlyLessonSummary(records: const []),
              selectedDay: null,
              onPreviousMonth: () {},
              onNextMonth: () {},
              onCurrentMonth: () {},
              onDaySelected: (_) {},
              onRetry: () {},
            ),
          ),
        );
    await tester.pumpWidget(app(MonthlyLessonViewState.empty));
    expect(find.text('이 달에 확정된 레슨 기록이 없어요.'), findsOneWidget);
    await tester.pumpWidget(app(MonthlyLessonViewState.networkError));
    expect(find.text('월간 레슨 기록을 불러오지 못했어요.'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 1.8]) {
      testWidgets('$width dp / $scale 배율에서 overflow가 없다', (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonthlyLessonCalendar(
                  month: DateTime(2026, 7),
                  state: MonthlyLessonViewState.success,
                  summary: MonthlyLessonSummary(
                    records: [record(id: 'a', status: 'completed')],
                  ),
                  selectedDay: DateTime(2026, 7, 20),
                  onPreviousMonth: () {},
                  onNextMonth: () {},
                  onCurrentMonth: () {},
                  onDaySelected: (_) {},
                  onRetry: () {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
