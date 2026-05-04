import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color kMemberSignPrimaryColor = Color(0xFF4F46E5);
const Color kMemberSignPrimaryColor2 = Color(0xFF9333EA);
const Color kMemberSignBgColor = Color(0xFFF3F4F6);


class MemberSignatureWebPage extends StatefulWidget {
  final String token;

  const MemberSignatureWebPage({
    super.key,
    required this.token,
  });

  @override
  State<MemberSignatureWebPage> createState() => _MemberSignatureWebPageState();
}



class _MemberSignatureWebPageState extends State<MemberSignatureWebPage> {
  final List<Offset?> _signaturePoints = [];

  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  bool _expired = false;
  bool _invalid = false;
  bool _loadingHistory = false;
  bool _isSigning = false;

  Map<String, dynamic>? _requestData;
  List<_MemberSignHistoryItem> _signatureHistory = [];

  int? _memberTotalSessions;
  int? _memberRemainingSessions;
  int? _memberDoneSessions;
  bool _reRegistrationRequested = false;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  String get _cleanToken => widget.token.trim();

  int get _safeTotalSessions => _memberTotalSessions ?? 0;

  int get _safeRemainingSessions => _memberRemainingSessions ?? 0;

  int get _safeDoneSessions {
    if (_memberDoneSessions != null) return _memberDoneSessions!;

    final total = _safeTotalSessions;
    final remain = _safeRemainingSessions;

    if (total <= 0) return _signatureHistory.length;
    return (total - remain).clamp(0, total);
  }

  int get _currentSignNumber => _safeDoneSessions + 1;

  double get _sessionProgress {
    final total = _safeTotalSessions;
    if (total <= 0) return 0;
    return (_safeDoneSessions / total).clamp(0.0, 1.0);
  }

  Color get _remainingAccentColor {
    final remain = _safeRemainingSessions;

    if (remain <= 0) return const Color(0xFF6B7280);
    if (remain <= 5) return const Color(0xFFDC2626);
    if (remain <= 10) return const Color(0xFFD97706);
    return kMemberSignPrimaryColor;
  }

  Color get _remainingSoftColor {
    final remain = _safeRemainingSessions;

    if (remain <= 0) return const Color(0xFFF3F4F6);
    if (remain <= 5) return const Color(0xFFFEF2F2);
    if (remain <= 10) return const Color(0xFFFFFBEB);
    return const Color(0xFFEEF2FF);
  }

  String get _remainingGuideText {
    final remain = _safeRemainingSessions;

    if (remain <= 0) {
      return '현재 잔여 수업이 없어요. 다음 수업 전 강사와 등록 상태를 확인해 주세요.';
    }

    if (remain <= 5) {
      return '곧 마지막 회차에 가까워져요. 수업 흐름이 끊기지 않게 다음 등록을 준비해 주세요.';
    }

    if (remain <= 10) {
      return '수업 흐름이 잘 이어지고 있어요. 재등록 시점을 미리 확인해두면 좋아요.';
    }

    return '꾸준히 잘 이어가고 있어요. 오늘의 한 걸음이 다음 변화를 만듭니다.';
  }

  bool get _shouldShowReRegistrationButton {
    return _safeRemainingSessions <= 10;
  }

  String get _motivationText {
    const messages = [
      '꾸준함은 가장 확실한 변화예요.',
      '오늘의 한 걸음이 다음 변화를 만듭니다.',
      '흔들려도 이어가면 기록이 됩니다.',
      '벽은 넘으면 디딤돌이 됩니다.',
      '좋은 수업은 오늘의 체크에서 시작돼요.',
    ];

    final seed = _safeDoneSessions % messages.length;
    return messages[seed];
  }

