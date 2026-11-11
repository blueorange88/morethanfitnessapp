import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HomeMemberLookupService {
  HomeMemberLookupService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('members');

  static Query<Map<String, dynamic>> _ownedMembers(String? ownerUid) {
    final owner = ownerUid?.trim() ?? '';
    if (owner.isEmpty) return _members;
    return _members
        .where('trainerId', isEqualTo: owner)
        .where('workspaceType', isEqualTo: 'personal');
  }

  static bool _matchesOwner(Map<String, dynamic> data, String? ownerUid) {
    final owner = ownerUid?.trim() ?? '';
    return owner.isEmpty ||
        ((data['trainerId'] ?? '').toString().trim() == owner &&
            (data['workspaceType'] ?? '').toString().trim() == 'personal');
  }

  static bool matchesPersonalOwner(
    Map<String, dynamic> data,
    String? ownerUid,
  ) => _matchesOwner(data, ownerUid);

  static Future<bool> validateMemberCardOwner(
    String memberId, {
    String? ownerUid,
    String source = 'unknown',
  }) async {
    final cleanId = memberId.trim();
    final owner = ownerUid?.trim() ?? '';
    if (cleanId.isEmpty) return false;

    try {
      final snapshot = await _members.doc(cleanId).get();
      final data = snapshot.data();
      final ownerValid = data != null && _matchesOwner(data, ownerUid);
      final active =
          ownerValid &&
          data['isDeleted'] != true &&
          (data['deleteStatus'] ?? '').toString() != 'pending_delete';
      if (kDebugMode) {
        debugPrint(
          '[MTF_RECENT_MEMBER] '
          'ownerScope=${owner.isEmpty ? 'legacy' : 'personal'} source=$source '
          'candidateCount=1 validatedCount=${active ? 1 : 0} '
          'ownerValidated=$ownerValid',
        );
      }
      return active;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_RECENT_MEMBER] '
          'ownerScope=${owner.isEmpty ? 'legacy' : 'personal'} source=$source '
          'candidateCount=1 validatedCount=0 ownerValidated=false '
          'errorType=${error.runtimeType}',
        );
      }
      return false;
    }
  }

  static String normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String formatPhoneDisplay(String value) {
    final digits = normalizePhone(value);

    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }

    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }

    return digits.isEmpty ? '-' : digits;
  }

  static String memberGenderLabel(Map<String, dynamic> data) {
    final raw =
        data['gender'] ??
        data['sex'] ??
        data['genderLabel'] ??
        data['memberGender'];

    final value = raw?.toString().trim().toLowerCase() ?? '';

    switch (value) {
      case '남':
      case '남자':
      case 'male':
      case 'm':
      case 'man':
      case '1':
        return '남';
      case '여':
      case '여자':
      case 'female':
      case 'f':
      case 'woman':
      case '2':
        return '여';
      default:
        return '-';
    }
  }

  static Map<String, String> memberSessionCountFieldsFromData(
    Map<String, dynamic> data,
  ) {
    final sessions =
        data['sessions'] is Map
            ? Map<String, dynamic>.from(data['sessions'] as Map)
            : <String, dynamic>{};

    final remainRaw =
        data['remainSessions'] ??
        data['remainingSessions'] ??
        sessions['remain'] ??
        data['remainingPt'] ??
        data['ptRemaining'];

    final totalRaw =
        data['totalSessions'] ?? sessions['total'] ?? data['sessionTotal'];

    final remain =
        remainRaw is num
            ? remainRaw.toInt()
            : int.tryParse((remainRaw ?? '').toString()) ?? 0;

    final total =
        totalRaw is num
            ? totalRaw.toInt()
            : int.tryParse((totalRaw ?? '').toString()) ?? 0;

    if (remain <= 0 && total <= 0) return {};

    return {
      'remainingSessions': remain.toString(),
      'totalSessions': total.toString(),
    };
  }

  static String sessionCountTextFromMemberData(Map<String, dynamic> data) {
    final fields = memberSessionCountFieldsFromData(data);
    final remain = fields['remainingSessions'] ?? '';
    final total = fields['totalSessions'] ?? '';

    if (remain.isEmpty && total.isEmpty) return '';
    if (remain.isNotEmpty && total.isNotEmpty) return '$total/$remain';
    if (total.isNotEmpty) return '$total/';
    return '/$remain';
  }

  // 홈이 회원 목록을 실시간으로 구독하고 있어 문서가 캐시에 있으면 서버를 기다리지 않는다.
  // 캐시에 없거나 읽기에 실패하면 기존처럼 서버에서 읽는다.
  static Future<DocumentSnapshot<Map<String, dynamic>>> _getMemberDocCacheFirst(
    String memberId,
  ) async {
    final ref = _members.doc(memberId);
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {}
    return ref.get();
  }

  static Future<bool> _hasCachedOwnedMember(String? ownerUid) async {
    try {
      final snap = await _ownedMembers(
        ownerUid,
      ).limit(1).get(const GetOptions(source: Source.cache));
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String> loadMemberSessionCountText(
    String memberId, {
    String? ownerUid,
  }) async {
    final cleanId = memberId.trim();
    if (cleanId.isEmpty) return '';

    try {
      final snap = await _getMemberDocCacheFirst(cleanId);
      final data = snap.data();

      if (data == null || !_matchesOwner(data, ownerUid)) return '';

      return sessionCountTextFromMemberData(data);
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, String>> loadMemberSessionCountFields(
    String memberId, {
    String? ownerUid,
  }) async {
    final cleanId = memberId.trim();
    if (cleanId.isEmpty) return {};

    try {
      final snap = await _members.doc(cleanId).get();
      final data = snap.data();

      if (data == null || !_matchesOwner(data, ownerUid)) return {};

      return memberSessionCountFieldsFromData(data);
    } catch (_) {
      return {};
    }
  }

  static Future<bool> isDeletedMemberId(
    String? memberId, {
    String? ownerUid,
  }) async {
    final cleanId = (memberId ?? '').trim();
    if (cleanId.isEmpty) return false;

    try {
      final snap = await _members.doc(cleanId).get();
      final data = snap.data();

      if (data == null || !_matchesOwner(data, ownerUid)) return true;

      return data['isDeleted'] == true ||
          (data['deleteStatus'] ?? '').toString() == 'pending_delete';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isActiveMemberDoc(
    String memberId, {
    String? ownerUid,
  }) async {
    final cleanId = memberId.trim();
    if (cleanId.isEmpty) return false;

    try {
      final snap = await _members.doc(cleanId).get();
      final data = snap.data();

      if (data == null || !_matchesOwner(data, ownerUid)) return false;

      final isDeleted = data['isDeleted'] == true;
      final deleteStatus = (data['deleteStatus'] ?? '').toString().trim();

      return !isDeleted && deleteStatus != 'pending_delete';
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> findExactMemberCandidates(
    String inputText, {
    String? ownerUid,
  }) async {
    final cleanText = inputText.trim();
    final normalizedDigits = normalizePhone(cleanText);

    final results = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    // 홈이 회원 목록을 구독해 이 기기 캐시에 회원이 있으면 캐시로 찾고,
    // 캐시가 비어 있으면(첫 실행 등) 기존처럼 서버에서 찾는다.
    final useCache = await _hasCachedOwnedMember(ownerUid);
    Future<QuerySnapshot<Map<String, dynamic>>> runQuery(
      Query<Map<String, dynamic>> query,
    ) async {
      if (useCache) {
        try {
          return await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}
      }
      return query.get();
    }

    void addDocs(QuerySnapshot<Map<String, dynamic>> snapshot) {
      for (final doc in snapshot.docs) {
        if (seenIds.contains(doc.id)) continue;

        final data = doc.data();

        if (data['isDeleted'] == true) continue;
        if ((data['deleteStatus'] ?? '').toString() == 'pending_delete') {
          continue;
        }

        seenIds.add(doc.id);

        final sessionCountText = sessionCountTextFromMemberData(data);
        final parts = sessionCountText.split('/');

        // 기존 home_page.dart 동작 유지
        final remain = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
        final total = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;

        DateTime? nextLessonAt;
        final rawNextLesson = data['nextLessonAt'] ?? data['nextReservationAt'];

        if (rawNextLesson is Timestamp) {
          nextLessonAt = rawNextLesson.toDate();
        } else if (rawNextLesson is DateTime) {
          nextLessonAt = rawNextLesson;
        } else if (rawNextLesson is String && rawNextLesson.isNotEmpty) {
          nextLessonAt = DateTime.tryParse(rawNextLesson);
        }

        results.add({
          'id': doc.id,
          'name': (data['name'] ?? '').toString().trim(),
          'phone': (data['phone'] ?? '').toString().trim(),
          'phoneDisplay': formatPhoneDisplay((data['phone'] ?? '').toString()),
          'gender': memberGenderLabel(data),
          'job':
              (data['job'] ??
                      data['occupation'] ??
                      data['work'] ??
                      data['memberJob'] ??
                      '')
                  .toString()
                  .trim(),
          'totalSessions': total,
          'remainingSessions': remain,
          'nextLessonAt': nextLessonAt,
        });
      }
    }

    if (normalizedDigits.length >= 9) {
      final byPhone = await runQuery(
        _ownedMembers(
          ownerUid,
        ).where('phone', isEqualTo: normalizedDigits).limit(10),
      );

      addDocs(byPhone);
    }

    if (cleanText.isNotEmpty) {
      final byName = await runQuery(
        _ownedMembers(ownerUid).where('name', isEqualTo: cleanText).limit(10),
      );

      addDocs(byName);
    }

    return results;
  }

  static Future<Map<String, String?>?> resolveSelectedMemberLink({
    String? selectedMemberId,
    String? selectedMemberPhone,
    String? ownerUid,
  }) async {
    final cleanMemberId = selectedMemberId?.trim() ?? '';
    final cleanPhone = normalizePhone(selectedMemberPhone ?? '');

    if (cleanMemberId.isEmpty && cleanPhone.isEmpty) {
      return null;
    }

    String sessionCountText = '';

    if (cleanMemberId.isNotEmpty) {
      sessionCountText = await loadMemberSessionCountText(
        cleanMemberId,
        ownerUid: ownerUid,
      );
    }

    return {
      'memberId': cleanMemberId.isNotEmpty ? cleanMemberId : null,
      'phone': cleanPhone.isNotEmpty ? cleanPhone : null,
      'name': null,
      'sessionCountText': sessionCountText.isNotEmpty ? sessionCountText : null,
    };
  }

  static Map<String, String?> resolvedLinkFromPickedCandidate(
    Map<String, dynamic> picked,
  ) {
    if (picked['manual'] == true) {
      return {
        'memberId': null,
        'phone': null,
        'name': null,
        'sessionCountText': null,
      };
    }

    final remain = picked['remainingSessions'];
    final total = picked['totalSessions'];

    final remainValue =
        remain is num
            ? remain.toInt()
            : int.tryParse((remain ?? '').toString()) ?? 0;

    final totalValue =
        total is num
            ? total.toInt()
            : int.tryParse((total ?? '').toString()) ?? 0;

    return {
      'memberId': picked['id']?.toString(),
      'phone': normalizePhone(picked['phone']?.toString() ?? ''),
      'name': picked['name']?.toString(),

      // 기존 home_page.dart 동작 유지
      'sessionCountText': totalValue > 0 ? '$remainValue/$totalValue' : null,
    };
  }

  static Map<String, String?> emptyResolvedLink() {
    return {
      'memberId': null,
      'phone': null,
      'name': null,
      'sessionCountText': null,
    };
  }
}
