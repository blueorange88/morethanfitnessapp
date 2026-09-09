import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/my_page.dart';
import 'package:mtf_app/services/personal_profile_start_reader.dart';
import 'package:mtf_app/widgets/home/sections/home_header_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('nickname과 onboardingCompleted가 모두 준비된 경우에만 온보딩을 건너뛴다', () {
    expect(
      const PersonalProfileStartResult(
        nickname: '',
        onboardingCompleted: true,
      ).needsNicknameOnboarding,
      isTrue,
    );
    expect(
      const PersonalProfileStartResult(
        nickname: '김트',
        onboardingCompleted: false,
      ).needsNicknameOnboarding,
      isTrue,
    );
    expect(
      const PersonalProfileStartResult(
        nickname: '김트',
        onboardingCompleted: true,
      ).needsNicknameOnboarding,
      isFalse,
    );
  });

  testWidgets('personal nickname 준비 전에는 강사님 placeholder를 표시하지 않는다',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpHeader(
      tester,
      scopeKey: 'personal_empty_uid',
      profileDisplayName: '',
    );

    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.textContaining('강사님'), findsNothing);
  });

  testWidgets('과거 기본 인사는 고정 문구가 아니라 nickname 자동 인사로 처리한다', (tester) async {
    const scope = 'personal_default_uid';
    SharedPreferences.setMockInitialValues({
      homeHeaderGreetingPreferenceKey(scope): '안녕하세요 강사님',
    });
    await _pumpHeader(
      tester,
      scopeKey: scope,
      profileDisplayName: '김트',
    );

    expect(find.text('안녕하세요 강사님'), findsNothing);
    expect(find.textContaining('김트님'), findsOneWidget);
  });

  testWidgets('사용자가 저장한 고정 인사는 같은 UID에서 우선한다', (tester) async {
    const scope = 'personal_custom_uid';
    SharedPreferences.setMockInitialValues({
      homeHeaderGreetingPreferenceKey(scope): '오늘도 차분하게',
    });
    await _pumpHeader(
      tester,
      scopeKey: scope,
      profileDisplayName: '김트',
    );

    expect(find.text('오늘도 차분하게'), findsOneWidget);
  });

  testWidgets('확대 글꼴과 작은 화면에서도 세 통계 블록 외곽은 1대1대1이다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpHeader(
      tester,
      scopeKey: 'personal_geometry_uid',
      profileDisplayName: '김트',
      width: 320,
      textScale: 1.8,
      isExpanded: true,
    );

    final today =
        tester.getSize(find.byKey(const Key('home_header_stat_today')));
    final moreSense =
        tester.getSize(find.byKey(const Key('home_header_stat_more_sense')));
    final week = tester.getSize(find.byKey(const Key('home_header_stat_week')));

    expect(today.width, closeTo(moreSense.width, 0.01));
    expect(moreSense.width, closeTo(week.width, 0.01));
    expect(today.height, closeTo(moreSense.height, 0.01));
    expect(moreSense.height, closeTo(week.height, 0.01));
    expect(find.text('MORE 센스'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('personal MyPage 경로와 로컬 nudge key는 UID마다 분리된다', () {
    expect(myPageProfileDocumentPath(null), 'trainer_profile/me');
    expect(
      myPageProfileDocumentPath('uid-a'),
      'trainer_profiles/uid-a',
    );
    expect(
      myPageProfileDocumentPath('uid-b'),
      'trainer_profiles/uid-b',
    );
    expect(
      myPageNudgePreferenceKey('uid-a', projectId: 'project-prod'),
      isNot(
        myPageNudgePreferenceKey('uid-b', projectId: 'project-prod'),
      ),
    );
    expect(
      myPageNudgePreferenceKey('uid-a', projectId: 'project-prod'),
      isNot(myPageNudgePreferenceKey(null)),
    );
  });

  test('MyPage는 상단 멤버십을 유지하고 명함 등급 보조 칩은 제거한다', () {
    final source = File('lib/pages/my_page.dart').readAsStringSync();
    expect(source, contains('이용 중인 멤버십'));
    expect(source, isNot(contains("'명함 Semi-Pro'")));
    expect(source, isNot(contains('class _MyProChip')));
  });
  testWidgets('profileDisplayName 변경은 내부 캐시 없이 즉시 반영된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpHeader(
      tester,
      scopeKey: 'personal_profile_update_uid',
      profileDisplayName: '라디오',
    );
    expect(find.text('라디오님'), findsOneWidget);

    await _pumpHeader(
      tester,
      scopeKey: 'personal_profile_update_uid',
      profileDisplayName: '새라디오',
    );
    expect(find.text('라디오님'), findsNothing);
    expect(find.text('새라디오님'), findsOneWidget);
  });
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required String scopeKey,
  required String profileDisplayName,
  double width = 390,
  double textScale = 1,
  bool isExpanded = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 760),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: HomeHeaderSection(
                isExpanded: isExpanded,
                todayCount: 2,
                weekCount: 8,
                moreSenseCount: 1,
                aiFcHeaderNotice: '오늘 흐름을 같이 챙겨볼게요.',
                notificationsOn: false,
                primaryColor: const Color(0xFF4F46E5),
                secondaryColor: const Color(0xFF9333EA),
                onToggleExpanded: () {},
                onQuickMemberTap: () {},
                onNotificationTap: () {},
                onTodayTap: () {},
                onMoreSenseTap: () {},
                onWeekTap: () {},
                loadProfileFromFirestore: false,
                profileDisplayName: profileDisplayName,
                greetingScopeKey: scopeKey,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
