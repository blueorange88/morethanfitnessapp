import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lesson_type_item.dart';
import '../../services/personal_contract_gateway.dart';
import '../../services/personal_member_preferences_service.dart';
import '../../theme.dart';
import '../../utils/lesson_contract/lesson_contract_rules.dart';
import '../../widgets/aifc_confirm_chat_sheet.dart';
import '../../widgets/aifc_interaction.dart';
import '../../widgets/card_expand_route.dart';
import '../../widgets/contract_chooser_sheet.dart';
import '../../widgets/lesson_type_color_picker.dart';
import '../../widgets/mtf_floating_more_menu.dart';
import 'lesson_contract_form_page.dart';
import 'lesson_contract_sign_flow_page.dart';
import 'lesson_contract_widgets.dart';

/// 레슨계약서 목록 한 줄(회원별 목록·전체 목록 공용).
class MemberContractItem {
  const MemberContractItem({
    required this.id,
    required this.contractNo,
    required this.status,
    required this.productName,
    required this.version,
    this.serviceContent = '',
    this.memberName = '',
    this.memberId = '',
    this.memberPhone = '',
    this.sessionCount,
    this.paidAmount,
    this.periodEnd,
    this.periodUnlimited = false,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String contractNo;
  final String status;
  final String productName;
  final int version;

  /// 계약서의 서비스 내용(레슨 종류를 가리는 데 쓴다).
  final String serviceContent;
  final String memberName;
  final String memberId;
  final String memberPhone;
  final int? sessionCount;
  final int? paidAmount;

  /// 계약 기간 종료일(없으면 null). 종료일이 없는 계약은 [periodUnlimited]가 true다.
  final DateTime? periodEnd;
  final bool periodUnlimited;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  factory MemberContractItem.fromDoc(String id, Map<String, dynamic> data) {
    Map<String, dynamic> section(String key) =>
        data[key] is Map
            ? Map<String, dynamic>.from(data[key] as Map)
            : <String, dynamic>{};
    DateTime? date(Object? value) => value is Timestamp ? value.toDate() : null;
    final product = section('product');
    final member = section('member');
    final version = (data['version'] as num?)?.toInt() ?? 1;
    final no = (data['contractNo'] ?? '').toString();
    return MemberContractItem(
      id: id,
      contractNo: version > 1 ? '$no-v$version' : no,
      status: (data['status'] ?? '').toString(),
      productName: (product['name'] ?? '').toString(),
      serviceContent: (product['serviceContent'] ?? '').toString(),
      version: version,
      memberName: (member['name'] ?? '').toString().trim(),
      memberId: (data['memberId'] ?? '').toString().trim(),
      memberPhone: (member['phone'] ?? '').toString().trim(),
      sessionCount: (product['sessionCount'] as num?)?.toInt(),
      paidAmount: (product['paidAmount'] as num?)?.toInt(),
      periodEnd: DateTime.tryParse((product['periodEnd'] ?? '').toString()),
      periodUnlimited: product['periodUnlimited'] == true,
      updatedAt: date(data['updatedAt']),
      completedAt: date(data['completedAt']),
    );
  }

  /// 서명이 끝나지 않은 계약(작성 중·서명 진행 중).
  bool get isOpen =>
      status == 'draft' || status == 'disclosed' || status == 'member_signed';

  /// 취소·파기된 계약(기본으로 숨긴다).
  bool get isInactive => status == 'cancelled' || status == 'voided';

  /// 계약서 종류. 지금 목록(`personal_contracts`)에는 레슨계약서만 있다.
  ContractFileKind get kind => ContractFileKind.lesson;

  /// 끝난 계약(회색 바인더): 해지·이전 버전·취소·파기, 또는 체결된 계약 중 기간이 지났거나
  /// 횟수를 모두 쓴 것.
  bool isEnded({ContractMemberItem? member, DateTime? now}) {
    if (status == 'terminated' || status == 'superseded' || isInactive) {
      return true;
    }
    if (status != 'completed') return false;
    final end = periodEnd;
    final today = now ?? DateTime.now();
    if (!periodUnlimited &&
        end != null &&
        DateTime(
          end.year,
          end.month,
          end.day,
        ).isBefore(DateTime(today.year, today.month, today.day))) {
      return true;
    }
    final total = member?.totalSessions;
    final remain = member?.remainingSessions;
    return total != null && total > 0 && remain != null && remain <= 0;
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return '작성 중';
      case 'disclosed':
        return '회원 서명 대기';
      case 'member_signed':
        return '강사 서명 대기';
      case 'completed':
        return '완료';
      case 'superseded':
        return '이전 버전';
      case 'cancelled':
        return '취소됨';
      case 'voided':
        return '파기됨';
      case 'terminated':
        return '해지됨';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  /// 목록에 보이는 날짜: 완료된 계약은 완료일, 아니면 마지막 수정일.
  DateTime? get shownDate => completedAt ?? updatedAt;
}

/// 회원의 계약서 목록을 불러오는 함수(테스트용 교체). 기본은 Firestore 실시간 조회.
typedef MemberContractsLoader =
    Stream<List<MemberContractItem>> Function(
      String ownerUid,
      String? memberId,
    );

Stream<List<MemberContractItem>> firestoreMemberContracts(
  String ownerUid,
  String? memberId,
) {
  // 같음 조건만 써서(회원별은 두 개, 전체는 하나) 별도 색인 없이 조회하고, 정렬은 앱에서 한다.
  var query = FirebaseFirestore.instance
      .collection('personal_contracts')
      .where('trainerId', isEqualTo: ownerUid);
  if (memberId != null) query = query.where('memberId', isEqualTo: memberId);
  return query.snapshots().map(
    (snapshot) => sortMemberContracts([
      for (final doc in snapshot.docs)
        MemberContractItem.fromDoc(doc.id, doc.data()),
    ]),
  );
}

/// 최근 것이 위로: 열린 계약 → 그 밖의 계약 순서가 아니라 날짜 내림차순.
List<MemberContractItem> sortMemberContracts(List<MemberContractItem> items) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final at = a.shownDate?.millisecondsSinceEpoch ?? 0;
    final bt = b.shownDate?.millisecondsSinceEpoch ?? 0;
    return bt.compareTo(at);
  });
  return sorted;
}

/// 전체 목록의 상태 필터.
enum ContractListFilter {
  all('전체'),
  open('진행 중'),
  completed('완료');

  const ContractListFilter(this.label);
  final String label;
}

/// 계약서 종류. 바인더 인덱스 탭의 가로 위치를 정한다(레슨 왼쪽, 회원권 가운데, 양도권 오른쪽).
enum ContractFileKind {
  lesson('레슨', '레슨계약서', -1),
  membership('회원권', '회원권계약서', 0),
  transfer('양도권', '양도권계약서', 1);

