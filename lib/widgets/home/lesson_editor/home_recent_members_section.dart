import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/home_member_lookup_service.dart';
import '../../../utils/korean_search_utils.dart' as search_utils;

const double homeMemberSuggestionContentMaxHeight = 118;

class HomeMemberSuggestionCandidate {
  const HomeMemberSuggestionCandidate({
    required this.id,
    required this.name,
    required this.phone,
    required this.sessionCountText,
    required this.createdAt,
    required this.trainerId,
    required this.workspaceType,
    required this.isDeleted,
    required this.deleteStatus,
    this.lastLessonAt,
  });

  final String id;
  final String name;
  final String phone;
  final String sessionCountText;
  final DateTime? createdAt;
  final String trainerId;
  final String workspaceType;
  final bool isDeleted;
  final String deleteStatus;
  final DateTime? lastLessonAt;
}

enum HomeAiRecommendationReason { recent, frequent, absent, sameSlot }

class HomeAiRecommendedMember {
  const HomeAiRecommendedMember({
    required this.candidate,
    required this.reason,
  });

  final HomeMemberSuggestionCandidate candidate;
  final HomeAiRecommendationReason reason;
}

@visibleForTesting
List<HomeAiRecommendedMember> buildAiRecommendedMembers({
  required List<HomeMemberSuggestionCandidate> candidatesByRecency,
  required Map<String, int> recentLessonCounts,
  required DateTime now,
  Map<String, int> slotLessonCounts = const {},
  int minSlotLessonCount = 2,
  int maxSlotSlots = 2,
  int totalSlots = 4,
  int maxRecentSlots = 2,
  int recentWindowDays = 14,
  int minFrequentLessonCount = 2,
  int minAbsentDays = 7,
}) {
  if (candidatesByRecency.isEmpty) return const [];

  final byId = {for (final c in candidatesByRecency) c.id: c};

  // 등록하려는 칸과 같은 요일·비슷한 시간대에 자주 레슨한 회원을 맨 앞에 둔다.
  final slotChosen =
      (slotLessonCounts.entries
              .where(
                (e) => e.value >= minSlotLessonCount && byId.containsKey(e.key),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(maxSlotSlots)
          .map((e) => byId[e.key]!)
          .toList();
  final slotIds = slotChosen.map((c) => c.id).toSet();

  // "최근등록"은 등록일이 실제로 recentWindowDays 이내인 회원만 포함한다.
  // 신규 등록이 없는 기간이 이어지면 이 목록은 자연히 줄어들고, 비어난 자리는
  // 자주 레슨한 회원으로 채워져 시트 높이가 함께 줄어든다.
  final recentCutoff = now.subtract(Duration(days: recentWindowDays));
  final allRecentEligible =
      candidatesByRecency
          .where(
            (c) =>
                c.createdAt != null &&
                !c.createdAt!.isBefore(recentCutoff) &&
                !slotIds.contains(c.id),
          )
          .toList();
  final recentEligible = allRecentEligible.take(maxRecentSlots).toList();
  final recentIds = recentEligible.map((c) => c.id).toSet();

  final absentCutoff = now.subtract(Duration(days: minAbsentDays));
  final absentRanked =
      candidatesByRecency
          .where(
            (c) =>
                c.lastLessonAt != null &&
                c.lastLessonAt!.isBefore(absentCutoff) &&
                !recentIds.contains(c.id) &&
                !slotIds.contains(c.id),
          )
          .toList()
        ..sort((a, b) => a.lastLessonAt!.compareTo(b.lastLessonAt!));
  final absent = absentRanked.isEmpty ? null : absentRanked.first;

  final excludedFromFrequent = <String>{
    ...slotIds,
    ...recentIds,
    if (absent != null) absent.id,
  };
  final frequentRanked =
      recentLessonCounts.entries
          .where(
            (e) =>
                e.value >= minFrequentLessonCount &&
                byId.containsKey(e.key) &&
                !excludedFromFrequent.contains(e.key),
          )
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

  final remainingBudget =
      totalSlots -
      slotChosen.length -
      recentEligible.length -
      (absent == null ? 0 : 1);
  final frequentChosen =
      frequentRanked
          .take(remainingBudget < 0 ? 0 : remainingBudget)
          .map((e) => byId[e.key]!)
          .toList();

  // 자주 레슨한 회원이 모자라 남는 칸은 14일 이내 신규 등록자로 더 채운다(오랜만 후보는 제외).
  final leftover = remainingBudget - frequentChosen.length;
  final extraRecent =
      leftover <= 0
          ? const <HomeMemberSuggestionCandidate>[]
          : allRecentEligible
              .where((c) => !recentIds.contains(c.id) && c.id != absent?.id)
              .take(leftover)
              .toList();

  return [
    for (final candidate in slotChosen)
      HomeAiRecommendedMember(
        candidate: candidate,
        reason: HomeAiRecommendationReason.sameSlot,
      ),
    for (final candidate in [...recentEligible, ...extraRecent])
      HomeAiRecommendedMember(
        candidate: candidate,
        reason: HomeAiRecommendationReason.recent,
      ),
    for (final candidate in frequentChosen)
      HomeAiRecommendedMember(
        candidate: candidate,
        reason: HomeAiRecommendationReason.frequent,
      ),
    if (absent != null)
      HomeAiRecommendedMember(
        candidate: absent,
        reason: HomeAiRecommendationReason.absent,
      ),
  ];
}

bool shouldShowHomeMemberSearchSuggestions({required String searchKeyword}) {
  return searchKeyword.trim().isNotEmpty;
}

@visibleForTesting
String maskedHomeMemberPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final suffix =
      digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  return '•••• $suffix';
}

@visibleForTesting
List<HomeMemberSuggestionCandidate> filterHomeMemberSuggestions({
  required Iterable<HomeMemberSuggestionCandidate> candidates,
  required String ownerUid,
  required String searchKeyword,
  int limit = 5,
}) {
  final owner = ownerUid.trim();
  if (owner.isEmpty || limit <= 0) return const [];

  final sorted =
      candidates
          .where(
            (candidate) =>
                candidate.trainerId == owner &&
                candidate.workspaceType == 'personal' &&
                !candidate.isDeleted &&
                candidate.deleteStatus != 'pending_delete' &&
                (candidate.name.isNotEmpty || candidate.phone.isNotEmpty),
          )
          .toList()
        ..sort((a, b) {
          final aMillis = a.createdAt?.millisecondsSinceEpoch ?? -1;
          final bMillis = b.createdAt?.millisecondsSinceEpoch ?? -1;
          return bMillis.compareTo(aMillis);
        });

  final seenMembers = <String>{};
  return sorted
      .where((candidate) {
        final memberKey = '${candidate.name}|${candidate.phone}';
        if (!seenMembers.add(memberKey)) return false;

        return search_utils.matchesSmartMemberSearch(
          rawQuery: searchKeyword,
          targets: [candidate.name, candidate.phone],
        );
      })
      .take(limit)
      .toList();
}

class HomeMemberSearchSuggestionsList extends StatelessWidget {
  const HomeMemberSearchSuggestionsList({
    super.key,
    required this.members,
    required this.onPicked,
  });

  final List<HomeMemberSuggestionCandidate> members;
  final ValueChanged<HomeMemberSuggestionCandidate> onPicked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          '일치하는 등록 회원이 없어요.',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: homeMemberSuggestionContentMaxHeight,
      ),
      child: ListView.separated(
        key: const Key('home_member_search_suggestions_list'),
        shrinkWrap: true,
        primary: false,
        physics: const ClampingScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
          final maskedPhone = maskedHomeMemberPhone(member.phone);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('home_member_search_suggestion_${member.id}'),
              onTap: () => onPicked(member),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (maskedPhone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        maskedPhone,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Query<Map<String, dynamic>> _homeMembersQuery(String owner) {
  return FirebaseFirestore.instance
      .collection('members')
      .where('trainerId', isEqualTo: owner)
      .where('workspaceType', isEqualTo: 'personal');
}

DateTime? _createdAtFromMemberData(Map<String, dynamic> data) {
  final raw = data['createdAt'];
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}

DateTime? _lastLessonAtFromMemberData(Map<String, dynamic> data) {
  final raw = data['lastLessonAt'] ?? data['lastLogAt'];
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return null;
}

String _phoneFromMemberData(Map<String, dynamic> data) {
  return [data['phoneNormalized'], data['phone'], data['phoneDisplay']]
      .map((value) => (value ?? '').toString().trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
}

HomeMemberSuggestionCandidate _candidateFromMemberDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  return HomeMemberSuggestionCandidate(
    id: doc.id,
    name: (data['name'] ?? '').toString().trim(),
    phone: _phoneFromMemberData(data),
    sessionCountText: HomeMemberLookupService.sessionCountTextFromMemberData(
      data,
    ),
    createdAt: _createdAtFromMemberData(data),
    trainerId: (data['trainerId'] ?? '').toString().trim(),
    workspaceType: (data['workspaceType'] ?? '').toString().trim(),
    isDeleted: data['isDeleted'] == true,
    deleteStatus: (data['deleteStatus'] ?? '').toString(),
    lastLessonAt: _lastLessonAtFromMemberData(data),
  );
}

Query<Map<String, dynamic>> _recentSchedulesQuery(
  String owner,
  DateTime since,
) {
  return FirebaseFirestore.instance
      .collection('schedules')
      .where('trainerId', isEqualTo: owner)
      .where('workspaceType', isEqualTo: 'personal')
      .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
}

@visibleForTesting
Map<String, int> lessonCountsFromScheduleDocs(
  Iterable<Map<String, dynamic>> docs,
) {
  final counts = <String, int>{};
  for (final data in docs) {
    if (data['isDeleted'] == true) continue;
    final memberId = (data['memberId'] ?? '').toString().trim();
    if (memberId.isEmpty) continue;
    counts[memberId] = (counts[memberId] ?? 0) + 1;
  }
  return counts;
}

class HomeMemberSearchSuggestionsOverlay extends StatelessWidget {
  const HomeMemberSearchSuggestionsOverlay({
    super.key,
    required this.searchKeyword,
    required this.onPicked,
    this.ownerUid,
  });

  final String searchKeyword;
  final String? ownerUid;
  final ValueChanged<HomeMemberSuggestionCandidate> onPicked;

  @override
  Widget build(BuildContext context) {
    final owner = ownerUid?.trim() ?? '';
    final keyword = searchKeyword.trim();
    final colors = Theme.of(context).colorScheme;

    if (owner.isEmpty || keyword.isEmpty) return const SizedBox.shrink();

    return Material(
      key: const Key('home_member_search_overlay'),
      elevation: 8,
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(10),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _homeMembersQuery(owner).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    '회원 목록을 불러오지 못했습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const SizedBox(
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final members = filterHomeMemberSuggestions(
              candidates: snapshot.data!.docs.map(_candidateFromMemberDoc),
              ownerUid: owner,
              searchKeyword: keyword,
            );

            if (kDebugMode) {
              debugPrint(
                '[MTF_MEMBER_AUTOCOMPLETE] ownerScope=personal '
                'candidateCount=${snapshot.data!.docs.length} '
                'validatedCount=${members.length}',
              );
            }

            return HomeMemberSearchSuggestionsList(
              members: members,
              onPicked: onPicked,
            );
          },
        ),
      ),
    );
  }
}

