import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/personal_tier_progress.dart';

void main() {
  test('서버 canonical 진행률을 일정과 선생님 정보 두 미션으로 읽는다', () {
    final progress = PersonalTierProgress.fromProfile({
      'tier': 'Beginner',
      'personalTierProgress': {
        'scheduleCount': 10,
        'scheduleGoal': 10,
        'scheduleMissionCompleted': true,
        'teacherInfoCompleted': false,
        'completedMissionCount': 1,
        'totalMissionCount': 2,
      },
    });

    expect(progress.currentTier, 'Beginner');
    expect(progress.scheduleCount, 10);
    expect(progress.scheduleMissionCompleted, isTrue);
    expect(progress.teacherInfoCompleted, isFalse);
    expect(progress.completedMissionCount, 1);
    expect(progress.totalMissionCount, 2);
  });

  test('서버 진행률이 없으면 회원 수나 provider를 미션으로 사용하지 않는다', () {
    final progress = PersonalTierProgress.fromProfile({
      'tier': 'Beginner',
      'lifetimeQualifiedMemberCount': 30,
      'accountLinked': true,
      'profileCompleted': true,
    });

    expect(progress.scheduleCount, 0);
    expect(progress.completedMissionCount, 0);
    expect(progress.teacherInfoCompleted, isFalse);
  });

  test('Amateur 이상은 raw 1/2여도 Beginner 미션을 달성 완료로 표시한다', () {
    final progress = PersonalTierProgress.fromProfile({
      'tier': 'Amateur',
      'personalTierProgress': {
        'scheduleCount': 10,
        'teacherInfoCompleted': false,
        'completedMissionCount': 1,
        'totalMissionCount': 2,
      },
    });

    expect(progress.beginnerMissionEarned, isTrue);
    expect(progress.displayCompletedMissionCount, 2);
    expect(progress.displayTeacherInfoCompleted, isTrue);
    expect(progress.needsTeacherInfoReview, isTrue);
    expect(progress.teacherInfoCompleted, isFalse);
    expect(
      progress.debugLog(source: 'home'),
      allOf(
        contains('currentTier=Amateur'),
        contains('rawCompleted=1'),
        contains('displayCompleted=2'),
        contains('displayTotal=2'),
        contains('earned=true'),
      ),
    );
  });

  test('Beginner 로그는 raw와 display 완료 수가 같다', () {
    final progress = PersonalTierProgress.fromProfile({
      'tier': 'Beginner',
      'personalTierProgress': {
        'scheduleCount': 6,
        'scheduleMissionCompleted': false,
        'teacherInfoCompleted': true,
        'completedMissionCount': 1,
        'totalMissionCount': 2,
      },
    });

    expect(
      progress.debugLog(source: 'myPage'),
      allOf(
        contains('rawCompleted=1'),
        contains('displayCompleted=1'),
        contains('earned=false'),
      ),
    );
  });
}
