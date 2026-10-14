import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/home_member_lookup_service.dart';
import '../../../aifc/core/aifc_avatar.dart';

/// 홈 하단 `최근 회원` 머리말(제목 + 전체보기). 다크모드에서도 보이도록 테마 색을 쓴다.
class HomeRecentClientsHeader extends StatelessWidget {
  const HomeRecentClientsHeader({
    super.key,
    required this.primaryColor,
    required this.onOpenAllTap,
  });

  final Color primaryColor;
  final VoidCallback onOpenAllTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 남색(primary)은 어두운 배경에 묻혀서 다크모드에서는 밝게 올려 쓴다.
    final linkColor =
        dark ? Color.lerp(primaryColor, Colors.white, 0.75)! : primaryColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '최근 회원',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        TextButton(
          onPressed: onOpenAllTap,
          child: Text('전체보기', style: TextStyle(fontSize: 12, color: linkColor)),
        ),
      ],
    );
  }
}

/// 홈 하단 `최근 회원` 의 원형 아바타. 이름은 아래에 따로 적히므로 원 안에는 이름 대신
/// 사람 모양을 넣는다. 색은 [index] 로 돌려 쓰고, 다크모드에서는 어두운 배경에 밝은 아이콘.
class HomeRecentClientAvatar extends StatelessWidget {
  const HomeRecentClientAvatar({
    super.key,
    required this.index,
    this.size = 48,
  });

  final int index;
  final double size;

  // 라이트: 연한 배경 + 진한 아이콘. 다크: 아이콘 색을 낮게 깐 배경 + 밝은 아이콘.
  static const List<
    ({Color lightBg, Color lightIcon, Color darkBg, Color darkIcon})
  >
  palette = [
    (
      lightBg: Color(0xFFEEF2FF),
      lightIcon: Color(0xFF4338CA),
      darkBg: Color(0xFF2A2F5C),
      darkIcon: Color(0xFFA5B4FC),
    ),
    (
      lightBg: Color(0xFFF3E8FF),
      lightIcon: Color(0xFF6B21A8),
      darkBg: Color(0xFF3F2A5C),
      darkIcon: Color(0xFFD8B4FE),
    ),
    (
      lightBg: Color(0xFFFFE4E6),
      lightIcon: Color(0xFFBE123C),
      darkBg: Color(0xFF5C2A33),
      darkIcon: Color(0xFFFDA4AF),
    ),
    (
      lightBg: Color(0xFFE0F2FE),
      lightIcon: Color(0xFF0369A1),
      darkBg: Color(0xFF1E3F57),
      darkIcon: Color(0xFF7DD3FC),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = palette[index % palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? colors.darkBg : colors.lightBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.58,
        color: dark ? colors.darkIcon : colors.lightIcon,
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeRecentClientsHeader(
            primaryColor: primaryColor,
            onOpenAllTap: onOpenAllTap,
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _membersQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Text(
                    '최근 회원을 불러오지 못했습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
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

              final candidates =
                  snapshot.data!.docs.where((doc) {
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
                      final aMillis =
                          aCreatedAt is Timestamp
                              ? aCreatedAt.millisecondsSinceEpoch
                              : -1;
                      final bMillis =
                          bCreatedAt is Timestamp
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AifcAvatar(size: 32, isAnimating: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '오! 아직 등록한 회원이 없어요.\n회원카드 등록 도와드릴까요?',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
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

                  return GestureDetector(
                    onTap: () => onMemberTap(docs[index].id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HomeRecentClientAvatar(index: index),
                        const SizedBox(height: 6),
                        Text(
                          safeName,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface,
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
