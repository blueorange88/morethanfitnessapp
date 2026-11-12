import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/lesson_contract/lesson_contract_settings.dart';
import '../utils/lesson_contract/signature_strokes.dart';
import 'dev_tier_fixture.dart';
import 'mtf_firebase_functions.dart';

typedef ContractCallable =
    Future<dynamic> Function(String name, Map<String, Object?> parameters);

/// 레슨계약서 v2의 서버 호출(callable)과 설정 읽기를 모은 창구.
/// 앱은 계약 문서를 직접 쓰지 않고 서버 함수만 호출한다.
class PersonalContractGateway {
  PersonalContractGateway({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ContractCallable? callable,
  }) : _firestore = firestore,
       _storage = storage,
       _callable = callable ?? _defaultCallable;

  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;
  final ContractCallable _callable;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static Future<dynamic> _defaultCallable(
    String name,
    Map<String, Object?> parameters,
  ) => MtfFirebaseFunctions.call(name, parameters: parameters);

  /// 프로필 문서(소유자 읽기). 문서가 없으면 null.
  Future<Map<String, dynamic>?> loadProfile(String uid) async {
    final snapshot =
        await _db.collection('trainer_profiles').doc(uid.trim()).get();
    return snapshot.data();
  }

  Future<ContractSettings> loadSettings(String uid) async =>
      ContractSettings.fromProfile(await loadProfile(uid));

  /// 계약 초안을 만들거나(`idempotencyKey`) 고친다(`contractId`). 둘 중 하나만 준다.
  Future<ContractDraftResult> saveDraft({
    String? idempotencyKey,
    String? contractId,
    required String memberId,
    required Map<String, Object?> content,
  }) async {
    assert((idempotencyKey == null) != (contractId == null));
    final raw = await _callable('savePersonalContractDraft', {
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      if (contractId != null) 'contractId': contractId,
      'memberId': memberId,
      'content': content,
    });
    return ContractDraftResult.fromCallable(raw);
  }

  /// 저장된 계약 문서(소유자 읽기). 없으면 null.
  Future<Map<String, dynamic>?> loadContract(String contractId) async {
    final snapshot =
        await _db.collection('personal_contracts').doc(contractId.trim()).get();
    return snapshot.data();
  }

