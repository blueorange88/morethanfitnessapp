import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;
import '../theme/app_colors.dart';

const Color kMembershipContractPrimary = Color(0xFF4F46E5);
const Color kMembershipContractBg = Color(0xFFF8FAFC);
const Color kMembershipContractBorder = Color(0xFFE5E7EB);
const Color kMembershipContractText = Color(0xFF111827);
const Color kMembershipContractMuted = Color(0xFF6B7280);

class MembershipContractPage extends StatefulWidget {
  const MembershipContractPage({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.trainerName,
    required this.lessonType,
    required this.totalSessions,
    required this.remainingSessions,
    required this.membershipStartAt,
    required this.membershipEndAt,
    required this.membershipPaused,
    this.loadExistingDraft = true,
  });

  final String memberId;
  final String memberName;
  final String trainerName;
  final String lessonType;
  final int totalSessions;
  final int remainingSessions;
  final DateTime? membershipStartAt;
  final DateTime? membershipEndAt;
  final bool membershipPaused;
  final bool loadExistingDraft;

  @override
  State<MembershipContractPage> createState() => _MembershipContractPageState();
}

class _MembershipContractPageState extends State<MembershipContractPage> {
  late final TextEditingController _productNameC;
  late final TextEditingController _maxPauseDaysC;
  late final TextEditingController _pauseRuleMemoC;
  late final TextEditingController _refundRuleMemoC;
  late final TextEditingController _transferRuleMemoC;
  late final TextEditingController _extraMemoC;

  bool _isSaving = false;
  bool _isDraftLoaded = false;
  bool _draftExists = false;

  final _signatureNameC = TextEditingController();

  bool _isSigned = false;
  DateTime? _signedAt;
  bool _isSigning = false;
  String? _signatureImageUrl;

  final GlobalKey _contractCaptureKey = GlobalKey();

  String? _contractImageUrl;
  DateTime? _contractImageArchivedAt;
  bool _isArchivingImage = false;

  DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    final suggestedPauseDays = _suggestedMaxPauseDays();

    _productNameC = TextEditingController(
      text: _defaultProductName(),
    );
    _maxPauseDaysC = TextEditingController(
      text: suggestedPauseDays.toString(),
    );
    _pauseRuleMemoC = TextEditingController(
      text:
          '회원권 정지는 계약 기간 내 최대 ${suggestedPauseDays}일까지 가능하며, 정지 기간만큼 종료일을 연장할 수 있습니다.',
    );
    _refundRuleMemoC = TextEditingController(
      text: '환불 조건은 센터/강사 운영 정책과 실제 이용 내역을 기준으로 별도 확인합니다.',
    );
    _transferRuleMemoC = TextEditingController(
      text: '회원권 양도는 담당 강사 확인 후 가능 여부를 결정합니다.',
    );

    _signatureNameC.text = widget.memberName.trim();

