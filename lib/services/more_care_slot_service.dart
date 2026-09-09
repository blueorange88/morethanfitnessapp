
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum MoreCareSlotStatus {
  basic,
  temporary,
  pending,
  active,
  rejected,
  expired,
}

extension MoreCareSlotStatusX on MoreCareSlotStatus {
  String get value {
    switch (this) {
      case MoreCareSlotStatus.basic:
        return 'basic';
      case MoreCareSlotStatus.temporary:
        return 'temporary';
      case MoreCareSlotStatus.pending:
        return 'pending';
      case MoreCareSlotStatus.active:
        return 'active';
      case MoreCareSlotStatus.rejected:
        return 'rejected';
      case MoreCareSlotStatus.expired:
        return 'expired';
    }
  }

  static MoreCareSlotStatus fromText(String value) {
    switch (value.trim()) {
      case 'temporary':
        return MoreCareSlotStatus.temporary;
      case 'pending':
        return MoreCareSlotStatus.pending;
      case 'active':
        return MoreCareSlotStatus.active;
      case 'rejected':
        return MoreCareSlotStatus.rejected;
      case 'expired':
        return MoreCareSlotStatus.expired;
      case 'basic':
      default:
        return MoreCareSlotStatus.basic;
    }
  }
}

class MoreCareSlotDecision {
  const MoreCareSlotDecision({
    required this.status,
    required this.canUseAdvancedMoreCare,
    required this.message,
    this.temporaryUntil,
    this.requestId,
  });

  final MoreCareSlotStatus status;
  final bool canUseAdvancedMoreCare;
  final String message;
  final DateTime? temporaryUntil;
  final String? requestId;
}

class MoreCareSlotActor {
  const MoreCareSlotActor({
    required this.trainerId,
    required this.trainerName,
    this.organizationId,
  });

  final String trainerId;
  final String trainerName;
  final String? organizationId;
}

class MoreCareSlotRequest {
  const MoreCareSlotRequest({
    required this.id,
    required this.status,
    required this.memberId,
    required this.memberName,
    required this.trainerId,
    required this.trainerName,
    this.organizationId,
    this.reason,
    this.temporaryUntil,
    this.requestedAt,
    this.updatedAt,
  });

  final String id;
  final MoreCareSlotStatus status;
  final String memberId;
  final String memberName;
  final String trainerId;
  final String trainerName;
  final String? organizationId;
  final String? reason;
  final DateTime? temporaryUntil;
  final DateTime? requestedAt;
  final DateTime? updatedAt;

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  factory MoreCareSlotRequest.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    final statusText = (data['status'] ?? '').toString();

    final memberId = (data['memberId'] ?? '').toString().trim();
    final memberName = (data['memberName'] ?? '회원').toString().trim();

    final trainerId = (data['trainerId'] ?? '').toString().trim();
    final trainerName = (data['trainerName'] ?? '트레이너').toString().trim();

    final organizationId = (data['organizationId'] ?? '').toString().trim();

    return MoreCareSlotRequest(
      id: doc.id,
      status: MoreCareSlotStatusX.fromText(statusText),
      memberId: memberId,
      memberName: memberName.isEmpty ? '회원' : memberName,
      trainerId: trainerId,
      trainerName: trainerName.isEmpty ? '트레이너' : trainerName,
      organizationId: organizationId.isEmpty ? null : organizationId,
      reason: (data['reason'] ?? '').toString().trim(),
      temporaryUntil: _dateFromAny(data['temporaryUntil']),
      requestedAt: _dateFromAny(data['requestedAt']),
      updatedAt: _dateFromAny(data['updatedAt']),
    );
  }
}

class MoreCareSlotService {
  const MoreCareSlotService._();

  static const int defaultTemporaryDays = 7;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _trainerProfileRef {
    return _db.collection('trainer_profile').doc('me');
  }

