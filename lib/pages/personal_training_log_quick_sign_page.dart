import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/member_smart_alarm_context_service.dart';
import '../services/more_care_slot_service.dart';
import '../services/app_tier_access_service.dart';
import '../services/member_sign_url_service.dart';
import '../widgets/personal_training_log_entry_guard.dart';
import '../theme/app_colors.dart';

const Color kQuickSignPrimaryColor = Color(0xFF4F46E5);
const Color kQuickSignPrimaryColor2 = Color(0xFF9333EA);
const Color kQuickSignBgColor = Color(0xFFF3F4F6);

enum _QuickLogMode {
  normalDeduct,
  serviceNoDeduct,
  noShowDeduct,
  noShowNoDeduct,
}

class PersonalTrainingQuickLogSignPage extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String? memberPhone;
  final String? scheduleDocId;
  final String lessonType;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? personalOwnerUid;

  const PersonalTrainingQuickLogSignPage({
    super.key,
    required this.memberId,
    required this.memberName,
    this.memberPhone,
    this.scheduleDocId,
    this.lessonType = 'PT',
    this.startAt,
    this.endAt,
    this.personalOwnerUid,
  });

  @override
  State<PersonalTrainingQuickLogSignPage> createState() =>
      _PersonalTrainingQuickLogSignPageState();
}

