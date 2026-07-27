import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/personal_tier_parser.dart';
import 'dev_tier_fixture.dart';

enum AppTierFeatureKey {
  customerCardCreate,
  trainingLog,
  lessonInsights,
  dday,
  moreDay,
  moreFocus,
  contract,
  contractHistory,
  badge,
  smartAlarm,
  anatomy,
  consult,

  dormantMember,
  membershipPauseResume,
  membershipContract,
}

class AppTierFeatureInfo {
  const AppTierFeatureInfo({
    required this.feature,
    required this.requiredRank,
    required this.title,
    required this.description,
    required this.shortBenefit,
    required this.highlightTier,
  });

  final AppTierFeatureKey feature;
  final int requiredRank;
  final String title;
  final String description;
  final String shortBenefit;

  /// HomeSupportTierGuideSheet highlightTier와 맞추기 위한 값.
  /// amateur / semiPro / pro
  final String highlightTier;

  String get requiredTierLabel {
    return AppTierAccessService.tierLabelFromRank(requiredRank);
  }
}

class AppTierAccessSnapshot {
  const AppTierAccessSnapshot({
    required this.tierRank,
    required this.earnedTierRank,
    required this.supportTierRank,
    required this.organizationTierRank,
    required this.storedTierRank,
    required this.isSponsor,
    required this.profileCompleted,
    required this.kakaoLinked,
    required this.activeMemberCount,
    required this.kakaoCardLinkedMemberCount,
    required this.contractSignedMemberCount,
    required this.branchCount,
  });

  /// 실제 기능 권한에 쓰는 최종 등급
  final int tierRank;

  /// 앱 사용/운영 데이터로 얻은 등급
  final int earnedTierRank;

  /// 후원/구독/수동 해금으로 얻은 등급
  final int supportTierRank;

  /// Master / Grand Prix 같은 조직 등급
  final int organizationTierRank;

  /// 기존 저장 필드에 남아 있는 등급값
  final int storedTierRank;

  final bool isSponsor;
  final bool profileCompleted;
  final bool kakaoLinked;

  final int activeMemberCount;
  final int kakaoCardLinkedMemberCount;
  final int contractSignedMemberCount;
  final int branchCount;

  AppTierAccessSnapshot withEffectiveTierRank(int effectiveTierRank) {
    if (effectiveTierRank == tierRank) return this;
    return AppTierAccessSnapshot(
      tierRank: effectiveTierRank,
      earnedTierRank: earnedTierRank,
      supportTierRank: supportTierRank,
      organizationTierRank: organizationTierRank,
      storedTierRank: storedTierRank,
      isSponsor: isSponsor,
      profileCompleted: profileCompleted,
      kakaoLinked: kakaoLinked,
      activeMemberCount: activeMemberCount,
      kakaoCardLinkedMemberCount: kakaoCardLinkedMemberCount,
      contractSignedMemberCount: contractSignedMemberCount,
      branchCount: branchCount,
    );
  }

  bool get canUseSmartAlarm {
    // Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseDday {
    // 목표 D-DAY는 Amateur 이상
    return tierRank >= 1;
  }

  bool get canUseMoreDay {
    // MORE 데이는 Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseMoreFocus {
    // MORE 포커스는 Pro 이상
    return tierRank >= 3;
  }

  bool get canUseBadge {
    // 메달 관리는 Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseContractHistory {
    // 계약 이력은 레슨계약서와 같은 Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseAnatomy {
    // 아나토미 레슨일지 기록은 Pro 이상
    return tierRank >= 3;
  }

  bool get canUseDormantMember {
    // 휴면회원 전환/해제는 Amateur 이상
    return tierRank >= 1;
  }

  bool get canUseMembershipPauseResume {
    // 회원권 정지/재개는 Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseMembershipContract {
    // 회원권계약서는 Pro 이상
    return tierRank >= 3;
  }

  bool get canUseSemiProSmartAlarm {
    // Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseContract {
    // 계약서 작성은 Semi-Pro 이상
    return tierRank >= 2;
  }

  bool get canUseProFeatures {
    // 고급 통계/고급 위젯/고급 자동화
    return tierRank >= 3;
  }

  bool get canUseOrganizationFeatures {
    // Master 이상. 세부 권한 위임은 나중에 연결.
    return tierRank >= 4;
  }

