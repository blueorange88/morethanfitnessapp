import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'mtf_firebase_functions.dart';

class ManagedMemberUsage {
  const ManagedMemberUsage({
    required this.count,
    required this.limit,
    this.lifetimeQualifiedCount = 0,
    this.tier = 'Beginner',
    this.accountLinked = false,
    this.profileCompleted = false,
    this.nickname = '',
    this.displayName = '',
    this.phone = '',
    this.activityRegion = '',
    this.primaryActivity = '',
    this.affiliationType = '',
  });

  final int count;
  final int limit;
  final int lifetimeQualifiedCount;
  final String tier;
  final bool accountLinked;
  final bool profileCompleted;
  final String nickname;
  final String displayName;
  final String phone;
  final String activityRegion;
  final String primaryActivity;
  final String affiliationType;

  int get completedProfileFieldCount => [
        displayName,
        phone,
        activityRegion,
        primaryActivity,
        affiliationType,
      ].where((value) => value.trim().isNotEmpty).length;
}

class ManagedMemberSummary {
  const ManagedMemberSummary({
    required this.memberId,
    required this.name,
    required this.phone,
    required this.managementState,
  });

  final String memberId;
  final String name;
  final String phone;
  final String managementState;
}

abstract interface class ManagedMemberWorkspaceGateway {
  Stream<ManagedMemberUsage> watchUsage();

  Stream<List<ManagedMemberSummary>> watchMembers();

  Future<void> createMember({
    required String idempotencyKey,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  });

  Future<void> transitionMember({
    required String memberId,
    required String nextState,
  });

  Future<void> updateMember({
    required String memberId,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  });

  Future<void> updateTrainerProfile({
    required String displayName,
    required String phone,
    required String activityRegion,
    required String primaryActivity,
    String? affiliationType,
    String? nickname,
    String? realName,
    String? jobTitle,
    String? contractTrainerNameSource,
    String? contractTrainerCustomName,
    String? nameEn,
    List<String>? activityRegions,
    String? gymName,
    String? centerLocation,
  });
}