  const ContractFileKind(this.label, this.fullLabel, this.tabSlot);
  final String label;
  final String fullLabel;

  /// 탭의 가로 위치(-1 왼쪽, 0 가운데, 1 오른쪽).
  final double tabSlot;
}

/// 홈 레슨 종류에 없는 이름의 기본 바인더 색. 홈 레슨 종류가 있으면 그 색이 먼저다
/// ([resolveContractBinderColor]). PT·필라테스·요가·회원권·양도권은 정해 두고, 나머지 이름은
/// 이름마다 일정한 색이 나오게 팔레트에서 고른다.
Color defaultContractBinderColor(String typeName) {
  switch (customLessonTypeComparisonKey(typeName)) {
    case 'pt':
      return kLessonTypePalette[0];
    case '필라테스':
      return kLessonTypePalette[1];
    case '요가':
      return kLessonTypePalette[4];
    case '회원권':
      return kLessonTypePalette[3];
    case '양도권':
      return kLessonTypePalette[5];
  }
  final hash = typeName.codeUnits.fold<int>(
    0,
    (acc, unit) => (acc * 31 + unit) & 0x7fffffff,
  );
  return kLessonTypePalette[hash % kLessonTypePalette.length];
}

/// 계약서의 상품 이름·서비스 내용에서 레슨 종류 이름을 가린다. 내 레슨 종류 이름(긴 이름 먼저)이
/// 상품 이름에 들어 있으면 그 이름, 없으면 서비스 내용에서 찾고, 그래도 없으면 PT로 본다
/// (계약서에 레슨 종류 필드가 따로 없고, 상품의 기본 레슨 종류가 PT다).
String contractLessonTypeNameOf(
  String productName, {
  String serviceContent = '',
  List<String> known = kBuiltInLessonTypes,
}) {
  final names = [
    for (final name in known)
      if (name.trim().isNotEmpty && name != '미입력') name.trim(),
  ]..sort((a, b) => b.length.compareTo(a.length));
  String? find(String text) {
    final lower = text.toLowerCase();
    for (final name in names) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    return null;
  }

  return find(productName) ?? find(serviceContent) ?? 'PT';
}

/// 바인더 색: 홈 레슨 종류(이름 → 색)에 같은 이름이 있으면 그 색, 없으면 기본 색.
Color resolveContractBinderColor(
  String typeName,
  Map<String, Color> homeTypeColors,
) {
  return homeTypeColors[customLessonTypeComparisonKey(typeName)] ??
      defaultContractBinderColor(typeName);
}

/// 전체 목록을 상태와 검색어(회원 이름·계약번호·상품명)로 거른다. 취소된 계약은 여기서 다루지 않는다.
List<MemberContractItem> filterContracts(
  List<MemberContractItem> items, {
  String query = '',
  ContractListFilter filter = ContractListFilter.all,
  ContractFileKind? kind,
}) {
  final text = query.trim().toLowerCase();
  bool matches(MemberContractItem item) {
    if (kind != null && item.kind != kind) return false;
    switch (filter) {
      case ContractListFilter.all:
        break;
      case ContractListFilter.open:
        if (!item.isOpen) return false;
      case ContractListFilter.completed:
        if (item.status != 'completed') return false;
    }
    if (text.isEmpty) return true;
    return item.memberName.toLowerCase().contains(text) ||
        item.contractNo.toLowerCase().contains(text) ||
        item.productName.toLowerCase().contains(text);
  }

  return items.where(matches).toList();
}

/// 계약서 관리의 `계약 미완료 회원` 계산에 쓰는 회원 한 명.
class ContractMemberItem {
  const ContractMemberItem({
    required this.id,
    required this.name,
    required this.active,
    required this.contractSigned,
    this.totalSessions,
    this.remainingSessions,
    this.expireAt,
  });

  final String id;
  final String name;

  /// 회원 문서의 등록 횟수와 잔여 횟수, 회원권 종료일(계약서 카드의 총/소진·남은 기간 표시용).
  final int? totalSessions;
  final int? remainingSessions;
  final DateTime? expireAt;

  /// 소진 횟수. 등록·잔여 횟수를 모르면 null.
  int? get usedSessions {
    final total = totalSessions;
    final remain = remainingSessions;
    if (total == null || remain == null || total <= 0) return null;
    return (total - remain).clamp(0, total);
  }

  /// 삭제 대기·휴면·만료가 아닌 활동 회원.
  final bool active;

  /// 회원 문서에 계약 체결 표시가 있는지(해지된 계약은 표시가 지워진다).
  final bool contractSigned;

  factory ContractMemberItem.fromDoc(String id, Map<String, dynamic> data) {
    final lessonSync =
        data['lessonSync'] is Map
            ? Map<String, dynamic>.from(data['lessonSync'] as Map)
            : <String, dynamic>{};
    final status = (data['memberStatus'] ?? '').toString();
    final state = (data['managementState'] ?? '').toString();
    final deleted =
        data['isDeleted'] == true ||
        (data['deleteStatus'] ?? '').toString() == 'pending_delete';
    final signed =
        data['contractSigned'] == true ||
        data['isContractSigned'] == true ||
        data['finalSigned'] == true ||
        lessonSync['contractSigned'] == true;
    final sessions =
        data['sessions'] is Map
            ? Map<String, dynamic>.from(data['sessions'] as Map)
            : <String, dynamic>{};
    final membership =
        data['membership'] is Map
            ? Map<String, dynamic>.from(data['membership'] as Map)
            : <String, dynamic>{};
    final end =
        membership['endAt'] ?? membership['passEnd'] ?? data['expireAt'];
    return ContractMemberItem(
      id: id,
      totalSessions:
          (sessions['total'] as num?)?.toInt() ??
          (data['totalSessions'] as num?)?.toInt(),
      remainingSessions:
          (sessions['remain'] as num?)?.toInt() ??
          (data['remainSessions'] as num?)?.toInt() ??
          (data['remainingSessions'] as num?)?.toInt(),
      expireAt:
          end is Timestamp
              ? end.toDate()
              : DateTime.tryParse((end ?? '').toString()),
      name: (data['name'] ?? '').toString().trim(),
      active:
          !deleted &&
          status != '휴면' &&
          status != '만료' &&
          state != 'dormant' &&
          state != 'expired',
      contractSigned:
          signed && (data['contractStatus'] ?? '').toString() != 'terminated',
    );
  }
}

/// 내 회원 목록을 불러오는 함수(테스트용 교체). 기본은 Firestore 실시간 조회.
typedef ContractMembersLoader =
    Stream<List<ContractMemberItem>> Function(String ownerUid);

Stream<List<ContractMemberItem>> firestoreContractMembers(String ownerUid) {
  return FirebaseFirestore.instance
      .collection('members')
      .where('trainerId', isEqualTo: ownerUid)
      .where('workspaceType', isEqualTo: 'personal')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ContractMemberItem.fromDoc(doc.id, doc.data()),
        ],
      );
}