class _PersonalTrainingQuickLogSignPageState
    extends State<PersonalTrainingQuickLogSignPage> {
  final TextEditingController _memoC = TextEditingController();

  final List<Offset?> _trainerSignaturePoints = [];
  final List<Offset?> _memberSignaturePoints = [];

  bool _trainerSigned = false;
  bool _memberSigned = false;
  bool _saving = false;
  bool _loadingMember = true;
  bool _modeExpanded = false;
  bool _isSigning = false;
  bool _waitingTrainerConfirm = false;
  bool _memberSignedFromWeb = false;
  bool _quickLogLocked = false;
  bool _quickLogDeductionApplied = false;
  bool _entryAccessResolved = false;
  bool _entryAccessAllowed = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _quickLogSub;

  DateTime? _trainerSignedAt;
  DateTime? _memberSignedAt;

  int? _remainingSessions;
  int? _totalSessions;
  int? _doneSessions;

  bool _hasContractLinked = false;
  String? _contractId;

  _QuickLogMode _mode = _QuickLogMode.normalDeduct;

  @override
  void initState() {
    super.initState();
    if (_personalOwnerUid.isEmpty) {
      _entryAccessResolved = true;
      _entryAccessAllowed = true;
      _startQuickSignData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolvePersonalEntryAccess();
      });
    }
  }

  void _startQuickSignData() {
    _loadInitialData();
    _bindQuickLogStream();
  }

  Future<void> _resolvePersonalEntryAccess() async {
    final allowed = await PersonalTrainingLogEntryGuard.guard(
      context: context,
      ownerUid: _personalOwnerUid,
      memberId: _cleanMemberId,
      loadAccess: () => AppTierAccessService.loadPersonalTrainerAccess(
        uid: _personalOwnerUid,
      ),
      entryPoint: 'personal_training_log_quick_sign_direct_route',
    );
    if (!mounted) return;
    setState(() {
      _entryAccessResolved = true;
      _entryAccessAllowed = allowed;
    });
    if (!allowed) {
      Navigator.of(context).maybePop();
      return;
    }
    _startQuickSignData();
  }

  @override
  void dispose() {
    _quickLogSub?.cancel();
    _memoC.dispose();
    super.dispose();
  }

  String get _cleanMemberId => widget.memberId.trim();

  String get _personalOwnerUid => widget.personalOwnerUid?.trim() ?? '';

  String get _cleanMemberName {
    final value = widget.memberName.trim();
    return value.isEmpty ? '회원' : value;
  }

  String get _cleanPhone {
    return (widget.memberPhone ?? '').replaceAll(RegExp(r'\D'), '');
  }

  int get _safeTotalSessions => _totalSessions ?? 0;

  int get _safeRemainingSessions => _remainingSessions ?? 0;

  int get _safeDoneSessions {
    if (_doneSessions != null) return _doneSessions!;

    final total = _safeTotalSessions;
    final remain = _safeRemainingSessions;

    if (total <= 0) return 0;
    return (total - remain).clamp(0, total);
  }

  String get _motivationText {
    const messages = [
      '꾸준함은 가장 확실한 변화예요.',
      '오늘의 한 걸음이 다음 변화를 만듭니다.',
      '흔들려도 이어가면 기록이 됩니다.',
      '벽은 넘으면 디딤돌이 됩니다.',
      '좋은 레슨은 오늘의 체크에서 시작돼요.',
    ];

    final seed = _safeDoneSessions % messages.length;
    return messages[seed];
  }

  DateTime get _effectiveStartAt {
    return widget.startAt ?? DateTime.now();
  }

  DateTime get _effectiveEndAt {
    return widget.endAt ?? _effectiveStartAt.add(const Duration(minutes: 50));
  }

  bool get _requiresMemberSignature {
    switch (_mode) {
      case _QuickLogMode.normalDeduct:
      case _QuickLogMode.serviceNoDeduct:
        return true;
      case _QuickLogMode.noShowDeduct:
      case _QuickLogMode.noShowNoDeduct:
        return false;
    }
  }

  bool get _shouldDeduct {
    switch (_mode) {
      case _QuickLogMode.normalDeduct:
      case _QuickLogMode.noShowDeduct:
        return true;
      case _QuickLogMode.serviceNoDeduct:
      case _QuickLogMode.noShowNoDeduct:
        return false;
    }
  }

  String get _modeLabel {
    switch (_mode) {
      case _QuickLogMode.normalDeduct:
        return '출석완료';
      case _QuickLogMode.serviceNoDeduct:
        return '서비스 레슨';
      case _QuickLogMode.noShowDeduct:
        return '노쇼(차감)';
      case _QuickLogMode.noShowNoDeduct:
        return '노쇼(미차감)';
    }
  }

  String get _modeHelperLabel {
    switch (_mode) {
      case _QuickLogMode.normalDeduct:
        return '저장 시 잔여 레슨 소진';
      case _QuickLogMode.serviceNoDeduct:
        return '저장 시 잔여 레슨 유지';
      case _QuickLogMode.noShowDeduct:
        return '강사 서명만으로 차감';
      case _QuickLogMode.noShowNoDeduct:
        return '강사 서명만으로 미차감';
    }
  }

  String get _modeStatusCode {
    switch (_mode) {
      case _QuickLogMode.normalDeduct:
        return 'completed';
      case _QuickLogMode.serviceNoDeduct:
        return 'service';
      case _QuickLogMode.noShowDeduct:
        return 'no_show_deducted';
      case _QuickLogMode.noShowNoDeduct:
        return 'no_show_not_deducted';
    }
  }

  String? get _scheduleAttendanceOverride {
    switch (_mode) {
      case _QuickLogMode.noShowDeduct:
        return 'no_show_deducted';
      case _QuickLogMode.noShowNoDeduct:
        return 'no_show_not_deducted';
      case _QuickLogMode.normalDeduct:
      case _QuickLogMode.serviceNoDeduct:
        return null;
    }
  }

  bool get _isQuickLogConfirmed {
    return _quickLogLocked || _quickLogDeductionApplied;
  }

  bool get _isModeLockedBySignature {
    return _trainerSigned ||
        _memberSigned ||
        _memberSignedFromWeb ||
        _waitingTrainerConfirm ||
        _isQuickLogConfirmed;
  }

  bool get _canSave {
    if (_saving) return false;
    if (_isQuickLogConfirmed) return false;
    if (!_trainerSigned) return false;
    if (_requiresMemberSignature && !_memberSigned) return false;
    return true;
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadMemberSummary(),
      _loadExistingQuickLog(),
    ]);

    if (!mounted) return;
    setState(() {
      _loadingMember = false;
    });
  }

  Future<void> _loadMemberSummary() async {
    final cleanId = _cleanMemberId;
    if (cleanId.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanId)
          .get();

      final data = snap.data();
      if (data == null) return;

      final sessions = data['sessions'] is Map
          ? Map<String, dynamic>.from(data['sessions'] as Map)
          : <String, dynamic>{};

      final lessonSync = data['lessonSync'] is Map
          ? Map<String, dynamic>.from(data['lessonSync'] as Map)
          : <String, dynamic>{};

      final loadedContractId =
          (lessonSync['contractId'] ?? '').toString().trim();

      final loadedHasContract =
          data['contractSigned'] == true || loadedContractId.isNotEmpty;

      final remainRaw = data['remainSessions'] ??
          data['remainingSessions'] ??
          sessions['remain'] ??
          data['remainingPt'] ??
          data['ptRemaining'];

      final totalRaw =
          data['totalSessions'] ?? sessions['total'] ?? data['sessionTotal'];

      final doneRaw = data['doneSessions'] ?? sessions['done'];

      if (!mounted) return;

      setState(() {
        _remainingSessions = remainRaw is num
            ? remainRaw.toInt()
            : int.tryParse((remainRaw ?? '').toString());

        _totalSessions = totalRaw is num
            ? totalRaw.toInt()
            : int.tryParse((totalRaw ?? '').toString());

        _doneSessions = doneRaw is num
            ? doneRaw.toInt()
            : int.tryParse((doneRaw ?? '').toString());

        _hasContractLinked = loadedHasContract;
        _contractId = loadedContractId.isEmpty ? null : loadedContractId;
      });
    } catch (e) {
      debugPrint('빠른 서명 회원 회차 불러오기 실패: $e');
    }
  }

  Future<void> _loadExistingQuickLog() async {
    final logId = _buildLogId();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('training_logs')
          .doc(logId)
          .get();

      final data = snap.data();
      if (data == null) return;

      final trainerSignature = data['trainerSignature'];
      final memberSignature = data['memberSignature'];

      final trainerPoints = trainerSignature is Map
          ? _signaturePointsFromJson(trainerSignature['points'])
          : <Offset?>[];

      final memberPoints = memberSignature is Map
          ? _signaturePointsFromJson(memberSignature['points'])
          : <Offset?>[];

      final trainerSignedAt = trainerSignature is Map
          ? _dateFromAny(trainerSignature['signedAt'])
          : null;

      final memberSignedAt = memberSignature is Map
          ? _dateFromAny(memberSignature['signedAt'])
          : null;

      final memo = (data['memo'] ?? '').toString();

      final status = (data['sessionStatus'] ?? '').toString();

      if (!mounted) return;
      _applyQuickLogData(data);
    } catch (e) {
      debugPrint('기존 빠른 서명 로그 불러오기 실패: $e');
    }
  }

  void _applyQuickLogData(Map<String, dynamic> data) {
    final trainerSignature = data['trainerSignature'];
    final memberSignature = data['memberSignature'];

    final trainerPoints = trainerSignature is Map
        ? _signaturePointsFromJson(trainerSignature['points'])
        : <Offset?>[];

    final memberPoints = memberSignature is Map
        ? _signaturePointsFromJson(memberSignature['points'])
        : <Offset?>[];

    final trainerSignedAt = trainerSignature is Map
        ? _dateFromAny(trainerSignature['signedAt'])
        : null;

    final memberSignedAt = memberSignature is Map
        ? _dateFromAny(memberSignature['signedAt'])
        : null;

    final memo = (data['memo'] ?? '').toString();
    final status = (data['sessionStatus'] ?? '').toString();

    setState(() {
      if (trainerPoints.isNotEmpty) {
        _trainerSignaturePoints
          ..clear()
          ..addAll(trainerPoints);
        _trainerSigned = data['trainerSigned'] == true;
        _trainerSignedAt = trainerSignedAt;
      }

      if (memberPoints.isNotEmpty) {
        _memberSignaturePoints
          ..clear()
          ..addAll(memberPoints);
        _memberSigned = data['memberSigned'] == true;
        _memberSignedAt = memberSignedAt;
        _memberSignedFromWeb = memberSignature is Map &&
            (memberSignature['signedBy'] ?? '').toString() == 'member_web';
      }

      _waitingTrainerConfirm = data['waitingTrainerConfirm'] == true;
      _quickLogLocked = data['locked'] == true;
      _quickLogDeductionApplied = data['deductionApplied'] == true;

      if (memo.isNotEmpty && _memoC.text.trim().isEmpty) {
        _memoC.text = memo;
      }

      switch (status) {
        case 'service':
          _mode = _QuickLogMode.serviceNoDeduct;
          break;
        case 'no_show_deducted':
          _mode = _QuickLogMode.noShowDeduct;
          break;
        case 'no_show_not_deducted':
          _mode = _QuickLogMode.noShowNoDeduct;
          break;
        default:
          _mode = _QuickLogMode.normalDeduct;
      }
    });
  }

  void _bindQuickLogStream() {
    final logId = _buildLogId();

    _quickLogSub?.cancel();
    _quickLogSub = FirebaseFirestore.instance
        .collection('training_logs')
        .doc(logId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (!mounted || data == null) return;

      _applyQuickLogData(data);
    });
  }

  String _dateLabel(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _timeLabel(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _displayDateLabel(DateTime value) {
    return '${value.month}월 ${value.day}일';
  }

  String _displayTimeRangeLabel() {
    return '${_timeLabel(_effectiveStartAt)} ~ ${_timeLabel(_effectiveEndAt)}';
  }

  String _buildLogId() {
    final scheduleDocId = (widget.scheduleDocId ?? '').trim();

    if (scheduleDocId.isNotEmpty) {
      return 'quick_sign_$scheduleDocId';
    }

    final start = _effectiveStartAt;
    final y = start.year.toString().padLeft(4, '0');
    final m = start.month.toString().padLeft(2, '0');
    final d = start.day.toString().padLeft(2, '0');
    final h = start.hour.toString().padLeft(2, '0');
    final min = start.minute.toString().padLeft(2, '0');

    return 'quick_sign_${_cleanMemberId}_${y}${m}${d}_$h$min';
  }

  String _buildDeductionKey(String logId) {
    return 'personal_training_quick_log:$logId';
  }

  void _showToast(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) {
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 90,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withOpacity(0.94),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 1500), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  String _generateMemberSignToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random.secure();

    return List.generate(
      32,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _buildMemberSignUrl(String token) {
    return MemberSignUrlService.build(token).toString();
  }

  Future<Map<String, String>?> _createMemberSignRequest() async {
    if (_isQuickLogConfirmed) {
      _showToast('이미 확정했습니다');
      return null;
    }

    final cleanMemberId = _cleanMemberId;
    if (cleanMemberId.isEmpty) {
      _showToast('연결된 회원이 없어 서명 요청을 만들 수 없어요.');
      return null;
    }

    final token = _generateMemberSignToken();
    final link = _buildMemberSignUrl(token);
    final logId = _buildLogId();

    await FirebaseFirestore.instance
        .collection('sign_requests')
        .doc(token)
        .set({
      'token': token,
      'status': 'waiting_member_signature',
      'used': false,
      'memberId': cleanMemberId,
      'memberName': _cleanMemberName,
      if (_cleanPhone.isNotEmpty) 'memberPhone': _cleanPhone,
      if ((widget.scheduleDocId ?? '').trim().isNotEmpty)
        'scheduleDocId': widget.scheduleDocId!.trim(),
      'trainingLogId': logId,
      'lessonType': widget.lessonType,
      'startAt': Timestamp.fromDate(_effectiveStartAt),
      'endAt': Timestamp.fromDate(_effectiveEndAt),
      'requestType': 'member_signature',
      'source': 'quick_sign_page',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    }, SetOptions(merge: true));

    return {
      'token': token,
      'link': link,
      'trainingLogId': logId,
    };
  }

  Future<void> _openMemberSignRequestSheet() async {
    final result = await _createMemberSignRequest();

    if (!mounted || result == null) return;

    final link = result['link'] ?? '';
    if (link.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '회원 서명 요청',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_cleanMemberName 님에게 QR 또는 링크로 서명을 요청할 수 있어요.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      size: 210,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: link),
                            );

                            _showToast('서명 링크를 복사했어요.');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
                            '링크 복사',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kQuickSignPrimaryColor,
                            side: BorderSide(
                              color: kQuickSignPrimaryColor.withOpacity(0.25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text(
                            '완료',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: kQuickSignPrimaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  List<Offset?> _signaturePointsFromJson(dynamic raw) {
    if (raw is! List) return <Offset?>[];

    return raw.map<Offset?>((item) {
      if (item == null) return null;
      if (item is! Map) return null;

      final x = item['x'];
      final y = item['y'];

      final dx =
          x is num ? x.toDouble() : double.tryParse((x ?? '').toString());
      final dy =
          y is num ? y.toDouble() : double.tryParse((y ?? '').toString());

      if (dx == null || dy == null) return null;
      return Offset(dx, dy);
    }).toList();
  }

  String _signedAtLabel(DateTime? value) {
    if (value == null) return '';

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second 완료';
  }

  DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _requestMoreCareSlotAfterQuickSignSaved() async {
    final memberId = _cleanMemberId.trim();

    if (memberId.isEmpty) return;

    try {
      final decision = await MoreCareSlotService.requestTemporarySlotForMember(
        memberId: memberId,
        reason: 'quick_sign_log_saved',
      );

      if (!mounted) return;

      if (decision.canUseAdvancedMoreCare &&
          decision.status == MoreCareSlotStatus.temporary) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'MORE 관리도 잠시 열어두었어요. 관리자에게 승인 요청을 보내둘게요.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      debugPrint('[MTF_MORE_SLOT] quick sign slot request failed: $e');
    }
  }

  Future<void> _saveQuickSignedLog() async {
    if (_saving) return;

    final memoText = _memoC.text.trim();

    final trainerSignaturePoints = List<Offset?>.from(_trainerSignaturePoints);
    final memberSignaturePoints = List<Offset?>.from(_memberSignaturePoints);

    if (_cleanMemberId.isEmpty) {
      _showToast('연결된 회원이 없어 빠른 서명을 저장할 수 없어요.');
      return;
    }

    if (!_trainerSigned || trainerSignaturePoints.isEmpty) {
      _showToast('강사 서명을 먼저 완료해주세요.');
      return;
    }

    if (_requiresMemberSignature &&
        (!_memberSigned || memberSignaturePoints.isEmpty)) {
      _showToast('회원 서명을 먼저 완료해주세요.');
      return;
    }

    setState(() {
      _saving = true;
    });

    final now = DateTime.now();
    final logId = _buildLogId();
    final deductionKey = _buildDeductionKey(logId);

    final memberRef =
        FirebaseFirestore.instance.collection('members').doc(_cleanMemberId);

    final logRef =
        FirebaseFirestore.instance.collection('training_logs').doc(logId);

    final scheduleDocId = (widget.scheduleDocId ?? '').trim();
    final scheduleRef = scheduleDocId.isEmpty
        ? null
        : FirebaseFirestore.instance.collection('schedules').doc(scheduleDocId);

    try {
      bool alreadyDeducted = false;
      bool actuallyDeducted = false;
      bool noRemaining = false;
      int? nextRemainForMessage;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final memberSnap = await transaction.get(memberRef);
        final logSnap = await transaction.get(logRef);

        if (!memberSnap.exists) {
          throw Exception('회원 문서를 찾지 못했어요.');
        }

        final memberData = memberSnap.data() ?? <String, dynamic>{};

        final sessions = memberData['sessions'] is Map
            ? Map<String, dynamic>.from(memberData['sessions'] as Map)
            : <String, dynamic>{};

        final deductedRaw = memberData['deductedTrainingLogIds'];

        final deductedIds = deductedRaw is List
            ? deductedRaw.map((e) => e.toString()).toSet()
            : <String>{};

        final existingLogData = logSnap.data();
        final existingDeductionApplied =
            existingLogData?['deductionApplied'] == true;

        alreadyDeducted =
            deductedIds.contains(deductionKey) || existingDeductionApplied;

        final rawRemain = memberData['remainSessions'] ??
            memberData['remainingSessions'] ??
            sessions['remain'] ??
            memberData['remainingPt'] ??
            memberData['ptRemaining'];

        final rawDone = memberData['doneSessions'] ?? sessions['done'];
        final rawTotal = memberData['totalSessions'] ??
            sessions['total'] ??
            memberData['sessionTotal'];

        final currentRemain = rawRemain is num
            ? rawRemain.toInt()
            : int.tryParse((rawRemain ?? '').toString()) ?? 0;

        final currentDone = rawDone is num
            ? rawDone.toInt()
            : int.tryParse((rawDone ?? '').toString()) ?? 0;
        final currentTotal = rawTotal is num
            ? rawTotal.toInt()
            : int.tryParse((rawTotal ?? '').toString()) ?? 0;

        int nextRemain = currentRemain;
        int nextDone = currentDone;

        if (_shouldDeduct && !alreadyDeducted) {
          if (currentRemain > 0) {
            nextRemain = currentRemain - 1;
            nextDone = currentDone + 1;
            actuallyDeducted = true;
          } else {
            noRemaining = true;
          }
        }

        nextRemainForMessage = nextRemain;

        final logPayload = <String, dynamic>{
          'id': logId,
          if (_personalOwnerUid.isNotEmpty) ...{
            'lessonLogId': logId,
            'trainerId': _personalOwnerUid,
            'workspaceType': 'personal',
          },
          'memberId': _cleanMemberId,
          'memberName': _cleanMemberName,
          'memberNameSnapshot': _cleanMemberName,
          if (_cleanPhone.isNotEmpty) 'memberPhone': _cleanPhone,
          if (scheduleDocId.isNotEmpty) 'scheduleDocId': scheduleDocId,
          'source': 'personal_training_quick_sign_page',
          'quickSignedOnly': true,
          'basis': _hasContractLinked ? 'contract' : 'manual',
          'contractLinked': _hasContractLinked,
          if (_contractId != null && _contractId!.isNotEmpty)
            'contractId': _contractId,
          if (_hasContractLinked) 'cancelLockedByContract': true,
          if (_hasContractLinked)
            'cancelLockContractReason': 'contract_linked_lesson_confirm',
          'title': _mode == _QuickLogMode.normalDeduct
              ? '빠른 서명'
              : '빠른 서명 · $_modeLabel',
          'logTitle': _mode == _QuickLogMode.normalDeduct
              ? '빠른 서명'
              : '빠른 서명 · $_modeLabel',
          'name': _cleanMemberName,
          'type': widget.lessonType,
          'lessonType': widget.lessonType,
          'inputMethod': 'quick_sign',
          'isQuickSignLog': true,
          'sessionStatus': _modeStatusCode,
          'status': _modeStatusCode,
          'sessionStatusLabel': _modeLabel,
          'memo': memoText,
          'publicMemo': '',
          'date': _dateLabel(_effectiveStartAt),
          'time': _timeLabel(_effectiveStartAt),
          'startAt': Timestamp.fromDate(_effectiveStartAt),
          'endAt': Timestamp.fromDate(_effectiveEndAt),
          'trainerSignature': {
            'type': 'drawing',
            'points': _signaturePointsToJson(trainerSignaturePoints),
            'signedAt': Timestamp.fromDate(_trainerSignedAt ?? now),
          },
          'memberSignature': _requiresMemberSignature
              ? {
                  'type': 'drawing',
                  'points': _signaturePointsToJson(memberSignaturePoints),
                  'signedAt': Timestamp.fromDate(_memberSignedAt ?? now),
                  'signedBy':
                      _memberSignedFromWeb ? 'member_web' : 'member_app',
                }
              : null,
          'trainerSig': '[drawing]',
          if (_requiresMemberSignature) 'memberSig': '[drawing]',
          if (_requiresMemberSignature) 'customerSig': '[drawing]',
          'trainerSigned': true,
          'memberSigned': _requiresMemberSignature,
          if (_requiresMemberSignature)
            'memberSignedAt': Timestamp.fromDate(_memberSignedAt ?? now),
          if (_requiresMemberSignature) 'cancelLockedByMemberSignature': true,
          if (_requiresMemberSignature)
            'cancelLockReason': 'member_signed_lesson_confirm',
          'waitingTrainerConfirm': false,
          'confirmedByTrainer': true,
          'confirmedAt': Timestamp.fromDate(now),
          'locked': true,
          'lockedAt': Timestamp.fromDate(now),
          'signedAt': Timestamp.fromDate(now),
          'deductionKey': deductionKey,
          'deductionTarget': _shouldDeduct,
          'deductionApplied': actuallyDeducted || alreadyDeducted,
          'deductionAlreadyApplied': alreadyDeducted,
          'deductionSkippedReason': noRemaining
              ? 'no_remaining_sessions'
              : (!_shouldDeduct ? 'not_deduction_mode' : null),
          'sessionSnapshotTotal': currentTotal,
          'sessionSnapshotRemainBefore': currentRemain,
          'sessionSnapshotRemainAfter': nextRemain,
          'sessionSnapshotDoneBefore': currentDone,
          'sessionSnapshotDoneAfter': nextDone,
          'sessionSnapshotLessonNumber': nextDone,
          'sessionSnapshotLabel': '$nextDone/$currentTotal',
          'updatedAt': FieldValue.serverTimestamp(),
          if (!logSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        };

        transaction.set(
          logRef,
          logPayload,
          SetOptions(merge: true),
        );

        final memberBaseUpdate = <String, dynamic>{
          'lastLogAt': Timestamp.fromDate(_effectiveStartAt),
          'lastLessonAt': Timestamp.fromDate(_effectiveStartAt),
          'lastLessonType': widget.lessonType,
          'lastLessonStatus': _modeStatusCode,
          'updatedAt': FieldValue.serverTimestamp(),
          'lessonStats.confirmedCount': FieldValue.increment(1),
          'lessonStats.lastConfirmStatus': _modeStatusCode,
          'lessonStats.lastConfirmedAt': Timestamp.fromDate(_effectiveStartAt),
          'lessonStats.lastLessonType': widget.lessonType,
          'lessonStats.lastBasis': _hasContractLinked ? 'contract' : 'manual',
        };

        if (_mode == _QuickLogMode.noShowDeduct) {
          memberBaseUpdate['noShowDeductedCount'] = FieldValue.increment(1);
          memberBaseUpdate['sessions.noShowDeductedCount'] =
              FieldValue.increment(1);
          memberBaseUpdate['lessonStats.noShowDeductedCount'] =
              FieldValue.increment(1);
        } else if (_mode == _QuickLogMode.noShowNoDeduct) {
          memberBaseUpdate['noShowUndeductedCount'] = FieldValue.increment(1);
          memberBaseUpdate['sessions.noShowUndeductedCount'] =
              FieldValue.increment(1);
          memberBaseUpdate['lessonStats.noShowUndeductedCount'] =
              FieldValue.increment(1);
        } else if (_mode == _QuickLogMode.serviceNoDeduct) {
          memberBaseUpdate['serviceSessionCount'] = FieldValue.increment(1);
          memberBaseUpdate['sessions.serviceSessionCount'] =
              FieldValue.increment(1);
          memberBaseUpdate['lessonStats.serviceSessionCount'] =
              FieldValue.increment(1);
        } else if (_mode == _QuickLogMode.normalDeduct) {
          memberBaseUpdate['lessonStats.completedCount'] =
              FieldValue.increment(1);
        }

        if (_shouldDeduct && !alreadyDeducted && actuallyDeducted) {
          transaction.set(
            memberRef,
            {
              ...memberBaseUpdate,
              'remainSessions': nextRemain,
              'remainingSessions': nextRemain,
              'doneSessions': nextDone,
              'sessions.remain': nextRemain,
              'sessions.done': nextDone,
              'deductedTrainingLogIds': FieldValue.arrayUnion([deductionKey]),
            },
            SetOptions(merge: true),
          );
        } else {
          transaction.set(
            memberRef,
            memberBaseUpdate,
            SetOptions(merge: true),
          );
        }

        if (scheduleRef != null) {
          final schedulePayload = <String, dynamic>{
            'quickTrainingLogId': logId,
            'lastTrainingLogId': logId,
            'lastSignedAt': Timestamp.fromDate(now),
            'lessonConfirmed': true,
            'lessonConfirmedAt': FieldValue.serverTimestamp(),
            'lessonConfirmStatus': _modeStatusCode,
            'lessonConfirmLabel': _modeLabel,
            'trainingLogId': logId,
            'basis': _hasContractLinked ? 'contract' : 'manual',
            'contractLinked': _hasContractLinked,
            if (_contractId != null && _contractId!.isNotEmpty)
              'contractId': _contractId,
            if (_hasContractLinked) 'cancelLockedByContract': true,
            if (_hasContractLinked)
              'cancelLockContractReason': 'contract_linked_lesson_confirm',
            if (_requiresMemberSignature) 'memberSigned': true,
            if (_requiresMemberSignature)
              'memberSignedAt': Timestamp.fromDate(_memberSignedAt ?? now),
            if (_requiresMemberSignature) 'cancelLockedByMemberSignature': true,
            if (_requiresMemberSignature)
              'cancelLockReason': 'member_signed_lesson_confirm',
            'updatedAt': FieldValue.serverTimestamp(),
          };

          switch (_mode) {
            case _QuickLogMode.normalDeduct:
            case _QuickLogMode.serviceNoDeduct:
              schedulePayload['attended'] = true;
              schedulePayload['attendanceOverride'] = FieldValue.delete();
              break;
            case _QuickLogMode.noShowDeduct:
              schedulePayload['attended'] = false;
              schedulePayload['attendanceOverride'] = 'no_show_deducted';
              break;
            case _QuickLogMode.noShowNoDeduct:
              schedulePayload['attended'] = false;
              schedulePayload['attendanceOverride'] = 'no_show_not_deducted';
              break;
          }

          transaction.set(
            scheduleRef,
            schedulePayload,
            SetOptions(merge: true),
          );
        }
      });

      if (!mounted) return;

      await _loadMemberSummary();

      if (alreadyDeducted) {
        _showToast('이미 잔여 레슨에 반영된 서명이에요.');
      } else if (actuallyDeducted) {
        _showToast('서명이 저장되고 레슨 1회가 진행되었어요.');
      } else if (noRemaining) {
        _showToast('서명은 저장됐지만 잔여 레슨이 0회라 소진되지 않았어요.');
      } else {
        _showToast('서명이 저장되었어요.');
      }

      if (!mounted) return;

      await _loadMemberSummary();

      await MemberSmartAlarmContextService.updateFromLessonLog(
        memberId: _cleanMemberId,
        trainingLogId: logId,
        lessonAt: _effectiveStartAt,
        summary: _mode == _QuickLogMode.normalDeduct
            ? '빠른 서명 · ${widget.lessonType}'
            : '빠른 서명 · $_modeLabel · ${widget.lessonType}',
        memo: memoText,
        conditionText: _modeStatusCode,
        painText: '',
        nextLessonHint: memoText.isNotEmpty
            ? memoText
            : (_mode == _QuickLogMode.noShowDeduct ||
                    _mode == _QuickLogMode.noShowNoDeduct
                ? '다음 레슨 일정과 노쇼 사유를 확인해 주세요.'
                : ''),
      );

      await _requestMoreCareSlotAfterQuickSignSaved();

      if (!mounted) return;

      if (alreadyDeducted) {
        _showToast('이미 잔여 레슨에 반영된 서명이에요.');
      } else if (actuallyDeducted) {
        _showToast('서명이 저장되고 레슨 1회가 진행되었어요.');
      } else if (noRemaining) {
        _showToast('서명은 저장됐지만 잔여 레슨이 0회라 소진되지 않았어요.');
      } else {
        _showToast('서명이 저장되었어요.');
      }

      await Future.delayed(const Duration(milliseconds: 450));

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('빠른 서명 레슨일지 저장 실패: $e');

      if (!mounted) return;
      _showToast('빠른 서명 저장에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildModeChip({
    required _QuickLogMode mode,
    required String label,
    required String helper,
    required IconData icon,
  }) {
    final selected = _mode == mode;

    return InkWell(
      onTap: _saving
          ? null
          : () {
              setState(() {
                _mode = mode;

                if (!_requiresMemberSignature) {
                  _memberSigned = false;
                  _memberSignedAt = null;
                }
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected
              ? kQuickSignPrimaryColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kQuickSignPrimaryColor : const Color(0xFFE5E7EB),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color:
                  selected ? kQuickSignPrimaryColor : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 18,
              color:
                  selected ? kQuickSignPrimaryColor : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? kQuickSignPrimaryColor
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _modeExpanded = !_modeExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kQuickSignPrimaryColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _modeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: kQuickSignPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _shouldDeduct ? '저장 시 잔여 레슨 소진' : '저장 시 잔여 레슨 유지',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _modeExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              heightFactor: _modeExpanded ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildModeChip(
                      mode: _QuickLogMode.normalDeduct,
                      label: '레슨 완료',
                      helper: '강사/회원 서명 후 잔여 레슨 1회 소진',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildModeChip(
                      mode: _QuickLogMode.serviceNoDeduct,
                      label: '서비스 레슨',
                      helper: '서명은 저장하지만 잔여 레슨은 소진하지 않음',
                      icon: Icons.volunteer_activism_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildModeChip(
                      mode: _QuickLogMode.noShowDeduct,
                      label: '노쇼(차감)',
                      helper: '강사 서명만으로 저장하고 잔여 레슨 1회 차감',
                      icon: Icons.person_off_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildModeChip(
                      mode: _QuickLogMode.noShowNoDeduct,
                      label: '노쇼(미차감)',
                      helper: '강사 서명만으로 저장하고 잔여 레슨은 유지',
                      icon: Icons.undo_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _motivationText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_waitingTrainerConfirm || _memberSignedFromWeb) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _waitingTrainerConfirm
                                ? '회원 웹서명 완료 · 강사 확인 후 레슨에 반영돼요'
                                : '회원 서명 완료',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox({
    required String title,
    required String helper,
    required List<Offset?> points,
    required bool signed,
    required DateTime? signedAt,
    required VoidCallback onSign,
    required VoidCallback onClear,
    required ValueChanged<Offset?> onPointAdded,
    bool enabled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Opacity(
      opacity: enabled ? 1 : 0.46,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: tokens.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: signed ? tokens.trainingLogCompleted : tokens.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IgnorePointer(
          ignoring: !enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    signed ? Icons.check_circle_rounded : Icons.draw_rounded,
                    size: 20,
                    color: signed ? const Color(0xFF059669) : scheme.secondary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (signed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _signedAtLabel(signedAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                helper,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tokens.signatureCanvasSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.contractDocumentBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: signed
                            ? null
                            : (event) {
                                setState(() {
                                  _isSigning = true;
                                });

                                final pos = event.localPosition;
                                onPointAdded(pos);
                              },
                        onPointerMove: signed
                            ? null
                            : (event) {
                                final pos = event.localPosition;
                                onPointAdded(pos);
                              },
                        onPointerUp: signed
                            ? null
                            : (_) {
                                onPointAdded(null);
                                setState(() {
                                  _isSigning = false;
                                });
                              },
                        onPointerCancel: signed
                            ? null
                            : (_) {
                                onPointAdded(null);
                                setState(() {
                                  _isSigning = false;
                                });
                              },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _QuickSignaturePainter(points),
                            child: points.whereType<Offset>().isEmpty
                                ? const Center(
                                    child: Text(
                                      '여기에 손서명해주세요',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  )
                                : const SizedBox.expand(),
                          ),
                        ),
                      ),
                      if ((_quickLogLocked || _quickLogDeductionApplied) &&
                          signed)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.54),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF111827).withOpacity(0.72),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      '확정 완료',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isQuickLogConfirmed
                          ? null
                          : (signed || points.isNotEmpty ? onClear : null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '지우기',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: signed
                          ? null
                          : () {
                              if (points.whereType<Offset>().isEmpty) {
                                _showToast('서명을 먼저 입력해주세요.');
                                return;
                              }
                              onSign();
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSecondary,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '서명 완료',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final remain = _remainingSessions;
    final total = _totalSessions;

    final countLabel = remain == null && total == null
        ? '회차정보 없음'
        : total == null
            ? '잔여 ${remain ?? 0}회'
            : '잔여 ${remain ?? 0}/$total';

    final topInset = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, topInset + 6, 18, 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '빠른 서명',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              InkWell(
                onTap: _openMemberSignRequestSheet,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 하나의 헤더 블럭
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_cleanMemberName 님',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_displayDateLabel(_effectiveStartAt)} · ${_displayTimeRangeLabel()} · ${widget.lessonType}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_loadingMember)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        countLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  if (_isModeLockedBySignature) {
                    _showToast('서명 완료 후에는 처리방식을 변경할 수 없어요.');
                    return;
                  }

                  setState(() {
                    _modeExpanded = !_modeExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fact_check_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _modeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _modeHelperLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _modeExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.topCenter,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  heightFactor: _modeExpanded ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        _buildHeaderModeChip(
                          mode: _QuickLogMode.normalDeduct,
                          label: '출석완료',
                          helper: '강사/회원 서명 후 잔여 레슨 1회 소진',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildHeaderModeChip(
                          mode: _QuickLogMode.serviceNoDeduct,
                          label: '서비스 레슨',
                          helper: '서명은 저장 후 잔여 레슨은 소진하지 않음',
                          icon: Icons.volunteer_activism_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildHeaderModeChip(
                          mode: _QuickLogMode.noShowDeduct,
                          label: '노쇼(차감)',
                          helper: '강사 서명 후 저장하고 잔여 레슨 1회 차감',
                          icon: Icons.person_off_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildHeaderModeChip(
                          mode: _QuickLogMode.noShowNoDeduct,
                          label: '노쇼(미차감)',
                          helper: '강사 서명 후 저장하고 잔여 레슨은 유지',
                          icon: Icons.undo_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderModeChip({
    required _QuickLogMode mode,
    required String label,
    required String helper,
    required IconData icon,
  }) {
    final selected = _mode == mode;

    return InkWell(
      onTap: _saving
          ? null
          : () {
              setState(() {
                _mode = mode;

                if (!_requiresMemberSignature) {
                  _memberSigned = false;
                  _memberSignedAt = null;
                }

                _modeExpanded = false;
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.70)
                : Colors.white.withOpacity(0.16),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: Colors.white,
              size: 19,
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    helper,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoSection() {
    final tokens = context.mtfThemeTokens;
    return TextField(
      controller: _memoC,
      maxLines: 2,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: '간단 메모',
        hintText: '예: 컨디션 확인, 다음 레슨 참고사항',
        filled: true,
        fillColor: tokens.trainingLogSetRow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.trainingLogSetDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.trainingLogSetDivider),
        ),
        contentPadding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      ),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildNoticeCard() {
    final text = _shouldDeduct
        ? '저장하면 레슨이 잠기고 잔여 레슨이 1회 차감돼요.'
        : '저장하면 레슨은 기록되지만 잔여 레슨은 차감되지 않아요.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color:
            _shouldDeduct ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              _shouldDeduct ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _shouldDeduct
                ? Icons.lock_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: _shouldDeduct
                ? const Color(0xFFD97706)
                : const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _shouldDeduct
                    ? const Color(0xFF92400E)
                    : const Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_entryAccessResolved || !_entryAccessAllowed) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final memberSignatureEnabled = _requiresMemberSignature;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: _isSigning
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
            child: Column(
              children: [
                _buildInfoCard(),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSignatureBox(
                        title: '강사 서명',
                        helper: '강사가 레슨 진행 또는 노쇼 처리를 확인합니다.',
                        points: _trainerSignaturePoints,
                        signed: _trainerSigned,
                        signedAt: _trainerSignedAt,
                        onPointAdded: (point) {
                          if (_trainerSigned) return;
                          setState(() {
                            _trainerSignaturePoints.add(point);
                          });
                        },
                        onSign: () {
                          setState(() {
                            _trainerSigned = true;
                            _trainerSignedAt = DateTime.now();
                          });
                        },
                        onClear: () {
                          setState(() {
                            _trainerSigned = false;
                            _trainerSignedAt = null;
                            _trainerSignaturePoints.clear();
                            _isSigning = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSignatureBox(
                        title: '회원 서명',
                        helper: !memberSignatureEnabled
                            ? '노쇼 처리에서는 회원 서명을 받지 않아도 저장할 수 있어요.'
                            : _memberSignedFromWeb
                                ? '회원이 링크로 서명을 완료했어요. 강사 서명 후 저장하면 레슨에 반영됩니다.'
                                : '회원이 레슨 참여를 확인합니다.',
                        points: _memberSignaturePoints,
                        signed: _memberSigned,
                        signedAt: _memberSignedAt,
                        enabled: memberSignatureEnabled,
                        onPointAdded: (point) {
                          if (_memberSigned) return;
                          setState(() {
                            _memberSignaturePoints.add(point);
                          });
                        },
                        onSign: () {
                          setState(() {
                            _memberSigned = true;
                            _memberSignedAt = DateTime.now();
                          });
                        },
                        onClear: () {
                          setState(() {
                            _memberSigned = false;
                            _memberSignedAt = null;
                            _memberSignaturePoints.clear();
                            _isSigning = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMemoSection(),
                      const SizedBox(height: 14),
                      _buildNoticeCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: context.mtfThemeTokens.cardSurface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .shadow
                      .withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: _isQuickLogConfirmed
                  ? () {
                      _showToast('이미 확정했습니다');
                    }
                  : (_canSave ? _saveQuickSignedLog : null),
              style: FilledButton.styleFrom(
                backgroundColor: _isQuickLogConfirmed
                    ? const Color(0xFFE5E7EB)
                    : Theme.of(context).colorScheme.secondary,
                foregroundColor: _isQuickLogConfirmed
                    ? const Color(0xFF9CA3AF)
                    : Theme.of(context).colorScheme.onSecondary,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isQuickLogConfirmed
                          ? '레슨 확정'
                          : _waitingTrainerConfirm
                              ? '강사 확인 후 레슨 반영'
                              : (_shouldDeduct ? '레슨 완료 저장' : '서명 저장하기'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSignaturePainter extends CustomPainter {
  final List<Offset?> points;

  const _QuickSignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.8;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current == null || next == null) continue;
      canvas.drawLine(current, next, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _QuickSignaturePainter oldDelegate) {
    // points 리스트를 같은 참조로 계속 쓰기 때문에 비교하면 false가 나올 수 있음.
    // 서명 패드는 입력마다 다시 그리는 게 맞다.
    return true;
  }
}
