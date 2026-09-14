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

enum HomeAiRecommendationReason { recent, frequent, absent }

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
  int totalSlots = 6,
  int maxRecentSlots = 4,
  int recentWindowDays = 14,
  int minFrequentLessonCount = 2,
  int minAbsentDays = 7,
}) {
  if (candidatesByRecency.isEmpty) return const [];

  final byId = {for (final c in candidatesByRecency) c.id: c};

  // "최근등록"은 등록일이 실제로 recentWindowDays 이내인 회원만 포함한다.
  // 신규 등록이 없는 기간이 이어지면 이 목록은 자연히 줄어들고, 비어난 자리는
  // 자주 레슨한 회원으로 채워져 시트 높이가 함께 줄어든다.
  final recentCutoff = now.subtract(Duration(days: recentWindowDays));
  final recentEligible =
      candidatesByRecency
          .where(
            (c) => c.createdAt != null && !c.createdAt!.isBefore(recentCutoff),
          )
          .take(maxRecentSlots)
          .toList();
  final recentIds = recentEligible.map((c) => c.id).toSet();

  final absentCutoff = now.subtract(Duration(days: minAbsentDays));
  final absentRanked =
      candidatesByRecency
          .where(
            (c) =>
                c.lastLessonAt != null &&
                c.lastLessonAt!.isBefore(absentCutoff) &&
                !recentIds.contains(c.id),
          )
          .toList()
        ..sort((a, b) => a.lastLessonAt!.compareTo(b.lastLessonAt!));
  final absent = absentRanked.isEmpty ? null : absentRanked.first;

  final excludedFromFrequent = <String>{
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
      totalSlots - recentEligible.length - (absent == null ? 0 : 1);
  final frequentChosen =
      frequentRanked
          .take(remainingBudget < 0 ? 0 : remainingBudget)
          .map((e) => byId[e.key]!)
          .toList();

  return [
    for (final candidate in recentEligible)
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

class HomeRecentMembersSection extends StatelessWidget {
  const HomeRecentMembersSection({
    super.key,
    required this.onOpenAllMembersTap,
    required this.onPicked,
    this.ownerUid,
  });

  final String? ownerUid;
  final Future<void> Function() onOpenAllMembersTap;
  final void Function(
    String name,
    String memberId,
    String phone,
    String sessionCountText,
  )
  onPicked;

  @override
  Widget build(BuildContext context) {
    final owner = ownerUid?.trim() ?? '';
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
              onPressed: onOpenAllMembersTap,
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
                future:
                    _recentSchedulesQuery(
                      owner,
                      now.subtract(const Duration(days: 14)),
                    ).get(),
                builder: (context, scheduleSnapshot) {
                  final lessonCounts =
                      scheduleSnapshot.hasData
                          ? lessonCountsFromScheduleDocs(
                            scheduleSnapshot.data!.docs.map(
                              (doc) => doc.data(),
                            ),
                          )
                          : const <String, int>{};

                  final recommended = buildAiRecommendedMembers(
                    candidatesByRecency: recencyPool,
                    recentLessonCounts: lessonCounts,
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
                            const columns = 3;
                            const spacing = 8.0;
                            final chipWidth =
                                (constraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
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
                                            onTap: () {
                                              onPicked(
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

class HomeRecentMemberChip extends StatelessWidget {
  const HomeRecentMemberChip({
    super.key,
    required this.name,
    required this.phone,
    required this.onTap,
    this.reason = HomeAiRecommendationReason.recent,
  });

  final String name;
  final String phone;
  final VoidCallback onTap;
  final HomeAiRecommendationReason reason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final phoneLastFour =
        digits.length >= 4
            ? digits.substring(digits.length - 4)
            : (digits.isEmpty ? '-' : digits);
    final cleanName = name.trim().isEmpty ? '회원' : name.trim();

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
        badgeIcon = Icons.person_outline_rounded;
        containerColor = colors.secondaryContainer;
        onContainerColor = colors.onSecondaryContainer;
        break;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onContainerColor.withValues(alpha: 0.18),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Icon(badgeIcon, size: 14, color: onContainerColor),
                ),
                const SizedBox(width: 6),
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    cleanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: onContainerColor,
                    ),
                  ),
                ),
                if (phoneLastFour != '-') ...[
                  Text(
                    ' · ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: onContainerColor,
                    ),
                  ),
                  Text(
                    phoneLastFour,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: onContainerColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