  /// 같은 회원에게 이 계약보다 뒤에 완료되어 횟수를 등록한 계약 중 가장 최근 것(없거나 못 읽으면 null).
  /// 파기는 가장 최근 등록 계약부터만 되어서, 막힌 이유를 알려 줄 때 쓴다. 같음 조건만 써서 색인이 필요 없다.
  Future<Map<String, dynamic>?> findLaterRegisteredContract(
    Map<String, dynamic> contract,
  ) async {
    final trainerId = (contract['trainerId'] ?? '').toString().trim();
    final memberId = (contract['memberId'] ?? '').toString().trim();
    final completedAt = contract['completedAt'];
    if (trainerId.isEmpty || memberId.isEmpty || completedAt is! Timestamp) {
      return null;
    }
    try {
      final snapshot =
          await _db
              .collection('personal_contracts')
              .where('trainerId', isEqualTo: trainerId)
              .where('memberId', isEqualTo: memberId)
              .get();
      Map<String, dynamic>? latest;
      Timestamp? latestAt;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final at = data['completedAt'];
        if (data['status'] != 'completed' ||
            data['registration'] == null ||
            at is! Timestamp ||
            at.compareTo(completedAt) <= 0) {
          continue;
        }
        if (latestAt == null || at.compareTo(latestAt) > 0) {
          latest = data;
          latestAt = at;
        }
      }
      return latest;
    } catch (_) {
      return null;
    }
  }

  /// 서명 한 단계를 서버에 기록한다. `step`은 `disclosure`(서명 ①) · `member`(서명 ②) ·
  /// `trainer`(강사). 서버가 순서·확인 항목·내용 해시를 검증하고 서버 시각으로 기록한다.
  Future<ContractSignResult> signContract({
    required String contractId,
    required String step,
    required String contentHash,
    List<String> checkedItems = const [],
    required Strokes strokes,
  }) async {
    final raw = await _callable('signPersonalContract', {
      'contractId': contractId,
      'step': step,
      'contentHash': contentHash,
      'checkedItems': checkedItems,
      'strokes': strokes,
    });
    return ContractSignResult.fromCallable(raw);
  }

  /// 완료된 계약서 PDF를 Storage에 올린다(`personal_contracts/{uid}/{계약 ID}/contract_v{n}.pdf`).
  /// 규칙이 완료된 본인 계약에 한 번만 올리게 허용한다(덮어쓰기 불가).
  Future<void> uploadContractPdf({
    required String trainerUid,
    required String contractId,
    required int version,
    required Uint8List bytes,
  }) async {
    final path =
        'personal_contracts/$trainerUid/$contractId/contract_v$version.pdf';
    final storage = _storage ?? FirebaseStorage.instance;
    await storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'application/pdf'));
  }

  /// 올라간 PDF를 서버에 등록하고(해시·크기 기록) 열람 링크를 새로 발급한다([issueLink]).
  /// 이미 등록된 PDF는 그대로 두고, 링크를 다시 발급하면 이전 링크는 바로 무효가 된다.
  Future<ContractDeliveryInfo> attachPdf(
    String contractId, {
    bool issueLink = true,
  }) async {
    final raw = await _callable('attachPersonalContractPdf', {
      'contractId': contractId,
      'issueLink': issueLink,
    });
    return ContractDeliveryInfo.fromCallable(raw);
  }

  /// 완료된 계약의 새 버전(정정·변경)을 만든다. 같은 [idempotencyKey]로 다시 부르면 이미 만든 새 버전을
  /// 돌려준다(`created: false`). 새 버전이 서명까지 완료되면 원본은 `이전 버전`이 된다. 완료되지 않은
  /// 계약이거나 이미 열린 새 버전이 있으면 서버가 거부한다.
  Future<ContractDraftResult> createNewVersion(
    String contractId, {
    required String idempotencyKey,
  }) async {
    final raw = await _callable('managePersonalContract', {
      'contractId': contractId,
      'action': 'new_version',
      'idempotencyKey': idempotencyKey,
    });
    return ContractDraftResult.fromCallable(raw);
  }

  /// 완료된 계약서를 파기한다(완료 후 3일 이내, 레슨을 받기 전). 회원의 파기 확인 서명 [strokes]와
  /// [reason]을 서버가 기록하고, 이 계약으로 등록된 횟수를 되돌리며, 회원에게 갈 알림 기록을 남긴다.
  /// 이미 파기된 계약을 다시 파기해도 안전하다.
  Future<void> voidContract(
    String contractId, {
    required String reason,
    required Strokes strokes,
  }) async {
    await _callable('voidPersonalContract', {
      'contractId': contractId,
      'reason': reason,
      'strokes': strokes,
    });
  }

  /// 완료된 계약서를 해지한다(기간 제한 없음, 그 회원의 가장 최근 완료 계약만). 환불은 다루지 않고
  /// 해지 사유·회원의 의사표시 방법/날짜와 그 시점의 횟수만 서버 시각으로 기록한다. 회원 서명 [strokes]는
  /// 선택이며, 있으면 증빙 등급이 `member_signed`, 없으면 `trainer_only`다. 이미 해지된 계약을 다시
  /// 해지해도 안전하다.
  Future<ContractTerminateResult> terminateContract(
    String contractId, {
    required String reasonCode,
    String reasonNote = '',
    required String noticeChannel,
    required String noticeDate,
    bool markExpired = false,
    Strokes? strokes,
  }) async {
    final raw = await _callable('terminatePersonalContract', {
      'contractId': contractId,
      'reasonCode': reasonCode,
      'reasonNote': reasonNote,
      'noticeChannel': noticeChannel,
      'noticeDate': noticeDate,
      'markExpired': markExpired,
      if (strokes != null && strokes.isNotEmpty) 'strokes': strokes,
    });
    return ContractTerminateResult.fromCallable(raw);
  }

  /// 서명이 끝나지 않은 계약(작성 중·서명 진행 중)을 취소한다. 서버에 취소 기록이 남고, 완료된
  /// 계약은 `contract_locked`로 거부된다. 이미 취소된 계약을 다시 취소해도 안전하다.
  Future<void> cancelContract(
    String contractId, {
    required String reason,
  }) async {
    await _callable('managePersonalContract', {
      'contractId': contractId,
      'action': 'cancel',
      'reason': reason,
    });
  }

  /// 열람 링크를 회원에게 보냈다는 기록(`share_sheet` 공유 · `copy_link` 링크 복사).
  Future<void> markShared(String contractId, {required String channel}) async {
    await _callable('managePersonalContract', {
      'contractId': contractId,
      'action': 'mark_shared',
      'channel': channel,
    });
  }

  /// 서명 이벤트에 저장된 서명 획(소유자 읽기). 없으면 빈 목록.
  Future<Strokes> loadSignatureStrokes(
    String contractId,
    String eventId,
  ) async {
    if (eventId.trim().isEmpty) return const [];
    final snapshot =
        await _db
            .collection('personal_contracts')
            .doc(contractId.trim())
            .collection('events')
            .doc(eventId.trim())
            .get();
    final payload = snapshot.data()?['payload'];
    return strokesFromStored(payload is Map ? payload['strokes'] : null);
  }

  /// 고객카드(회원 문서)의 이름·연락처·생년월일. 문서가 없으면 null.
  Future<Map<String, dynamic>?> loadMemberCard(String memberId) async {
    final snapshot = await _db.collection('members').doc(memberId.trim()).get();
    return snapshot.data();
  }

  /// 마이페이지에서 올린 센터 로고 경로를 저장한다(빈 문자열이면 지운다).
  Future<void> saveCenterLogo(String path) async {
    await _callable('savePersonalContractSettings', {'centerLogoPath': path});
  }

  Future<void> saveSettings({
    ContractParty? party,
    ContractDefaults? defaults,
    List<ContractProductPreset>? products,
  }) async {
    final payload = <String, Object?>{
      if (party != null) 'contractParty': party.toCallable(),
      if (defaults != null) 'contractDefaults': defaults.toCallable(),
      if (products != null)
        'contractProducts': [for (final item in products) item.toCallable()],
    };
    if (payload.isEmpty) return;
    await _callable('savePersonalContractSettings', payload);
  }
}