class HomeRecentMembersSection extends StatefulWidget {
  const HomeRecentMembersSection({
    super.key,
    required this.onOpenAllMembersTap,
    required this.onPicked,
    this.ownerUid,
    this.slotDay,
    this.slotTime,
  });

  final String? ownerUid;

  /// 등록하려는 칸의 요일("월"~"일")과 시작 시간("HH:mm"). 둘 다 있으면 같은 요일·비슷한
  /// 시간대에 자주 레슨한 회원을 맨 앞에 추천한다.
  final String? slotDay;
  final String? slotTime;
  final Future<void> Function() onOpenAllMembersTap;
  final void Function(
    String name,
    String memberId,
    String phone,
    String sessionCountText,
  )
  onPicked;

  @override
  State<HomeRecentMembersSection> createState() =>
      _HomeRecentMembersSectionState();
}

/// 시간대 추천에 쓰는 과거 레슨을 살펴볼 기간.
const int homeSlotRecommendationWindowDays = 56;

class _HomeRecentMembersSectionState extends State<HomeRecentMembersSection> {
  // 시트가 다시 그려질 때마다 서버를 다시 부르지 않도록 한 번만 가져온다.
  Future<QuerySnapshot<Map<String, dynamic>>>? _schedulesFuture;
  String _schedulesFutureOwner = '';