    if (widget.loadExistingDraft) {
      _loadDraftFromFirestore();
    } else {
      _isDraftLoaded = true;
    }
    _extraMemoC = TextEditingController();
  }

  @override
  void dispose() {
    _productNameC.dispose();
    _maxPauseDaysC.dispose();
    _pauseRuleMemoC.dispose();
    _refundRuleMemoC.dispose();
    _transferRuleMemoC.dispose();
    _extraMemoC.dispose();
    _signatureNameC.dispose();
    super.dispose();
  }

  String _safeMemberName() {
    final value = widget.memberName.trim();
    return value.isEmpty ? '회원' : value;
  }

  String _safeTrainerName() {
    final value = widget.trainerName.trim();
    return value.isEmpty ? '담당 강사' : value;
  }

  String _dateText(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('yyyy-MM-dd').format(value);
  }

  int? _membershipDays() {
    final start = widget.membershipStartAt;
    final end = widget.membershipEndAt;

    if (start == null || end == null) return null;

    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);

    return e.difference(s).inDays + 1;
  }

  int _suggestedMaxPauseDays() {
    final days = _membershipDays();

    if (days == null || days <= 0) return 0;

    if (days <= 90) return 14;
    if (days <= 180) return 30;
    if (days <= 365) return 60;

    return 90;
  }

  String _defaultProductName() {
    final days = _membershipDays();

    if (days == null || days <= 0) {
      return '회원권';
    }

    if (days <= 40) return '1개월 회원권';
    if (days <= 100) return '3개월 회원권';
    if (days <= 200) return '6개월 회원권';
    if (days <= 380) return '12개월 회원권';

    return '${days}일 회원권';
  }

  Future<void> _loadDraftFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('membership_contracts')
          .doc('current')
          .get();

      if (!mounted) return;

      if (!snap.exists) {
        setState(() {
          _isDraftLoaded = true;
          _draftExists = false;
        });
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};

      String textValue(String key, String fallback) {
        final value = (data[key] ?? '').toString().trim();
        return value.isEmpty ? fallback : value;
      }

      int intValue(String key, int fallback) {
        final value = data[key];

        if (value is num) return value.toInt();

        final parsed = int.tryParse((value ?? '').toString());
        return parsed ?? fallback;
      }

      setState(() {
        _draftExists = true;
        _isDraftLoaded = true;

        _productNameC.text = textValue(
          'productName',
          _productNameC.text,
        );

        _maxPauseDaysC.text = intValue(
          'maxPauseDays',
          int.tryParse(_maxPauseDaysC.text.trim()) ?? _suggestedMaxPauseDays(),
        ).toString();

        _pauseRuleMemoC.text = textValue(
          'pauseRuleMemo',
          _pauseRuleMemoC.text,
        );

        _refundRuleMemoC.text = textValue(
          'refundRuleMemo',
          _refundRuleMemoC.text,
        );

        _transferRuleMemoC.text = textValue(
          'transferRuleMemo',
          _transferRuleMemoC.text,
        );

        _extraMemoC.text = textValue(
          'extraMemo',
          _extraMemoC.text,
        );

        _isSigned = (data['status'] ?? '').toString() == 'signed' ||
            data['signedAt'] != null;

        _signedAt = _dateFromAny(data['signedAt']);

        _signatureNameC.text = textValue(
          'signedByName',
          _signatureNameC.text,
        );
        final loadedSignatureUrl =
            (data['signatureImageUrl'] ?? '').toString().trim();

        _signatureImageUrl =
            loadedSignatureUrl.isEmpty ? null : loadedSignatureUrl;

        final loadedContractImageUrl =
            (data['contractImageUrl'] ?? data['archiveImageUrl'] ?? '')
                .toString()
                .trim();

        _contractImageUrl =
            loadedContractImageUrl.isEmpty ? null : loadedContractImageUrl;

        _contractImageArchivedAt = _dateFromAny(
          data['contractImageArchivedAt'] ?? data['archivedAt'],
        );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isDraftLoaded = true;
      });
    }
  }

  Future<void> _saveDraft() async {
    final memberId = widget.memberId.trim();

    if (memberId.isEmpty) {
      _showToast('회원 연결이 없어 저장할 수 없어요.');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final maxPauseDays =
          int.tryParse(_maxPauseDaysC.text.trim()) ?? _suggestedMaxPauseDays();

      await FirebaseFirestore.instance
          .collection('members')
          .doc(memberId)
          .collection('membership_contracts')
          .doc('current')
          .set({
        'memberId': memberId,
        'memberName': _safeMemberName(),
        'trainerName': _safeTrainerName(),
        'productName': _productNameC.text.trim(),
        'lessonType': widget.lessonType.trim(),
        'totalSessions': widget.totalSessions,
        'remainingSessions': widget.remainingSessions,
        'membershipStartAt': widget.membershipStartAt == null
            ? null
            : Timestamp.fromDate(widget.membershipStartAt!),
        'membershipEndAt': widget.membershipEndAt == null
            ? null
            : Timestamp.fromDate(widget.membershipEndAt!),
        'membershipDays': _membershipDays(),
        'maxPauseDays': maxPauseDays,
        'pauseRuleMemo': _pauseRuleMemoC.text.trim(),
        'refundRuleMemo': _refundRuleMemoC.text.trim(),
        'transferRuleMemo': _transferRuleMemoC.text.trim(),
        'extraMemo': _extraMemoC.text.trim(),
        'status': 'draft',
        'source': 'client_card_membership_contract',
        if (!_draftExists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('members').doc(memberId).set({
        'membershipContractDraftExists': true,
        'membershipContractStatus': 'draft',
        'membershipContractUpdatedAt': FieldValue.serverTimestamp(),
        'membership.maxPauseDaysFromContract': maxPauseDays,
        'membership.contractStatus': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showToast('회원권계약서 초안을 저장했어요.');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _showToast('회원권계약서 초안을 저장하지 못했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String> _uploadMembershipSignature(Uint8List bytes) async {
    final path =
        'membership_contract_signatures/${widget.memberId}/signature_${DateTime.now().millisecondsSinceEpoch}.png';

    final ref = FirebaseStorage.instance.ref(path);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'public, max-age=3600',
      ),
    );

    return ref.getDownloadURL();
  }

  Future<String> _uploadMembershipContractImage(Uint8List bytes) async {
    final path =
        'membership_contract_images/${widget.memberId}/contract_${DateTime.now().millisecondsSinceEpoch}.png';

    final ref = FirebaseStorage.instance.ref(path);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/png',
        cacheControl: 'public, max-age=3600',
      ),
    );

    return ref.getDownloadURL();
  }

  Future<Uint8List> _captureMembershipContractImage() async {
    await WidgetsBinding.instance.endOfFrame;

    final boundary = _contractCaptureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('contract_capture_boundary_not_found');
    }

    final image = await boundary.toImage(pixelRatio: 2.0);

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final bytes = byteData?.buffer.asUint8List();

    if (bytes == null || bytes.isEmpty) {
      throw Exception('contract_capture_bytes_empty');
    }

    return bytes;
  }

  Future<void> _completeSignature() async {
    if (_isSigning) return;

    final signedName = _signatureNameC.text.trim();

    if (signedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객님 이름을 입력해주세요.'),
        ),
      );
      return;
    }
    final signatureBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MembershipSignaturePadPage(
          memberName: widget.memberName.trim().isEmpty
              ? '회원'
              : widget.memberName.trim(),
        ),
      ),
    );

    if (!mounted || signatureBytes == null) {
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '회원권계약서 서명 완료',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: kMembershipContractText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.memberName} 님의 회원권계약서를 서명 완료 상태로 저장할게요.\n'
                    '이후에는 계약서 기준 정지/연장 조건으로 관리됩니다.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: kMembershipContractMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(sheetContext).colorScheme.secondary,
                            foregroundColor:
                                Theme.of(sheetContext).colorScheme.onSecondary,
                            minimumSize: const Size(0, 46),
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
      },
    );

    if (ok != true || !mounted) return;

    setState(() {
      _isSigning = true;
    });

    try {
      final now = DateTime.now();
      final maxPauseDays =
          int.tryParse(_maxPauseDaysC.text.trim()) ?? _suggestedMaxPauseDays();

      final signatureImageUrl =
          await _uploadMembershipSignature(signatureBytes);

      final contractRef = FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('membership_contracts')
          .doc('current');

      await contractRef.set({
        'memberId': widget.memberId,
        'memberName': widget.memberName.trim(),
        'trainerName': widget.trainerName.trim(),
        'productName': _productNameC.text.trim(),
        'lessonType': widget.lessonType.trim(),
        'totalSessions': widget.totalSessions,
        'remainingSessions': widget.remainingSessions,
        'membershipStartAt': widget.membershipStartAt == null
            ? null
            : Timestamp.fromDate(widget.membershipStartAt!),
        'membershipEndAt': widget.membershipEndAt == null
            ? null
            : Timestamp.fromDate(widget.membershipEndAt!),
        'membershipDays': _membershipDays(),
        'maxPauseDays': maxPauseDays,
        'pauseRuleMemo': _pauseRuleMemoC.text.trim(),
        'refundRuleMemo': _refundRuleMemoC.text.trim(),
        'transferRuleMemo': _transferRuleMemoC.text.trim(),
        'extraMemo': _extraMemoC.text.trim(),
        'status': 'signed',
        'signedAt': Timestamp.fromDate(now),
        'signedByName': signedName,
        'signatureType': 'drawn_signature',
        'signatureImageUrl': signatureImageUrl,
        'source': 'membership_contract_page',
        if (!_draftExists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .set({
        'membershipContractDraftExists': true,
        'membershipContractStatus': 'signed',
        'membershipContractSignedAt': Timestamp.fromDate(now),
        'membershipContractSignedByName': signedName,
        'membershipContractSignatureImageUrl': signatureImageUrl,
        'membership.maxPauseDaysFromContract': maxPauseDays,
        'membership.contractStatus': 'signed',
        'membership.contractSignedAt': Timestamp.fromDate(now),
        'membership.contractSignatureImageUrl': signatureImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _isSigned = true;
        _signedAt = now;
        _draftExists = true;
        _isSigning = false;
        _signatureImageUrl = signatureImageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원권계약서 서명을 완료했어요.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSigning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원권계약서 서명을 저장하지 못했어요. 다시 시도해주세요.'),
        ),
      );
    }
  }

  Future<void> _archiveContractImage() async {
    if (_isArchivingImage) return;

    if (!_isSigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서명 완료 후 계약서 이미지를 보관할 수 있어요.'),
        ),
      );
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '계약서 이미지를 보관할까요?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: kMembershipContractText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '현재 화면의 회원권계약서 내용을 이미지로 저장해둘게요.\n'
                    '나중에 PDF 보관 기능을 붙이면 이 이미지도 함께 활용할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: kMembershipContractMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(sheetContext).colorScheme.secondary,
                            foregroundColor:
                                Theme.of(sheetContext).colorScheme.onSecondary,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '보관하기',
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
      },
    );

    if (ok != true || !mounted) return;

    setState(() {
      _isArchivingImage = true;
    });

    try {
      final bytes = await _captureMembershipContractImage();
      final imageUrl = await _uploadMembershipContractImage(bytes);
      final archivedAt = DateTime.now();

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('membership_contracts')
          .doc('current')
          .set({
        'contractImageUrl': imageUrl,
        'archiveImageUrl': imageUrl,
        'contractImageArchivedAt': Timestamp.fromDate(archivedAt),
        'archivedAt': Timestamp.fromDate(archivedAt),
        'archiveType': 'image_png',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .set({
        'membershipContractImageUrl': imageUrl,
        'membershipContractArchivedAt': Timestamp.fromDate(archivedAt),
        'membership.contractImageUrl': imageUrl,
        'membership.contractArchivedAt': Timestamp.fromDate(archivedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _contractImageUrl = imageUrl;
        _contractImageArchivedAt = archivedAt;
        _isArchivingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원권계약서 이미지를 보관했어요.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isArchivingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계약서 이미지를 보관하지 못했어요. 다시 시도해주세요.'),
        ),
      );
    }
  }

  void _showToast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kMembershipContractBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kMembershipContractBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: kMembershipContractPrimary,
          width: 1.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membershipDays = _membershipDays();
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: context.mtfHeaderGradient),
        ),
        elevation: 0,
        title: const Text(
          '회원권계약서',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: tokens.cardSurface,
            border: Border(
              top: BorderSide(color: tokens.cardBorder),
            ),
          ),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveDraft,
            icon: _isSaving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? '저장 중' : '초안 저장'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepaintBoundary(
              key: _contractCaptureKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(
                    memberName: _safeMemberName(),
                    trainerName: _safeTrainerName(),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.inventory_2_outlined,
                    title: '회원카드 기준 정보',
                    subtitle: '현재 회원카드에 등록된 값을 먼저 불러왔어요.',
                    child: Column(
                      children: [
                        _InfoRow(label: '상품명', value: _productNameC.text),
                        _InfoRow(
                          label: '회원권 기간',
                          value:
                              '${_dateText(widget.membershipStartAt)} ~ ${_dateText(widget.membershipEndAt)}',
                        ),
                        _InfoRow(
                          label: '총 기간',
                          value: membershipDays == null
                              ? '-'
                              : '${membershipDays}일',
                        ),
                        _InfoRow(
                          label: '레슨',
                          value:
                              '총 ${widget.totalSessions}회 / 잔여 ${widget.remainingSessions}회',
                        ),
                        _InfoRow(
                          label: '레슨 형태',
                          value: widget.lessonType.trim().isEmpty
                              ? '-'
                              : widget.lessonType.trim(),
                        ),
                        _InfoRow(
                          label: '현재 상태',
                          value: widget.membershipPaused ? '회원권 정지중' : '진행중',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.edit_document,
                    title: '계약 기본 정보',
                    subtitle: '나중에 서명 화면과 PDF 보관으로 이어질 영역이에요.',
                    child: Column(
                      children: [
                        TextField(
                          controller: _productNameC,
                          decoration: _inputDecoration(
                            '회원권 상품명',
                            hint: '예: 3개월 PT 회원권',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _maxPauseDaysC,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            '최대 정지 가능일',
                            suffixText: '일',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.pause_circle_outline_rounded,
                    title: '회원권 정지 / 재개 조건',
                    subtitle: '회원권 정지 가능일 검증 기준으로 사용합니다.',
                    child: TextField(
                      controller: _pauseRuleMemoC,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoration(
                        '정지 / 재개 조건',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.payments_outlined,
                    title: '환불 / 양도 / 연장 조건',
                    subtitle: '운영 기준을 명확히 남겨두는 영역이에요.',
                    child: Column(
                      children: [
                        TextField(
                          controller: _refundRuleMemoC,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _inputDecoration('환불 조건'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _transferRuleMemoC,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _inputDecoration('양도 조건'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _extraMemoC,
                          minLines: 2,
                          maxLines: 5,
                          decoration: _inputDecoration(
                            '추가 특약',
                            hint: '예: 부상, 출장, 개인 사정에 따른 예외 처리',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _signatureSection(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _archiveSection(),
            const SizedBox(height: 12),
            const _NoticeCard(),
          ],
        ),
      ),
    );
  }

  Widget _signatureSection() {
    final signedText = _signedAt == null
        ? '서명 전'
        : '서명 완료 · ${DateFormat('yyyy-MM-dd').format(_signedAt!)}';

    return _SectionCard(
      icon: Icons.draw_outlined,
      title: '회원 동의 / 서명',
      subtitle: signedText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _signatureNameC,
            enabled: !_isSigned,
            decoration: InputDecoration(
              labelText: '서명자 이름',
              hintText: '예: ${widget.memberName}',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_signatureImageUrl != null &&
              _signatureImageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '저장된 서명',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _signatureImageUrl!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const SizedBox(
                          height: 80,
                          child: Center(
                            child: Text(
                              '서명 이미지를 불러오지 못했어요.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color:
                  _isSigned ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSigned
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Text(
              _isSigned
                  ? '이 회원권계약서는 서명 완료 상태예요.'
                  : '회원이 내용을 확인했다면 서명 완료로 저장할 수 있어요. 실제 손글씨 서명/PDF 보관은 다음 단계에서 붙일 예정이에요.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: _isSigned
                    ? const Color(0xFF166534)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSigned || _isSigning ? null : _completeSignature,
              icon: _isSigning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(_isSigned ? '서명 완료됨' : '서명 완료 처리'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                minimumSize: const Size(0, 48),
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

  Widget _archiveSection() {
    final archivedText = _contractImageArchivedAt == null
        ? '보관 전'
        : '보관 완료 · ${DateFormat('yyyy-MM-dd').format(_contractImageArchivedAt!)}';

    return _SectionCard(
      icon: Icons.image_outlined,
      title: '계약서 이미지 보관',
      subtitle: archivedText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_contractImageUrl != null &&
              _contractImageUrl!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '보관된 계약서 이미지',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: kMembershipContractText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _contractImageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const SizedBox(
                          height: 90,
                          child: Center(
                            child: Text(
                              '계약서 이미지를 불러오지 못했어요.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kMembershipContractMuted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color:
                  _isSigned ? const Color(0xFFF8FAFC) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isSigned
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFFDE68A),
              ),
            ),
            child: Text(
              _isSigned
                  ? '현재 계약서 내용을 이미지로 보관할 수 있어요. 수정 후 다시 보관하면 최신 이미지로 갱신됩니다.'
                  : '서명 완료 후 계약서 이미지를 보관할 수 있어요.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: _isSigned
                    ? kMembershipContractMuted
                    : const Color(0xFF92400E),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: !_isSigned || _isArchivingImage
                  ? null
                  : _archiveContractImage,
              icon: _isArchivingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _contractImageUrl == null ? '계약서 이미지 보관' : '계약서 이미지 다시 보관',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kMembershipContractPrimary,
                side: BorderSide(
                  color: kMembershipContractPrimary.withOpacity(0.24),
                ),
                minimumSize: const Size(0, 48),
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
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.memberName,
    required this.trainerName,
  });

  final String memberName;
  final String trainerName;

  @override
  Widget build(BuildContext context) {
    final gradient = context.mtfHeaderGradient;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kMembershipContractPrimary.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
              ),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$memberName 님 회원권계약서',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '담당 $trainerName · 초안 작성',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
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
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mtfThemeTokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: tokens.contractDocumentSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.contractDocumentBorder),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kMembershipContractPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: kMembershipContractPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.contractDocumentText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: tokens.contractDocumentText
                              .withValues(alpha: 0.68),
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim().isEmpty ? '-' : value.trim();
    final tokens = context.mtfThemeTokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.contractDocumentText.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              cleanValue,
              style: TextStyle(
                color: tokens.contractDocumentText,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFDE68A),
        ),
      ),
      child: const Text(
        '지금 단계는 회원권계약서 초안입니다.\n'
        '다음 단계에서 회원 서명, PDF 보관, 계약서 기반 정지 가능일 검증을 연결하면 됩니다.',
        style: TextStyle(
          color: Color(0xFF92400E),
          fontSize: 11.5,
          height: 1.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MembershipSignaturePadPage extends StatefulWidget {
  const _MembershipSignaturePadPage({
    required this.memberName,
  });

  final String memberName;

  @override
  State<_MembershipSignaturePadPage> createState() =>
      _MembershipSignaturePadPageState();
}

class _MembershipSignaturePadPageState
    extends State<_MembershipSignaturePadPage> {
  final GlobalKey _signatureKey = GlobalKey();
  final List<Offset?> _points = [];

  bool get _hasSignature {
    return _points.whereType<Offset>().length >= 4;
  }

  void _clear() {
    setState(() {
      _points.clear();
    });
  }

  Future<void> _save() async {
    if (!_hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서명을 먼저 입력해주세요.'),
        ),
      );
      return;
    }

    try {
      final boundary = _signatureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('signature_boundary_not_found');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null || bytes.isEmpty) {
        throw Exception('signature_bytes_empty');
      }

      if (!mounted) return;

      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서명을 저장하지 못했어요. 다시 시도해주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: context.mtfHeaderGradient),
        ),
        elevation: 0,
        title: const Text(
          '회원권계약서 서명',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clear,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              '지우기',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: tokens.cardSurface,
            border: Border(
              top: BorderSide(
                color: tokens.cardBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.secondary,
                    foregroundColor: scheme.onSecondary,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '서명 저장',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE9D5FF),
              ),
            ),
            child: Text(
              '${widget.memberName} 님이 회원권계약서 내용을 확인했다면 아래 칸에 직접 서명해주세요.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4C1D95),
              ),
            ),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: _signatureKey,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                color: tokens.signatureCanvasSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: tokens.contractDocumentBorder,
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _points.add(null);
                  });
                },
                child: CustomPaint(
                  painter: _MembershipSignaturePainter(
                    points: _points,
                  ),
                  child: Stack(
                    children: [
                      if (!_hasSignature)
                        Center(
                          child: Text(
                            '여기에 서명해주세요',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF9CA3AF).withOpacity(0.55),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 42,
                        child: Container(
                          height: 1,
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      const Positioned(
                        right: 20,
                        bottom: 18,
                        child: Text(
                          'Signature',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '서명은 회원권계약서 이미지/PDF 보관 단계에서 함께 사용됩니다.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipSignaturePainter extends CustomPainter {
  const _MembershipSignaturePainter({
    required this.points,
  });

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current == null || next == null) continue;

      canvas.drawLine(current, next, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MembershipSignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
