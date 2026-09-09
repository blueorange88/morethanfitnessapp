import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';

AppTierAccessSnapshot access(int rank) => AppTierAccessSnapshot(
      tierRank: rank,
      earnedTierRank: rank,
      supportTierRank: 0,
      organizationTierRank: 0,
      storedTierRank: rank,
      isSponsor: false,
      profileCompleted: false,
      kakaoLinked: false,
      activeMemberCount: 0,
      kakaoCardLinkedMemberCount: 0,
      contractSignedMemberCount: 0,
      branchCount: 0,
    );

void main() {
  test('MORE 스마트 알람은 Semi-Pro 이상만 허용한다', () {
    expect(access(0).canUseSmartAlarm, isFalse);
    expect(access(1).canUseSmartAlarm, isFalse);
    for (var rank = 2; rank <= 5; rank++) {
      expect(access(rank).canUseSmartAlarm, isTrue);
    }
  });

  test('고객카드 신규 등록은 Amateur 이상만 허용한다', () {
    expect(
      AppTierAccessService.canUseFeature(
        access(0),
        AppTierFeatureKey.customerCardCreate,
      ),
      isFalse,
    );
    for (var rank = 1; rank <= 5; rank++) {
      expect(
        AppTierAccessService.canUseFeature(
          access(rank),
          AppTierFeatureKey.customerCardCreate,
        ),
        isTrue,
      );
    }
  });

  test('레슨일지 8개 진입 경로는 Semi-Pro 이상만 허용한다', () {
    const entryPoints = <String>[
      '고객카드',
      '회원목록',
      'Home 빠른작업',
      '일정 확정 회원 서명 요청',
      '빠른서명',
      'QR/deep link',
      'PersonalTrainingLogPage 직접 route',
      '페이지 내부 direct defense',
    ];

    for (final entryPoint in entryPoints) {
      expect(
        AppTierAccessService.canUseFeature(
          access(1),
          AppTierFeatureKey.trainingLog,
        ),
        isFalse,
        reason: '$entryPoint Amateur 차단',
      );
      expect(
        AppTierAccessService.canUseFeature(
          access(2),
          AppTierFeatureKey.trainingLog,
        ),
        isTrue,
        reason: '$entryPoint Semi-Pro 허용',
      );
    }
  });

  test('Personal 레슨 인사이트는 Pro 이상만 허용한다', () {
    for (var rank = 0; rank <= 2; rank++) {
      expect(
        AppTierAccessService.canUseFeature(
          access(rank),
          AppTierFeatureKey.lessonInsights,
        ),
        isFalse,
      );
    }
    for (var rank = 3; rank <= 5; rank++) {
      expect(
        AppTierAccessService.canUseFeature(
          access(rank),
          AppTierFeatureKey.lessonInsights,
        ),
        isTrue,
      );
    }
  });

  test('계약서 신규 작성은 Semi-Pro 이상만 허용한다', () {
    for (var rank = 0; rank <= 1; rank++) {
      expect(
        AppTierAccessService.canUseFeature(
          access(rank),
          AppTierFeatureKey.contract,
        ),
        isFalse,
      );
    }
    for (var rank = 2; rank <= 5; rank++) {
      expect(
        AppTierAccessService.canUseFeature(
          access(rank),
          AppTierFeatureKey.contract,
        ),
        isTrue,
      );
    }
  });
}