  Future<QuerySnapshot<Map<String, dynamic>>> _schedulesFor(String owner) {
    if (_schedulesFuture == null || _schedulesFutureOwner != owner) {
      _schedulesFutureOwner = owner;
      _schedulesFuture =
          _recentSchedulesQuery(
            owner,
            DateTime.now().subtract(
              const Duration(days: homeSlotRecommendationWindowDays),
            ),
          ).get();
    }
    return _schedulesFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.ownerUid?.trim() ?? '';
    final colors = Theme.of(context).colorScheme;

    Widget boundedContent(Widget child) {
      return ConstrainedBox(
        key: const Key('home_member_suggestion_content'),
        constraints: const BoxConstraints(
          maxHeight: homeMemberSuggestionContentMaxHeight,
        ),
        child: child,
      );
    }

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI 레슨 추천 회원',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: widget.onOpenAllMembersTap,
              child: const Text('전체보기', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (owner.isEmpty)
          boundedContent(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '회원 목록을 불러오지 못했습니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _homeMembersQuery(owner).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return boundedContent(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '회원 목록을 불러오지 못했습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return boundedContent(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final candidates = docs.map(_candidateFromMemberDoc).toList();
              final recencyPool = filterHomeMemberSuggestions(
                candidates: candidates,
                ownerUid: owner,
                searchKeyword: '',
                limit: 200,
              );

              if (recencyPool.isEmpty) {
                return boundedContent(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '최근 등록 회원이 없습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }

              final now = DateTime.now();
              return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: _schedulesFor(owner),
                builder: (context, scheduleSnapshot) {
                  final scheduleDocs =
                      scheduleSnapshot.hasData
                          ? scheduleSnapshot.data!.docs
                              .map((doc) => doc.data())
                              .toList()
                          : const <Map<String, dynamic>>[];

                  // "자주 레슨"은 예전처럼 최근 14일만 센다.
                  final recentCutoff = now.subtract(const Duration(days: 14));
                  final lessonCounts = lessonCountsFromScheduleDocs(
                    scheduleDocs.where((data) {
                      final startAt = homeScheduleDocStartAt(data);
                      return startAt != null && !startAt.isBefore(recentCutoff);
                    }),
                  );

                  // 같은 요일·비슷한 시간대(앞뒤 1시간)에 자주 레슨한 회원.
                  final slotWeekday = homeWeekdayFromKoreanDay(widget.slotDay);
                  final slotMinutes = homeMinutesFromTimeText(widget.slotTime);
                  final slotCounts =
                      slotWeekday == null || slotMinutes == null
                          ? const <String, int>{}
                          : slotLessonCountsFromScheduleDocs(
                            scheduleDocs,
                            weekday: slotWeekday,
                            minutesOfDay: slotMinutes,
                          );

                  final recommended = buildAiRecommendedMembers(
                    candidatesByRecency: recencyPool,
                    recentLessonCounts: lessonCounts,
                    slotLessonCounts: slotCounts,
                    now: now,
                  );

                  if (kDebugMode) {
                    debugPrint(
                      '[MTF_RECENT_MEMBER] ownerScope=personal '
                      'source=lesson_editor_recent_members candidateCount=${docs.length} '
                      'recommendedCount=${recommended.length}',
                    );
                  }

                  return boundedContent(
                    SingleChildScrollView(
                      key: const Key('home_recent_members_scroll'),
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const columns = 4;
                            const spacing = 4.0;
                            final chipWidth =
                                (constraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
                            // 같은 이름이 둘 이상이면 구분되도록 그 회원에게만 전화번호 뒤 4자리를 붙인다.
                            final nameCounts = <String, int>{};
                            for (final entry in recommended) {
                              final key = entry.candidate.name.trim();
                              nameCounts[key] = (nameCounts[key] ?? 0) + 1;
                            }
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children:
                                  recommended
                                      .map(
                                        (entry) => SizedBox(
                                          width: chipWidth,
                                          child: HomeRecentMemberChip(
                                            name: entry.candidate.name,
                                            phone: entry.candidate.phone,
                                            reason: entry.reason,
                                            showPhoneSuffix:
                                                (nameCounts[entry.candidate.name
                                                        .trim()] ??
                                                    0) >
                                                1,
                                            onTap: () {
                                              widget.onPicked(
                                                entry.candidate.name,
                                                entry.candidate.id,
                                                entry.candidate.phone,
                                                entry
                                                    .candidate
                                                    .sessionCountText,
                                              );
                                            },
                                          ),
                                        ),
                                      )
                                      .toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );

    return KeyedSubtree(
      key: const Key('home_recent_members_section'),
      child: section,
    );
  }
}

/// 추천 이유를 사용자에게 보여 주는 짧은 문구.
String homeAiRecommendationLabel(HomeAiRecommendationReason reason) {
  switch (reason) {
    case HomeAiRecommendationReason.frequent:
      return '자주 레슨';
    case HomeAiRecommendationReason.absent:
      return '오랜만';
    case HomeAiRecommendationReason.recent:
      return '최근 등록';
    case HomeAiRecommendationReason.sameSlot:
      return '이 시간대';
  }
}

/// `AI 레슨 추천 회원` 한 명. 홈의 `최근 회원`처럼 원형 아바타 아래에 이름을 두고,
/// 왜 추천됐는지는 아바타 모서리의 아이콘과 이름 아래 글자로 알려 준다. 전화번호는 보여 주지 않고,
/// 같은 이름이 둘 이상일 때만([showPhoneSuffix]) 이름 뒤에 뒤 4자리를 붙인다.
class HomeRecentMemberChip extends StatelessWidget {
  const HomeRecentMemberChip({
    super.key,
    required this.name,
    required this.phone,
    required this.onTap,
    this.reason = HomeAiRecommendationReason.recent,
    this.showPhoneSuffix = false,
  });

  final String name;
  final String phone;
  final VoidCallback onTap;
  final HomeAiRecommendationReason reason;
  final bool showPhoneSuffix;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final phoneLastFour =
        digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    final baseName = name.trim().isEmpty ? '회원' : name.trim();
    final displayName =
        showPhoneSuffix && phoneLastFour.isNotEmpty
            ? '$baseName·$phoneLastFour'
            : baseName;
    final label = homeAiRecommendationLabel(reason);

    final IconData badgeIcon;
    final Color containerColor;
    final Color onContainerColor;
    switch (reason) {
      case HomeAiRecommendationReason.frequent:
        badgeIcon = Icons.local_fire_department_rounded;
        containerColor = colors.tertiaryContainer;
        onContainerColor = colors.onTertiaryContainer;
        break;
      case HomeAiRecommendationReason.absent:
        badgeIcon = Icons.event_busy_rounded;
        containerColor = colors.errorContainer;
        onContainerColor = colors.onErrorContainer;
        break;
      case HomeAiRecommendationReason.recent:
        badgeIcon = Icons.fiber_new_rounded;
        containerColor = colors.secondaryContainer;
        onContainerColor = colors.onSecondaryContainer;
        break;
      case HomeAiRecommendationReason.sameSlot:
        badgeIcon = Icons.schedule_rounded;
        containerColor = colors.primaryContainer;
        onContainerColor = colors.onPrimaryContainer;
        break;
    }

    return Semantics(
      button: true,
      label: '$baseName, $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 50,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      key: const Key('home_recent_member_avatar'),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: containerColor,
                        border: Border.all(color: colors.outline),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 26,
                        color: onContainerColor,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surface,
                          border: Border.all(color: onContainerColor),
                        ),
                        child: Icon(
                          badgeIcon,
                          size: 12,
                          color: onContainerColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 일정 문서의 시작 시각을 DateTime으로 읽는다(Timestamp·DateTime 모두 허용).
@visibleForTesting
DateTime? homeScheduleDocStartAt(Map<String, dynamic> data) {
  final value = data['startAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// "월"~"일"을 DateTime.weekday(월=1 … 일=7)로 바꾼다. 모르는 값은 null.
@visibleForTesting
int? homeWeekdayFromKoreanDay(String? day) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  final index = days.indexOf((day ?? '').trim());
  return index < 0 ? null : index + 1;
}

/// "HH:mm"을 하루 중 분(0~1439)으로 바꾼다. 형식이 틀리면 null.
@visibleForTesting
int? homeMinutesFromTimeText(String? time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch((time ?? '').trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

/// 같은 요일이고 시작 시각이 [toleranceMinutes] 이내인 레슨을 회원별로 센다.
/// 이미 지난 레슨과 앞으로 잡힌 레슨 모두 그 회원의 시간대 패턴으로 본다.
@visibleForTesting
Map<String, int> slotLessonCountsFromScheduleDocs(
  Iterable<Map<String, dynamic>> docs, {
  required int weekday,
  required int minutesOfDay,
  int toleranceMinutes = 60,
}) {
  final counts = <String, int>{};
  for (final data in docs) {
    if (data['isDeleted'] == true) continue;
    final memberId = (data['memberId'] ?? '').toString().trim();
    if (memberId.isEmpty) continue;
    final startAt = homeScheduleDocStartAt(data);
    if (startAt == null || startAt.weekday != weekday) continue;
    final startMinutes = startAt.hour * 60 + startAt.minute;
    if ((startMinutes - minutesOfDay).abs() > toleranceMinutes) continue;
    counts[memberId] = (counts[memberId] ?? 0) + 1;
  }
  return counts;
}