  static Future<String> _loadMemberName(String memberId) async {
    final cleanMemberId = memberId.trim();

    if (cleanMemberId.isEmpty) return '회원';

    try {
      final snap = await _memberRef(cleanMemberId)
          .get()
          .timeout(const Duration(seconds: 2));

      final data = snap.data() ?? <String, dynamic>{};

      final name = (
          data['name'] ??
              data['memberName'] ??
              data['clientName'] ??
              data['displayName'] ??
              ''
      ).toString().trim();

      return name.isEmpty ? '회원' : name;
    } catch (e) {
      debugPrint('[MTF_MORE_SLOT] member name load failed: $e');
      return '회원';
    }
  }

  static Future<MoreCareSlotActor> _loadCurrentTrainerActor() async {
    try {
      final snap = await _trainerProfileRef
          .get()
          .timeout(const Duration(seconds: 2));

      final data = snap.data() ?? <String, dynamic>{};

      final trainerId = (
          data['trainerId'] ??
              data['uid'] ??
              data['userId'] ??
              data['ownerId'] ??
              'me'
      ).toString().trim();

      final trainerName = (
          data['trainerName'] ??
              data['name'] ??
              data['displayName'] ??
              data['nickname'] ??
              '트레이너'
      ).toString().trim();

      final organizationId = (
          data['organizationId'] ??
              data['orgId'] ??
              data['centerOrganizationId'] ??
              ''
      ).toString().trim();

      return MoreCareSlotActor(
        trainerId: trainerId.isEmpty ? 'me' : trainerId,
        trainerName: trainerName.isEmpty ? '트레이너' : trainerName,
        organizationId: organizationId.isEmpty ? null : organizationId,
      );
    } catch (e) {
      debugPrint('[MTF_MORE_SLOT] trainer actor load failed: $e');

      return const MoreCareSlotActor(
        trainerId: 'me',
        trainerName: '트레이너',
      );
    }
  }

  /// 관리자 요청 화면에서 현재 강사/조직 정보를 확인할 때 사용합니다.
  static Future<MoreCareSlotActor> loadCurrentActor() {
    return _loadCurrentTrainerActor();
  }

  static DocumentReference<Map<String, dynamic>> _memberRef(String memberId) {
    return _db.collection('members').doc(memberId);
  }

  static DocumentReference<Map<String, dynamic>> _requestRef({
    required String memberId,
    String? organizationId,
  }) {
    final requestId = 'member_$memberId';

    return _requestCollection(
      organizationId: organizationId,
    ).doc(requestId);
  }