/// `attachPersonalContractPdf` 응답. [viewUrl]은 링크를 새로 발급했을 때만 있다.
class ContractDeliveryInfo {
  const ContractDeliveryInfo({
    required this.contractId,
    required this.version,
    required this.pdfHash,
    required this.pdfSize,
    this.viewUrl,
    this.linkExpiresAt,
  });

  final String contractId;
  final int version;
  final String pdfHash;
  final int pdfSize;
  final String? viewUrl;
  final DateTime? linkExpiresAt;

  factory ContractDeliveryInfo.fromCallable(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final expiresMs = map['linkExpiresAtMs'];
    final url = (map['viewUrl'] ?? '').toString();
    return ContractDeliveryInfo(
      contractId: (map['contractId'] ?? '').toString(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      pdfHash: (map['pdfHash'] ?? '').toString(),
      pdfSize: (map['pdfSize'] as num?)?.toInt() ?? 0,
      viewUrl: url.isEmpty ? null : url,
      linkExpiresAt:
          expiresMs is num
              ? DateTime.fromMillisecondsSinceEpoch(expiresMs.toInt())
              : null,
    );
  }
}

/// `signPersonalContract` 응답.
class ContractSignResult {
  const ContractSignResult({
    required this.status,
    required this.contractNo,
    this.alreadySigned = false,
  });

  final String status;
  final String contractNo;
  final bool alreadySigned;

  factory ContractSignResult.fromCallable(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return ContractSignResult(
      status: (map['status'] ?? '').toString(),
      contractNo: (map['contractNo'] ?? '').toString(),
      alreadySigned: map['alreadySigned'] == true,
    );
  }
}

/// `terminatePersonalContract` 응답: 해지 증빙 등급과 해지 시점의 횟수 스냅샷.
class ContractTerminateResult {
  const ContractTerminateResult({
    required this.evidence,
    this.alreadyTerminated = false,
    this.zeroedRemain = false,
    this.markedExpired = false,
  });

  /// `member_signed`(회원 서명 확인) 또는 `trainer_only`(강사 단독 기록).
  final String evidence;
  final bool alreadyTerminated;
  final bool zeroedRemain;
  final bool markedExpired;

  factory ContractTerminateResult.fromCallable(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return ContractTerminateResult(
      evidence: (map['evidence'] ?? '').toString(),
      alreadyTerminated: map['alreadyTerminated'] == true,
      zeroedRemain: map['zeroedRemain'] == true,
      markedExpired: map['markedExpired'] == true,
    );
  }
}

/// `savePersonalContractDraft` 응답.
class ContractDraftResult {
  const ContractDraftResult({
    required this.contractId,
    required this.contractNo,
    required this.version,
    required this.status,
    required this.contentHash,
    this.created = false,
    this.unchanged = false,
    this.invalidatedSignatures = false,
  });

