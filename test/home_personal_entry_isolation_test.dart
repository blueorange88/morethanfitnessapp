import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/home_page.dart';
import 'package:mtf_app/pages/my_page.dart';
import 'package:mtf_app/pages/personal_my_page.dart';
import 'package:mtf_app/services/home_member_lookup_service.dart';
import 'package:mtf_app/services/managed_member_workspace_service.dart';
import 'package:mtf_app/services/personal_my_page_nudge_service.dart';
import 'package:mtf_app/services/personal_profile_start_reader.dart';
import 'package:mtf_app/widgets/home/sections/home_header_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('personal nickname onboarding', () {
    test('AccountGate 초기 프로필은 과거 캐시보다 우선하고 서버 갱신은 반영한다', () {
      var displayedNickname = '라디오';

      if (shouldApplyPersonalProfileSnapshot(
        hasInitialProfile: true,
        fromCache: true,
      )) {
        displayedNickname = '김트';
      }
      expect(displayedNickname, '라디오');

      if (shouldApplyPersonalProfileSnapshot(
        hasInitialProfile: true,
        fromCache: false,
      )) {
        displayedNickname = '새라디오';
      }
      expect(displayedNickname, '새라디오');
    });

    test('오프라인 캐시만 도착하면 AccountGate 초기 nickname을 유지한다', () {
      var displayedNickname = '라디오';

      if (shouldApplyPersonalProfileSnapshot(
        hasInitialProfile: true,
        fromCache: true,
      )) {
        displayedNickname = '김트';
      }

      expect(displayedNickname, '라디오');
    });

    test('nickname이 없으면 다른 이름 필드와 무관하게 온보딩이 필요하다', () {
      const result = PersonalProfileStartResult(
        nickname: '',
        onboardingCompleted: true,
      );

      expect(result.needsNicknameOnboarding, isTrue);
    });

    test('nickname과 완료 상태가 모두 준비되어야 홈으로 갈 수 있다', () {
      expect(
        const PersonalProfileStartResult(
          nickname: '김트레이너',
          onboardingCompleted: false,
        ).needsNicknameOnboarding,
        isTrue,
      );
      expect(
        const PersonalProfileStartResult(
          nickname: '김트레이너',
          onboardingCompleted: true,
        ).needsNicknameOnboarding,
        isFalse,
      );
    });
  });

  group('home greeting', () {
    test('시간대 인사는 문장부호까지 포함한 최종 문자열이다', () {
      expect(homeGreetingTextForHour(10), '숨을 고르고 시작해볼까요?');
      expect(homeGreetingTextForHour(12), '점심은 드셨어요?');
      expect(homeGreetingTextForHour(15), '내일은 더 힘이 날꺼에요!');
      expect(homeGreetingTextForHour(18), '오늘 하루도 저물어가네요');
    });

    test('nickname은 둘째 줄용 님 라벨을 한 번만 만든다', () {
      expect(homeHeaderNicknameLabel('김트레이너'), '김트레이너님');
      expect(homeHeaderNicknameLabel('김트레이너님'), '김트레이너님');
      expect(homeHeaderNicknameLabel(''), isEmpty);
    });

    test('자동 인사에서는 nickname을 첫 줄에서 분리한다', () {
      expect(
        homeHeaderFirstLine('오늘도 잘 시작해볼까요, 김트레이너님', '김트레이너'),
        '오늘도 잘 시작해볼까요,',
      );
      expect(
        homeHeaderGreetingIncludesNickname(
          '김트레이너님, 오늘도 힘내요',
          '김트레이너',
        ),
        isTrue,
      );
    });

    testWidgets('고정 문구는 첫 줄, nickname은 17px 둘째 줄로 표시한다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: HomeHeaderSection(
                isExpanded: false,
                todayCount: 0,
                weekCount: 0,
                moreSenseCount: 0,
                aiFcHeaderNotice: '',
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
                profileDisplayName: '김트레이너',
                headerGreetingText: '오늘도 잘 시작해볼까요,',
                greetingScopeKey: 'test-two-lines',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final first = tester.widget<Text>(
        find.byKey(const Key('home_header_greeting_line')),
      );
      final second = tester.widget<Text>(
        find.byKey(const Key('home_header_nickname_line')),
      );
      expect(first.data, '오늘도 잘 시작해볼까요,');
      expect(first.style?.fontSize, 12);
      expect(first.style?.fontWeight, FontWeight.w600);
      expect(second.data, '김트레이너님');
      expect(second.style?.fontSize, 17);
      expect(second.style?.fontWeight, FontWeight.w700);
      expect(tester.takeException(), isNull);
    });
  });

  group('MyPage name save boundary', () {
    test('nickname만 있으면 확인 없이 저장할 수 있다', () {
      expect(
        resolveMyPageNameSaveAction(nickname: '모어댄', realName: ''),
        MyPageNameSaveAction.save,
      );
    });

    test('nickname과 실명이 모두 비어 있으면 저장을 막는다', () {
      expect(
        resolveMyPageNameSaveAction(nickname: '  ', realName: '  '),
        MyPageNameSaveAction.requireName,
      );
    });

    test('실명만 있으면 nickname 복사 확인이 필요하다', () {
      expect(
        resolveMyPageNameSaveAction(nickname: '', realName: '김트레이너'),
        MyPageNameSaveAction.confirmRealName,
      );
      expect(canUseRealNameAsNickname('김트레이너'), isTrue);
      expect(canUseRealNameAsNickname('아주긴트레이너이름'), isFalse);
    });

    test('초기 onboarding과 MyPage 저장은 각각 서버 callable만 사용한다', () {
      final myPageSource = File('lib/pages/my_page.dart').readAsStringSync();
      final gatewaySource = File(
        'lib/services/personal_profile_start_reader.dart',
      ).readAsStringSync();

      expect(
        myPageSource,
        contains('.updateTrainerProfile('),
      );
      expect(myPageSource, contains('nickname: displayName'));
      expect(myPageSource, contains('realName: name'));
      expect(
        myPageSource,
        isNot(contains('FirebasePersonalNicknameOnboardingGateway()')),
      );
      expect(gatewaySource, contains("'completeNicknameOnboarding'"));
      expect(gatewaySource, contains('[MTF_NICKNAME_WRITE]'));
      expect(
        myPageSource,
        isNot(contains(".update({'nickname':")),
      );
    });
  });

  group('recent member ownership', () {
    const mine = <String, dynamic>{
      'trainerId': 'uid-a',
      'workspaceType': 'personal',
    };

    test('personal은 현재 UID와 personal workspace가 모두 일치해야 한다', () {
      expect(
          HomeMemberLookupService.matchesPersonalOwner(mine, 'uid-a'), isTrue);
      expect(
          HomeMemberLookupService.matchesPersonalOwner(mine, 'uid-b'), isFalse);
      expect(
        HomeMemberLookupService.matchesPersonalOwner(
          const {'trainerId': 'uid-a', 'workspaceType': 'legacy'},
          'uid-a',
        ),
        isFalse,
      );
    });

    test('두 최근 회원 UI는 static 전역 members stream을 사용하지 않는다', () {
      final homeSource = File(
        'lib/widgets/home/sections/home_recent_clients_section.dart',
      ).readAsStringSync();
      final editorSource = File(
        'lib/widgets/home/lesson_editor/home_recent_members_section.dart',
      ).readAsStringSync();

      expect(homeSource, contains("where('trainerId', isEqualTo: owner)"));
      expect(homeSource,
          contains("where('workspaceType', isEqualTo: 'personal')"));
      expect(editorSource, contains("where('trainerId', isEqualTo: owner)"));
      expect(editorSource, isNot(contains('static final Stream')));
    });
  });

  test('personal MyPage는 displayName이 아니라 canonical nickname을 표시한다', () {
    expect(
      myPageNicknameFromProfile(
        const {'displayName': '', 'nickname': '김트레이너'},
        personalWorkspace: true,
      ),
      '김트레이너',
    );
    expect(
      myPageNicknameFromProfile(
        const {'displayName': '다른 이름', 'nickname': '김트레이너'},
        personalWorkspace: true,
      ),
      '김트레이너',
    );
  });

  test('온보딩 nickname이 있으면 MyPage는 다음 미완성 항목부터 안내한다', () {
    final missing = personalMissingProfileFields(
      const ManagedMemberUsage(
        count: 0,
        limit: 10,
        nickname: '김트레이너',
        displayName: '',
      ),
    );

    expect(missing, isNot(contains(PersonalProfileNudgeKey.displayName)));
    expect(missing.first, PersonalProfileNudgeKey.phone);
  });

  group('personal schedule defaults', () {
    test('personal 시간표 설정 key는 UID마다 분리된다', () {
      expect(
        homeSchedulePreferenceKey(
          'home_start_hour',
          'uid-a',
          projectId: 'project-prod',
        ),
        'mtf_project-prod_uid-a_home_start_hour',
      );
      expect(
        homeSchedulePreferenceKey(
          'home_start_hour',
          'uid-a',
          projectId: 'project-prod',
        ),
        isNot(
          homeSchedulePreferenceKey(
            'home_start_hour',
            'uid-b',
            projectId: 'project-prod',
          ),
        ),
      );
      expect(
        homeSchedulePreferenceKey(
          'home_start_hour',
          'uid-a',
          projectId: 'project-dev',
        ),
        isNot(
          homeSchedulePreferenceKey(
            'home_start_hour',
            'uid-a',
            projectId: 'project-prod',
          ),
        ),
      );
      expect(
        homeSchedulePreferenceKey('home_start_hour', null),
        'home_start_hour',
      );
    });

    test('신규 기본 범위는 06:00부터 23:00까지다', () {
      final source = File('lib/pages/home_page.dart').readAsStringSync();
      expect(source, contains('int startHour = 6;'));
      expect(source, contains('int endHour = 23;'));
      expect(source, contains('endHour - startHour'));
    });
  });
}
