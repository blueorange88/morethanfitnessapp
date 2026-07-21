import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/home_member_lookup_service.dart';
import '../../../aifc/core/aifc_avatar.dart';

class HomeRecentClientsSection extends StatelessWidget {
  const HomeRecentClientsSection({
    super.key,
    required this.primaryColor,
    required this.onOpenAllTap,
    required this.onMemberTap,
    required this.onCreateTap,
    this.ownerUid,
  });

  final Color primaryColor;
  final VoidCallback onOpenAllTap;
  final ValueChanged<String> onMemberTap;
  final VoidCallback onCreateTap;
  final String? ownerUid;

  Query<Map<String, dynamic>> _membersQuery() {
    final base = FirebaseFirestore.instance.collection('members');
    final owner = ownerUid?.trim() ?? '';
    if (owner.isEmpty) return base;
    return base
        .where('trainerId', isEqualTo: owner)
        .where('workspaceType', isEqualTo: 'personal');
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF4338CA),
      },
      {
        'bg': const Color(0xFFF3E8FF),
        'text': const Color(0xFF6B21A8),
      },
      {
        'bg': const Color(0xFFFFE4E6),
        'text': const Color(0xFFBE123C),
      },
      {
        'bg': const Color(0xFFE0F2FE),
        'text': const Color(0xFF0369A1),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 회원',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: onOpenAllTap,
                child: Text(
                  '전체보기',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _membersQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: const Text(
                    '최근 회원을 불러오지 못했습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final candidates = snapshot.data!.docs.where((doc) {
                final data = doc.data();

                if (!HomeMemberLookupService.matchesPersonalOwner(
                  data,
                  ownerUid,
                )) {
                  return false;
                }

                if (data['isDeleted'] == true) return false;

                if ((data['deleteStatus'] ?? '').toString() ==
                    'pending_delete') {
                  return false;
                }

                final name = (data['name'] ?? '').toString().trim();
                final phone = (data['phone'] ?? '').toString().trim();

                return name.isNotEmpty || phone.isNotEmpty;
              }).toList()
                ..sort((a, b) {
                  final aCreatedAt = a.data()['createdAt'];
                  final bCreatedAt = b.data()['createdAt'];
                  final aMillis = aCreatedAt is Timestamp
                      ? aCreatedAt.millisecondsSinceEpoch
                      : -1;
                  final bMillis = bCreatedAt is Timestamp
                      ? bCreatedAt.millisecondsSinceEpoch
                      : -1;
                  return bMillis.compareTo(aMillis);
                });
              final docs = candidates.take(4).toList();

              if (kDebugMode) {
                debugPrint(
                  '[MTF_RECENT_MEMBER] uid=${ownerUid?.trim() ?? 'legacy'} '
                  'workspace=${(ownerUid?.trim() ?? '').isEmpty ? 'legacy' : 'personal'} '
                  'source=home_recent_members candidateCount=${snapshot.data!.docs.length} '
                  'validatedCount=${candidates.length}',
                );
              }

              if (docs.isEmpty) {
                return InkWell(
                  onTap: onCreateTap,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AifcAvatar(size: 32, isAnimating: true),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '오! 아직 등록한 회원이 없어요.\n고객카드 등록 도와드릴까요?',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(docs.length, (index) {
                  final data = docs[index].data();
                  final name = (data['name'] ?? '').toString().trim();
                  final safeName = name.isEmpty ? '회원' : name;
                  final colorSet = colors[index % colors.length];

                  return GestureDetector(
                    onTap: () => onMemberTap(docs[index].id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorSet['bg'] as Color,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            safeName.length > 4
                                ? safeName.substring(0, 4)
                                : safeName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorSet['text'] as Color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          safeName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