  Future<void> _loadRequest() async {
    if (_cleanToken.isEmpty) {
      setState(() {
        _loading = false;
        _invalid = true;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('sign_requests')
          .doc(_cleanToken)
          .get();

      final data = snap.data();

      if (!snap.exists || data == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _invalid = true;
        });
        return;
      }

      final used = data['used'] == true;
      final status = (data['status'] ?? '').toString();

      final expiresAtRaw = data['expiresAt'];
      DateTime? expiresAt;

      if (expiresAtRaw is Timestamp) {
        expiresAt = expiresAtRaw.toDate();
      } else if (expiresAtRaw is DateTime) {
        expiresAt = expiresAtRaw;
      } else if (expiresAtRaw is String) {
        expiresAt = DateTime.tryParse(expiresAtRaw);
      }

      final isExpired =
          expiresAt != null && DateTime.now().isAfter(expiresAt);

      if (!mounted) return;

      setState(() {
        _requestData = data;
        _loading = false;
        _submitted = used || status == 'signed';
        _expired = isExpired && !_submitted;
      });

      final memberId = (data['memberId'] ?? '').toString().trim();
      if (memberId.isNotEmpty) {
        await _loadMemberSessionSummary(memberId);
        await _loadSignatureHistory(memberId);
      }
    } catch (e) {
      debugPrint('회원 서명 요청 불러오기 실패: $e');

      if (!mounted) return;
      setState(() {
        _loading = false;
        _invalid = true;
      });
    }
  }