  static CollectionReference<Map<String, dynamic>> _requestCollection({
    String? organizationId,
  }) {
    final cleanOrgId = (organizationId ?? '').trim();

    if (cleanOrgId.isNotEmpty) {
      return _db
          .collection('organizations')
          .doc(cleanOrgId)
          .collection('more_care_slot_requests');
    }

    return _db.collection('more_care_slot_requests');
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static MoreCareSlotStatus _statusFromMemberData(
      Map<String, dynamic> data,
      ) {
    final slot = data['moreCareSlot'] is Map
        ? Map<String, dynamic>.from(data['moreCareSlot'] as Map)
        : <String, dynamic>{};

    final raw = (slot['status'] ?? data['moreCareStatus'] ?? '').toString();

    return MoreCareSlotStatusX.fromText(raw);
  }

  static DateTime? _temporaryUntilFromMemberData(
      Map<String, dynamic> data,
      ) {
    final slot = data['moreCareSlot'] is Map
        ? Map<String, dynamic>.from(data['moreCareSlot'] as Map)
        : <String, dynamic>{};

    return _dateFromAny(slot['temporaryUntil'] ?? data['moreCareTemporaryUntil']);
  }
  /// 현재 로그인/프로필 기준 강사 정보로 MORE 관리 슬롯을 임시 요청합니다.
  ///
  /// 레슨일지, 계약서, 스마트 알림 같은 현장 기능에서는
  /// 이 메서드를 우선 사용하면 됩니다.
  static Future<MoreCareSlotDecision> requestTemporarySlotForCurrentTrainer({
    required String memberId,
    required String memberName,
    String reason = 'field_trainer_request',
    int temporaryDays = defaultTemporaryDays,
  }) async {
    final actor = await _loadCurrentTrainerActor();

    return requestTemporarySlot(
      memberId: memberId,
      memberName: memberName,
      trainerId: actor.trainerId,
      trainerName: actor.trainerName,
      organizationId: actor.organizationId,
      reason: reason,
      temporaryDays: temporaryDays,
    );
  }

  /// memberId만으로 현재 강사의 MORE 관리 슬롯을 임시 요청합니다.
  ///
  /// 각 페이지에서 회원 이름 변수를 몰라도 되게 하기 위한 간편 메서드입니다.
  static Future<MoreCareSlotDecision> requestTemporarySlotForMember({
    required String memberId,
    String reason = 'field_trainer_request',
    int temporaryDays = defaultTemporaryDays,
  }) async {
    final memberName = await _loadMemberName(memberId);

    return requestTemporarySlotForCurrentTrainer(
      memberId: memberId,
      memberName: memberName,
      reason: reason,
      temporaryDays: temporaryDays,
    );
  }

  /// 현장 트레이너가 먼저 MORE 관리 슬롯을 열 때 사용합니다.
  ///
  /// 정책:
  /// - 이미 active면 그대로 사용
  /// - temporary가 아직 유효하면 그대로 사용
  /// - 아니면 temporary 상태로 7일 열고 관리자 승인 요청 생성
  static Future<MoreCareSlotDecision> requestTemporarySlot({
    required String memberId,
    required String memberName,
    required String trainerId,
    required String trainerName,
    String? organizationId,
    String reason = 'field_trainer_request',
    int temporaryDays = defaultTemporaryDays,
  }) async {
    final cleanMemberId = memberId.trim();
    final cleanTrainerId = trainerId.trim();
    final cleanTrainerName = trainerName.trim();
    final cleanMemberName = memberName.trim();
    final cleanOrgId = (organizationId ?? '').trim();

    if (cleanMemberId.isEmpty) {
      return const MoreCareSlotDecision(
        status: MoreCareSlotStatus.basic,
        canUseAdvancedMoreCare: false,
        message: '회원 정보를 찾지 못했어요.',
      );
    }

    final now = DateTime.now();
    final temporaryUntil = now.add(Duration(days: temporaryDays));

    final memberRef = _memberRef(cleanMemberId);
    final requestRef = _requestRef(
      memberId: cleanMemberId,
      organizationId: cleanOrgId,
    );

    MoreCareSlotDecision decision = MoreCareSlotDecision(
      status: MoreCareSlotStatus.temporary,
      canUseAdvancedMoreCare: true,
      temporaryUntil: temporaryUntil,
      requestId: requestRef.id,
      message: 'MORE 관리 슬롯을 임시로 열어두고 관리자에게 승인 요청을 보냈어요.',
    );

    try {
      await _db.runTransaction((tx) async {
        final memberSnap = await tx.get(memberRef);
        final memberData = memberSnap.data() ?? <String, dynamic>{};

        final currentStatus = _statusFromMemberData(memberData);
        final currentUntil = _temporaryUntilFromMemberData(memberData);

        if (currentStatus == MoreCareSlotStatus.active) {
          decision = MoreCareSlotDecision(
            status: MoreCareSlotStatus.active,
            canUseAdvancedMoreCare: true,
            requestId: requestRef.id,
            message: '이미 정식 MORE 관리 슬롯으로 사용 중이에요.',
          );
          return;
        }

        if (currentStatus == MoreCareSlotStatus.temporary &&
            currentUntil != null &&
            currentUntil.isAfter(now)) {
          decision = MoreCareSlotDecision(
            status: MoreCareSlotStatus.temporary,
            canUseAdvancedMoreCare: true,
            temporaryUntil: currentUntil,
            requestId: requestRef.id,
            message: '이미 임시 MORE 관리로 사용 중이에요.',
          );
          return;
        }

        final requestPayload = <String, dynamic>{
          'status': MoreCareSlotStatus.pending.value,
          'memberId': cleanMemberId,
          'memberName': cleanMemberName.isEmpty ? '회원' : cleanMemberName,
          'trainerId': cleanTrainerId,
          'trainerName': cleanTrainerName.isEmpty ? '트레이너' : cleanTrainerName,
          if (cleanOrgId.isNotEmpty) 'organizationId': cleanOrgId,
          'reason': reason,
          'temporaryUntil': Timestamp.fromDate(temporaryUntil),
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        tx.set(
          requestRef,
          requestPayload,
          SetOptions(merge: true),
        );

        tx.set(
          memberRef,
          {
            'moreCareStatus': MoreCareSlotStatus.temporary.value,
            'moreCareSlot': {
              'status': MoreCareSlotStatus.temporary.value,
              'requestId': requestRef.id,
              'memberId': cleanMemberId,
              'trainerId': cleanTrainerId,
              'trainerName':
              cleanTrainerName.isEmpty ? '트레이너' : cleanTrainerName,
              if (cleanOrgId.isNotEmpty) 'organizationId': cleanOrgId,
              'temporaryUntil': Timestamp.fromDate(temporaryUntil),
              'requestedAt': FieldValue.serverTimestamp(),
              'source': 'field_trainer_nudge',
              'reason': reason,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      return decision;
    } catch (e) {
      debugPrint('[MTF_MORE_SLOT] temporary slot request failed: $e');

      return const MoreCareSlotDecision(
        status: MoreCareSlotStatus.basic,
        canUseAdvancedMoreCare: false,
        message: 'MORE 관리 슬롯 요청에 실패했어요.',
      );
    }
  }

  /// 관리자 화면에서 승인 대기 중인 MORE 관리 슬롯 요청을 읽습니다.
  ///
  /// Firestore 인덱스 부담을 줄이기 위해 requestedAt 정렬은 클라이언트에서 처리합니다.
  static Stream<List<MoreCareSlotRequest>> watchPendingRequests({
    String? organizationId,
    int limit = 50,
  }) {
    return _requestCollection(
      organizationId: organizationId,
    )
        .where('status', isEqualTo: MoreCareSlotStatus.pending.value)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map(MoreCareSlotRequest.fromDoc)
          .where((request) => request.memberId.trim().isNotEmpty)
          .toList();

      requests.sort((a, b) {
        final aTime = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bTime.compareTo(aTime);
      });

      return requests;
    });
  }

  /// 관리자 헤더/마이페이지 배지에 쓸 승인 대기 요청 개수입니다.
  static Stream<int> watchPendingRequestCount({
    String? organizationId,
  }) {
    return watchPendingRequests(
      organizationId: organizationId,
      limit: 100,
    ).map((items) => items.length);
  }

  /// 고급 MORE 기능 사용 가능 여부 확인.
  ///
  /// 기본 회원관리/스케줄/기본 레슨일지는 이 결과로 막지 않습니다.
  /// 이 값은 계약서 자동 판단, 레슨일지 메모 기반 알림, 고급 분석 같은
  /// "깊은 관리 기능"에만 사용합니다.
  static Future<MoreCareSlotDecision> checkAdvancedMoreCareAccess({
    required String memberId,
  }) async {
    final cleanMemberId = memberId.trim();

    if (cleanMemberId.isEmpty) {
      return const MoreCareSlotDecision(
        status: MoreCareSlotStatus.basic,
        canUseAdvancedMoreCare: false,
        message: '회원 정보를 찾지 못했어요.',
      );
    }

    try {
      final memberRef = _memberRef(cleanMemberId);
      final snap = await memberRef.get();
      final data = snap.data() ?? <String, dynamic>{};

      final status = _statusFromMemberData(data);
      final temporaryUntil = _temporaryUntilFromMemberData(data);
      final now = DateTime.now();

      if (status == MoreCareSlotStatus.active) {
        return const MoreCareSlotDecision(
          status: MoreCareSlotStatus.active,
          canUseAdvancedMoreCare: true,
          message: '정식 MORE 관리 슬롯으로 사용 중이에요.',
        );
      }

      if (status == MoreCareSlotStatus.temporary) {
        if (temporaryUntil != null && temporaryUntil.isAfter(now)) {
          return MoreCareSlotDecision(
            status: MoreCareSlotStatus.temporary,
            canUseAdvancedMoreCare: true,
            temporaryUntil: temporaryUntil,
            message: '임시 MORE 관리로 사용 중이에요. 관리자 승인 대기 중입니다.',
          );
        }

        await memberRef.set({
          'moreCareStatus': MoreCareSlotStatus.expired.value,
          'moreCareSlot.status': MoreCareSlotStatus.expired.value,
          'moreCareSlot.expiredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return const MoreCareSlotDecision(
          status: MoreCareSlotStatus.expired,
          canUseAdvancedMoreCare: false,
          message: '임시 사용 기간이 끝났어요. 관리자 승인 후 다시 열 수 있어요.',
        );
      }

      if (status == MoreCareSlotStatus.rejected) {
        return const MoreCareSlotDecision(
          status: MoreCareSlotStatus.rejected,
          canUseAdvancedMoreCare: false,
          message: '관리자가 기본 관리로 유지했어요.',
        );
      }

      return const MoreCareSlotDecision(
        status: MoreCareSlotStatus.basic,
        canUseAdvancedMoreCare: false,
        message: '기본 관리 회원이에요.',
      );
    } catch (e) {
      debugPrint('[MTF_MORE_SLOT] check access failed: $e');

      return const MoreCareSlotDecision(
        status: MoreCareSlotStatus.basic,
        canUseAdvancedMoreCare: false,
        message: 'MORE 관리 상태를 확인하지 못했어요.',
      );
    }
  }

  /// 관리자 승인.
  static Future<void> approveRequest({
    required String memberId,
    required String approvedByTrainerId,
    String? organizationId,
  }) async {
    final cleanMemberId = memberId.trim();
    final cleanApproverId = approvedByTrainerId.trim();
    final cleanOrgId = (organizationId ?? '').trim();

    if (cleanMemberId.isEmpty) return;

    final memberRef = _memberRef(cleanMemberId);
    final requestRef = _requestRef(
      memberId: cleanMemberId,
      organizationId: cleanOrgId,
    );

    final nowPayload = {
      'status': MoreCareSlotStatus.active.value,
      'approvedByTrainerId': cleanApproverId,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.runTransaction((tx) async {
      tx.set(
        requestRef,
        nowPayload,
        SetOptions(merge: true),
      );

      tx.set(
        memberRef,
        {
          'moreCareStatus': MoreCareSlotStatus.active.value,
          'moreCareSlot.status': MoreCareSlotStatus.active.value,
          'moreCareSlot.approvedByTrainerId': cleanApproverId,
          'moreCareSlot.approvedAt': FieldValue.serverTimestamp(),
          'moreCareSlot.rejectedAt': FieldValue.delete(),
          'moreCareSlot.expiredAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// 관리자 거절/기본 관리 유지.
  ///
  /// 기본 스케줄/회원관리/기본 레슨일지는 계속 사용 가능하게 두고,
  /// 고급 MORE 기능만 잠그는 상태로 전환합니다.
  static Future<void> rejectRequest({
    required String memberId,
    required String rejectedByTrainerId,
    String? organizationId,
    String reason = 'manager_keep_basic',
  }) async {
    final cleanMemberId = memberId.trim();
    final cleanRejectorId = rejectedByTrainerId.trim();
    final cleanOrgId = (organizationId ?? '').trim();

    if (cleanMemberId.isEmpty) return;

    final memberRef = _memberRef(cleanMemberId);
    final requestRef = _requestRef(
      memberId: cleanMemberId,
      organizationId: cleanOrgId,
    );

    await _db.runTransaction((tx) async {
      tx.set(
        requestRef,
        {
          'status': MoreCareSlotStatus.rejected.value,
          'rejectedByTrainerId': cleanRejectorId,
          'rejectReason': reason,
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        memberRef,
        {
          'moreCareStatus': MoreCareSlotStatus.rejected.value,
          'moreCareSlot.status': MoreCareSlotStatus.rejected.value,
          'moreCareSlot.rejectedByTrainerId': cleanRejectorId,
          'moreCareSlot.rejectReason': reason,
          'moreCareSlot.rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}