  final String contractId;
  final String contractNo;
  final int version;
  final String status;
  final String contentHash;
  final bool created;
  final bool unchanged;
  final bool invalidatedSignatures;

  factory ContractDraftResult.fromCallable(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final contractId = (map['contractId'] ?? '').toString();
    if (contractId.isEmpty) {
      throw const FormatException('draft_response_invalid');
    }
    return ContractDraftResult(
      contractId: contractId,
      contractNo: (map['contractNo'] ?? '').toString(),
      version: map['version'] is num ? (map['version'] as num).toInt() : 1,
      status: (map['status'] ?? 'draft').toString(),
      contentHash: (map['contentHash'] ?? '').toString(),
      created: map['created'] == true,
      unchanged: map['unchanged'] == true,
      invalidatedSignatures: map['invalidatedSignatures'] == true,
    );
  }
}

/// 서버 오류 코드(`HttpsError.message`). 서버 오류가 아니면 빈 문자열.
String contractErrorCode(Object error) =>
    error is FirebaseFunctionsException ? (error.message ?? '') : '';

/// 등급 부족 안내. 서버는 저장된 등급으로 판단한다. DEV 앱에서 화면용 등급을 골라 둔 경우
/// (서버에는 반영되지 않음) 그 사실도 함께 알린다.
String _semiProRequiredMessage() {
  const base = '레슨계약서는 서버에 저장된 등급이 세미프로 이상이어야 쓸 수 있어요.';
  if (DevTierFixtureController.isAvailable &&
      DevTierFixtureController.selection.value != DevTierFixture.server) {
    return '$base (DEV 배너에서 고른 등급은 화면에만 적용돼요)';
  }
  return base;
}

/// 서버 오류 코드(`HttpsError.message`)를 사용자 문구로 바꾼다.
String contractErrorMessage(Object error) {
  final message = _contractErrorMessage(error);
  // DEV 앱에서는 원인을 바로 알 수 있게 서버 오류코드를 덧붙인다.
  if (!DevTierFixtureController.isAvailable) return message;
  final code = contractErrorCode(error);
  final detail =
      code.isNotEmpty
          ? code
          : (error is FirebaseFunctionsException
              ? error.code
              : '${error.runtimeType}');
  return '$message [DEV $detail]';
}

String _contractErrorMessage(Object error) {
  final code = contractErrorCode(error);
  switch (code) {
    case 'profile_required':
      return '서버에서 내 트레이너 프로필을 찾지 못했어요.';
    case 'semi_pro_required':
      return _semiProRequiredMessage();
    case 'workspace_not_eligible':
      return '계정 연결을 마친 뒤에 쓸 수 있어요.';
    case 'penaltyPercent_invalid':
      return '위약금은 0~10% 안에서 정할 수 있어요.';
    case 'refundBusinessDays_invalid':
      return '환급 처리 기한은 영업일 1~130일(약 6개월) 안에서 정할 수 있어요.';
    case 'logoPath_invalid':
      return '로고 파일 위치가 올바르지 않아요. 다시 올려 주세요.';
    case 'transfer_amount_not_allowed_in_defaults':
      return '정액 수수료는 계약마다 정해요.';
    case 'member_owner_mismatch':
    case 'member_not_found':
      return '선택한 회원을 찾을 수 없어요. 회원 목록에서 다시 선택해 주세요.';
    case 'member_deleted':
      return '삭제된 회원이라 계약서를 만들 수 없어요.';
    case 'pdf_not_uploaded':
      return '계약서 PDF가 올라가지 않았어요. 다시 시도해 주세요.';
    case 'pdf_invalid':
    case 'pdf_too_large':
      return '계약서 PDF를 만들지 못했어요. 다시 시도해 주세요.';
    case 'contract_not_completed':
      return '서명이 모두 끝난 계약서만 보낼 수 있어요.';
    case 'link_not_issued':
      return '먼저 열람 링크를 만들어야 해요.';
    case 'void_requires_completed':
      return '서명이 모두 끝난 계약서만 파기할 수 있어요.';
    case 'void_window_passed':
      return '계약 완료 후 3일이 지나 파기할 수 없어요. 더보기의 "계약 해지"로 진행해 주세요.';
    case 'void_lessons_taken':
      return '이미 레슨을 받아서 파기할 수 없어요. 더보기의 "계약 해지"로 진행해 주세요.';
    case 'void_not_latest_registration':
      return '이 계약 뒤에 다른 계약이 등록되어 파기할 수 없어요.';
    case 'terminate_requires_completed':
      return '서명이 모두 끝난 계약서만 해지할 수 있어요.';
    case 'terminate_not_latest':
      return '이 회원에게 더 나중에 완료된 계약서가 있어요. 가장 최근 계약서부터 해지해 주세요.';
    case 'noticeDate_out_of_range':
      return '해지 의사를 밝힌 날짜는 계약 완료일부터 오늘 사이여야 해요.';
    case 'reasonNote_required':
      return '사유가 기타이면 내용을 적어 주세요.';
    case 'new_version_requires_completed':
      return '서명이 모두 끝난 계약서만 새 버전으로 고칠 수 있어요.';
    case 'new_version_already_open':
      return '이미 진행 중인 새 버전이 있어요. 계약서 목록에서 이어서 작성해 주세요.';
    case 'contract_locked':
      return '이미 완료되었거나 취소된 계약서는 고칠 수 없어요.';
    case 'content_changed':
      return '계약 내용이 바뀌어서 서명을 받을 수 없어요. 화면을 닫고 다시 시작해 주세요.';
    case 'invalid_state':
      return '서명 순서가 맞지 않아요. 화면을 새로 열어 주세요.';
    case 'checkedItems_mismatch':
      return '확인하지 않은 항목이 있어요. 모든 항목을 확인해 주세요.';
    case 'strokes_invalid':
      return '서명이 너무 짧거나 올바르지 않아요. 다시 서명해 주세요.';
    case 'step_invalid':
      return '서명 단계가 올바르지 않아요.';
    case 'contract_not_found':
    case 'contract_owner_mismatch':
      return '계약서를 찾을 수 없어요.';
    case 'period_invalid':
      return '사용 가능 기간을 확인해 주세요. 유효기간 종료일은 사용 시작일 이후, 최대 3년이에요.';
    case 'product_name_duplicate':
      return '같은 이름의 수업 상품이 이미 있어요.';
    case 'products_too_many':
      return '수업 상품은 최대 20개까지 저장할 수 있어요.';
    case 'listPrice_required_for_basis':
    case 'listPrice_invalid':
      return '정상가는 실결제금액보다 커야 하고, 정상가 기준 환불은 정상가가 있어야 해요.';
  }
  if (code.startsWith('forbidden_phrase:')) {
    return '환불을 막거나 책임을 모두 면제하는 문구는 쓸 수 없어요.';
  }
  if (error is FirebaseFunctionsException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return '네트워크가 불안정해요. 잠시 뒤에 다시 시도해 주세요.';
  }
  return '저장하지 못했어요. 잠시 뒤에 다시 시도해 주세요.';
}

const int kContractLogoMaxEdge = 512;

/// 선택한 이미지를 가로·세로 512px 이하 PNG로 바꾼다(Storage 규칙: PNG 2MB 이하).
Future<Uint8List> preparePngLogo(Uint8List source) async {
  final codec = await ui.instantiateImageCodec(
    source,
    targetWidth: kContractLogoMaxEdge,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  if (data == null) {
    throw const FormatException('logo_encode_failed');
  }
  final bytes = data.buffer.asUint8List();
  if (bytes.length > 2 * 1024 * 1024) {
    throw const FormatException('logo_too_large');
  }
  return bytes;
}

/// 로고 PNG를 `contract_logos/{uid}/logo_{ms}.png`에 올리고 경로를 돌려준다.
Future<String> uploadContractLogo({
  required String uid,
  required Uint8List png,
  FirebaseStorage? storage,
  DateTime? now,
}) async {
  final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final path = 'contract_logos/${uid.trim()}/logo_$stamp.png';
  await (storage ?? FirebaseStorage.instance)
      .ref(path)
      .putData(png, SettableMetadata(contentType: 'image/png'));
  return path;
}

/// 저장된 로고 경로의 내용을 읽는다(없거나 실패하면 null).
Future<Uint8List?> loadContractLogo(
  String path, {
  FirebaseStorage? storage,
}) async {
  if (path.trim().isEmpty) return null;
  try {
    return await (storage ?? FirebaseStorage.instance)
        .ref(path)
        .getData(2 * 1024 * 1024);
  } catch (_) {
    return null;
  }
}