  String get tierLabel {
    return AppTierAccessService.tierLabelFromRank(tierRank);
  }

  String get earnedTierLabel {
    return AppTierAccessService.tierLabelFromRank(earnedTierRank);
  }

  String get supportTierLabel {
    return AppTierAccessService.tierLabelFromRank(supportTierRank);
  }

  String get organizationTierLabel {
    return AppTierAccessService.tierLabelFromRank(organizationTierRank);
  }
}

class AppTierAccessService {
  const AppTierAccessService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Future<AppTierAccessSnapshot> loadPersonalTrainerAccess({
    required String uid,
    FirebaseFirestore? firestore,
  }) async {
    final ownerUid = uid.trim();
    if (ownerUid.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'personal owner uid is required');
    }

    final snapshot = await (firestore ?? _db)
        .collection('trainer_profiles')
        .doc(ownerUid)
        .get()
        .timeout(const Duration(seconds: 2));
    if (!snapshot.exists) {
      throw StateError('personal_trainer_profile_not_found');
    }

    final serverAccess =
        personalSnapshotFromProfile(snapshot.data() ?? const {});
    final effectiveTierRank = DevTierFixtureController.resolveTierRank(
      serverAccess.tierRank,
    );
    if (kDebugMode &&
        DevTierFixtureController.isAvailable &&
        effectiveTierRank != serverAccess.tierRank) {
      debugPrint(
        '[MTF_DEV_TIER_FIXTURE] '
        'serverTier=${serverAccess.tierLabel} '
        'effectiveTier=${tierLabelFromRank(effectiveTierRank)} '
        'localOnly=true',
      );
    }
    return serverAccess.withEffectiveTierRank(effectiveTierRank);
  }

  @visibleForTesting
  static AppTierAccessSnapshot personalSnapshotFromProfile(
    Map<String, dynamic> data,
  ) {
    final tier = parsePersonalTierLabel(data['tier']);
    if (tier == null) {
      throw StateError('personal_tier_missing');
    }
    final tierRank = tierRankFromText(tier);

    return AppTierAccessSnapshot(
      tierRank: tierRank,
      earnedTierRank: tierRank,
      supportTierRank: 0,
      organizationTierRank: 0,
      storedTierRank: tierRank,
      isSponsor: false,
      profileCompleted: _boolFromAny(
        data['profileCompleted'] ?? data['trainerProfileCompleted'],
      ),
      kakaoLinked: false,
      activeMemberCount: _intFromAny(
        data['validMemberCount'] ?? data['managedMemberCount'],
      ),
      kakaoCardLinkedMemberCount: 0,
      contractSignedMemberCount: 0,
      branchCount: 0,
    );
  }

  static Future<AppTierAccessSnapshot> loadTrainerAccess() async {
    try {
      final snap = await _db
          .collection('trainer_profile')
          .doc('me')
          .get()
          .timeout(const Duration(seconds: 2));

      final data = snap.data() ?? <String, dynamic>{};

      final isSponsor = _boolFromAny(data['isSponsor']);

      final profileCompleted = _boolFromAny(
        data['profileCompleted'] ??
            data['trainerInfoDone'] ??
            data['myInfoCompleted'],
      );

      final kakaoLinked = _boolFromAny(
        data['kakaoLinked'] ??
            data['kakaoConnected'] ??
            data['kakaoSyncEnabled'] ??
            data['hasKakaoAccount'],
      );

      final activeMemberCount = _intFromAny(
        data['activeMemberCount'] ??
            data['memberCount'] ??
            data['membersCount'] ??
            data['currentActiveMemberCount'],
      );

      final kakaoCardLinkedMemberCount = _intFromAny(
        data['kakaoCardLinkedMemberCount'] ??
            data['kakaoLinkedMemberCount'] ??
            data['kakaoSyncedMemberCount'] ??
            data['kakaoClientCardLinkedCount'] ??
            data['moreSenseMemberCount'],
      );

      final contractSignedMemberCount = _intFromAny(
        data['contractSignedMemberCount'] ??
            data['contractMemberCount'] ??
            data['signedContractMemberCount'] ??
            data['contractCount'],
      );

      final branchCount = _intFromAny(
        data['branchCount'] ??
            data['centerBranchCount'] ??
            data['organizationBranchCount'],
      );

      final earnedTierRank = _earnedTierRank(
        profileCompleted: profileCompleted,
        kakaoLinked: kakaoLinked,
        activeMemberCount: activeMemberCount,
        kakaoCardLinkedMemberCount: kakaoCardLinkedMemberCount,
        contractSignedMemberCount: contractSignedMemberCount,
      );

      var supportTierRank = _maxTierRankFromValues([
        data['supportTier'],
        data['subscriptionTier'],
        data['paidTier'],
        data['sponsorTier'],
        data['planTier'],
        data['plan'],
      ]);

      // 기존 bool 후원값은 최소 Semi-Pro 해금으로 봅니다.
      // 추후 결제/후원 구조가 명확해지면 supportTier로 통일하면 됩니다.
      if (isSponsor && supportTierRank < 2) {
        supportTierRank = 2;
      }

      final organizationTierRank = _maxTierRankFromValues([
        data['organizationTier'],
        data['orgTier'],
        data['centerTier'],
      ]);

      // 기존 저장 필드. 이전 버전 호환용입니다.
      final storedTierRank = _maxTierRankFromValues([
        data['effectiveTier'],
        data['currentTier'],
        data['earnedTier'],
        data['appTier'],
        data['tier'],
      ]);

      final tierRank = [
        earnedTierRank,
        supportTierRank,
        organizationTierRank,
        storedTierRank,
      ].fold<int>(0, (maxValue, value) {
        return value > maxValue ? value : maxValue;
      });

      return AppTierAccessSnapshot(
        tierRank: tierRank,
        earnedTierRank: earnedTierRank,
        supportTierRank: supportTierRank,
        organizationTierRank: organizationTierRank,
        storedTierRank: storedTierRank,
        isSponsor: isSponsor,
        profileCompleted: profileCompleted,
        kakaoLinked: kakaoLinked,
        activeMemberCount: activeMemberCount,
        kakaoCardLinkedMemberCount: kakaoCardLinkedMemberCount,
        contractSignedMemberCount: contractSignedMemberCount,
        branchCount: branchCount,
      );
    } catch (e) {
      debugPrint('[MTF_TIER] access load failed: $e');

      return const AppTierAccessSnapshot(
        tierRank: 0,
        earnedTierRank: 0,
        supportTierRank: 0,
        organizationTierRank: 0,
        storedTierRank: 0,
        isSponsor: false,
        profileCompleted: false,
        kakaoLinked: false,
        activeMemberCount: 0,
        kakaoCardLinkedMemberCount: 0,
        contractSignedMemberCount: 0,
        branchCount: 0,
      );
    }
  }

  static int _earnedTierRank({
    required bool profileCompleted,
    required bool kakaoLinked,
    required int activeMemberCount,
    required int kakaoCardLinkedMemberCount,
    required int contractSignedMemberCount,
  }) {
    // Pro
    if (activeMemberCount >= 50 ||
        kakaoCardLinkedMemberCount >= 40 ||
        contractSignedMemberCount >= 20) {
      return 3;
    }

    // Semi-Pro
    if (activeMemberCount >= 30 || kakaoCardLinkedMemberCount >= 20) {
      return 2;
    }

    // Amateur
    if (kakaoLinked || profileCompleted) {
      return 1;
    }

    // Beginner
    return 0;
  }

  static int _maxTierRankFromValues(List<dynamic> values) {
    var maxRank = 0;

    for (final value in values) {
      final rank = tierRankFromText((value ?? '').toString());

      if (rank > maxRank) {
        maxRank = rank;
      }
    }

    return maxRank;
  }

  static bool _boolFromAny(dynamic value) {
    if (value is bool) return value;

    final text = (value ?? '').toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on' ||
        text == 'linked' ||
        text == 'connected';
  }

  static int _intFromAny(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = (value ?? '').toString().replaceAll(RegExp(r'[^0-9-]'), '');

    if (text.trim().isEmpty) return 0;

    return int.tryParse(text) ?? 0;
  }

  static int tierRankFromText(String value) {
    final text = value.trim().toLowerCase();

    if (text.isEmpty) return 0;

    if (text == 'beginner' || text == '비기너') {
      return 0;
    }

    if (text == 'amateur' || text == '아마추어') {
      return 1;
    }

    if (text == 'semi-pro' ||
        text == 'semipro' ||
        text == 'semi_pro' ||
        text == 'semi pro' ||
        text == 'semi' ||
        text == '세미프로') {
      return 2;
    }

    if (text == 'pro' || text == '프로') {
      return 3;
    }

    if (text == 'master' || text == '마스터') {
      return 4;
    }

    if (text == 'grand prix' ||
        text == 'grandprix' ||
        text == 'grand_prix' ||
        text == 'grand-prix' ||
        text == '그랑프리') {
      return 5;
    }

    return 0;
  }

  static AppTierFeatureInfo featureInfo(AppTierFeatureKey feature) {
    switch (feature) {
      case AppTierFeatureKey.customerCardCreate:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.customerCardCreate,
          requiredRank: 1,
          title: '고객카드 등록',
          description: '레슨 일정 10개와 선생님 정보 입력을 완료하면 사용할 수 있어요.',
          shortBenefit: '회원별 고객카드 관리',
          highlightTier: 'amateur',
        );

      case AppTierFeatureKey.trainingLog:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.trainingLog,
          requiredRank: 2,
          title: '레슨일지',
          description: '레슨 기록 작성과 회원 서명 요청은 Semi-Pro부터 사용할 수 있어요.',
          shortBenefit: '레슨일지 작성·서명',
          highlightTier: 'semiPro',
        );

      case AppTierFeatureKey.lessonInsights:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.lessonInsights,
          requiredRank: 3,
          title: '인사이트',
          description: '레슨 추이, 회원 흐름, 월간 확정 기록을 실제 데이터로 확인할 수 있어요.',
          shortBenefit: '레슨·회원 흐름 분석',
          highlightTier: 'pro',
        );

      case AppTierFeatureKey.dday:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.dday,
          requiredRank: 1,
          title: '목표 D-DAY',
          description: '바디프로필, 대회, 촬영일처럼 날짜가 정해진 목표를 D-DAY로 관리할 수 있어요.',
          shortBenefit: '목표 날짜 관리',
          highlightTier: 'amateur',
        );

      case AppTierFeatureKey.smartAlarm:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.smartAlarm,
          requiredRank: 2,
          title: 'MORE 스마트 알림',
          description: '연속 레슨은 줄이고, 필요한 알림만 더 똑똑하게 챙길 수 있어요.',
          shortBenefit: '기본 스마트 알림',
          highlightTier: 'semipro',
        );

      case AppTierFeatureKey.moreDay:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.moreDay,
          requiredRank: 2,
          title: 'MORE 데이',
          description: '생일, 기념일, 자녀 수능, 바디프로필처럼 더 신경 쓸 날을 저장하고 챙길 수 있어요.',
          shortBenefit: '중요한 날짜 관리',
          highlightTier: 'semiPro',
        );

      case AppTierFeatureKey.contract:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.contract,
          requiredRank: 2,
          title: '레슨계약서',
          description: '회원별 레슨계약서를 작성하고 서명 흐름까지 연결할 수 있어요.',
          shortBenefit: '계약서 작성/서명',
          highlightTier: 'semiPro',
        );

      case AppTierFeatureKey.contractHistory:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.contractHistory,
          requiredRank: 2,
          title: '계약 이력',
          description: '현재 계약과 지난 계약 흐름을 한 번에 확인할 수 있어요.',
          shortBenefit: '지난 계약 확인',
          highlightTier: 'semiPro',
        );

      case AppTierFeatureKey.badge:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.badge,
          requiredRank: 2,
          title: '메달 관리',
          description: '100회 레슨, 바디프로필 완료, 우수 출석 같은 성취를 메달로 관리할 수 있어요.',
          shortBenefit: '회원 성취 메달',
          highlightTier: 'semiPro',
        );

      case AppTierFeatureKey.moreFocus:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.moreFocus,
          requiredRank: 3,
          title: 'MORE 포커스',
          description: '잔여 회차, 재등록, 목표 이후 케어처럼 모어댄이 놓치기 쉬운 관리 포인트를 자동으로 짚어줘요.',
          shortBenefit: '자동 관리 포인트',
          highlightTier: 'pro',
        );

      case AppTierFeatureKey.anatomy:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.anatomy,
          requiredRank: 3,
          title: '아나토미 레슨일지 작성',
          description: '해부학적 근육의 부위 선택 기반으로 레슨 내용을 더 체계적으로 정리할 수 있어요.',
          shortBenefit: '해부학적 근육의 부위 기반 레슨 기록',
          highlightTier: 'pro',
        );

      case AppTierFeatureKey.consult:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.consult,
          requiredRank: 3,
          title: '상담 체크리스트',
          description:
              '첫 상담이나 OT 때 회원의 목표, 통증, 운동 경험, 생활 패턴을 대화형 체크리스트로 정리할 수 있어요.',
          shortBenefit: '상담 체크리스트',
          highlightTier: 'pro',
        );

      case AppTierFeatureKey.dormantMember:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.dormantMember,
          requiredRank: 1,
          title: '휴면회원 관리',
          description: '장기 미방문 회원을 휴면으로 분류하고, 다시 레슨을 시작할 때 활성 회원으로 되돌릴 수 있어요.',
          shortBenefit: '휴면회원 전환/해제',
          highlightTier: 'amateur',
        );

      case AppTierFeatureKey.membershipPauseResume:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.membershipPauseResume,
          requiredRank: 2,
          title: '회원권 정지/재개',
          description:
              '고객카드에 입력된 회원권 기간을 기준으로, 레슨을 잠시 쉬는 회원을 정지 처리하고 휴면회원으로 함께 분류할 수 있어요.',
          shortBenefit: '고객카드 기준 회원권 정지/재개',
          highlightTier: 'semiPro',
        );

      case AppTierFeatureKey.membershipContract:
        return const AppTierFeatureInfo(
          feature: AppTierFeatureKey.membershipContract,
          requiredRank: 3,
          title: '회원권계약서',
          description:
              '회원권 기간, 정지/연장, 환불/양도 조건처럼 회원권 운영에 필요한 내용을 계약서로 명확하게 남길 수 있어요.',
          shortBenefit: '회원권계약서 작성',
          highlightTier: 'pro',
        );
    }
  }

  static int requiredRankForFeature(AppTierFeatureKey feature) {
    return featureInfo(feature).requiredRank;
  }

  static String featureTitle(AppTierFeatureKey feature) {
    return featureInfo(feature).title;
  }

  static String featureDescription(AppTierFeatureKey feature) {
    return featureInfo(feature).description;
  }

  static String featureShortBenefit(AppTierFeatureKey feature) {
    return featureInfo(feature).shortBenefit;
  }

  static bool canUseFeature(
    AppTierAccessSnapshot access,
    AppTierFeatureKey feature,
  ) {
    return access.tierRank >= requiredRankForFeature(feature);
  }

  static List<AppTierFeatureInfo> featureInfosForRank(int rank) {
    return AppTierFeatureKey.values
        .map(featureInfo)
        .where((info) => info.requiredRank == rank)
        .toList();
  }

  static List<String> tierFeatureSummaryItems(int rank) {
    switch (rank) {
      case 1:
        return const [
          '목표 D-DAY 관리',
          'MORE 스마트 알림',
          '휴면회원 관리',
        ];

      case 2:
        return const [
          'MORE 데이',
          '레슨계약서',
          '계약 이력',
          '메달 관리',
          '회원권 정지/재개',
        ];

      case 3:
        return const [
          'MORE 포커스',
          '상담 체크리스트',
          '자동 관리 포인트',
          'D-DAY 이후 케어',
          '아나토미 기록',
          '회원권계약서',
        ];

      case 4:
        return const [
          '센터 단위 관리',
          '조직 관리 준비',
        ];

      case 5:
        return const [
          '다수 지점 관리',
          'Grand Prix 운영 흐름',
        ];

      case 0:
      default:
        return const [
          '기본 회원관리',
          '기본 스케줄 관리',
        ];
    }
  }

  static String tierLabelFromRank(int rank) {
    switch (rank) {
      case 5:
        return 'Grand Prix';
      case 4:
        return 'Master';
      case 3:
        return 'Pro';
      case 2:
        return 'Semi-Pro';
      case 1:
        return 'Amateur';
      case 0:
      default:
        return 'Beginner';
    }
  }
}
