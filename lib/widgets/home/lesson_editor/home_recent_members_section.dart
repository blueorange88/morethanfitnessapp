import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/home_member_lookup_service.dart';
import '../../../utils/korean_search_utils.dart' as search_utils;

class HomeRecentMembersSection extends StatelessWidget {
  const HomeRecentMembersSection({
    super.key,
    required this.searchKeyword,
    required this.onOpenAllMembersTap,
    required this.onPicked,
    this.ownerUid,
  });

  final String searchKeyword;
  final String? ownerUid;
  final Future<void> Function() onOpenAllMembersTap;
  final void Function(
    String name,
    String memberId,
    String phone,
    String sessionCountText,
  ) onPicked;

  Query<Map<String, dynamic>> _membersQuery() {
    final base = FirebaseFirestore.instance.collection('members');
    final owner = ownerUid?.trim() ?? '';
    if (owner.isEmpty) return base;
    return base
        .where('trainerId', isEqualTo: owner)
        .where('workspaceType', isEqualTo: 'personal');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 등록 회원',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: onOpenAllMembersTap,
              child: const Text('전체보기', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _membersQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '회원 목록을 불러오지 못했습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final docs = [...snapshot.data!.docs]..sort((a, b) {
                final aCreatedAt = a.data()['createdAt'];
                final bCreatedAt = b.data()['createdAt'];
                final aMillis = aCreatedAt is Timestamp
                    ? aCreatedAt.toDate().millisecondsSinceEpoch
                    : aCreatedAt is DateTime
                        ? aCreatedAt.millisecondsSinceEpoch
                        : -1;
                final bMillis = bCreatedAt is Timestamp
                    ? bCreatedAt.toDate().millisecondsSinceEpoch
                    : bCreatedAt is DateTime
                        ? bCreatedAt.millisecondsSinceEpoch
                        : -1;
                return bMillis.compareTo(aMillis);
              });
            final seenMembers = <String>{};

            final members = docs
                .map((doc) {
                  final data = doc.data();
                  if (!HomeMemberLookupService.matchesPersonalOwner(
                    data,
                    ownerUid,
                  )) {
                    return <String, dynamic>{};
                  }
                  final name = (data['name'] ?? '').toString().trim();
                  final phone = _phoneFromMemberData(data);

                  return {
                    'id': doc.id,
                    'name': name,
                    'phone': phone,
                    'sessionCountText':
                        HomeMemberLookupService.sessionCountTextFromMemberData(
                      data,
                    ),
                    'isDeleted': data['isDeleted'] == true,
                    'deleteStatus': (data['deleteStatus'] ?? '').toString(),
                  };
                })
                .where((member) {
                  if (member.isEmpty) return false;
                  if (member['isDeleted'] == true) return false;
                  if ((member['deleteStatus'] ?? '').toString() ==
                      'pending_delete') {
                    return false;
                  }

                  final name = (member['name'] ?? '').toString().trim();
                  final phone = (member['phone'] ?? '').toString().trim();
                  if (name.isEmpty && phone.isEmpty) return false;

                  final memberKey = '$name|$phone';
                  if (!seenMembers.add(memberKey)) return false;

                  return search_utils.matchesSmartMemberSearch(
                    rawQuery: searchKeyword,
                    targets: [name, phone],
                  );
                })
                .take(5)
                .toList();

            if (kDebugMode) {
              debugPrint(
                '[MTF_RECENT_MEMBER] uid=${ownerUid?.trim() ?? 'legacy'} '
                'workspace=${(ownerUid?.trim() ?? '').isEmpty ? 'legacy' : 'personal'} '
                'source=lesson_editor_recent_members candidateCount=${docs.length} '
                'validatedCount=${members.length}',
              );
            }

            if (members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '검색되는 회원이 없습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members
                    .map(
                      (member) => HomeRecentMemberChip(
                        name: (member['name'] ?? '').toString(),
                        phone: (member['phone'] ?? '').toString(),
                        onTap: () {
                          onPicked(
                            (member['name'] ?? '').toString(),
                            (member['id'] ?? '').toString(),
                            (member['phone'] ?? '').toString(),
                            (member['sessionCountText'] ?? '').toString(),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ],
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
              color: const Color(0xFF4F46E5).withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF4F46E5).withOpacity(0.14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F46E5).withOpacity(0.10),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withOpacity(0.14),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    cleanName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
                if (phoneLastFour != '-') ...[
                  const Text(
                    ' · ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  Text(
                    phoneLastFour,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
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