  Future<void> _loadMemberSessionSummary(String memberId) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanMemberId)
          .get();

      final data = snap.data();
      if (data == null) return;

      final sessions = data['sessions'] is Map
          ? Map<String, dynamic>.from(data['sessions'] as Map)
          : <String, dynamic>{};

      final remainRaw = data['remainSessions'] ??
          data['remainingSessions'] ??
          sessions['remain'] ??
          data['remainingPt'] ??
          data['ptRemaining'];

      final totalRaw = data['totalSessions'] ??
          sessions['total'] ??
          data['sessionTotal'];

      final doneRaw = data['doneSessions'] ?? sessions['done'];

      final remain = remainRaw is num
          ? remainRaw.toInt()
          : int.tryParse((remainRaw ?? '').toString());

      final total = totalRaw is num
          ? totalRaw.toInt()
          : int.tryParse((totalRaw ?? '').toString());

      final done = doneRaw is num
          ? doneRaw.toInt()
          : int.tryParse((doneRaw ?? '').toString());

      if (!mounted) return;

      setState(() {
        _memberRemainingSessions = remain;
        _memberTotalSessions = total;

        if (done != null) {
          _memberDoneSessions = done;
        } else if (total != null && remain != null) {
          _memberDoneSessions = (total - remain).clamp(0, total);
        }
      });
    } catch (e) {
      debugPrint('회원 회차 요약 불러오기 실패: $e');
    }
  }

  Future<void> _loadSignatureHistory(String memberId) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    if (mounted) {
      setState(() {
        _loadingHistory = true;
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('training_logs')
          .where('memberId', isEqualTo: cleanMemberId)
          .where('memberSigned', isEqualTo: true)
          .get();

      final rawItems = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final memberSignature = data['memberSignature'];
        if (memberSignature is! Map) continue;

        final signedAt = _dateFromAny(memberSignature['signedAt']) ??
            _dateFromAny(data['signedAt']) ??
            _dateFromAny(data['startAt']);

        if (signedAt == null) continue;

        final startAt = _dateFromAny(data['startAt']) ?? signedAt;

        rawItems.add({
          'id': doc.id,
          'signedAt': signedAt,
          'startAt': startAt,
          'title': (data['title'] ?? data['logTitle'] ?? '수업 서명').toString(),
          'lessonType': (data['lessonType'] ?? data['type'] ?? '수업').toString(),
          'sessionStatus': (data['sessionStatus'] ?? 'completed').toString(),
        });
      }

      rawItems.sort((a, b) {
        final aStart = a['startAt'] as DateTime;
        final bStart = b['startAt'] as DateTime;
        return aStart.compareTo(bStart);
      });

      final numbered = <_MemberSignHistoryItem>[];

      for (int i = 0; i < rawItems.length; i++) {
        final item = rawItems[i];

        numbered.add(
          _MemberSignHistoryItem(
            number: i + 1,
            title: item['title'] as String,
            lessonType: item['lessonType'] as String,
            statusLabel: _statusLabelFromRaw(item['sessionStatus'] as String),
            signedAt: item['signedAt'] as DateTime,
          ),
        );
      }

      numbered.sort((a, b) => b.number.compareTo(a.number));

      if (!mounted) return;

      setState(() {
        _signatureHistory = numbered;
        _loadingHistory = false;
      });
    } catch (e) {
      debugPrint('회원 서명 내역 불러오기 실패: $e');

      if (!mounted) return;

      setState(() {
        _loadingHistory = false;
      });
    }
  }

  String _formatDateTime(dynamic raw) {
    DateTime? value;

    if (raw is Timestamp) {
      value = raw.toDate();
    } else if (raw is DateTime) {
      value = raw;
    } else if (raw is String) {
      value = DateTime.tryParse(raw);
    }

    if (value == null) return '-';

    final month = value.month;
    final day = value.day;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$month월 $day일 $hour:$minute';
  }

  DateTime? _dateFromAny(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _shortDateTimeLabel(DateTime value) {
    final month = value.month;
    final day = value.day;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$month월 $day일 $hour:$minute';
  }

  String _statusLabelFromRaw(String raw) {
    switch (raw) {
      case 'service':
        return '서비스';
      case 'no_show_deducted':
        return '노쇼 차감';
      case 'no_show_not_deducted':
        return '노쇼 미차감';
      case 'completed':
      default:
        return '출석완료';
    }
  }

  List<Map<String, double>?> _signaturePointsToJson(List<Offset?> points) {
    return points.map((point) {
      if (point == null) return null;

      return {
        'x': point.dx,
        'y': point.dy,
      };
    }).toList();
  }

  bool get _hasSignature {
    return _signaturePoints.whereType<Offset>().isNotEmpty;
  }

  Future<void> _submitSignature() async {
    if (_submitting) return;

    if (!_hasSignature) {
      _showToast('서명을 먼저 입력해주세요.');
      return;
    }

    final data = _requestData;
    if (data == null) {
      _showToast('서명 요청 정보를 찾지 못했어요.');
      return;
    }

    final token = _cleanToken;
    final trainingLogId = (data['trainingLogId'] ?? '').toString().trim();
    final memberId = (data['memberId'] ?? '').toString().trim();

    if (token.isEmpty || trainingLogId.isEmpty || memberId.isEmpty) {
      _showToast('서명 요청 정보가 올바르지 않아요.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    final now = DateTime.now();
    final requestRef =
    FirebaseFirestore.instance.collection('sign_requests').doc(token);
    final logRef =
    FirebaseFirestore.instance.collection('training_logs').doc(trainingLogId);

    final signaturePayload = {
      'type': 'drawing',
      'points': _signaturePointsToJson(List<Offset?>.from(_signaturePoints)),
      'signedAt': Timestamp.fromDate(now),
      'signedBy': 'member_web',
    };

    try {
      bool alreadySigned = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final requestSnap = await transaction.get(requestRef);
        final requestData = requestSnap.data();

        if (!requestSnap.exists || requestData == null) {
          throw Exception('서명 요청을 찾지 못했어요.');
        }

        final used = requestData['used'] == true;
        final status = (requestData['status'] ?? '').toString();

        if (used || status == 'signed') {
          alreadySigned = true;
          return;
        }

        final expiresAtRaw = requestData['expiresAt'];
        DateTime? expiresAt;

        if (expiresAtRaw is Timestamp) {
          expiresAt = expiresAtRaw.toDate();
        } else if (expiresAtRaw is DateTime) {
          expiresAt = expiresAtRaw;
        } else if (expiresAtRaw is String) {
          expiresAt = DateTime.tryParse(expiresAtRaw);
        }

        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          throw Exception('서명 요청이 만료되었어요.');
        }

        final logSnap = await transaction.get(logRef);
        final logData = logSnap.data() ?? <String, dynamic>{};

        final trainerSigned = logData['trainerSigned'] == true;
        final existingMemberSigned = logData['memberSigned'] == true;

        final sessionStatus = (logData['sessionStatus'] ??
            requestData['sessionStatus'] ??
            'completed')
            .toString();

        transaction.set(
          requestRef,
          {
            'status': 'signed',
            'used': true,
            'signedAt': Timestamp.fromDate(now),
            'memberSignature': signaturePayload,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        final baseLogPayload = <String, dynamic>{
          'id': trainingLogId,
          'memberId': memberId,
          'memberName': (requestData['memberName'] ?? '회원').toString(),
          if ((requestData['memberPhone'] ?? '').toString().trim().isNotEmpty)
            'memberPhone': requestData['memberPhone'],
          if ((requestData['scheduleDocId'] ?? '').toString().trim().isNotEmpty)
            'scheduleDocId': requestData['scheduleDocId'],
          'source': 'member_signature_web',
          'quickSignedOnly': true,
          'isQuickSignLog': true,
          'inputMethod': 'quick_sign',
          'title': '빠른 서명',
          'logTitle': '빠른 서명',
          'type': (requestData['lessonType'] ?? 'PT수업').toString(),
          'lessonType': (requestData['lessonType'] ?? 'PT수업').toString(),
          'sessionStatus': sessionStatus,
          'sessionStatusLabel': sessionStatus == 'completed'
              ? '출석완료'
              : (requestData['sessionStatusLabel'] ?? '').toString(),
          'startAt': requestData['startAt'],
          'endAt': requestData['endAt'],
          'date': _dateTextFromAny(requestData['startAt']),
          'time': _timeTextFromAny(requestData['startAt']),
          'memo': (logData['memo'] ?? '').toString(),
          'publicMemo': '',
          'memberSignature': signaturePayload,
          'memberSig': '[drawing]',
          'customerSig': '[drawing]',
          'memberSigned': true,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!logSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        };

        baseLogPayload['memberSignedAt'] = Timestamp.fromDate(now);
        baseLogPayload['waitingTrainerConfirm'] = true;

        transaction.set(
          logRef,
          baseLogPayload,
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;

      setState(() {
        _submitted = true;
        _submitting = false;
      });

      if (alreadySigned) {
        _showToast('이미 완료된 서명 요청이에요.');
      } else {
        _showToast('서명이 완료되었어요. 강사 확인 후 수업에 반영됩니다.');
      }
    } catch (e) {
      debugPrint('회원 웹서명 저장 실패: $e');

      if (!mounted) return;
      setState(() {
        _submitting = false;
      });

      _showToast('서명 저장에 실패했어요. 강사에게 다시 요청해주세요.');
    }
  }

  String _dateTextFromAny(dynamic raw) {
    DateTime? value;

    if (raw is Timestamp) {
      value = raw.toDate();
    } else if (raw is DateTime) {
      value = raw;
    } else if (raw is String) {
      value = DateTime.tryParse(raw);
    }

    value ??= DateTime.now();

    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _timeTextFromAny(dynamic raw) {
    DateTime? value;

    if (raw is Timestamp) {
      value = raw.toDate();
    } else if (raw is DateTime) {
      value = raw;
    } else if (raw is String) {
      value = DateTime.tryParse(raw);
    }

    value ??= DateTime.now();

    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _requestReRegistrationConsult() async {
    if (_reRegistrationRequested) {
      _showToast('이미 다음 등록 준비 요청을 보냈어요.');
      return;
    }

    final data = _requestData;
    if (data == null) {
      _showToast('회원 정보를 찾지 못했어요.');
      return;
    }

    final memberId = (data['memberId'] ?? '').toString().trim();
    final memberName = (data['memberName'] ?? '회원').toString().trim();

    if (memberId.isEmpty) {
      _showToast('회원 연결 정보를 찾지 못했어요.');
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('re_registration_requests').add({
        'memberId': memberId,
        'memberName': memberName.isEmpty ? '회원' : memberName,
        if ((data['memberPhone'] ?? '').toString().trim().isNotEmpty)
          'memberPhone': data['memberPhone'],
        'totalSessions': _safeTotalSessions,
        'remainingSessions': _safeRemainingSessions,
        'doneSessions': _safeDoneSessions,
        'status': 'requested',
        'source': 'member_signature_web',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _reRegistrationRequested = true;
      });

      _showToast('다음 등록 준비 요청을 보냈어요.');
    } catch (e) {
      debugPrint('재등록 요청 실패: $e');
      _showToast('요청을 보내지 못했어요. 강사에게 직접 문의해주세요.');
    }
  }

  void _showToast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: kMemberSignBgColor,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildInvalid({
    required String title,
    required String body,
  }) {
    return Scaffold(
      backgroundColor: kMemberSignBgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 38,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final memberName = (data['memberName'] ?? '회원').toString();
    final lessonType = (data['lessonType'] ?? '수업').toString();
    final startLabel = _formatDateTime(data['startAt']);

    final total = _safeTotalSessions;
    final done = _safeDoneSessions;
    final remain = _safeRemainingSessions;

    final summaryText = total > 0
        ? '$lessonType 총 ${total}회 중 ${done}회 진행'
        : '$lessonType 수업 진행 중';

    final remainText = total > 0 ? '잔여 ${remain}회' : '회차정보 확인 중';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kMemberSignPrimaryColor, kMemberSignPrimaryColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Than Fitness',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '회원 서명',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$memberName 님',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        remainText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.fitness_center_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _sessionProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.16),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white70,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$startLabel · $lessonType',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _motivationText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox() {
    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            setState(() {
              _isSigning = true;
              _signaturePoints.add(event.localPosition);
            });
          },
          onPointerMove: (event) {
            setState(() {
              _signaturePoints.add(event.localPosition);
            });
          },
          onPointerUp: (_) {
            setState(() {
              _signaturePoints.add(null);
              _isSigning = false;
            });
          },
          onPointerCancel: (_) {
            setState(() {
              _signaturePoints.add(null);
              _isSigning = false;
            });
          },
          child: CustomPaint(
            painter: _MemberWebSignaturePainter(_signaturePoints),
            child: _hasSignature
                ? const SizedBox.expand()
                : const Center(
              child: Text(
                '여기에 손서명해주세요',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReRegistrationGuideCard() {
    if (!_shouldShowReRegistrationButton) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _remainingSoftColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _remainingAccentColor.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _safeRemainingSessions <= 0
                    ? Icons.error_outline_rounded
                    : Icons.event_available_rounded,
                color: _remainingAccentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _safeRemainingSessions <= 0
                      ? '등록 확인이 필요해요'
                      : '다음 등록을 준비하기 좋은 시점이에요',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: _remainingAccentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _remainingGuideText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.42,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
              _reRegistrationRequested ? null : _requestReRegistrationConsult,
              style: FilledButton.styleFrom(
                backgroundColor: _remainingAccentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _reRegistrationRequested ? '요청 완료' : '다음 등록 준비하기',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureHistorySection() {
    if (_loadingHistory) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              '서명 내역을 불러오는 중이에요.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    if (_signatureHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '아직 완료된 회원 서명이 없어요.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final visibleItems = _signatureHistory.take(6).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '지난 수업',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_safeDoneSessions}회 진행',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...visibleItems.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.number}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.number}회차 손서명 완료',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_shortDateTimeLabel(item.signedAt)} · ${item.lessonType}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _hasSignature && !_submitting ? _submitSignature : null,
        style: FilledButton.styleFrom(
          backgroundColor: kMemberSignPrimaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _submitting
            ? const SizedBox(
          width: 19,
          height: 19,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text(
          '서명 제출하기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();

    if (_invalid) {
      return _buildInvalid(
        title: '서명 요청을 찾지 못했어요',
        body: '링크가 잘못되었거나 삭제된 요청일 수 있어요. 강사에게 새 링크를 요청해주세요.',
      );
    }

    if (_expired) {
      return _buildInvalid(
        title: '서명 요청이 만료되었어요',
        body: '이 링크는 더 이상 사용할 수 없어요. 강사에게 새 서명 링크를 요청해주세요.',
      );
    }

    if (_submitted) {
      return _buildInvalid(
        title: '서명이 완료되었어요',
        body: '수업 확인 서명이 정상적으로 저장되었습니다.',
      );
    }

    final data = _requestData ?? <String, dynamic>{};

    return Scaffold(
      backgroundColor: kMemberSignBgColor,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              physics: _isSigning
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(data),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReRegistrationGuideCard(),
                        if (_shouldShowReRegistrationButton)
                          const SizedBox(height: 14),

                        Text(
                          '${_currentSignNumber}회차 수업 확인',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '수업 내용을 확인했다면 아래 칸에 손으로 서명해주세요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildSignatureBox(),

                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _signaturePoints.isEmpty
                                ? null
                                : () {
                              setState(() {
                                _signaturePoints.clear();
                                _isSigning = false;
                              });
                            },
                            child: const Text(
                              '지우기',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        _buildSubmitButton(),

                        const SizedBox(height: 18),
                        _buildSignatureHistorySection(),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSignHistoryItem {
  final int number;
  final String title;
  final String lessonType;
  final String statusLabel;
  final DateTime signedAt;

  const _MemberSignHistoryItem({
    required this.number,
    required this.title,
    required this.lessonType,
    required this.statusLabel,
    required this.signedAt,
  });
}

class _MemberWebSignaturePainter extends CustomPainter {
  final List<Offset?> points;

  const _MemberWebSignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current == null || next == null) continue;
      canvas.drawLine(current, next, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MemberWebSignaturePainter oldDelegate) {
    return true;
  }
}