/// 체결된 계약서가 없는 활동 회원(이름순). 회원 문서의 계약 표시나 완료된 계약서 중 하나라도 있으면
/// 계약이 있는 회원으로 본다.
List<ContractMemberItem> membersWithoutContract(
  List<ContractMemberItem> members,
  List<MemberContractItem> contracts,
) {
  final signedIds = {
    for (final contract in contracts)
      if (contract.status == 'completed' && contract.memberId.isNotEmpty)
        contract.memberId,
  };
  final missing = [
    for (final member in members)
      if (member.active &&
          member.name.isNotEmpty &&
          !member.contractSigned &&
          !signedIds.contains(member.id))
        member,
  ];
  missing.sort((a, b) => a.name.compareTo(b.name));
  return missing;
}

/// 최근 검색어 칩의 최대 개수. 넘으면 가장 오래된 것부터 사라진다.
const int recentContractQueryMax = 5;

/// 최근 검색어 목록에 [query]를 맨 앞으로 넣는다(대소문자 무시 중복 제거, 최대 [max]개).
List<String> addRecentContractQuery(
  List<String> current,
  String query, {
  int max = recentContractQueryMax,
}) {
  final text = query.trim();
  if (text.isEmpty) return current;
  return [
    text,
    ...current.where((e) => e.toLowerCase() != text.toLowerCase()),
  ].take(max).toList();
}

/// 계약서 카드를 한 번 눌렀을 때 펼쳐지는 요약(이름·연락처·상품·총/소진·남은 기간).
class ContractCardSummary {
  const ContractCardSummary({
    required this.heading,
    required this.name,
    required this.phone,
    required this.product,
    required this.paid,
    required this.sessions,
    required this.period,
  });

  final String heading;
  final String name;
  final String phone;
  final String product;

  /// 총 결제금액(`1,000,000원`). 계약서에 없으면 `-`.
  final String paid;
  final String sessions;
  final String period;
}