class FirebaseManagedMemberWorkspaceGateway
    implements ManagedMemberWorkspaceGateway {
  FirebaseManagedMemberWorkspaceGateway({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? MtfFirebaseFunctions.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<ManagedMemberUsage> watchUsage() => _firestore
          .collection('trainer_profiles')
          .doc(uid)
          .snapshots()
          .map((snapshot) {
        final data = snapshot.data() ?? const <String, dynamic>{};
        return ManagedMemberUsage(
          count: (data['managedMemberCount'] as num?)?.toInt() ?? 0,
          limit: (data['managedMemberLimit'] as num?)?.toInt() ?? 10,
          lifetimeQualifiedCount:
              (data['lifetimeQualifiedMemberCount'] as num?)?.toInt() ?? 0,
          tier: (data['tier'] as String? ?? 'Beginner').trim(),
          accountLinked: data['accountLinked'] == true,
          profileCompleted: data['profileCompleted'] == true,
          nickname: (data['nickname'] as String? ?? '').trim(),
          displayName: (data['displayName'] as String? ?? '').trim(),
          phone: (data['phone'] as String? ?? '').trim(),
          activityRegion: (data['activityRegion'] as String? ?? '').trim(),
          primaryActivity: (data['primaryActivity'] as String? ?? '').trim(),
          affiliationType: (data['affiliationType'] as String? ?? '').trim(),
        );
      });

  @override
  Stream<List<ManagedMemberSummary>> watchMembers() => _firestore
          .collection('members')
          .where('trainerId', isEqualTo: uid)
          .where('workspaceType', isEqualTo: 'personal')
          .snapshots()
          .map((snapshot) {
        final members = snapshot.docs
            .map((document) {
              final data = document.data();
              return ManagedMemberSummary(
                memberId: document.id,
                name: (data['name'] as String? ?? '').trim(),
                phone: (data['phone'] as String? ?? '').trim(),
                managementState:
                    (data['managementState'] as String? ?? 'active').trim(),
              );
            })
            .where((member) => member.managementState != 'deleted')
            .toList();
        members.sort((left, right) => left.name.compareTo(right.name));
        return members;
      });

  @override
  Future<void> createMember({
    required String idempotencyKey,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  }) async {
    await MtfFirebaseFunctions.call(
      'createManagedMember',
      functions: _functions,
      parameters: {
        'idempotencyKey': idempotencyKey,
        'name': name,
        'gender': gender,
        'phone': phone,
        'activityRegion': activityRegion,
        'note': note,
      },
    );
    try {
      await reconcilePersonalTier();
    } catch (_) {
      // 회원 생성은 이미 transaction으로 완료됐다. 승급 self-heal은 다음 시점에 재시도한다.
    }
  }

  Future<void> reconcilePersonalTier() async {
    await MtfFirebaseFunctions.call(
      'reconcilePersonalTier',
      functions: _functions,
    );
  }

  @override
  Future<void> transitionMember({
    required String memberId,
    required String nextState,
  }) async {
    await MtfFirebaseFunctions.call(
      'transitionManagedMemberState',
      functions: _functions,
      parameters: {
        'memberId': memberId,
        'nextState': nextState,
      },
    );
  }

  @override
  Future<void> updateMember({
    required String memberId,
    required String name,
    required String gender,
    required String phone,
    required String activityRegion,
    required String note,
  }) async {
    await MtfFirebaseFunctions.call(
      'updateManagedMember',
      functions: _functions,
      parameters: {
        'memberId': memberId,
        'name': name,
        'gender': gender,
        'phone': phone,
        'activityRegion': activityRegion,
        'note': note,
      },
    );
  }

  @override
  Future<void> updateTrainerProfile({
    required String displayName,
    required String phone,
    String? birth,
    required String activityRegion,
    required String primaryActivity,
    String? affiliationType,
    String? nickname,
    String? realName,
    String? jobTitle,
    String? contractTrainerNameSource,
    String? contractTrainerCustomName,
    String? nameEn,
    List<String>? activityRegions,
    String? gymName,
    String? centerLocation,
  }) async {
    final parameters = <String, dynamic>{
      'displayName': displayName,
      'phone': phone,
      'activityRegion': activityRegion,
      'primaryActivity': primaryActivity,
    };
    if (birth != null) parameters['birth'] = birth;
    if (affiliationType != null) {
      parameters['affiliationType'] = affiliationType;
    }
    if (nickname != null) parameters['nickname'] = nickname;
    if (realName != null) parameters['realName'] = realName;
    if (jobTitle != null) parameters['jobTitle'] = jobTitle;
    if (contractTrainerNameSource != null) {
      parameters['contractTrainerNameSource'] = contractTrainerNameSource;
    }
    if (contractTrainerCustomName != null) {
      parameters['contractTrainerCustomName'] = contractTrainerCustomName;
    }
    if (nameEn != null) parameters['nameEn'] = nameEn;
    if (activityRegions != null) {
      parameters['activityRegions'] = activityRegions;
    }
    if (gymName != null) parameters['gymName'] = gymName;
    if (centerLocation != null) {
      parameters['centerLocation'] = centerLocation;
    }
    await MtfFirebaseFunctions.call(
      'updatePersonalTrainerProfile',
      functions: _functions,
      parameters: parameters,
    );
  }
}

String managedMemberErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final message = error.message ?? '';
    if (message.contains('amateur_required')) {
      return '고객카드 등록은 Amateur부터 사용할 수 있어요.\n'
          '레슨 일정 10개와 선생님 정보 입력을 완료하면 열려요.';
    }
    if (error.code == 'resource-exhausted' ||
        message.contains('member_limit_reached')) {
      return '현재 Beginner에서는 관리 중인 회원을 10명까지 등록할 수 있어요.\n'
          '기존 회원 기록은 그대로 유지됩니다.\n'
          '관리 범위를 넓히려면 다음 단계로 이어가 주세요.';
    }
    if (message.contains('account_link_required')) {
      return '11번째 유효 회원부터는 계정 연결이 필요해요.\n'
          '기존 10명의 기록은 그대로 유지됩니다.';
    }
    if (message.contains('profile_completion_required')) {
      return '11번째 유효 회원부터는 선생님 내 정보 완료가 필요해요.';
    }
    if (message.contains('duplicate_member')) {
      return '같은 전화번호로 등록된 회원이 이미 있어요.';
    }
    if (message.contains('gender_') ||
        message.contains('phone_') ||
        message.contains('activityRegion_')) {
      return '이름·성별·전화번호·활동 지역을 모두 확인해주세요.';
    }
    if (error.code == 'unauthenticated') {
      return '로그인 상태를 확인한 뒤 다시 시도해주세요.';
    }
    if (error.code == 'permission-denied') {
      return '이 작업공간에서 처리할 수 없는 요청이에요.';
    }
  }
  return '회원 정보를 저장하지 못했어요. 잠시 후 다시 시도해주세요.';
}

String managedMemberSafeErrorCode(Object error) {
  if (error is FirebaseFunctionsException) return error.code;
  if (error is FirebaseException) return error.code;
  return error.runtimeType.toString();
}

String managedMemberProfileSaveErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    if ((error.message ?? '').contains('profile_not_found')) {
      return '프로필을 먼저 준비한 뒤 다시 시도해주세요.';
    }
    if (error.code == 'not-found') {
      return '저장 기능이 아직 준비되지 않았어요. 잠시 후 다시 시도해주세요.';
    }
    if (error.code == 'unauthenticated') {
      return '계정 상태를 확인한 뒤 다시 시도해주세요.';
    }
    if (error.code == 'invalid-argument') {
      return '입력한 정보를 다시 확인해주세요.';
    }
    if (error.code == 'internal' || error.code == 'unavailable') {
      return '서버에 연결하지 못했어요. 잠시 후 다시 시도해주세요.';
    }
  }
  return '저장하지 못했어요. 잠시 후 다시 시도해주세요.';
}
