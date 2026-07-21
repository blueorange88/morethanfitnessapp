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
