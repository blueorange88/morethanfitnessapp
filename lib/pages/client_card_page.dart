import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mtf_app/pages/client_list_page.dart' show ClientListPage;
import 'package:mtf_app/pages/contract_page.dart';
import 'package:mtf_app/pages/personal_training_log_page.dart'
    show PersonalTrainingLogPage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtf_app/pages/training_log_consent_page.dart';

const Color kPagePrimary = Color(0xFF4F46E5);
const Color kPagePrimary2 = Color(0xFF9333EA);
const Color kPageBg = Color(0xFFF8FAFC);
const Color kPageBorder = Color(0xFFE5E7EB);
const Color kPageText = Color(0xFF111827);
const Color kPageMuted = Color(0xFF6B7280);
const Color kPageFieldBg = Color(0xFFF8FAFC);

class _MemberGradeTheme {
  final List<Color> gradient;
  final Color accent;
  final Color border;

  const _MemberGradeTheme({
    required this.gradient,
    required this.accent,
    required this.border,
  });
}

class _ContractHistoryItem {
  final String title;
  final String subtitle;
  final String badge;
  final bool isCurrent;


  const _ContractHistoryItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isCurrent,
  });
}

class ClientCardPage extends StatefulWidget {
  final String memberId;
  final bool isEditMode;

  final String? initialName;
  final String? initialPhone;
  final DateTime? initialVisitDate;
  final DateTime? initialConsultDate;

  const ClientCardPage({
    super.key,
    required this.memberId,
    this.isEditMode = false,
    this.initialName,
    this.initialPhone,
    this.initialVisitDate,
    this.initialConsultDate,
  });

  const ClientCardPage.edit({
    super.key,
    required this.memberId,
    this.initialName,
  })  : isEditMode = true,
        initialPhone = null,
        initialVisitDate = null,
        initialConsultDate = null;

  factory ClientCardPage.newMember({
    Key? key,
    required String memberId,
  }) {
    return ClientCardPage(
      key: key,
      memberId: memberId,
      isEditMode: false,
    );
  }

  const ClientCardPage.fromQuickRegistration({
    super.key,
    required this.memberId,
    required this.initialName,
    required this.initialPhone,
    this.initialVisitDate,
    this.initialConsultDate,
  }) : isEditMode = false;

  factory ClientCardPage.fromAny({
    Key? key,
    required Map<String, dynamic> member,
  }) {
    final id = (member['id'] ?? member['memberId'] ?? '').toString();
    return ClientCardPage(
      key: key,
      memberId: id,
      isEditMode: true,
      initialName: member['name'] as String?,
      initialPhone: member['phone'] as String?,
    );
  }

  @override
  State<ClientCardPage> createState() =>
      _ClientCardPageState();
}

