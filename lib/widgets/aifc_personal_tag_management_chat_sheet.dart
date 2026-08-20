import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_sheet.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../models/personal_member_taxonomy.dart';
import '../services/personal_member_taxonomy_service.dart';
import 'aifc_confirm_chat_sheet.dart';
import 'personal_tag_horizontal_strip.dart';

class AifcPersonalTagManagementChatSheet extends StatefulWidget {
  const AifcPersonalTagManagementChatSheet({
    super.key,
    required this.ownerUid,
  });

  final String ownerUid;

  static Future<bool> show({
    required BuildContext context,
    required String ownerUid,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcPersonalTagManagementChatSheet(
        ownerUid: ownerUid,
      ),
    );
    return changed == true;
  }

  @override
  State<AifcPersonalTagManagementChatSheet> createState() =>
      _AifcPersonalTagManagementChatSheetState();
}

class _AifcPersonalTagManagementChatSheetState
    extends State<AifcPersonalTagManagementChatSheet> {
  late final PersonalMemberTaxonomyService _service =
      PersonalMemberTaxonomyService(uid: widget.ownerUid);
  String? _selectedTagId;
  bool _changed = false;
  bool _isBusy = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _membersStream =>
      FirebaseFirestore.instance
          .collection('members')
          .where('trainerId', isEqualTo: widget.ownerUid)
          .where('workspaceType', isEqualTo: 'personal')
          .snapshots();

  Future<void> _createTag() async {
    if (_isBusy) return;
    await AifcChatSheet.show(
      context: context,
      question: '새 태그를 만들어볼까요?\n회원 분류에 사용할 이름을 알려주세요.',
      inputLabel: '예: VIP / 다이어트 / 허리통증',
      skipLabel: '취소',
      skipClosesImmediately: true,
      onSkip: () {},
      onSave: (name) async {
        final created = await _service.create(
          kind: PersonalMemberTaxonomyKind.tag,
          idempotencyKey:
              'taxonomy_tag_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
        );
        if (mounted) {
          setState(() {
            _selectedTagId = created.id;
            _changed = true;
          });
        }
        return '${created.name} 태그를 만들었어요.';
      },
    );
  }

  Future<void> _renameTag(PersonalMemberTaxonomyItem item) async {
    if (_isBusy) return;
    await AifcChatSheet.show(
      context: context,
      question: '${item.name} 태그 이름을 어떻게 바꿀까요?',
      inputLabel: '새 태그 이름',
      initialValue: item.name,
      skipLabel: '취소',
      skipClosesImmediately: true,
      onSkip: () {},
      onSave: (name) async {
        final renamed = await _service.rename(
          kind: PersonalMemberTaxonomyKind.tag,
          id: item.id,
          name: name,
        );
        if (mounted) setState(() => _changed = true);
        return '${renamed.name}(으)로 바꿨어요.';
      },
    );
  }

  Future<void> _deleteTag(
    PersonalMemberTaxonomyItem item,
    int memberCount,
  ) async {
    if (_isBusy) return;
    final confirmed = await AifcConfirmChatSheet.show(
      context: context,
      title: '태그를 삭제할까요?',
      message: memberCount == 0
          ? '${item.name} 태그를 삭제합니다.'
          : '회원 $memberCount명에게서 ${item.name} 태그가 제거됩니다.',
      cancelText: '취소',
      confirmText: '태그 삭제',
      userConfirmText: '${item.name} 태그를 삭제할게요',
      confirmReplyText: '연결된 회원에서도 안전하게 제거할게요.',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await _service.delete(
        kind: PersonalMemberTaxonomyKind.tag,
        id: item.id,
      );
      if (!mounted) return;
      setState(() {
        _selectedTagId = null;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} 태그를 삭제했어요.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _changed) Navigator.of(context).pop(true);
      },
      child: AifcSheetFrame(
        maxHeightFactor: 0.82,
        children: [
          Flexible(
            child: StreamBuilder<List<PersonalMemberTaxonomyItem>>(
              stream: _service.watch(PersonalMemberTaxonomyKind.tag),
              builder: (context, tagSnapshot) {
                if (tagSnapshot.hasError) {
                  return _SheetMessage(
                      message: _errorMessage(tagSnapshot.error));
                }
                if (!tagSnapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final tags = [...tagSnapshot.data!]..sort((a, b) {
                    final createdAt = a.createdAt.compareTo(b.createdAt);
                    return createdAt != 0 ? createdAt : a.id.compareTo(b.id);
                  });

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _membersStream,
                  builder: (context, memberSnapshot) {
                    final counts = <String, int>{
                      for (final tag in tags) tag.id: 0
                    };
                    for (final document
                        in memberSnapshot.data?.docs ?? const []) {
                      final data = document.data();
                      if (data['isDeleted'] == true) continue;
                      final ids = data['personalTagIds'] is Iterable
                          ? (data['personalTagIds'] as Iterable)
                              .map((value) => value.toString())
                              .toSet()
                          : const <String>{};
                      for (final id in ids) {
                        if (counts.containsKey(id)) {
                          counts[id] = counts[id]! + 1;
                        }
                      }
                    }
                    final selected = tags
                        .where((item) => item.id == _selectedTagId)
                        .firstOrNull;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AifcChatBubble(
                            side: AifcBubbleSide.fc,
                            useThemeSurface: true,
                            text: '태그를 관리해볼까요?\n태그를 선택하면 이름 변경과 삭제를 할 수 있어요.',
                            child: tags.isEmpty
                                ? Text(
                                    '아직 만든 태그가 없어요.',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : PersonalTagHorizontalStrip(
                                    scrollKey: const ValueKey(
                                      'tag_management_sheet_scroll',
                                    ),
                                    children: [
                                      for (final tag in tags)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 7),
                                          child: ChoiceChip(
                                            label: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 132,
                                              ),
                                              child: Text(
                                                tag.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            selected: tag.id == _selectedTagId,
                                            onSelected: _isBusy
                                                ? null
                                                : (_) => setState(
                                                      () => _selectedTagId =
                                                          tag.id,
                                                    ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('create_personal_tag_button'),
                            onPressed: _isBusy ? null : _createTag,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('새 태그 만들기'),
                          ),
                          if (selected != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isBusy
                                        ? null
                                        : () => _renameTag(selected),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('이름 변경'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isBusy
                                        ? null
                                        : () => _deleteTag(
                                              selected,
                                              counts[selected.id] ?? 0,
                                            ),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    label: Text(
                                      '삭제 (${counts[selected.id] ?? 0}명)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_changed),
            child: const Text('닫기'),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

String _errorMessage(Object? error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'already-exists':
        return '같은 이름의 태그가 이미 있어요.';
      case 'permission-denied':
        return '현재 등급이나 소유권을 확인해 주세요.';
      case 'invalid-argument':
        return '태그 이름을 다시 확인해 주세요.';
      case 'failed-precondition':
        return '안전하게 처리할 수 없는 상태예요.';
    }
  }
  return '태그를 불러오지 못했어요. 다시 시도해 주세요.';
}