/// 종료일까지 남은 기간 표시: 지났으면 `만료`, 오늘이면 `D-day`, 아니면 `D-N`. 모르면 `-`.
String remainingPeriodLabel(DateTime? end, {DateTime? now}) {
  if (end == null) return '-';
  final today = now ?? DateTime.now();
  final days =
      DateTime(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (days < 0) return '만료';
  if (days == 0) return 'D-day';
  return 'D-$days';
}

/// 카드 요약을 만든다. 체결된 계약은 회원 문서의 등록·잔여 횟수로 소진 횟수를 보여 주고,
/// 아직 체결되지 않았거나 취소·파기된 계약은 계약서의 횟수만 보여 준다.
ContractCardSummary contractCardSummary(
  MemberContractItem item,
  ContractMemberItem? member, {
  DateTime? now,
}) {
  final name = item.memberName.isEmpty ? '-' : item.memberName;
  final completed = item.status == 'completed';
  final used = member?.usedSessions;
  final memberTotal = member?.totalSessions ?? 0;
  final String sessions;
  if (completed && used != null && memberTotal > 0) {
    sessions = '총 $memberTotal회 / 소진 $used회';
  } else if (item.sessionCount != null) {
    sessions = '총 ${item.sessionCount}회';
  } else {
    sessions = '-';
  }
  final String period;
  if (item.periodUnlimited) {
    period = '기간 제한 없음';
  } else {
    period = remainingPeriodLabel(
      (completed ? member?.expireAt : null) ?? item.periodEnd,
      now: now,
    );
  }
  return ContractCardSummary(
    heading: item.memberName.isEmpty ? '레슨계약서' : '${item.memberName}님 레슨계약서',
    name: name,
    phone: item.memberPhone.isEmpty ? '-' : item.memberPhone,
    product: item.productName.isEmpty ? '-' : item.productName,
    paid: item.paidAmount == null ? '-' : '${formatWon(item.paidAmount!)}원',
    sessions: sessions,
    period: period,
  );
}

String _date(DateTime? value) {
  if (value == null) return '';
  final kst = value.toUtc().add(const Duration(hours: 9));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${kst.year}.${two(kst.month)}.${two(kst.day)}';
}

/// 레슨계약서 목록 화면. [memberId]를 주면 그 회원의 계약서만(회원카드 계약서 아이콘), 주지 않으면
/// 내 모든 회원의 새 레슨계약서를 상태 필터·검색과 함께 보여 준다(MY 페이지 `계약서 관리`).
/// 어느 쪽이든 모아 보고, 열고, 새로 쓴다.
///
/// - 계약서가 하나도 없으면([autoStartWhenEmpty]) 바로 새 계약 작성 화면으로 간다.
/// - 작성 중인 계약은 이어서 쓰고, 서명이 진행 중이거나 완료된 계약은 서명·완료 화면으로 연다
///   (완료 화면에서 PDF 저장·공유와 링크 보내기를 할 수 있다).
class MemberContractsPage extends StatefulWidget {
  const MemberContractsPage({
    super.key,
    required this.personalOwnerUid,
    required this.memberId,
    this.memberName = '',
    this.autoStartWhenEmpty = true,
    this.loader,
    this.membersLoader,
    this.formBuilder,
    this.flowBuilder,
    this.onOpenMembership,
    this.gateway,
    this.lessonTypesLoader,
  });

  final String personalOwnerUid;
  final String? memberId;
  final String memberName;
  final bool autoStartWhenEmpty;
  final MemberContractsLoader? loader;

  /// 전체 목록의 `계약 미완료 회원` 계산에 쓰는 회원 목록(테스트용 교체).
  final ContractMembersLoader? membersLoader;

  /// 새 계약·초안 작성 화면과 서명·완료 화면(테스트용 교체).
  final Widget Function(String? contractId)? formBuilder;
  final Widget Function(String contractId)? flowBuilder;

  /// 회원권계약서 작성으로 가는 동작. 주면 `회원권계약서 작성` 버튼을 함께 보여 준다.
  final Future<void> Function()? onOpenMembership;
  final PersonalContractGateway? gateway;

  /// 내 레슨 종류 이름 목록(바인더 이름·색 구분용, 테스트용 교체). 기본은 개인 프로필에서 읽는다.
  final Future<List<String>> Function(String ownerUid)? lessonTypesLoader;

  @override
  State<MemberContractsPage> createState() => _MemberContractsPageState();
}

class _MemberContractsPageState extends State<MemberContractsPage> {
  StreamSubscription<List<MemberContractItem>>? _sub;
  StreamSubscription<List<ContractMemberItem>>? _membersSub;
  List<MemberContractItem>? _items;
  List<ContractMemberItem>? _members;
  bool _failed = false;
  bool _firstEvent = true;
  bool _showCancelled = false;
  bool _cancelling = false;
  final TextEditingController _query = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<String> _recent = const [];
  ContractListFilter _filter = ContractListFilter.all;
  ContractFileKind? _kindFilter;
  List<String> _lessonTypes = kBuiltInLessonTypes;
  Map<String, Color> _homeTypeColors = const {};

  /// 한 회원이 아니라 내 모든 회원의 계약서를 보는 전체 목록인지.
  bool get _allMembers => widget.memberId == null;
  late final PersonalContractGateway _gateway =
      widget.gateway ?? PersonalContractGateway();

  @override
  void initState() {
    super.initState();
    final loader = widget.loader ?? firestoreMemberContracts;
    _sub = loader(widget.personalOwnerUid, widget.memberId).listen(
      (items) {
        if (!mounted) return;
        final first = _firstEvent;
        _firstEvent = false;
        if (first &&
            items.isEmpty &&
            widget.autoStartWhenEmpty &&
            !_allMembers) {
          _startNew(replace: true);
          return;
        }
        setState(() {
          _items = items;
          _failed = false;
        });
      },
      onError: (Object error) {
        debugPrint(
          '[MTF_MEMBER_CONTRACTS] 목록을 불러오지 못했어요: ${error.runtimeType}',
        );
        if (mounted) setState(() => _failed = true);
      },
    );
    _listenMembers();
    if (_allMembers) {
      _loadRecent();
      _loadLessonTypes();
    }
  }

  /// 내 레슨 종류(기본 + 직접 추가한 것 + 홈에서 만든 것)를 불러온다. 홈 레슨 종류의 색이 바인더
  /// 색이 된다. 못 불러오면 있는 것만 쓴다.
  Future<void> _loadLessonTypes() async {
    var custom = const <String>[];
    try {
      final loader =
          widget.lessonTypesLoader ??
          (String uid) async =>
              (await PersonalMemberPreferencesService(
                    uid: uid,
                  ).loadFromServer())
                  .customLessonTypes;
      custom = await loader(widget.personalOwnerUid);
    } catch (error) {
      debugPrint(
        '[MTF_MEMBER_CONTRACTS] 레슨 종류를 불러오지 못했어요: ${error.runtimeType}',
      );
    }
    var home = const <LessonTypeItem>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      home = parseHomeLessonTypes(prefs.getString(kHomeLessonTypesPrefsKey));
    } catch (error) {
      debugPrint(
        '[MTF_MEMBER_CONTRACTS] 홈 레슨 종류를 불러오지 못했어요: ${error.runtimeType}',
      );
    }
    if (!mounted) return;
    final seen = <String>{};
    final colors = <String, Color>{};
    for (final item in home) {
      final color = lessonTypeColorTryParse(item.colorHex);
      if (color != null) {
        colors[customLessonTypeComparisonKey(item.name)] = color;
      }
    }
    setState(() {
      _homeTypeColors = colors;
      _lessonTypes = [
        for (final name in [
          ...kBuiltInLessonTypes,
          ...custom,
          for (final item in home) item.name,
        ])
          if (seen.add(customLessonTypeComparisonKey(name))) name,
      ];
    });
  }

  Color _binderColorFor(String typeName) =>
      resolveContractBinderColor(typeName, _homeTypeColors);

  String get _recentKey => 'member_contracts_recent_${widget.personalOwnerUid}';

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_recentKey) ?? const <String>[];
      if (mounted) {
        setState(() => _recent = saved.take(recentContractQueryMax).toList());
      }
    } catch (error) {
      debugPrint(
        '[MTF_MEMBER_CONTRACTS] 최근 검색어를 불러오지 못했어요: ${error.runtimeType}',
      );
    }
  }

  Future<void> _saveRecent(List<String> next) async {
    setState(() => _recent = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, next);
    } catch (error) {
      debugPrint(
        '[MTF_MEMBER_CONTRACTS] 최근 검색어를 저장하지 못했어요: ${error.runtimeType}',
      );
    }
  }

  /// 검색어를 최근 검색어에 남긴다(검색 키를 눌렀을 때, 검색한 뒤 계약서를 열었을 때).
  void _rememberQuery() {
    if (!_allMembers) return;
    final text = _query.text.trim();
    if (text.isEmpty) return;
    _saveRecent(addRecentContractQuery(_recent, text));
  }

  /// 전체 목록에서만 회원 목록을 받아 `계약 미완료 회원` 수를 센다. 못 받으면 수는 '-'로 둔다.
  void _listenMembers() {
    if (!_allMembers) return;
    try {
      final load = widget.membersLoader ?? firestoreContractMembers;
      _membersSub = load(widget.personalOwnerUid).listen(
        (members) {
          if (mounted) setState(() => _members = members);
        },
        onError: (Object error) {
          debugPrint(
            '[MTF_MEMBER_CONTRACTS] 회원 목록을 불러오지 못했어요: ${error.runtimeType}',
          );
        },
      );
    } catch (error) {
      debugPrint('[MTF_MEMBER_CONTRACTS] 회원 목록을 열지 못했어요: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    _sub?.cancel();
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Route<void> _formRoute({String? contractId, String? memberId}) =>
      MaterialPageRoute<void>(
        builder:
            (_) =>
                widget.formBuilder?.call(contractId) ??
                LessonContractFormPage(
                  personalOwnerUid: widget.personalOwnerUid,
                  contractId: contractId,
                  initialMemberId:
                      contractId == null ? (memberId ?? widget.memberId) : null,
                ),
      );

  Future<void> _startNew({bool replace = false, String? memberId}) async {
    final navigator = Navigator.of(context);
    if (replace) {
      await navigator.pushReplacement(_formRoute(memberId: memberId));
    } else {
      await navigator.push(_formRoute(memberId: memberId));
    }
  }

  /// 새 계약서: 회원권계약서로 갈 수 있으면 레슨·회원권 중 고르고, 아니면 바로 레슨계약서를 쓴다.
  Future<void> _chooseAndStart() async {
    if (widget.onOpenMembership == null) {
      await _startNew();
      return;
    }
    final kind = await showContractChooserSheet(context);
    if (kind == null || !mounted) return;
    if (kind == ContractKind.lesson) {
      await _startNew();
    } else {
      await widget.onOpenMembership!();
    }
  }

  /// `계약 미완료 회원`을 눌렀을 때: 계약서가 없는 활동 회원을 보여 주고, 고르면 그 회원으로 새 계약을 쓴다.
  Future<void> _showMissingMembers() async {
    final members = _members;
    final items = _items;
    if (members == null || items == null) return;
    final missing = membersWithoutContract(members, items);
    final picked = await showModalBottomSheet<ContractMemberItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '계약서가 없는 회원 ${missing.length}명',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final member in missing)
                        ListTile(
                          key: ValueKey<String>(
                            'member_contracts_missing_${member.id}',
                          ),
                          title: Text(member.name),
                          subtitle: const Text('눌러서 레슨계약서 작성'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(sheetContext).pop(member),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await _startNew(memberId: picked.id);
  }

  Future<void> _open(MemberContractItem item) async {
    _rememberQuery();
    final navigator = Navigator.of(context);
    if (item.status == 'draft') {
      await navigator.push(_formRoute(contractId: item.id));
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                widget.flowBuilder?.call(item.id) ??
                LessonContractSignFlowPage(contractId: item.id),
      ),
    );
  }

  void _toast(String message) =>
      AifcInteraction.toast(context: context, message: message);

  /// 길게 누르기: 서명이 끝나지 않은 계약은 삭제(= 취소 처리, 목록에서 숨김)할 수 있고,
  /// 완료된 계약은 삭제할 수 없다.
  Future<void> _onLongPress(MemberContractItem item) async {
    if (_cancelling) return;
    if (item.isInactive) return;
    if (!item.isOpen) {
      _toast('완료된 계약서는 삭제할 수 없어요.');
      return;
    }
    final signed = item.status != 'draft';
    final ok = await AifcConfirmChatSheet.show(
      context: context,
      title: '이 계약서를 삭제할까요?',
      message:
          '${item.productName.isEmpty ? '레슨계약서' : item.productName}'
          '${item.contractNo.isEmpty ? '' : ' (${item.contractNo})'}를 삭제해요.\n'
          '${signed ? '회원이 이미 서명한 내용도 함께 정리돼요.\n' : ''}'
          '삭제한 계약서는 목록에서 숨겨지고 취소 기록으로 남아요.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '그대로 둘게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 계약서는 그대로 둘게요.',
      confirmReplyText: '확인했어요. 계약서를 삭제할게요.',
      danger: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _gateway.cancelContract(item.id, reason: '강사가 삭제함');
      if (mounted) _toast('계약서를 삭제했어요.');
    } catch (error) {
      if (mounted) _toast(contractErrorMessage(error));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Color _statusColor(ColorScheme scheme, MemberContractItem item) {
    if (item.status == 'completed') return const Color(0xFF15803D);
    if (item.status == 'terminated') return scheme.error;
    if (item.isOpen) return const Color(0xFFB45309);
    return scheme.onSurfaceVariant;
  }

  ContractMemberItem? _memberFor(String memberId) {
    if (memberId.isEmpty) return null;
    for (final member in _members ?? const <ContractMemberItem>[]) {
      if (member.id == memberId) return member;
    }
    return null;
  }

  Widget _card(BuildContext context, MemberContractItem item) {
    final scheme = Theme.of(context).colorScheme;
    final member = _memberFor(item.memberId);
    final kind = item.kind;
    final typeLabel =
        kind == ContractFileKind.lesson
            ? contractLessonTypeNameOf(
              item.productName,
              serviceContent: item.serviceContent,
              known: _lessonTypes,
            )
            : kind.label;
    final tabLabel = [
      if (item.memberName.isNotEmpty) item.memberName,
      typeLabel,
    ].join(' ');
    final meta = [
      if (item.contractNo.isNotEmpty) item.contractNo,
      if (item.sessionCount != null) '${item.sessionCount}회',
      if (item.paidAmount != null) '${formatWon(item.paidAmount!)}원',
      if (_date(item.shownDate).isNotEmpty) _date(item.shownDate),
    ].join(' · ');
    return _ContractDocCard(
      item: item,
      tabLabel: tabLabel,
      title: item.productName.isEmpty ? kind.fullLabel : item.productName,
      meta: meta,
      statusColor: _statusColor(scheme, item),
      binder: _BinderStyle.of(
        _binderColorFor(typeLabel),
        isEnded: item.isEnded(member: member),
      ),
      tabSlot: kind.tabSlot,
      summary: contractCardSummary(item, member),
      onOpen: () => _open(item),
      onLongPress: () => _onLongPress(item),
    );
  }

  /// 목록 맨 끝의 `+ 새 계약서 작성` 카드. 금색 바인더(가로, 인덱스 탭 포함) 위에 흰 종이를 얹고,
  /// 종이에는 글줄과 펜으로 서명하는 모양을 넣어 계약서 느낌을 낸다.
  Widget _addCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _NewContractCard(onTap: _chooseAndStart),
    );
  }

  /// 상태 칩, 종류 칩, 최근 검색어 칩을 한 줄로 늘어놓고 옆으로 밀어서 본다.
  Widget _chipRow(BuildContext context) {
    const gap = SizedBox(width: 8);
    return SizedBox(
      height: 40,
      child: ListView(
        key: const ValueKey<String>('member_contracts_chip_row'),
        scrollDirection: Axis.horizontal,
        children: [
          // 전체 → 최근 검색어 → 진행 중 → 완료 → 종류 순서로 늘어놓는다.
          for (final filter in ContractListFilter.values) ...[
            ChoiceChip(
              key: ValueKey<String>('member_contracts_filter_${filter.name}'),
              label: Text(filter.label),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
            gap,
            if (filter == ContractListFilter.all)
              for (final text in _recent) ...[
                InputChip(
                  key: ValueKey<String>('member_contracts_recent_$text'),
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(text),
                  onPressed: () {
                    setState(() => _query.text = text);
                    _query.selection = TextSelection.collapsed(
                      offset: text.length,
                    );
                    _rememberQuery();
                  },
                  onDeleted:
                      () => _saveRecent([
                        for (final e in _recent)
                          if (e != text) e,
                      ]),
                ),
                gap,
              ],
          ],
          const SizedBox(width: 4),
          for (final kind in ContractFileKind.values) ...[
            ChoiceChip(
              key: ValueKey<String>('member_contracts_kind_${kind.name}'),
              label: Text(kind.label),
              selected: _kindFilter == kind,
              onSelected:
                  (_) => setState(
                    () => _kindFilter = _kindFilter == kind ? null : kind,
                  ),
            ),
            gap,
          ],
        ],
      ),
    );
  }

  /// 머리말 안쪽 요약 카드 세 개(회원리스트 머리말과 같은 모양: 아이콘·이름·숫자).
  Widget _summary(BuildContext context) {
    final items = _items;
    final members = _members;
    final open = items?.where((i) => i.isOpen).length;
    final done = items?.where((i) => i.status == 'completed').length;
    final missing =
        items == null || members == null
            ? null
            : membersWithoutContract(members, items).length;
    void toggle(ContractListFilter filter) => setState(
      () => _filter = _filter == filter ? ContractListFilter.all : filter,
    );
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            key: const ValueKey<String>('member_contracts_stat_open'),
            icon: Icons.edit_note_rounded,
            label: '진행 중 계약',
            value: open == null ? '-' : '$open건',
            isSelected: _filter == ContractListFilter.open,
            onTap:
                () =>
                    open == 0
                        ? _toast('진행 중인 계약이 없습니다.')
                        : toggle(ContractListFilter.open),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            key: const ValueKey<String>('member_contracts_stat_missing'),
            icon: Icons.person_off_outlined,
            label: '미작성 회원',
            value: missing == null ? '-' : '$missing명',
            onTap:
                () =>
                    missing == 0
                        ? _toast('미작성 회원이 없습니다.')
                        : _showMissingMembers(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            key: const ValueKey<String>('member_contracts_stat_done'),
            icon: Icons.task_alt_rounded,
            label: '체결된 계약',
            value: done == null ? '-' : '$done건',
            isSelected: _filter == ContractListFilter.completed,
            onTap:
                () =>
                    done == 0
                        ? _toast('체결된 계약이 없습니다.')
                        : toggle(ContractListFilter.completed),
          ),
        ),
      ],
    );
  }

  /// 머리말 오른쪽 `+`와 더보기. 더보기에서 취소·파기된 계약서를 별도 화면으로 본다.
  Widget _headerActions() {
    final inactive = _items?.where((i) => i.isInactive).length ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey<String>('member_contracts_add'),
          tooltip: '새 계약서 작성',
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          onPressed: _chooseAndStart,
        ),
        // 다른 페이지(회원카드·회원리스트)와 같은 공용 더보기 메뉴.
        MtfFloatingMoreMenuButton<String>(
          key: const ValueKey<String>('member_contracts_more'),
          tooltip: '더보기',
          icon: Icons.more_vert_rounded,
          iconSize: 24,
          cardWidth: 212,
          offset: const Offset(0, 8),
          onSelected: (value) {
            if (value == 'inactive') _showInactive();
          },
          items: [
            MtfMoreMenuItem(
              value: 'inactive',
              icon: Icons.inventory_2_outlined,
              label: '취소·파기된 계약서',
              subLabel: '$inactive건 · 지난 기록 보기',
            ),
          ],
        ),
      ],
    );
  }

  /// 취소·파기된 계약서를 모아 보는 화면(목록에서는 숨겨 둔다).
  Future<void> _showInactive() async {
    final inactive = [...?_items?.where((i) => i.isInactive)];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _InactiveContractsPage(items: inactive, cardBuilder: _card),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    if (_failed && items == null) {
      return const Center(
        key: ValueKey<String>('member_contracts_failed'),
        child: Text('계약서 목록을 불러오지 못했어요. 잠시 뒤에 다시 열어 주세요.'),
      );
    }
    if (items == null) {
      return const Center(
        key: ValueKey<String>('member_contracts_loading'),
        child: CircularProgressIndicator(),
      );
    }
    final cancelledCount = items.where((i) => i.isInactive).length;
    // 전체 목록에서는 취소·파기된 계약서를 더보기의 별도 화면에서 본다.
    final shown =
        !_allMembers && _showCancelled
            ? items
            : items.where((i) => !i.isInactive).toList();
    final visible =
        _allMembers
            ? filterContracts(
              shown,
              query: _query.text,
              filter: _filter,
              kind: _kindFilter,
            )
            : shown;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (!_allMembers) ...[
          FilledButton.icon(
            key: const ValueKey<String>('member_contracts_new'),
            onPressed: () => _startNew(),
            icon: const Icon(Icons.edit_document),
            label: const Text('새 레슨계약서 작성'),
          ),
          if (widget.onOpenMembership != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey<String>('member_contracts_membership'),
              onPressed: () => widget.onOpenMembership!(),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('회원권계약서 작성'),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (_allMembers) ...[
          TextField(
            key: const ValueKey<String>('member_contracts_search'),
            controller: _query,
            focusNode: _searchFocus,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _rememberQuery(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '회원 이름·계약번호 검색',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              suffixIcon:
                  _query.text.isEmpty
                      ? null
                      : IconButton(
                        key: const ValueKey<String>(
                          'member_contracts_search_clear',
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(_query.clear),
                      ),
            ),
          ),
          const SizedBox(height: 8),
          _chipRow(context),
          const SizedBox(height: 8),
        ],
        if (visible.isEmpty)
          Padding(
            key: const ValueKey<String>('member_contracts_empty'),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                _kindFilter != null && _kindFilter != ContractFileKind.lesson
                    ? '${_kindFilter!.fullLabel}는 준비 중이에요.'
                    : (_allMembers && shown.isNotEmpty
                        ? '조건에 맞는 계약서가 없어요.'
                        : '아직 계약서가 없어요.'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final item in visible) _card(context, item),
        if (_allMembers) _addCard(context),
        if (items.any((item) => item.isOpen))
          Padding(
            key: const ValueKey<String>('member_contracts_hint'),
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              '작성 중이거나 서명 중인 계약서는 길게 눌러 삭제할 수 있어요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!_allMembers && cancelledCount > 0)
          TextButton(
            key: const ValueKey<String>('member_contracts_toggle_cancelled'),
            onPressed: () => setState(() => _showCancelled = !_showCancelled),
            child: Text(
              _showCancelled
                  ? '취소·파기된 계약서 숨기기'
                  : '취소·파기된 계약서 보기 ($cancelledCount)',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.memberName.trim();
    return Scaffold(
      backgroundColor: context.mtfThemeTokens.memberListBackground,
      body: Column(
        children: [
          LessonContractHeader(
            title:
                _allMembers
                    ? '계약서 관리'
                    : (name.isEmpty ? '레슨계약서' : '$name 레슨계약서'),
            backKey: const ValueKey<String>('member_contracts_back'),
            onBack: () => Navigator.of(context).maybePop(),
            trailing: _allMembers ? _headerActions() : null,
            bottom: _allMembers ? _summary(context) : null,
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }
}

/// 바인더 색: 레슨 종류별로 고른 색에서 만들고, 종료된 계약은 어두운 회색이다.
class _BinderStyle {
  const _BinderStyle(this.light, this.dark, this.ink);

  final Color light;
  final Color dark;

  /// 인덱스 탭 글씨 색.
  final Color ink;

  Color get edge => Color.lerp(dark, Colors.black, 0.35)!;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [light, dark],
  );

  static const _BinderStyle ended = _BinderStyle(
    Color(0xFF7B8794),
    Color(0xFF4B5563),
    Colors.white,
  );

  static _BinderStyle of(Color base, {required bool isEnded}) {
    if (isEnded) return ended;
    final light = Color.lerp(base, Colors.white, 0.28)!;
    return _BinderStyle(light, base, lessonTypeInkColor(base));
  }
}

/// 아래쪽 [overlap]만큼 겹쳐서 배치하는 칸. 다음 바인더가 앞 바인더의 아랫부분을 덮어
/// 파일이 겹겹이 쌓인 것처럼 보인다. 겹친 부분은 눌리지 않는다.
class _TrailingOverlap extends SingleChildRenderObjectWidget {
  const _TrailingOverlap({required this.overlap, required super.child});

  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTrailingOverlap(overlap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTrailingOverlap renderObject,
  ) {
    renderObject.overlap = overlap;
  }
}

class _RenderTrailingOverlap extends RenderShiftedBox {
  _RenderTrailingOverlap(this._overlap) : super(null);

  double _overlap;

  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  Size _shrink(Size size) =>
      Size(size.width, math.max(0, size.height - _overlap));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(_shrink(child.getDryLayout(constraints)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_shrink(child.size));
  }
}

/// 바인더 파일 모양 계약서 카드. 인덱스 탭에 `이름 + 종류`를 쓰고 종이에는 상품과 상태를 보인다.
/// 종이를 한 번 누르면 위로 올라오며 요약이 펼쳐지고, 펼친 상태에서 한 번 더 누르면 계약서를 연다.
/// 인덱스 탭을 누르면 펼침/접힘이 바뀐다.
class _ContractDocCard extends StatefulWidget {
  const _ContractDocCard({
    required this.item,
    required this.tabLabel,
    required this.title,
    required this.meta,
    required this.statusColor,
    required this.binder,
    required this.tabSlot,
    required this.summary,
    required this.onOpen,
    required this.onLongPress,
  });

  final MemberContractItem item;
  final String tabLabel;
  final String title;
  final String meta;
  final Color statusColor;
  final _BinderStyle binder;

  /// 탭의 가로 위치: -1 왼쪽(레슨), 0 가운데(회원권), 1 오른쪽(양도권).
  final double tabSlot;
  final ContractCardSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  @override
  State<_ContractDocCard> createState() => _ContractDocCardState();
}

class _ContractDocCardState extends State<_ContractDocCard> {
  bool _expanded = false;

  static const double _tabTop = 3;
  static const double _bodyTop = 22;
  static const double _tabWidth = 132;
  static const double _tabInset = 18;

  /// 종이가 접혀 있을 때의 높이. 아래쪽은 다음 바인더가 덮는 자리다(바인더가 아래로 길게 이어진다).
  static const double _collapsedPaperHeight = 106;

  /// 다음 바인더가 이 바인더 위로 올라타는 높이. 접혀 있으면 깊게, 펼치면 얕게 겹친다.
  static const double _collapsedOverlap = 56;
  static const double _expandedOverlap = 8;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _onPaperTap() {
    if (_expanded) {
      widget.onOpen();
    } else {
      setState(() => _expanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.mtfThemeTokens;
    final item = widget.item;
    final color = widget.statusColor;
    final summary = widget.summary;
    final binder = widget.binder;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        end: _expanded ? _expandedOverlap : _collapsedOverlap,
      ),
      builder:
          (context, overlap, child) =>
              _TrailingOverlap(overlap: overlap, child: child!),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabLeft =
              _tabInset +
              (constraints.maxWidth - _tabWidth - 2 * _tabInset) *
                  (widget.tabSlot + 1) /
                  2;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BinderPainter(
                    gradient: binder.gradient,
                    edge: binder.edge,
                    tabWidth: _tabWidth,
                    tabTop: _tabTop,
                    bodyTop: _bodyTop,
                    tabAlignX: widget.tabSlot,
                    tabInset: _tabInset,
                  ),
                ),
              ),
              Positioned(
                left: tabLeft,
                top: 0,
                width: _tabWidth,
                height: _bodyTop,
                child: GestureDetector(
                  key: ValueKey<String>('member_contract_tab_${item.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  onLongPress: widget.onLongPress,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, _tabTop, 14, 0),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.tabLabel,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: binder.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.fromLTRB(
                  14,
                  _expanded ? _bodyTop - 2 : _bodyTop + 6,
                  14,
                  _expanded ? 14 : 6,
                ),
                child: _DocPaper(
                  inkKey: ValueKey<String>('member_contract_${item.id}'),
                  fill: tokens.memberListCard,
                  border: tokens.memberListCardBorder,
                  onTap: _onPaperTap,
                  onLongPress: widget.onLongPress,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          key: ValueKey<String>(
                            'member_contract_head_${item.id}',
                          ),
                          onTap: _toggle,
                          onLongPress: widget.onLongPress,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: _expanded ? 0 : _collapsedPaperHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 26,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              widget.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        if (widget.meta.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.meta,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      item.statusLabel,
                                      key: ValueKey<String>(
                                        'member_contract_status_${item.id}',
                                      ),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _expanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.chevron_right_rounded,
                                    color: scheme.outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_expanded)
                          Padding(
                            key: ValueKey<String>(
                              'member_contract_summary_${item.id}',
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 0, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Divider(
                                  height: 1,
                                  color: scheme.outlineVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  summary.heading,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _DocField('이름', summary.name),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: _DocField('전화번호', summary.phone),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: _DocField('상품', summary.product),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _DocField('총 결제금액', summary.paid),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: _DocField(
                                        '총 / 소진',
                                        summary.sessions,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: _DocField('남은 기간', summary.period),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '내용을 누르면 계약서가 열리고, 머리를 누르면 닫혀요',
                                    key: ValueKey<String>(
                                      'member_contract_open_hint_${item.id}',
                                    ),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 서류 양식의 작은 칸: 위에 이름표, 아래에 내용.
class _DocField extends StatelessWidget {
  const _DocField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 취소·파기된 계약서 화면(계약서 관리의 더보기에서 연다).
class _InactiveContractsPage extends StatelessWidget {
  const _InactiveContractsPage({
    required this.items,
    required this.cardBuilder,
  });

  final List<MemberContractItem> items;
  final Widget Function(BuildContext context, MemberContractItem item)
  cardBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mtfThemeTokens.memberListBackground,
      body: Column(
        children: [
          LessonContractHeader(
            title: '취소·파기된 계약서',
            backKey: const ValueKey<String>('member_contracts_inactive_back'),
            onBack: () => Navigator.of(context).maybePop(),
            neon: true,
          ),
          Expanded(
            child:
                items.isEmpty
                    ? const Center(
                      key: ValueKey<String>('member_contracts_inactive_empty'),
                      child: Text('취소·파기된 계약서가 없어요.'),
                    )
                    : ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        28 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        for (final item in items) cardBuilder(context, item),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

/// 머리말 안쪽(어두운 바탕) 요약 카드. 회원리스트 머리말 카드와 같은 모양이다(아이콘·이름·숫자).
class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 76,
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isSelected ? 0.24 : 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: isSelected ? 0.48 : 0.0),
              width: isSelected ? 1.2 : 0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
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
}

/// 둥근 모서리 종이 모양의 경로(접힌 모서리 없음).
Path _docPath(Size size, {double radius = 6}) {
  return Path()..addRRect(
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
  );
}

class _DocClipper extends CustomClipper<Path> {
  const _DocClipper();

  @override
  Path getClip(Size size) => _docPath(size);

  @override
  bool shouldReclip(_DocClipper oldClipper) => false;
}

class _DocPaperPainter extends CustomPainter {
  const _DocPaperPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _docPath(size);
    // 종이가 살짝 떠 있는 느낌의 그림자.
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.4), 2, false);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DocPaperPainter old) =>
      old.fill != fill || old.border != border;
}

/// `새 계약서 작성` 카드: 금색 바인더 + 인덱스 탭 + 흰 종이(글줄·`+`·펜 서명).
class _NewContractCard extends StatelessWidget {
  const _NewContractCard({required this.onTap});

  final VoidCallback onTap;

  static const Color _ink = Color(0xFF3A2704);
  static const double _height = 156;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _BinderPainter()),
            ),
            const Align(
              alignment: Alignment(_BinderPainter.defaultTabAlignX, -1),
              child: SizedBox(
                width: _BinderPainter.defaultTabWidth,
                height: _BinderPainter.defaultBodyTop,
                child: Align(
                  alignment: Alignment(0, 0.35),
                  child: Text(
                    'CONTRACT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              top: _BinderPainter.defaultBodyTop + 6,
              bottom: 12,
              child: _DocPaper(
                inkKey: const ValueKey<String>('member_contracts_add_card'),
                fill: Colors.white,
                border: Colors.black.withValues(alpha: 0.14),
                onTap: onTap,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(
                        painter: _DocRuledLinesPainter(
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: kMemberAddCardGradient,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 26,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '새 계약서 작성',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 76,
                            height: 44,
                            child: CustomPaint(painter: _PenSignaturePainter()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 바인더(뒷판)와 인덱스 탭. 기본값은 `새 계약서 작성` 카드의 금색 바인더다.
class _BinderPainter extends CustomPainter {
  const _BinderPainter({
    this.gradient = kMemberAddCardGradient,
    this.edge = const Color(0xFF8A6310),
    this.tabWidth = defaultTabWidth,
    this.tabTop = defaultTabTop,
    this.bodyTop = defaultBodyTop,
    this.tabAlignX = defaultTabAlignX,
    this.tabInset = 0,
  });

  static const double defaultTabWidth = 96;

  /// 탭 윗변의 세로 위치(위에서부터).
  static const double defaultTabTop = 3;

  /// 바인더 몸통의 윗변(위에서부터). 종이는 이보다 조금 위에서 시작해 살짝 솟아 보인다.
  static const double defaultBodyTop = 22;

  /// 탭의 가로 위치(`Alignment.x`: -1 왼쪽 끝, 1 오른쪽 끝).
  static const double defaultTabAlignX = 0.52;

  final Gradient gradient;
  final Color edge;
  final double tabWidth;
  final double tabTop;
  final double bodyTop;
  final double tabAlignX;

  /// 탭이 양끝에 붙을 때 두는 바깥 여백.
  final double tabInset;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tabLeft =
        tabInset + (w - tabWidth - 2 * tabInset) * (tabAlignX + 1) / 2;
    final path =
        Path()
          ..moveTo(0, bodyTop + 16)
          ..quadraticBezierTo(0, bodyTop, 16, bodyTop)
          ..lineTo(tabLeft, bodyTop)
          ..lineTo(tabLeft + 10, tabTop + 6)
          ..quadraticBezierTo(tabLeft + 12, tabTop, tabLeft + 20, tabTop)
          ..lineTo(tabLeft + tabWidth - 20, tabTop)
          ..quadraticBezierTo(
            tabLeft + tabWidth - 12,
            tabTop,
            tabLeft + tabWidth - 10,
            tabTop + 6,
          )
          ..lineTo(tabLeft + tabWidth, bodyTop)
          ..lineTo(w - 16, bodyTop)
          ..quadraticBezierTo(w, bodyTop, w, bodyTop + 16)
          ..lineTo(w, h - 16)
          ..quadraticBezierTo(w, h, w - 16, h)
          ..lineTo(16, h)
          ..quadraticBezierTo(0, h, 0, h - 16)
          ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 3, false);
    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = edge.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_BinderPainter old) =>
      old.gradient != gradient ||
      old.edge != edge ||
      old.tabWidth != tabWidth ||
      old.tabAlignX != tabAlignX;
}

/// 종이 아래쪽 오른쪽: 서명 글씨 한 줄과 그 끝에서 쓰고 있는 펜.
class _PenSignaturePainter extends CustomPainter {
  const _PenSignaturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height - 8;
    final line =
        Paint()
          ..color = const Color(0xFF3A2704).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
    final sign =
        Path()
          ..moveTo(2, baseY)
          ..cubicTo(8, baseY - 14, 14, baseY - 14, 18, baseY - 2)
          ..cubicTo(22, baseY - 12, 28, baseY - 12, 32, baseY - 2)
          ..lineTo(48, baseY - 2);
    canvas.drawPath(sign, line);

    // 펜: 끝(펜촉)이 서명 끝에 닿고 몸통은 오른쪽 위로 기울어 있다.
    canvas.save();
    canvas.translate(48, baseY - 2);
    canvas.rotate(0.75);
    final tip =
        Path()
          ..moveTo(0, 0)
          ..lineTo(-3.2, -9)
          ..lineTo(3.2, -9)
          ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFF1F2937));
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-3.6, -36, 3.6, -9),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF0B1E32));
    canvas.drawRect(
      const Rect.fromLTRB(-3.6, -16, 3.6, -13),
      Paint()..color = const Color(0xFFE9C25A),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PenSignaturePainter old) => false;
}

/// 서류의 글줄: 왼쪽 위에서 시작하는 세 줄, 아래로 갈수록 길다.
class _DocRuledLinesPainter extends CustomPainter {
  const _DocRuledLinesPainter({required this.color});

  final Color color;

  static const List<double> _widthFractions = [0.34, 0.58, 0.82];

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.30)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
    const left = 20.0;
    const top = 16.0;
    const gap = 12.0;
    final maxWidth = size.width - left - 24;
    for (var i = 0; i < _widthFractions.length; i++) {
      final y = top + gap * i;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + maxWidth * _widthFractions[i], y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DocRuledLinesPainter old) => old.color != color;
}

/// 문서(종이) 모양의 눌리는 카드.
class _DocPaper extends StatelessWidget {
  const _DocPaper({
    required this.fill,
    required this.border,
    required this.child,
    this.inkKey,
    this.onTap,
    this.onLongPress,
  });

  final Color fill;
  final Color border;
  final Key? inkKey;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DocPaperPainter(fill: fill, border: border),
      child: ClipPath(
        clipper: const _DocClipper(),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: inkKey,
            onTap: onTap,
            onLongPress: onLongPress,
            child: child,
          ),
        ),
      ),
    );
  }
}