class _ClientCardPageState
    extends State<ClientCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  Uint8List? _profileBytes;
  String? _photoUrl;

  final _nameC = TextEditingController();
  String _gender = '미입력';
  DateTime? _birthDate;
  final _birthTextC = TextEditingController();
  final _phoneC = TextEditingController();

  final _postalC = TextEditingController();
  final _addrC = TextEditingController();
  final _addrDetailC = TextEditingController();

  String _membershipGrade = 'GOLD';
  final _jobC = TextEditingController();
  String _lessonType = '미입력';
  String _memberStatus = '활성';

  bool _lessonsNotRegistered = false;
  final _totalSessionsC = TextEditingController(text: '0');
  final _remainSessionsC = TextEditingController(text: '0');

  bool _membershipNotRegistered = false;
  int? _termMonths;
  int? _customDays;
  DateTime? _passStart;
  DateTime? _passEnd;
  DateTime? _lastRegisteredAt;
  int _noShowDeductedCount = 0;
  int _noShowUndeductedCount = 0;
  int _serviceSessionCount = 0;
  int _reregisterCount = 0;
  DateTime? _lastReregisterAt;

  bool _inbodyNotProvided = false;
  final _diseaseC = TextEditingController();
  final _medicineC = TextEditingController();
  final _heightC = TextEditingController(text: '170.0');
  final _weightC = TextEditingController(text: '65.0');
  final _bfPctC = TextEditingController(text: '18.5');
  final _smmC = TextEditingController(text: '29.0');
  final _bfKgC = TextEditingController(text: '12.0');

  DateTime? _nextReservation;
  final _noteC = TextEditingController();

  DateTime? _anniversaryDate;
  final _specialEventC = TextEditingController();
  late final PageController _memoPageController;
  int _memoPageIndex = 0;

  bool _contractSigned = false;
  DateTime? _contractSignedAt;

  bool _trainingLogConsentAgreed = false;
  DateTime? _trainingLogConsentAgreedAt;

  bool _isHeaderExpanded = false;
  late final PageController _basicInfoPageController;
  int _basicInfoPageIndex = 0;
  late final PageController _memberSetupPageController;
  int _memberSetupPageIndex = 0;
  late final PageController _bodyHealthPageController;
  int _bodyHealthPageIndex = 0;

  bool _isHeaderCardFlipped = false;

  Timer? _draftTimer;
  late final String _draftKey;
  bool _isFormattingBirth = false;
  String _headerDisplayName = '';
  String _headerGroupLabel = 'MORE THAN GYM';

  bool get _isEditMode => widget.isEditMode;

  String get _pageTitle => 'MEMBERSHIP CARD';

  String get _pageSubtitle {
    if (!_isEditMode) {
      return '신규등록회원';
    }

    final name = _nameC.text.trim();
    if (name.isEmpty) {
      return '회원카드';
    }

    return '$name 님 회원카드';
  }

  int get _totalSessionValue {
    return int.tryParse(_totalSessionsC.text.trim()) ?? 0;
  }

  int get _remainSessionValue {
    return int.tryParse(_remainSessionsC.text.trim()) ?? 0;
  }

  int get _doneSessionValue {
    final total = _totalSessionValue;
    final remain = _remainSessionValue;

    if (total <= 0) return 0;
    return (total - remain).clamp(0, total);
  }

  String get _membershipProgressLabel {
    final total = _totalSessionValue;
    final done = _doneSessionValue;

    if (_lessonsNotRegistered || total <= 0) {
      return '수강권 미등록';
    }

    return '총 ${total}회 중 ${done}회 진행';
  }

  String get _membershipRemainLabel {
    final remain = _remainSessionValue;

    if (_lessonsNotRegistered || _totalSessionValue <= 0) {
      return '잔여 회차 없음';
    }

    return '잔여 ${remain}회';
  }

  @override
  void initState() {
    super.initState();

    _headerDisplayName = (widget.initialName ?? '').trim();
    _nameC.text = widget.initialName ?? '';
    _phoneC.text = widget.initialPhone ?? '';

    _basicInfoPageController = PageController();
    _memberSetupPageController = PageController();
    _bodyHealthPageController = PageController();
    _memoPageController = PageController();

    if (widget.initialVisitDate != null) {
      _membershipNotRegistered = false;
      _passStart = widget.initialVisitDate;
    }

    if (widget.initialConsultDate != null) {
      final noteText =
          '최초 방문일: ${DateFormat('yyyy-MM-dd').format(widget.initialVisitDate ?? DateTime.now())}\n'
          '상담 예정: ${DateFormat('yyyy-MM-dd').format(widget.initialConsultDate!)}';
      _noteC.text = noteText;
      _nextReservation = widget.initialConsultDate;
    }

    _draftKey = 'member_form_draft_${widget.memberId}_v6';

    if (widget.initialName == null && widget.initialPhone == null) {
      _loadDraft();
    }

    _loadFromFirestore();

    for (final c in [
      _nameC,
      _birthTextC,
      _phoneC,
      _postalC,
      _addrC,
      _addrDetailC,
      _jobC,
      _totalSessionsC,
      _remainSessionsC,
      _diseaseC,
      _medicineC,
      _heightC,
      _weightC,
      _bfPctC,
      _smmC,
      _bfKgC,
      _noteC,
      _specialEventC,
    ]) {
      c.addListener(_debouncedSave);
    }

    _birthTextC.addListener(_autoFormatBirth);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _nameC.dispose();
    _birthTextC.dispose();
    _phoneC.dispose();
    _postalC.dispose();
    _addrC.dispose();
    _addrDetailC.dispose();
    _jobC.dispose();
    _totalSessionsC.dispose();
    _remainSessionsC.dispose();
    _diseaseC.dispose();
    _medicineC.dispose();
    _heightC.dispose();
    _weightC.dispose();
    _bfPctC.dispose();
    _smmC.dispose();
    _bfKgC.dispose();
    _noteC.dispose();
    _basicInfoPageController.dispose();
    _memberSetupPageController.dispose();
    _bodyHealthPageController.dispose();
    _specialEventC.dispose();
    _memoPageController.dispose();
    super.dispose();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .get();
      if (!snap.exists || !mounted) return;

      final d = snap.data() ?? <String, dynamic>{};

      DateTime? dt(dynamic v) {
        if (v == null) return null;
        if (v is Timestamp) return v.toDate();
        if (v is String && v.isNotEmpty) {
          final s = v.length == 10 ? '${v}T00:00:00.000' : v;
          return DateTime.tryParse(s);
        }
        return null;
      }

      final sessions =
      (d['sessions'] is Map) ? Map<String, dynamic>.from(d['sessions']) : {};
      final membership =
      (d['membership'] is Map) ? Map<String, dynamic>.from(d['membership']) : {};
      final health =
      (d['health'] is Map) ? Map<String, dynamic>.from(d['health']) : {};

      String nextGroupLabel = 'MORE THAN FITNESS';
      final rawStatus = (d['memberStatus'] as String?) ?? _memberStatus;
      final groupId = (d['groupId'] as String?)?.trim();

      if (rawStatus == '휴면') {
        nextGroupLabel = '휴면회원';
      } else if (rawStatus == '만료') {
        nextGroupLabel = '만료회원';
      } else if (groupId != null && groupId.isNotEmpty) {
        try {
          final groupSnap = await FirebaseFirestore.instance
              .collection('member_groups')
              .doc(groupId)
              .get();
          if (groupSnap.exists) {
            final groupData = groupSnap.data() ?? <String, dynamic>{};
            final groupName = (groupData['name'] ?? '').toString().trim();
            if (groupName.isNotEmpty) {
              nextGroupLabel = groupName.toUpperCase();
            }
          }
        } catch (_) {}
      }

      setState(() {
        final loadedName = (d['name'] as String?) ?? '';
        if (_nameC.text.trim().isEmpty && loadedName.trim().isNotEmpty) {
          _nameC.text = loadedName;
        }
        _headerDisplayName = _nameC.text.trim();
        _headerGroupLabel = nextGroupLabel;

        _gender = _normalizeGender(d['gender'] as String?) ?? _gender;

        final birthDisplay = (d['birthDisplay'] as String?) ?? '';
        if (_birthTextC.text.isEmpty && birthDisplay.isNotEmpty) {
          _birthTextC.text = birthDisplay;
        }
        _birthDate = _parseDate(_birthTextC.text);

        final loadedPhone = (d['phone'] as String?) ?? '';
        if (_phoneC.text.trim().isEmpty && loadedPhone.isNotEmpty) {
          _phoneC.text = loadedPhone;
        }

        _postalC.text = (d['postal'] as String?) ?? _postalC.text;
        _addrC.text = (d['address'] as String?) ?? _addrC.text;
        _addrDetailC.text =
            (d['detailAddress'] as String?) ?? _addrDetailC.text;

        _membershipGrade =
            (d['membershipGrade'] as String?) ?? _membershipGrade;
        _jobC.text = (d['job'] as String?) ?? _jobC.text;
        _memberStatus = (d['memberStatus'] as String?) ?? _memberStatus;
        _lessonType = (d['lessonType'] as String?) ?? _lessonType;

        _photoUrl = d['photoUrl'] as String?;

        _lessonsNotRegistered =
            (sessions['notRegistered'] as bool?) ?? _lessonsNotRegistered;
        final rawTotalSessions =
            sessions['total'] ?? d['totalSessions'] ?? d['sessionTotal'];

        final rawRemainSessions =
            sessions['remain'] ??
                d['remainSessions'] ??
                d['remainingSessions'] ??
                d['remainingPt'] ??
                d['ptRemaining'];

        final rawDoneSessions =
            sessions['done'] ?? d['doneSessions'];

        _totalSessionsC.text = rawTotalSessions is num
            ? rawTotalSessions.toInt().toString()
            : int.tryParse((rawTotalSessions ?? '').toString())?.toString() ??
            _totalSessionsC.text;

        _remainSessionsC.text = rawRemainSessions is num
            ? rawRemainSessions.toInt().toString()
            : int.tryParse((rawRemainSessions ?? '').toString())?.toString() ??
            _remainSessionsC.text;

// doneSessions는 화면에서 직접 입력하지 않고 total - remain으로 계산하지만,
// 기존 데이터 확인용으로 fallback만 준비해 둡니다.
        if (rawDoneSessions != null &&
            _totalSessionsC.text.trim().isEmpty &&
            _remainSessionsC.text.trim().isEmpty) {
          final done = rawDoneSessions is num
              ? rawDoneSessions.toInt()
              : int.tryParse(rawDoneSessions.toString()) ?? 0;
          _totalSessionsC.text = done.toString();
          _remainSessionsC.text = '0';
        }

        _membershipNotRegistered =
            (membership['notRegistered'] as bool?) ?? _membershipNotRegistered;
        _termMonths = (membership['termMonths'] as num?)?.toInt();
        _customDays = (membership['customDays'] as num?)?.toInt();
        _passStart = dt(membership['startAt']) ?? _passStart;
        _passEnd = dt(membership['endAt']) ?? _passEnd;
        _lastRegisteredAt =
            dt(membership['lastRegisteredAt']) ?? _lastRegisteredAt;

        _noShowDeductedCount =
            (sessions['noShowDeductedCount'] as num?)?.toInt() ??
                _noShowDeductedCount;
        _noShowUndeductedCount =
            (sessions['noShowUndeductedCount'] as num?)?.toInt() ??
                _noShowUndeductedCount;
        _serviceSessionCount =
            (sessions['serviceSessionCount'] as num?)?.toInt() ??
                _serviceSessionCount;
        _reregisterCount =
            (membership['reregisterCount'] as num?)?.toInt() ?? _reregisterCount;
        _lastReregisterAt =
            dt(membership['lastReregisterAt']) ?? _lastReregisterAt;

        _inbodyNotProvided =
            (health['inbodyNotProvided'] as bool?) ?? _inbodyNotProvided;
        _diseaseC.text =
            (health['diseaseHistory'] as String?) ?? _diseaseC.text;
        _medicineC.text =
            (health['medicineHistory'] as String?) ?? _medicineC.text;

        final inbodyRaw = (health['inbody'] is Map)
            ? Map<String, dynamic>.from(health['inbody'])
            : null;
        if (inbodyRaw != null && inbodyRaw.isNotEmpty) {
          final h = inbodyRaw['heightCm'];
          if (h is num) _heightC.text = h.toString();
          final w = inbodyRaw['weightKg'];
          if (w is num) _weightC.text = w.toString();
          final bfPct = inbodyRaw['bodyFatPct'];
          if (bfPct is num) _bfPctC.text = bfPct.toString();
          final smm = inbodyRaw['skeletalMuscleKg'];
          if (smm is num) _smmC.text = smm.toString();
          final bfKg = inbodyRaw['bodyFatKg'];
          if (bfKg is num) _bfKgC.text = bfKg.toString();
        }

        _nextReservation = dt(d['nextReservationAt']) ?? _nextReservation;
        _noteC.text = (d['note'] as String?) ?? _noteC.text;

        _anniversaryDate = dt(d['anniversaryDate']) ?? _anniversaryDate;
        _specialEventC.text =
            (d['specialEvent'] as String?) ?? _specialEventC.text;

        _contractSigned = (d['contractSigned'] as bool?) ?? false;
        _contractSignedAt = dt(d['contractSignedAt']);

        _trainingLogConsentAgreed =
            (d['trainingLogConsentAgreed'] as bool?) ?? false;
        _trainingLogConsentAgreedAt = dt(d['trainingLogConsentAgreedAt']);
      });
    } catch (_) {}
  }

  void _debouncedSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _collectFormMap(includeRegisteredAt: false);

    map.remove('phone');
    map.remove('note');
    map.remove('inbody');
    map.remove('diseaseHistory');
    map.remove('medicineHistory');

    await prefs.setString(_draftKey, jsonEncode(map));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || !mounted) return;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _nameC.text = (m['name'] ?? '').toString();
        _headerDisplayName = _nameC.text.trim();

        _birthTextC.text = (m['birthDate'] ?? '').toString();
        _birthDate = _parseDate(_birthTextC.text);

        _postalC.text = (m['postal'] ?? '').toString();
        _addrC.text = (m['address'] ?? '').toString();
        _addrDetailC.text = (m['detailAddress'] ?? '').toString();

        _membershipGrade =
            (m['membershipGrade'] ?? _membershipGrade).toString();
        _jobC.text = (m['job'] ?? '').toString();
        _memberStatus = (m['memberStatus'] ?? _memberStatus).toString();
        _lessonType = (m['lessonType'] ?? _lessonType).toString();

        _lessonsNotRegistered = (m['lessonsNotRegistered'] == true);
        _totalSessionsC.text = (m['totalSessions']?.toString() ?? '0');
        _remainSessionsC.text = (m['remainSessions']?.toString() ?? '0');

        _membershipNotRegistered = (m['membershipNotRegistered'] == true);
        _termMonths =
        (m['termMonths'] is num) ? (m['termMonths'] as num).toInt() : null;
        _customDays =
        (m['customDays'] is num) ? (m['customDays'] as num).toInt() : null;
        _passStart = _parseDate(m['passStart'] as String?);
        _passEnd = _parseDate(m['passEnd'] as String?);
        _lastRegisteredAt = _parseDate(m['lastRegisteredAt'] as String?);

        _nextReservation = _parseDate(m['nextReservationDate'] as String?);

        _anniversaryDate = _parseDate(m['anniversaryDate'] as String?);
        _specialEventC.text = (m['specialEvent'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Map<String, dynamic> _collectFormMap({required bool includeRegisteredAt}) {
    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;

    return {
      'memberId': widget.memberId,
      'name': _nameC.text.trim(),
      'gender': _gender,
      'birthDate': _birthTextC.text.trim(),
      'phone': _phoneC.text.trim(),
      'postal': _postalC.text.trim(),
      'address': _addrC.text.trim(),
      'detailAddress': _addrDetailC.text.trim(),
      'membershipGrade': _membershipGrade,
      'job': _jobC.text.trim(),
      'memberStatus': _memberStatus,
      'lessonType': _lessonType,
      'lessonsNotRegistered': _lessonsNotRegistered,
      'totalSessions': total,
      'remainSessions': remain,
      'doneSessions': (total - remain).clamp(0, total),
      'membershipNotRegistered': _membershipNotRegistered,
      'termMonths': _termMonths,
      'customDays': _customDays,
      'passStart': _formatDate(_passStart),
      'passEnd': _formatDate(_passEnd),
      'passDays': _passDays(),
      'lastRegisteredAt': _formatDate(_lastRegisteredAt),
      'noShowDeductedCount': _noShowDeductedCount,
      'noShowUndeductedCount': _noShowUndeductedCount,
      'serviceSessionCount': _serviceSessionCount,
      'reregisterCount': _reregisterCount,
      'lastReregisterAt': _formatDate(_lastReregisterAt),
      'inbodyNotProvided': _inbodyNotProvided,
      'diseaseHistory': _diseaseC.text.trim(),
      'medicineHistory': _medicineC.text.trim(),
      'inbody': _inbodyNotProvided
          ? null
          : {
        'heightCm': double.tryParse(_heightC.text) ?? 0,
        'weightKg': double.tryParse(_weightC.text) ?? 0,
        'bodyFatPct': double.tryParse(_bfPctC.text) ?? 0,
        'skeletalMuscleKg': double.tryParse(_smmC.text) ?? 0,
        'bodyFatKg': double.tryParse(_bfKgC.text) ?? 0,
        'bmi': _safeBmi(
          double.tryParse(_heightC.text) ?? 0,
          double.tryParse(_weightC.text) ?? 0,
        ),
      },
      'nextReservationDate':
      _formatDate(_nextReservation).isEmpty ? null : _formatDate(_nextReservation),
      'anniversaryDate':
      _formatDate(_anniversaryDate).isEmpty ? null : _formatDate(_anniversaryDate),
      'specialEvent': _specialEventC.text.trim().isEmpty ? null : _specialEventC.text.trim(),
      'note': _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
      'trainingLogConsentAgreed': _trainingLogConsentAgreed,
      'trainingLogConsentAgreedAt': _formatDate(_trainingLogConsentAgreedAt),
      if (includeRegisteredAt) 'registeredAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _toFirestorePayload(
      Map<String, dynamic> raw, {
        required bool includeCreatedAt,
        String? photoUrl,
      }) {
    Timestamp? ts(String? ymd) {
      if (ymd == null || ymd.isEmpty) return null;
      try {
        final d = DateFormat('yyyy-MM-dd').parseStrict(ymd);
        return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
      } catch (_) {
        return null;
      }
    }

    String digits(String s) => s.replaceAll(RegExp(r'\D'), '');
    final bool activeMembership = raw['membershipNotRegistered'] != true;

    final totalSessions = (raw['totalSessions'] as int?) ??
        int.tryParse((raw['totalSessions'] ?? '0').toString()) ??
        0;

    final remainSessions = (raw['remainSessions'] as int?) ??
        int.tryParse((raw['remainSessions'] ?? '0').toString()) ??
        0;

    final doneSessions = (raw['doneSessions'] as int?) ??
        (totalSessions - remainSessions).clamp(0, totalSessions);

    final payload = <String, dynamic>{
      'memberId': raw['memberId'],
      'name': raw['name'],
      'gender': raw['gender'],
      'birth': ts(raw['birthDate']),
      'birthDisplay': raw['birthDate'],
      'phone': digits((raw['phone'] ?? '').toString()),
      'postal': raw['postal'],
      'address': raw['address'],
      'detailAddress': raw['detailAddress'],
      'membershipGrade': raw['membershipGrade'],
      'job': raw['job'],
      'memberStatus': raw['memberStatus'],
      'lessonType': raw['lessonType'],

// 홈, 회원관리, 수업일지 차감 로직에서 같이 참조할 수 있도록 루트 필드도 유지합니다.
      'totalSessions': totalSessions,
      'remainSessions': remainSessions,
      'remainingSessions': remainSessions,
      'doneSessions': doneSessions,

      'sessions': {
        'notRegistered': raw['lessonsNotRegistered'] == true,
        'total': totalSessions,
        'remain': remainSessions,
        'done': doneSessions,
        'noShowDeductedCount': raw['noShowDeductedCount'] ?? 0,
        'noShowUndeductedCount': raw['noShowUndeductedCount'] ?? 0,
        'serviceSessionCount': raw['serviceSessionCount'] ?? 0,
      },

      'membership': {
        'notRegistered': raw['membershipNotRegistered'] == true,
        'termMonths': raw['termMonths'],
        'customDays': raw['customDays'],
        'startAt': ts(raw['passStart']),
        'endAt': ts(raw['passEnd']),
        'days': raw['passDays'],
        'reregisterCount': raw['reregisterCount'] ?? 0,
        'lastReregisterAt': ts(raw['lastReregisterAt']),
        if (activeMembership) 'lastRegisteredAt': FieldValue.serverTimestamp(),
      },
      'health': {
        'inbodyNotProvided': raw['inbodyNotProvided'] == true,
        'diseaseHistory': raw['diseaseHistory'],
        'medicineHistory': raw['medicineHistory'],
        'inbody': raw['inbody'],
      },
      'nextReservationAt': ts(raw['nextReservationDate']),
      'anniversaryDate': ts(raw['anniversaryDate']),
      'specialEvent': raw['specialEvent'],
      'note': raw['note'],
      'trainingLogConsentAgreed': raw['trainingLogConsentAgreed'] == true,
      'trainingLogConsentAgreedAt': ts(raw['trainingLogConsentAgreedAt']),
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (activeMembership) 'lastRegisteredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    return payload;
  }

  Future<void> _bootstrapMemberArtifacts({
    required String memberId,
    required Map<String, dynamic> raw,
    String? photoUrl,
  }) async {
    final db = FirebaseFirestore.instance;
    final memberRef = db.collection('members').doc(memberId);
    final batch = db.batch();

    final cardRef = memberRef.collection('client_card').doc('v1');
    final total = (raw['totalSessions'] as int?) ?? 0;
    final remain = (raw['remainSessions'] as int?) ?? 0;
    final done = (raw['doneSessions'] as int?) ?? 0;

    batch.set(cardRef, {
      'memberId': memberId,
      'name': (raw['name'] ?? '').toString(),
      'phone': (raw['phone'] ?? '').toString(),
      'membershipGrade': raw['membershipGrade'],
      'memberStatus': raw['memberStatus'],

      'totalSessions': total,
      'remainSessions': remain,
      'remainingSessions': remain,
      'doneSessions': done,

      'sessions': {'total': total, 'remain': remain, 'done': done},
      'membership': {
        'startAt': raw['passStart'],
        'endAt': raw['passEnd'],
        'days': raw['passDays'],
        'notRegistered': raw['membershipNotRegistered'] == true,
      },
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final idxRef = memberRef.collection('training_logs').doc('_index');
    batch.set(
      idxRef,
      {
        'entries': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final todayYmd = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final firstLogRef = memberRef.collection('training_logs').doc(todayYmd);

    final inbody = (raw['inbody'] is Map)
        ? Map<String, dynamic>.from(raw['inbody'])
        : null;

    batch.set(firstLogRef, {
      'date': todayYmd,
      'memberId': memberId,
      'notes': null,
      'checklist': {'warmup': false, 'main': false, 'cooldown': false},
      'metrics': {
        'weightKg': inbody?['weightKg'],
        'bodyFatPct': inbody?['bodyFatPct'],
        'smmKg': inbody?['skeletalMuscleKg'],
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      '_template': true,
    });

    await batch.commit();
  }

  static double _safeBmi(double hCm, double wKg) {
    if (hCm <= 0) return 0;
    final hM = hCm / 100.0;
    return double.parse((wKg / (hM * hM)).toStringAsFixed(2));
  }

  String? _normalizeGender(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;

    switch (value) {
      case '남':
      case '남성':
      case '남자':
      case 'male':
      case 'Male':
      case 'M':
        return '남';

      case '여':
      case '여성':
      case '여자':
      case 'female':
      case 'Female':
      case 'F':
        return '여';

      default:
        return null;
    }
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  bool _isSameOrAfterToday(DateTime date) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final target = DateTime(date.year, date.month, date.day);
    return !target.isBefore(base);
  }

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }


  void _extendMembershipDays(int addedDays) {
    if (addedDays <= 0) return;

    final today = _todayOnly();

    final DateTime nextStart;
    if (_passEnd != null && _isSameOrAfterToday(_passEnd!)) {
      nextStart = DateTime(
        _passEnd!.year,
        _passEnd!.month,
        _passEnd!.day,
      ).add(const Duration(days: 1));
    } else {
      nextStart = today;
    }

    final nextEnd = nextStart.add(Duration(days: addedDays - 1));

    setState(() {
      _membershipNotRegistered = false;
      _memberStatus = '활성';

      if (_passStart == null ||
          (_passEnd != null && !_isSameOrAfterToday(_passEnd!))) {
        _passStart = nextStart;
      }

      _passEnd = nextEnd;
      _termMonths = null;
      _customDays = addedDays;

      _reregisterCount += 1;
      _lastReregisterAt = DateTime.now();
      _lastRegisteredAt = DateTime.now();
    });
  }

  void _addPtSessions(int addedSessions) {
    if (addedSessions <= 0) return;

    final currentTotal = int.tryParse(_totalSessionsC.text) ?? 0;
    final currentRemain = int.tryParse(_remainSessionsC.text) ?? 0;

    setState(() {
      _lessonsNotRegistered = false;
      _memberStatus = '활성';
      _totalSessionsC.text = (currentTotal + addedSessions).toString();
      _remainSessionsC.text = (currentRemain + addedSessions).toString();

      _reregisterCount += 1;
      _lastReregisterAt = DateTime.now();
    });
  }

  void _applyReregistration({
    int addedPtSessions = 0,
    int addedMembershipDays = 0,
  }) {
    if (addedPtSessions > 0) {
      _addPtSessions(addedPtSessions);
    }

    if (addedMembershipDays > 0) {
      _extendMembershipDays(addedMembershipDays);
    }
  }

  void _autoFormatBirth() {
    if (_isFormattingBirth) return;
    final raw = _birthTextC.text.replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return;

    String? ymd;
    if (raw.length == 8) {
      final y = raw.substring(0, 4);
      final m = raw.substring(4, 6);
      final d = raw.substring(6, 8);
      ymd = '$y-$m-$d';
    } else if (raw.length == 6) {
      final yy = int.tryParse(raw.substring(0, 2)) ?? 0;
      final mm = raw.substring(2, 4);
      final dd = raw.substring(4, 6);
      final nowYear = DateTime.now().year % 100;
      final century = (yy <= nowYear + 1) ? 2000 : 1900;
      ymd = '${century + yy}-$mm-$dd';
    } else {
      return;
    }

    try {
      final dt = DateFormat('yyyy-MM-dd').parseStrict(ymd);
      if (dt.isAfter(DateTime.now())) return;
      _isFormattingBirth = true;
      _birthTextC.text = ymd;
      _birthDate = dt;
      _birthTextC.selection =
          TextSelection.collapsed(offset: _birthTextC.text.length);
    } catch (_) {
      return;
    } finally {
      _isFormattingBirth = false;
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
    DateTime? first,
    DateTime? last,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: first ?? DateTime(1900),
      lastDate: last ?? DateTime(now.year + 2),
    );
    if (picked != null) onPicked(picked);
  }

  int? _passDays() {
    if (_passStart == null || _passEnd == null) return null;
    final s = DateTime(_passStart!.year, _passStart!.month, _passStart!.day);
    final e = DateTime(_passEnd!.year, _passEnd!.month, _passEnd!.day);
    return e.difference(s).inDays + 1;
  }

  int? _daysLeft() {
    if (_passEnd == null) return null;
    final today = DateTime.now();
    final end = DateTime(_passEnd!.year, _passEnd!.month, _passEnd!.day);
    return end.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  int _approxDays(int months) => months * 30;

  Future<void> _pickProfileImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() {
      _profileBytes = bytes;
    });
  }

  Future<String?> _uploadProfileIfAny() async {
    if (_profileBytes == null) return null;
    final path = 'member_profiles/${widget.memberId}/profile.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    final meta = SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=3600',
    );
    await ref.putData(_profileBytes!, meta);
    return await ref.getDownloadURL();
  }

  Future<void> _openContract() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: widget.memberId,
          memberName: _nameC.text.trim(),
          trainerName: '',
        ),
      ),
    );

    if (ok == true) {
      await _loadFromFirestore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계약서 저장 완료')),
        );
      }
    }
  }

  List<_ContractHistoryItem> _buildContractHistoryItems() {
    final items = <_ContractHistoryItem>[];

    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;
    final start = _formatDate(_passStart);
    final end = _formatDate(_passEnd);

    if (_contractSigned || total > 0 || start.isNotEmpty || end.isNotEmpty) {
      items.add(
        _ContractHistoryItem(
          title: _contractSigned ? '현재 적용 계약' : '현재 계약 정보',
          subtitle: [
            if (start.isNotEmpty || end.isNotEmpty) '기간 $start ~ $end',
            '수업 $remain / $total',
            if (_contractSignedAt != null)
              '서명 ${DateFormat('yyyy-MM-dd').format(_contractSignedAt!)}',
          ].join(' · '),
          badge: _contractSigned ? '현재 적용중' : '작성중',
          isCurrent: true,
        ),
      );
    }

    return items;
  }

  Future<void> _openContractHistorySheet() async {
    final items = _buildContractHistoryItems();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '계약 이력',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kPageText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '현재 적용 계약과 이전 계약 이력을 확인합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kPageMuted,
                  ),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kPageBorder),
                    ),
                    child: const Text(
                      '아직 표시할 계약 이력이 없어요.\n계약서를 작성하면 현재 계약과 지난 계약을 이곳에서 확인할 수 있어요.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kPageMuted,
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  ...items.map((item) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.isCurrent
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: item.isCurrent
                              ? const Color(0xFFBFDBFE)
                              : kPageBorder,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: item.isCurrent
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.isCurrent
                                  ? Icons.verified_outlined
                                  : Icons.history_rounded,
                              color: item.isCurrent
                                  ? const Color(0xFF1D4ED8)
                                  : kPageMuted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: kPageText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kPageMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: item.isCurrent
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: item.isCurrent
                                    ? const Color(0xFF1D4ED8)
                                    : kPageMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openContract();
                    },
                    icon: const Icon(Icons.edit_document),
                    label: const Text('계약서 작성 / 확인으로 이동'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPageText,
                      side: const BorderSide(color: kPageBorder),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTrainingLogConsent() async {
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TrainingLogConsentPage(),
      ),
    );

    if (agreed == true) {
      setState(() {
        _trainingLogConsentAgreed = true;
        _trainingLogConsentAgreedAt = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수업일지 개인정보 동의가 저장되었어요.')),
        );
      }
    } else if (agreed == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('개인정보 동의가 취소되었어요.')),
        );
      }
    }
  }

  Future<void> _showPreview() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final preview = const JsonEncoder.withIndent('  ')
        .convert(_collectFormMap(includeRegisteredAt: true));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장 미리보기'),
        content: SingleChildScrollView(
          child: SelectableText(preview),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTrainingLogWithConsent() async {
    if (!_trainingLogConsentAgreed) {
      final agreed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const TrainingLogConsentPage(),
        ),
      );

      if (agreed != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('개인정보 동의 후 수업일지를 사용할 수 있어요.')),
          );
        }
        return;
      }

      setState(() {
        _trainingLogConsentAgreed = true;
        _trainingLogConsentAgreedAt = DateTime.now();
      });
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPage(
          memberId: widget.memberId,
          memberName: _nameC.text.trim(),
          memberPhone: _phoneC.text.trim(),
          totalSessions: int.tryParse(_totalSessionsC.text.trim()) ?? 0,
          remainingSessions: int.tryParse(_remainSessionsC.text.trim()) ?? 0,
        ),
      ),
    );
  }

  Future<void> _submitAndStay() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력한 내용을 한 번 확인해주세요.')),
      );
      return;
    }

    if (!_membershipNotRegistered) {
      _lastRegisteredAt ??= DateTime.now();
    }

    String? photoUrl;
    try {
      photoUrl = await _uploadProfileIfAny();
      _photoUrl = photoUrl ?? _photoUrl;
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: kPagePrimary),
        ),
      );
    }

    try {
      final raw = _collectFormMap(includeRegisteredAt: true);
      final docRef =
      FirebaseFirestore.instance.collection('members').doc(widget.memberId);

      final preSnap = await docRef.get();
      final bool isNew = !preSnap.exists;

      void offerNextActionsDialog() {
        if (!mounted) return;

        final pendingActions = <_PostSaveActionItem>[];

        if (!_contractSigned) {
          pendingActions.add(
            _PostSaveActionItem(
              icon: Icons.description_outlined,
              title: '계약서 작성/서명',
              subtitle: '계약서는 나중에 이어서 작성할 수 있어요',
              onTap: () {
                _openContract();
              },
            ),
          );
        }

        if (!_trainingLogConsentAgreed) {
          pendingActions.add(
            _PostSaveActionItem(
              icon: Icons.privacy_tip_outlined,
              title: '개인정보동의서',
              subtitle: '운동기록일지 사용 전 동의가 필요해요',
              onTap: () {
                _openTrainingLogConsent();
              },
            ),
          );
        }

        pendingActions.add(
          _PostSaveActionItem(
            icon: Icons.menu_book_outlined,
            title: '수업일지 열기',
            subtitle: _trainingLogConsentAgreed ? '동의 완료됨' : '개인정보 동의 필요',
            onTap: () {
              _openTrainingLogWithConsent();
            },
          ),
        );

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNew
                  ? '내 회원 정보가 저장되었어요 · 나중에 이어서 입력 가능'
                  : '내 회원 정보가 저장되었어요 · 필요한 작업은 나중에 이어서 가능',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '다음 작업',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ListTile(
                          title: Text('다음 작업'),
                          subtitle: Text('지금 안 해도 되고, 필요하면 이어서 진행하세요.'),
                        ),
                        const Divider(height: 1),
                        ...pendingActions.map(
                              (item) => ListTile(
                            leading: Icon(item.icon),
                            title: Text(item.title),
                            subtitle:
                            item.subtitle == null ? null : Text(item.subtitle!),
                            onTap: () {
                              Navigator.pop(context);
                              item.onTap();
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final payload = _toFirestorePayload(
          raw,
          includeCreatedAt: isNew,
          photoUrl: photoUrl,
        );
        tx.set(docRef, payload, SetOptions(merge: true));
      });

      if (isNew) {
        await _bootstrapMemberArtifacts(
          memberId: widget.memberId,
          raw: raw,
          photoUrl: _photoUrl,
        );
      }

      await _clearDraft();

      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      offerNextActionsDialog();
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류: $e')),
        );
      }
    }
  }

  Future<void> _resetForm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('입력 초기화'),
        content: const Text('입력한 내용을 모두 초기화할까요? 저장된 초안도 함께 삭제돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('리셋'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _profileBytes = null;
      _photoUrl = null;
      _headerDisplayName = _nameC.text.trim();
      _gender = '미입력';
      _birthDate = null;
      _birthTextC.clear();
      _phoneC.text = widget.initialPhone ?? '';
      _postalC.clear();
      _addrC.clear();
      _addrDetailC.clear();
      _membershipGrade = 'GOLD';
      _jobC.clear();
      _memberStatus = '활성';
      _lessonType = '미입력';

      _lessonsNotRegistered = false;
      _totalSessionsC.text = '0';
      _remainSessionsC.text = '0';

      _membershipNotRegistered = false;
      _termMonths = null;
      _customDays = null;
      _passStart = widget.initialVisitDate;
      _passEnd = null;
      _lastRegisteredAt = null;
      _noShowDeductedCount = 0;
      _noShowUndeductedCount = 0;
      _serviceSessionCount = 0;
      _reregisterCount = 0;
      _lastReregisterAt = null;

      _inbodyNotProvided = false;
      _diseaseC.clear();
      _medicineC.clear();
      _heightC.text = '170.0';
      _weightC.text = '65.0';
      _bfPctC.text = '18.5';
      _smmC.text = '29.0';
      _bfKgC.text = '12.0';

      _nextReservation = widget.initialConsultDate;
      _noteC.text = '';
      _anniversaryDate = null;
      _specialEventC.clear();
      _contractSigned = false;
      _contractSignedAt = null;
      _isHeaderExpanded = false;
      _trainingLogConsentAgreed = false;
      _trainingLogConsentAgreedAt = null;
    });

    await _clearDraft();
  }



  Future<void> _confirmDeleteMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원 정보 삭제'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '회원의 모든 정보와 기록이 삭제됩니다.\n회원 정보를 삭제하시겠습니까?',
            ),
            SizedBox(height: 10),
            Text(
              '회원 삭제 후 7일 내에만 복구할 수 있어요.\n복구요청은 고객센터로 문의해주세요.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(_, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _softDeleteMember();
  }

  Future<void> _softDeleteMember() async {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: kPagePrimary),
        ),
      );
    }

    try {
      final memberRef =
      FirebaseFirestore.instance.collection('members').doc(widget.memberId);

      final now = DateTime.now();
      final deleteAt = now.add(const Duration(days: 7));

      await memberRef.set({
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(now),
        'deleteScheduledAt': Timestamp.fromDate(deleteAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제 처리되었습니다. 복구 문의는 고객센터로 문의해주세요.'),
        ),
      );

      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 처리 중 오류: $e')),
      );
    }
  }

  InputDecoration _inputDecoration(
      String label, {
        String? hint,
        String? suffixText,
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: kPageFieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPageBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPageBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPagePrimary, width: 1.3),
      ),
    );
  }

  Widget _buildHeaderContractButton() {
    return SizedBox(
      width: 36,
      height: 36,
      child: InkWell(
        onTap: _openContract,
        borderRadius: BorderRadius.circular(999),
        child: const Center(
          child: Icon(
            Icons.description_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderMenu() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeaderContractButton(),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          height: 42,
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) async {
              if (value == 'preview') {
                await _showPreview();
              } else if (value == 'reset') {
                await _resetForm();
              } else if (value == 'history') {
                await _openContractHistorySheet();
              } else if (value == 'delete') {
                await _confirmDeleteMember();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'history',
                child: Text('지난 계약서'),
              ),
              PopupMenuItem(
                value: 'preview',
                child: Text('저장 미리보기'),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Text('입력 리셋'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Text('회원 삭제'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _basicInfoPageIndex == 0 ? '기본정보 1/2' : '기본정보 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _basicInfoPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _basicInfoPageIndex == 0
                    ? null
                    : () {
                  _basicInfoPageController.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _basicInfoPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _basicInfoPageIndex == 1
                    ? null
                    : () {
                  _basicInfoPageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSetupPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _memberSetupPageIndex == 0 ? '상태/등급 1/2' : '상태/등급 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _memberSetupPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _memberSetupPageIndex == 0
                    ? null
                    : () {
                  _memberSetupPageController.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _memberSetupPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _memberSetupPageIndex == 1
                    ? null
                    : () {
                  _memberSetupPageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSetupPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _memberSetupPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildBodyHealthPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _bodyHealthPageIndex == 0 ? '인바디/건강 1/2' : '인바디/건강 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _bodyHealthPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _bodyHealthPageIndex == 0
                    ? null
                    : () {
                  _bodyHealthPageController.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _bodyHealthPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _bodyHealthPageIndex == 1
                    ? null
                    : () {
                  _bodyHealthPageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBodyHealthPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _bodyHealthPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildMemoPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _memoPageIndex == 0 ? '메모/체크포인트 1/2' : '메모/체크포인트 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _memoPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _memoPageIndex == 0
                    ? null
                    : () {
                  _memoPageController.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _memoPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _memoPageIndex == 1
                    ? null
                    : () {
                  _memoPageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  );
                },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemoPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _memoPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildBasicInfoPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _basicInfoPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  String _eventSummaryText() {
    final items = <String>[];

    if (_anniversaryDate != null) {
      items.add('기념일 ${DateFormat('MM.dd').format(_anniversaryDate!)}');
    }

    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    if (total >= 100) {
      items.add('레슨 100회+');
    }

    if (_lastRegisteredAt != null) {
      final days = DateTime.now()
          .difference(DateTime(
        _lastRegisteredAt!.year,
        _lastRegisteredAt!.month,
        _lastRegisteredAt!.day,
      ))
          .inDays;
      if (days >= 100) {
        items.add('등록 100일+');
      }
    }

    if (_specialEventC.text.trim().isNotEmpty) {
      items.add('특별 일정 있음');
    }

    if (items.isEmpty) return '표시할 체크포인트 없음';
    return items.join(' · ');
  }

  Widget _buildCollapsedHeaderInfo() {
    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;
    final theme = _gradeTheme();

    final lessonSummary = _lessonsNotRegistered ? '-' : '$total/$remain';

    String memoSummary = '기록 없음';
    if (_noteC.text.trim().isNotEmpty) {
      memoSummary = _noteC.text.trim();
    } else if (_specialEventC.text.trim().isNotEmpty) {
      memoSummary = _specialEventC.text.trim();
    } else if (_anniversaryDate != null) {
      memoSummary = '기념일 ${DateFormat('yyyy.MM.dd').format(_anniversaryDate!)}';
    }

    return MemberSummaryThreeBoxHeader(
      avatarImage: _avatarImage(),
      name: _nameC.text.trim().isEmpty ? '이름 미입력' : _nameC.text.trim(),
      phone: _phoneC.text.trim().isEmpty
          ? '연락처 미입력'
          : _prettyPhone(_phoneC.text),
      lessonType: _lessonTypeOnlyText(),
      lessonSummary: lessonSummary,
      warningSummary: _warningSummaryText(),
      accentColor: theme.accent,
      borderColor: theme.border,
      membershipLabel: _membershipLabelText(),
      membershipPeriod: _membershipPeriodText(),
      statusIcon: _memberStatusIcon(),
      isFlipped: _isHeaderCardFlipped,
      onFlip: () {
        setState(() {
          _isHeaderCardFlipped = !_isHeaderCardFlipped;
        });
      },
      contractStatusText: _contractSigned ? '완료' : '미작성',
      consentStatusText: _trainingLogConsentAgreed ? '완료' : '필요',
      memberGradeText: _membershipGrade,
      reregisterText: '$_reregisterCount회',
      noShowText: '차감 $_noShowDeductedCount / 미차감 $_noShowUndeductedCount',
      serviceText: '$_serviceSessionCount회',
      memoText: memoSummary,
      groupLabel: _headerGroupLabel,
      memberStatusText: _memberStatusLabel(),
    );
  }


  List<MemberHeaderBadgeData> _buildHeaderBadges() {
    return const [];
  }

  String _warningSummaryText() {
    final parts = <String>[];

    final disease = _diseaseC.text.trim();
    final medicine = _medicineC.text.trim();
    final note = _noteC.text.trim();
    final special = _specialEventC.text.trim();

    if (disease.isNotEmpty) parts.add('질병');
    if (medicine.isNotEmpty) parts.add('복약');
    if (note.isNotEmpty) parts.add('메모');
    if (special.isNotEmpty) parts.add('일정');

    if (parts.isEmpty) return '없음';
    return parts.join(' · ');
  }

  List<String> _missingRequiredFields() {
    final items = <String>[];

    if (_nameC.text.trim().isEmpty) {
      items.add('이름');
    }

    if (_gender != '남' && _gender != '여') {
      items.add('성별');
    }

    if (_parseDate(_birthTextC.text) == null) {
      items.add('생년월일');
    }

    final phoneDigits = _phoneC.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length < 9 || phoneDigits.length > 11) {
      items.add('전화번호');
    }

    if (_lessonType.trim().isEmpty || _lessonType == '미입력') {
      items.add('수업형태');
    }

    return items;
  }

  Widget _buildRequiredFieldsNoticeCard() {
    final missing = _missingRequiredFields();
    if (missing.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '필수 입력 항목이 남아 있어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '먼저 저장하고, 아래 항목은 나중에 이어서 입력할 수 있어요.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF92400E).withOpacity(0.84),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: missing.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  _MemberGradeTheme _gradeTheme() {
    switch (_membershipGrade) {
      case 'VVIP':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
          accent: Color(0xFFF9A8D4),
          border: Color(0xFFF5D0FE),
        );
      case 'VIP':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF4338CA), Color(0xFF7C3AED)],
          accent: Color(0xFFC4B5FD),
          border: Color(0xFFD8B4FE),
        );
      case 'GOLD':
        return const _MemberGradeTheme(
          gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
          accent: Color(0xFFFDE68A),
          border: Color(0xFFFCD34D),
        );
      case 'SILVER':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF64748B), Color(0xFF94A3B8)],
          accent: Color(0xFFE2E8F0),
          border: Color(0xFFCBD5E1),
        );
      case 'BRONZE':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF92400E), Color(0xFFB45309)],
          accent: Color(0xFFFCD7AA),
          border: Color(0xFFF59E0B),
        );
      default:
        return const _MemberGradeTheme(
          gradient: [Color(0xFF4F46E5), Color(0xFF9333EA)],
          accent: Color(0xFFC4B5FD),
          border: Color(0xFFD8B4FE),
        );
    }
  }

  String _contractStatusText() {
    if (_contractSigned) return '계약서 완료';
    return '계약서 미작성';
  }

  IconData _memberStatusIcon() {
    switch (_memberStatus) {
      case '활성':
        return Icons.radio_button_on_rounded;
      case '휴면':
        return Icons.pause_circle_outline_rounded;
      case '만료':
        return Icons.do_not_disturb_on_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _memberStatusLabel() {
    switch (_memberStatus) {
      case '활성':
        return '활성';
      case '휴면':
        return '휴면';
      case '만료':
        return '만료';
      default:
        return _memberStatus;
    }
  }

  String _membershipLabelText() {
    if (_membershipNotRegistered) return '-';

    if (_termMonths != null) {
      return '${_termMonths}개월 회원권';
    }

    if (_customDays != null) {
      return '${_customDays}일 회원권';
    }

    return '회원권';
  }

  String _membershipPeriodText() {
    if (_membershipNotRegistered || _passStart == null || _passEnd == null) {
      return '-';
    }

    final start = DateFormat('yyyy. MM. dd').format(_passStart!);
    final end = DateFormat('yyyy. MM. dd').format(_passEnd!);
    final daysLeft = _daysLeft();

    final remainText = daysLeft == null
        ? ''
        : daysLeft >= 0
        ? ' (${daysLeft}일 남음)'
        : ' (${daysLeft.abs()}일 지남)';

    return '$start - $end$remainText';
  }

  String _lessonTypeOnlyText() {
    if (_lessonsNotRegistered) return '-';

    final value = _lessonType.trim();
    if (value.isEmpty || value == '미입력') return '-';

    return value;
  }

  String _consentStatusText() {
    if (_trainingLogConsentAgreed) return '개인정보동의 완료';
    return '개인정보동의 필요';
  }

  bool get _hideTopActionCards {
    return _trainingLogConsentAgreed;
  }


  String _trainingLogReadyText() {
    if (_trainingLogConsentAgreed) return '수업일지 사용 가능';
    return '수업일지 사용 전 동의 필요';
  }

  Widget _buildHeaderExpandedBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassHeaderChip(text: _contractStatusText()),
              _GlassHeaderChip(text: _consentStatusText()),
              _GlassHeaderChip(text: '등급 $_membershipGrade'),
              _GlassHeaderChip(text: '재등록 $_reregisterCount회'),
              _GlassHeaderChip(text: '노쇼 차감 $_noShowDeductedCount회'),
              _GlassHeaderChip(text: '노쇼 미차감 $_noShowUndeductedCount회'),
              _GlassHeaderChip(text: '서비스 $_serviceSessionCount회'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '간단한 기념일 / 메모',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_anniversaryDate != null)
                  Text(
                    '기념일 ${DateFormat('yyyy.MM.dd').format(_anniversaryDate!)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                if (_specialEventC.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '일정 ${_specialEventC.text.trim()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (_noteC.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _noteC.text.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (_anniversaryDate == null &&
                    _specialEventC.text.trim().isEmpty &&
                    _noteC.text.trim().isEmpty)
                  Text(
                    '등록된 기념일이나 메모가 없습니다.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLabelValue({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _consentStatusChip() {
    final color = _trainingLogConsentAgreed
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    final text = _trainingLogConsentAgreed
        ? (_trainingLogConsentAgreedAt == null
        ? '동의 완료'
        : '동의 ${DateFormat('yyyy-MM-dd').format(_trainingLogConsentAgreedAt!)}')
        : '동의 필요';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _contractSummaryCard() {
    final signedText = _contractSigned ? '서명 완료' : '서명 전';
    final signedColor = _contractSigned
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    return _SectionCard(
      icon: Icons.description_outlined,
      title: '계약서 / 서명',
      subtitle: _contractSignedAt == null
          ? '계약서 없이도 먼저 등록하고, 나중에 작성할 수 있어요'
          : '서명일 ${DateFormat('yyyy-MM-dd').format(_contractSignedAt!)}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: signedColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          signedText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: signedColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _openContract,
              icon: const Icon(Icons.edit_document),
              label: Text(_contractSigned ? '계약서 확인 / 재서명' : '계약서 작성 / 서명'),
              style: FilledButton.styleFrom(
                backgroundColor: kPagePrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openContractHistorySheet,
              icon: const Icon(Icons.history),
              label: const Text('지난 계약서'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPageText,
                side: const BorderSide(color: kPageBorder),
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingLogConsentCard() {
    return _SectionCard(
      icon: Icons.privacy_tip_outlined,
      title: '개인정보동의서',
      subtitle: _trainingLogConsentAgreedAt == null
          ? '계약서 없이 수업일지를 사용하는 경우 필요해요'
          : '동의일 ${DateFormat('yyyy-MM-dd').format(_trainingLogConsentAgreedAt!)}',
      trailing: _consentStatusChip(),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _openTrainingLogConsent,
              icon: const Icon(Icons.description_outlined),
              label: Text(_trainingLogConsentAgreed ? '동의서 확인' : '동의서 작성'),
              style: FilledButton.styleFrom(
                backgroundColor: kPagePrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _trainingLogConsentAgreed = false;
                  _trainingLogConsentAgreedAt = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('개인정보동의 상태를 초기화했습니다.')),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('동의 초기화'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPageText,
                side: const BorderSide(color: kPageBorder),
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _basicInfoSection() {
    return _ExpandableSectionCard(
      icon: Icons.person_outline_rounded,
      title: '회원 정보',
      subtitle: '담당 회원의 기본정보를 입력해요',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          _buildBasicInfoPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: PageView(
              controller: _basicInfoPageController,
              onPageChanged: (index) {
                setState(() {
                  _basicInfoPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameC,
                              decoration: _inputDecoration('이름'),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty) ? '이름 입력' : null,
                              onChanged: (v) => setState(() {
                                _headerDisplayName = v.trim();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: _inputDecoration('성별'),
                              items: const [
                                DropdownMenuItem(value: '미입력', child: Text('미입력')),
                                DropdownMenuItem(value: '남', child: Text('남')),
                                DropdownMenuItem(value: '여', child: Text('여')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _gender = v ?? '미입력'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _birthTextC,
                              decoration: _inputDecoration(
                                '생년월일',
                                hint: 'YYYY-MM-DD',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.date_range),
                                  onPressed: () async {
                                    final current =
                                        _birthDate ?? _parseDate(_birthTextC.text);
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: current ??
                                          DateTime(now.year - 25, now.month, now.day),
                                      firstDate: DateTime(1900),
                                      lastDate: now,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _birthDate = picked;
                                        _birthTextC.text = _formatDate(picked);
                                      });
                                    }
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _jobC,
                              decoration: _inputDecoration(
                                '직업',
                                hint: '예: 사무직',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneC,
                        decoration: _inputDecoration(
                          '전화번호',
                          hint: '010-1234-5678',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_KoreaPhoneTextInputFormatter()],
                        validator: (v) {
                          final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (d.length < 9 || d.length > 11) return '전화번호 확인';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _postalC,
                              decoration: _inputDecoration('우편번호'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _postalC.text = '01234';
                                  _addrC.text = '서울특별시 중구 샘플로 1';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                side: const BorderSide(color: kPageBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('우편번호 찾기'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addrC,
                        decoration: _inputDecoration('주소'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addrDetailC,
                        decoration: _inputDecoration('상세주소'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildBasicInfoPageDots(),
        ],
      ),
    );
  }

  Widget _memberSetupSection() {
    return _ExpandableSectionCard(
      icon: Icons.badge_outlined,
      title: '회원 현황',
      subtitle: '회원 현황 등을 체크합니다',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          _buildMemberSetupPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            height: 252,
            child: PageView(
              controller: _memberSetupPageController,
              onPageChanged: (index) {
                setState(() {
                  _memberSetupPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _memberStatus,
                              decoration: _inputDecoration('회원 상태'),
                              items: const [
                                DropdownMenuItem(value: '활성', child: Text('활성')),
                                DropdownMenuItem(value: '휴면', child: Text('휴면')),
                                DropdownMenuItem(value: '만료', child: Text('만료')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _memberStatus = v ?? '활성'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _membershipGrade,
                              decoration: _inputDecoration('회원 등급'),
                              items: const [
                                DropdownMenuItem(value: 'VVIP', child: Text('VVIP')),
                                DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                                DropdownMenuItem(value: 'GOLD', child: Text('GOLD')),
                                DropdownMenuItem(value: 'SILVER', child: Text('SILVER')),
                                DropdownMenuItem(value: 'BRONZE', child: Text('BRONZE')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _membershipGrade = v ?? 'GOLD'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _lessonType,
                        decoration: _inputDecoration('수업 형태'),
                        items: const [
                          DropdownMenuItem(value: '미입력', child: Text('미입력')),
                          DropdownMenuItem(value: 'PT', child: Text('PT')),
                          DropdownMenuItem(value: 'PL', child: Text('PL')),
                          DropdownMenuItem(value: '요가', child: Text('요가')),
                          DropdownMenuItem(value: '그룹', child: Text('그룹')),
                          DropdownMenuItem(value: '줌바', child: Text('줌바')),
                          DropdownMenuItem(value: '재활', child: Text('재활')),
                        ],
                        onChanged: (v) =>
                            setState(() => _lessonType = v ?? '미입력'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _noShowDeductedCount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('노쇼 차감'),
                              onChanged: (v) =>
                              _noShowDeductedCount = int.tryParse(v) ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _noShowUndeductedCount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('노쇼 미차감'),
                              onChanged: (v) =>
                              _noShowUndeductedCount = int.tryParse(v) ?? 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _serviceSessionCount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('서비스 수업'),
                              onChanged: (v) =>
                              _serviceSessionCount = int.tryParse(v) ?? 0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: _reregisterCount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('재등록 횟수'),
                              onChanged: (v) =>
                              _reregisterCount = int.tryParse(v) ?? 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _tapDateField(
                        label: '최근 재등록일',
                        text: _formatDate(_lastReregisterAt),
                        onTap: () => _pickDate(
                          current: _lastReregisterAt,
                          onPicked: (d) => setState(() => _lastReregisterAt = d),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildMemberSetupPageDots(),
        ],
      ),
    );
  }

  Widget _lessonMembershipSection() {
    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;
    final done = (total - remain).clamp(0, total);

    return _ExpandableSectionCard(
      icon: Icons.inventory_2_outlined,
      title: '수업 / 멤버십',
      subtitle: '수업 등록 과 멤버십 등록을 체크합니다',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: kPageFieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPageBorder),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '수업 미등록',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: kPageText,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '회차 등록이 아직 없는 회원',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kPageMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _lessonsNotRegistered,
                        onChanged: (v) {
                          setState(() {
                            _lessonsNotRegistered = v;
                            if (v) {
                              _totalSessionsC.text = '0';
                              _remainSessionsC.text = '0';
                            }
                          });
                        },
                        activeColor: kPagePrimary,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _totalSessionsC,
                          enabled: !_lessonsNotRegistered,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('총 세션'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _remainSessionsC,
                          enabled: !_lessonsNotRegistered,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('잔여 세션'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Row(
                    children: [
                      _SoftInfoChip(
                        label: _lessonsNotRegistered ? '미기입' : '완료 $done회',
                      ),
                      const SizedBox(width: 8),
                      _SoftInfoChip(label: '총 $total / 잔여 $remain'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: kPageFieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPageBorder),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '멤버십 미등록',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: kPageText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lastRegisteredAt == null
                                  ? '마지막 등록일 없음'
                                  : '마지막 등록일 ${DateFormat('yyyy-MM-dd').format(_lastRegisteredAt!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kPageMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _membershipNotRegistered,
                        onChanged: (v) {
                          setState(() {
                            _membershipNotRegistered = v;
                            if (v) {
                              _termMonths = null;
                              _customDays = null;
                              _passStart = null;
                              _passEnd = null;
                            }
                          });
                        },
                        activeColor: kPagePrimary,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: AbsorbPointer(
                    absorbing: _membershipNotRegistered,
                    child: Opacity(
                      opacity: _membershipNotRegistered ? 0.45 : 1.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in [1, 3, 6, 12])
                                ChoiceChip(
                                  label: Text('$m개월'),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                                  selected: _termMonths == m && _customDays == null,
                                  onSelected: (sel) {
                                    if (!sel) return;
                                    setState(() {
                                      _termMonths = m;
                                      _customDays = null;
                                      _passStart ??= DateTime.now();
                                      _passEnd = _passStart!.add(
                                        Duration(days: _approxDays(m) - 1),
                                      );
                                    });
                                  },
                                ),
                              ChoiceChip(
                                label: Text(
                                  _customDays == null
                                      ? '직접입력(일)'
                                      : '${_customDays}일',
                                ),
                                selected: _customDays != null,
                                onSelected: (sel) async {
                                  if (!sel) return;
                                  final d = await _askDays(context);
                                  if (d == null) return;
                                  setState(() {
                                    _termMonths = null;
                                    _customDays = d;
                                    _passStart ??= DateTime.now();
                                    _passEnd = _passStart!.add(
                                      Duration(days: d - 1),
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _tapDateField(
                                  label: '시작일',
                                  text: _formatDate(_passStart),
                                  onTap: () => _pickDate(
                                    current: _passStart,
                                    onPicked: (d) => setState(() {
                                      _passStart = d;
                                      if (_termMonths != null) {
                                        _passEnd = d.add(
                                          Duration(days: _approxDays(_termMonths!) - 1),
                                        );
                                      } else if (_customDays != null) {
                                        _passEnd = d.add(
                                          Duration(days: _customDays! - 1),
                                        );
                                      }
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _tapDateField(
                                  label: '종료일',
                                  text: _formatDate(_passEnd),
                                  onTap: () => _pickDate(
                                    current: _passEnd,
                                    onPicked: (d) => setState(() {
                                      _passEnd = d;
                                      if (_passStart != null) {
                                        final s = DateTime(
                                          _passStart!.year,
                                          _passStart!.month,
                                          _passStart!.day,
                                        );
                                        final e = DateTime(d.year, d.month, d.day);
                                        final days = e.difference(s).inDays + 1;
                                        _termMonths = null;
                                        _customDays = days;
                                      }
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SoftInfoChip(
                                label:
                                '기간 ${_termMonths != null ? '${_termMonths}개월' : (_customDays != null ? '${_customDays}일' : '-')}',
                              ),
                              _SoftInfoChip(label: '총 ${_passDays() ?? '-'}일'),
                              _SoftInfoChip(
                                label: '남은 ${_daysLeft()?.toString() ?? '-'}일',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthSection() {
    final bmi = _calcBmi();

    return _ExpandableSectionCard(
      icon: Icons.monitor_heart_outlined,
      title: '인바디 / 건강정보',
      subtitle: '인바디 결과와 신체의 건강 입력을 입력합니다',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          _buildBodyHealthPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            height: 304,
            child: PageView(
              controller: _bodyHealthPageController,
              onPageChanged: (index) {
                setState(() {
                  _bodyHealthPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _numField(_heightC, '키', 'cm')),
                          const SizedBox(width: 10),
                          Expanded(child: _numField(_weightC, '체중', 'kg')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _numField(_bfPctC, '체지방률', '%')),
                          const SizedBox(width: 10),
                          Expanded(child: _numField(_smmC, '골격근량', 'kg')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _numField(_bfKgC, '체지방량', 'kg')),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: kPageFieldBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kPageBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'BMI',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: kPageText,
                                    ),
                                  ),
                                  Text(
                                    (_inbodyNotProvided || bmi <= 0)
                                        ? '-'
                                        : bmi.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: kPagePrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        value: _inbodyNotProvided,
                        onChanged: (v) => setState(() => _inbodyNotProvided = v),
                        activeColor: kPagePrimary,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '인바디 미기입',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          '측정값이 없으면 활성화하세요',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _diseaseC,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '건강정보 간단요약',
                          hint: '예: 허리 통증, 무릎 이슈, 어깨 불편감',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '질병 / 수술 이력',
                          hint: '예: 디스크, 어깨 수술, 무릎 수술',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _medicineC,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '복약 이력',
                          hint: '복용 약물 기록',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildBodyHealthPageDots(),
        ],
      ),
    );
  }

  Widget _inbodySection() {
    final bmi = _calcBmi();

    return _ExpandableSectionCard(
      icon: Icons.monitor_weight_outlined,
      title: '인바디',
      subtitle: _inbodyNotProvided ? '미기입 상태' : '선택 입력',
      initiallyExpanded: !_isEditMode,
      trailing: Switch.adaptive(
        value: _inbodyNotProvided,
        onChanged: (v) => setState(() => _inbodyNotProvided = v),
        activeColor: kPagePrimary,
      ),
      child: AbsorbPointer(
        absorbing: _inbodyNotProvided,
        child: Opacity(
          opacity: _inbodyNotProvided ? 0.45 : 1.0,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _numField(_heightC, '키', 'cm')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_weightC, '체중', 'kg')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_bfPctC, '체지방률', '%')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_smmC, '골격근량', 'kg')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_bfKgC, '체지방량', 'kg')),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPageFieldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kPageBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BMI (자동 계산)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kPageText,
                      ),
                    ),
                    Text(
                      (_inbodyNotProvided || bmi <= 0)
                          ? '-'
                          : bmi.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: kPagePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etcSection() {
    return _ExpandableSectionCard(
      icon: Icons.event_note_outlined,
      title: '메모 / 체크포인트',
      subtitle: '좌우로 넘기며 메모와 이벤트를 관리합니다',
      initiallyExpanded: true,
      child: Column(
        children: [
          _buildMemoPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            height: 244,
            child: PageView(
              controller: _memoPageController,
              onPageChanged: (index) {
                setState(() {
                  _memoPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      _tapDateField(
                        label: '다음 예약일',
                        text: _formatDate(_nextReservation),
                        onTap: () => _pickDate(
                          current: _nextReservation,
                          onPicked: (d) => setState(() => _nextReservation = d),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteC,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          '등록 시 메모 / 최근 메모',
                          hint: '선호 운동, 특이사항, 상담 내용 등',
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      _tapDateField(
                        label: '결혼기념일',
                        text: _formatDate(_anniversaryDate),
                        onTap: () => _pickDate(
                          current: _anniversaryDate,
                          onPicked: (d) => setState(() => _anniversaryDate = d),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _specialEventC,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '특별 일정',
                          hint: '예: 출장, 시험, 여행, 가족 행사',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPageFieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPageBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '자동 체크포인트',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kPageText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _eventSummaryText(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: kPageMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildMemoPageDots(),
        ],
      ),
    );
  }

  ImageProvider<Object>? _avatarImage() {
    if (_profileBytes != null) return MemoryImage(_profileBytes!);
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return null;
  }

  String _prettyPhone(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '-';

    if (d.startsWith('02')) {
      if (d.length <= 2) return d;
      if (d.length <= 5) return '${d.substring(0, 2)}-${d.substring(2)}';
      if (d.length <= 9) {
        return '${d.substring(0, 2)}-${d.substring(2, d.length - 4)}-${d.substring(d.length - 4)}';
      }
      return '${d.substring(0, 2)}-${d.substring(2, 6)}-${d.substring(6, 10)}';
    }

    if (d.length <= 3) return d;
    if (d.length <= 7) return '${d.substring(0, 3)}-${d.substring(3)}';
    return '${d.substring(0, 3)}-${d.substring(3, d.length - 4)}-${d.substring(d.length - 4)}';
  }

  Widget _tapDateField({
    required String label,
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDecoration(
          label,
          suffixIcon: const Icon(Icons.date_range),
        ),
        child: Text(
          text.isEmpty ? '선택하세요' : text,
          style: TextStyle(
            color: text.isEmpty ? kPageMuted : kPageText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, String suffix) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(
        signed: false,
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*$')),
      ],
      decoration: _inputDecoration(label, suffixText: suffix),
      validator: (v) {
        if (_inbodyNotProvided) return null;
        if (v == null || v.trim().isEmpty) return '값 입력';
        final parsed = double.tryParse(v);
        if (parsed == null) return '숫자만 입력';
        if (parsed < 0) return '0 이상';
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Future<int?> _askDays(BuildContext context) async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('직접입력 (일수)'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '예: 45'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    c.dispose();

    if (r == null) return null;
    final d = int.tryParse(r);
    if (d == null || d <= 0) return null;
    return d;
  }

  double _calcBmi() {
    if (_inbodyNotProvided) return 0;
    final h = double.tryParse(_heightC.text) ?? 0;
    final w = double.tryParse(_weightC.text) ?? 0;
    if (h <= 0) return 0;
    final hm = h / 100.0;
    return double.parse((w / (hm * hm)).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final gradeTheme = _gradeTheme();
    return Scaffold(
      backgroundColor: kPageBg,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kPageBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openContract,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('계약서'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPageText,
                    side: const BorderSide(color: kPageBorder),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitAndStay,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isEditMode ? '회원정보 저장' : '신규 회원 등록'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPagePrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          MemberFormGradientHeader(
            title: _pageTitle,
            subtitle: _pageSubtitle,
            onBackTap: () => Navigator.of(context).maybePop(),
            gradientColors: gradeTheme.gradient,
            accentColor: gradeTheme.accent,
            borderColor: gradeTheme.border,
            action: _buildHeaderMenu(),
            badges: _buildHeaderBadges(),
            collapsedChild: _buildCollapsedHeaderInfo(),
            isExpanded: _isHeaderExpanded,
            onToggleExpand: () {
              setState(() {
                _isHeaderExpanded = !_isHeaderExpanded;
              });
            },
            expandedChild: _buildHeaderExpandedBox(),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  if (!_hideTopActionCards) ...[
                    _trainingLogConsentCard(),
                    const SizedBox(height: 8),
                  ],
                  _buildRequiredFieldsNoticeCard(),
                  if (_missingRequiredFields().isNotEmpty)
                    const SizedBox(height: 8),
                  _basicInfoSection(),
                  const SizedBox(height: 8),
                  _memberSetupSection(),
                  const SizedBox(height: 8),
                  _lessonMembershipSection(),
                  const SizedBox(height: 8),
                  _healthSection(),
                  const SizedBox(height: 8),
                  _etcSection(),
                  const SizedBox(height: 8),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- gradient header ------------------------- */

class MemberFormGradientHeader extends StatelessWidget {
  const MemberFormGradientHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBackTap,
    required this.gradientColors,
    required this.accentColor,
    required this.borderColor,
    this.badges = const [],
    this.isExpanded = false,
    this.onToggleExpand,
    this.expandedChild,
    this.action,
    this.collapsedChild,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBackTap;
  final List<MemberHeaderBadgeData> badges;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final Widget? expandedChild;
  final Widget? action;
  final Widget? collapsedChild;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14,
        topPadding + 10,
        14,
        isExpanded && expandedChild != null ? 12 : 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderFullCreditCardShell(
            gradientColors: gradientColors,
            accentColor: accentColor,
            borderColor: borderColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCardTopBar(
                  title: title,
                  onBackTap: onBackTap,
                  action: action,
                ),
                if (collapsedChild != null) ...[
                  const SizedBox(height: 8),
                  collapsedChild!,
                ] else if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: badges.map((badge) {
                        return _MemberHeaderBadge(data: badge);
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isExpanded && expandedChild != null
                ? Padding(
              key: const ValueKey('member_form_header_open'),
              padding: const EdgeInsets.only(top: 10),
              child: expandedChild!,
            )
                : const SizedBox.shrink(
              key: ValueKey('member_form_header_closed'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderFullCreditCardShell extends StatelessWidget {
  const _HeaderFullCreditCardShell({
    required this.child,
    required this.gradientColors,
    required this.accentColor,
    required this.borderColor,
  });

  final Widget child;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: accentColor.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      gradientColors.first.withOpacity(0.98),
                      gradientColors.last.withOpacity(0.96),
                      Colors.black.withOpacity(0.16),
                    ],
                    stops: const [0.0, 0.68, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _HeaderCardTexturePainter(
                  accentColor: accentColor,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.transparent,
                        Colors.white.withOpacity(0.05),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _HeaderCardTopBar extends StatelessWidget {
  const _HeaderCardTopBar({
    required this.title,
    required this.onBackTap,
    required this.action,
  });

  final String title;
  final VoidCallback onBackTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            InkWell(
              onTap: onBackTap,
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class MemberHeaderBadgeData {
  const MemberHeaderBadgeData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _MemberHeaderBadge extends StatelessWidget {
  const _MemberHeaderBadge({
    required this.data,
  });

  final MemberHeaderBadgeData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.icon,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              '${data.label} · ${data.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MemberSummarySection extends StatelessWidget {
  const _MemberSummarySection({
    required this.icon,
    required this.title,
    required this.topValue,
    required this.bottomValue,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String topValue;
  final String bottomValue;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final String resolvedTop = topValue.trim().isEmpty ? '-' : topValue.trim();
    final String resolvedBottom =
    bottomValue.trim().isEmpty ? '-' : bottomValue.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MemberSummaryBoxLabel(
          icon: icon,
          label: title,
          color: Colors.white.withOpacity(0.92),
        ),
        const SizedBox(height: 10),
        Text(
          resolvedTop,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.74),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          resolvedBottom,
          maxLines: isWarning ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: isWarning ? 13 : 18,
            fontWeight: FontWeight.w900,
            height: isWarning ? 1.25 : 1.1,
            letterSpacing: isWarning ? -0.1 : -0.2,
          ),
        ),
      ],
    );
  }
}

class _MemberSummaryBoxLabel extends StatelessWidget {
  const _MemberSummaryBoxLabel({
    super.key,
    required this.icon,
    required this.label,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withOpacity(0.92),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class MemberSummaryThreeBoxHeader extends StatelessWidget {
  const MemberSummaryThreeBoxHeader({
    super.key,
    required this.avatarImage,
    required this.name,
    required this.phone,
    required this.lessonType,
    required this.lessonSummary,
    required this.warningSummary,
    required this.accentColor,
    required this.borderColor,
    required this.membershipLabel,
    required this.membershipPeriod,
    required this.statusIcon,
    required this.isFlipped,
    required this.onFlip,
    required this.contractStatusText,
    required this.consentStatusText,
    required this.memberGradeText,
    required this.reregisterText,
    required this.noShowText,
    required this.serviceText,
    required this.memoText,
    required this.groupLabel,
    required this.memberStatusText,
  });

  final ImageProvider<Object>? avatarImage;
  final String name;
  final String phone;
  final String lessonType;
  final String lessonSummary;
  final String warningSummary;
  final Color accentColor;
  final Color borderColor;
  final String membershipLabel;
  final String membershipPeriod;
  final IconData statusIcon;

  final bool isFlipped;
  final VoidCallback onFlip;

  final String contractStatusText;
  final String consentStatusText;
  final String memberGradeText;
  final String reregisterText;
  final String noShowText;
  final String serviceText;
  final String memoText;
  final String groupLabel;
  final String memberStatusText;

  String get _lessonLine {
    if (lessonSummary.trim().isEmpty || lessonSummary.trim() == '-') {
      return '수업 -';
    }

    final parts = lessonSummary.split('/');
    final typeText = lessonType.trim().isEmpty ? '-' : lessonType.trim();

    if (parts.length == 2) {
      final total = parts[0].trim();
      final remain = parts[1].trim();
      return '수업 $typeText   총 ${total}회 / 잔여 ${remain}회';
    }

    return '수업 $typeText';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: isFlipped ? math.pi : 0,
        ),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
        builder: (context, angle, _) {
          final bool showBack = angle > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateY(angle),
            child: showBack
                ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _MembershipHeaderCardShell(
                accentColor: accentColor,
                borderColor: borderColor,
                child: _buildBackFace(context),
              ),
            )
                : _MembershipHeaderCardShell(
              accentColor: accentColor,
              borderColor: borderColor,
              child: _buildFrontFace(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontFace(BuildContext context) {
    final displayTitle =
    name.trim().isEmpty ? '신규 멤버십카드생성중' : '${name.trim()} 님';

    final displayPhone = phone.trim().isEmpty ? '연락처 미입력' : phone.trim();

    final membershipTitle =
    membershipLabel.trim().isEmpty ? '멤버십 -' : membershipLabel.trim();

    final membershipPeriodText =
    membershipPeriod.trim().isEmpty ? '-' : membershipPeriod.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: avatarImage != null
                      ? Image(
                    image: avatarImage!,
                    fit: BoxFit.cover,
                  )
                      : Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: Colors.white.withOpacity(0.86),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderStatusBadge(text: memberStatusText),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      displayPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _lessonLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.98),
                              fontSize: 13.4,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _HeaderMetalChip(
                          accentColor: accentColor,
                          borderColor: borderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      membershipTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.98),
                        fontSize: 13.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (membershipPeriodText != '-') ...[
                      const SizedBox(height: 4),
                      Text(
                        membershipPeriodText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: 12.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _HeaderMagneticStripe(
          groupLabel: groupLabel,
          isFlipped: isFlipped,
          onTap: onFlip,
          helperText: 'MAGNETIC STRIPE · TAP TO BACK',
        ),
      ],
    );
  }

  Widget _buildBackFace(BuildContext context) {
    final contractChipText =
    contractStatusText == '미작성' ? '계약서 미작성' : '계약서 완료';

    final consentChipText =
    consentStatusText == '필요' ? '동의 필요' : '동의 완료';

    final noShowSummary = noShowText.trim().isEmpty ? '-' : noShowText.trim();
    final serviceSummary =
    serviceText.trim().isEmpty ? '-' : serviceText.trim();
    final gradeSummary =
    memberGradeText.trim().isEmpty ? '-' : memberGradeText.trim();
    final memoSummary = memoText.trim().isEmpty ? '메모 없음' : memoText.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '재등록 $reregisterText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderBackTinyChip(text: contractChipText),
              const SizedBox(width: 6),
              _HeaderBackTinyChip(text: consentChipText),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _HeaderBackMetric(
                  label: 'NO SHOW',
                  value: noShowSummary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderBackMetric(
                  label: 'SERVICE',
                  value: serviceSummary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderBackMetric(
                  label: 'GRADE',
                  value: gradeSummary,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '메모',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          memoSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.2,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HeaderBackQr(accentColor: accentColor),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: InkWell(
            onTap: onFlip,
            borderRadius: BorderRadius.circular(999),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.14),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flip_to_front_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '앞면 보기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MembershipHeaderCardShell extends StatelessWidget {
  const _MembershipHeaderCardShell({
    required this.child,
    required this.accentColor,
    required this.borderColor,
  });

  final Widget child;
  final Color accentColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class _HeaderMagneticStripe extends StatelessWidget {
  const _HeaderMagneticStripe({
    required this.groupLabel,
    required this.isFlipped,
    required this.onTap,
    required this.helperText,
  });

  final String groupLabel;
  final bool isFlipped;
  final VoidCallback onTap;
  final String helperText;

  static const double _bottomRadius = 30;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(_bottomRadius),
        ),
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF030303),
                Color(0xFF202020),
                Color(0xFF050505),
                Color(0xFF2C2C2C),
                Color(0xFF070707),
              ],
              stops: [0.0, 0.25, 0.52, 0.78, 1.0],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(_bottomRadius),
              bottomRight: Radius.circular(_bottomRadius),
            ),
            border: Border(
              top: BorderSide(
                color: Color(0xFF303030),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Color(0x22FFFFFF),
                          Colors.transparent,
                          Color(0x18FFFFFF),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.28, 0.52, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                child: Row(
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      color: Colors.white.withOpacity(0.62),
                      size: 19,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_left_rounded,
                      color: Colors.white.withOpacity(0.34),
                      size: 17,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 76),
                child: Text(
                  groupLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.35,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                child: AnimatedRotation(
                  turns: isFlipped ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withOpacity(0.92),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBackMetric extends StatelessWidget {
  const _HeaderBackMetric({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
      alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.6,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HeaderBackQr extends StatelessWidget {
  const _HeaderBackQr({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _HeaderQrPainter(
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _HeaderQrPainter extends CustomPainter {
  const _HeaderQrPainter({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fg = Paint()..color = accentColor.withOpacity(0.92);

    const cells = 9;
    final cell = size.width / cells;

    final points = <Offset>[
      Offset(0, 0),
      Offset(1, 0),
      Offset(2, 0),
      Offset(6, 0),
      Offset(7, 0),
      Offset(8, 0),
      Offset(0, 1),
      Offset(2, 1),
      Offset(4, 1),
      Offset(6, 1),
      Offset(8, 1),
      Offset(0, 2),
      Offset(1, 2),
      Offset(2, 2),
      Offset(5, 2),
      Offset(6, 2),
      Offset(7, 2),
      Offset(8, 2),
      Offset(3, 3),
      Offset(5, 3),
      Offset(1, 4),
      Offset(2, 4),
      Offset(4, 4),
      Offset(7, 4),
      Offset(0, 5),
      Offset(3, 5),
      Offset(4, 5),
      Offset(8, 5),
      Offset(0, 6),
      Offset(1, 6),
      Offset(2, 6),
      Offset(5, 6),
      Offset(6, 6),
      Offset(8, 6),
      Offset(0, 7),
      Offset(2, 7),
      Offset(4, 7),
      Offset(6, 7),
      Offset(0, 8),
      Offset(1, 8),
      Offset(2, 8),
      Offset(5, 8),
      Offset(7, 8),
      Offset(8, 8),
    ];

    for (final p in points) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            p.dx * cell,
            p.dy * cell,
            cell * 0.82,
            cell * 0.82,
          ),
          const Radius.circular(1),
        ),
        fg,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderQrPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

class _HeaderCardTexturePainter extends CustomPainter {
  const _HeaderCardTexturePainter({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.86, -0.86),
        radius: 0.95,
        colors: [
          accentColor.withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      glowPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (double x = -size.width; x < size.width * 2; x += 34) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeaderCardTexturePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}


class _HeaderStatusBadge extends StatelessWidget {
  const _HeaderStatusBadge({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderBackTinyChip extends StatelessWidget {
  const _HeaderBackTinyChip({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderBackBlockCard extends StatelessWidget {
  const _HeaderBackBlockCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.8,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetalChip extends StatelessWidget {
  const _HeaderMetalChip({
    required this.accentColor,
    required this.borderColor,
  });

  final Color accentColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            borderColor.withOpacity(0.95),
            accentColor.withOpacity(0.92),
            Colors.white.withOpacity(0.72),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.26),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 6,
            child: Container(
              width: 10,
              height: 18,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          Positioned(
            left: 18,
            top: 6,
            child: Container(
              width: 2,
              height: 18,
              color: Colors.white.withOpacity(0.30),
            ),
          ),
          Positioned(
            left: 23,
            top: 6,
            child: Container(
              width: 2,
              height: 18,
              color: Colors.white.withOpacity(0.24),
            ),
          ),
          Positioned(
            left: 28,
            top: 6,
            child: Container(
              width: 2,
              height: 18,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackInfoChip extends StatelessWidget {
  const _HeaderBackInfoChip({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 214 : 146,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- widgets ------------------------- */

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPageBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kPagePrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kPagePrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: kPageText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPageMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ExpandableSectionCard extends StatelessWidget {
  const _ExpandableSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kPageBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kPagePrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kPagePrimary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kPageText,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPageMuted,
            ),
          ),
          trailing: trailing,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          children: [
            child,
          ],
        ),
      ),
    );
  }
}

class _HeaderMiniStat extends StatelessWidget {
  const _HeaderMiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.74),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassHeaderChip extends StatelessWidget {
  const _GlassHeaderChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SoftInfoChip extends StatelessWidget {
  const _SoftInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kPageBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kPageMuted,
        ),
      ),
    );
  }
}

/* ------------------------- phone formatter ------------------------- */

class _PostSaveActionItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _PostSaveActionItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}

class _KoreaPhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String f = digits;

    if (digits.startsWith('02')) {
      if (digits.length > 2 && digits.length <= 5) {
        f = '${digits.substring(0, 2)}-${digits.substring(2)}';
      } else if (digits.length > 5 && digits.length <= 9) {
        f =
        '${digits.substring(0, 2)}-${digits.substring(2, digits.length - 4)}-${digits.substring(digits.length - 4)}';
      } else if (digits.length >= 10) {
        f =
        '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6, 10)}';
      }
    } else {
      if (digits.length > 3 && digits.length <= 7) {
        f = '${digits.substring(0, 3)}-${digits.substring(3)}';
      } else if (digits.length > 7) {
        f =
        '${digits.substring(0, 3)}-${digits.substring(3, digits.length - 4)}-${digits.substring(digits.length - 4)}';
      }
    }

    return TextEditingValue(
      text: f,
      selection: TextSelection.collapsed(offset: f.length),
    );
  }
}
