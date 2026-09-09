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
}

bool shouldShowHomeMemberSearchSuggestions({
  required String searchKeyword,
}) {
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

  final sorted = candidates
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

String _phoneFromMemberData(Map<String, dynamic> data) {
  return [
    data['phoneNormalized'],
    data['phone'],
    data['phoneDisplay'],
  ]
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
    sessionCountText:
        HomeMemberLookupService.sessionCountTextFromMemberData(data),
    createdAt: _createdAtFromMemberData(data),
    trainerId: (data['trainerId'] ?? '').toString().trim(),
    workspaceType: (data['workspaceType'] ?? '').toString().trim(),
    isDeleted: data['isDeleted'] == true,
    deleteStatus: (data['deleteStatus'] ?? '').toString(),
  );
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
  ) onPicked;

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
              '최근 등록 회원',
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
          boundedContent(const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '회원 목록을 불러오지 못했습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ))
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _homeMembersQuery(owner).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return boundedContent(const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '회원 목록을 불러오지 못했습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ));
              }

              if (!snapshot.hasData) {
                return boundedContent(const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ));
              }

              final docs = snapshot.data!.docs;
              final candidates = docs.map(_candidateFromMemberDoc).toList();
              final members = filterHomeMemberSuggestions(
                candidates: candidates,
                ownerUid: owner,
                searchKeyword: '',
              );

              if (kDebugMode) {
                debugPrint(
                  '[MTF_RECENT_MEMBER] ownerScope=personal '
                  'source=lesson_editor_recent_members candidateCount=${docs.length} '
                  'validatedCount=${members.length}',
                );
              }

              if (members.isEmpty) {
                return boundedContent(const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '최근 등록 회원이 없습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ));
              }

              return boundedContent(
                SingleChildScrollView(
                  key: const Key('home_recent_members_scroll'),
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members
                          .map(
                            (member) => HomeRecentMemberChip(
                              name: member.name,
                              phone: member.phone,
                              onTap: () {
                                onPicked(
                                  member.name,
                                  member.id,
                                  member.phone,
                                  member.sessionCountText,
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
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
  });

  final String name;
  final String phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final phoneLastFour = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : (digits.isEmpty ? '-' : digits);
    final cleanName = name.trim().isEmpty ? '회원' : name.trim();

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
              color: colors.secondaryContainer,
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
                    color: colors.secondary.withValues(alpha: 0.18),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: colors.onSecondaryContainer,
                  ),
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
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
                if (phoneLastFour != '-') ...[
                  Text(
                    ' · ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    phoneLastFour,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: colors.onSecondaryContainer,
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
