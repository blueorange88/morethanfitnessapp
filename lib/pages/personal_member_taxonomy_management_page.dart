import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/personal_member_taxonomy.dart';
import '../services/personal_member_preferences_service.dart';
import '../services/personal_member_taxonomy_service.dart';
import '../theme/app_colors.dart';

class PersonalMemberTaxonomyManagementPage extends StatelessWidget {
  const PersonalMemberTaxonomyManagementPage({
    super.key,
    required this.ownerUid,
    required this.kind,
  });

  final String ownerUid;
  final PersonalMemberTaxonomyKind kind;

  bool get _isGroup => kind == PersonalMemberTaxonomyKind.group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    final service = PersonalMemberTaxonomyService(uid: ownerUid);
    final membersStream = FirebaseFirestore.instance
        .collection('members')
        .where('trainerId', isEqualTo: ownerUid)
        .where('workspaceType', isEqualTo: 'personal')
        .snapshots();

    return Scaffold(
      backgroundColor: tokens.memberListBackground,
      body: Column(
        children: [
          _TaxonomyBrandedHeader(
            title: _isGroup ? '그룹 관리' : '태그 관리',
            onBackTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: StreamBuilder<List<PersonalMemberTaxonomyItem>>(
              stream: service.watch(kind),
              builder: (context, taxonomySnapshot) {
                if (taxonomySnapshot.hasError) {
                  return _ErrorBody(
                    message: _taxonomyErrorMessage(taxonomySnapshot.error!),
                  );
                }
                if (!taxonomySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = [...taxonomySnapshot.data!]..sort((a, b) {
                    final createdAt = a.createdAt.compareTo(b.createdAt);
                    return createdAt != 0 ? createdAt : a.id.compareTo(b.id);
                  });

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: membersStream,
                  builder: (context, memberSnapshot) {
                    if (memberSnapshot.hasError) {
                      return _ErrorBody(
                        message: _taxonomyErrorMessage(memberSnapshot.error!),
                      );
                    }
                    final members = memberSnapshot.data?.docs
                            .where((doc) => doc.data()['isDeleted'] != true)
                            .map((doc) => doc.data())
                            .toList(growable: false) ??
                        const <Map<String, dynamic>>[];
                    final counts = personalTaxonomyUsageCounts(
                      kind: kind,
                      items: items,
                      members: members,
                    );

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        if (_isGroup)
                          StreamBuilder<PersonalMemberPreferences>(
                            stream:
                                PersonalMemberPreferencesService(uid: ownerUid)
                                    .watch(),
                            builder: (context, preferenceSnapshot) {
                              final label =
                                  preferenceSnapshot.data?.defaultGroupLabel ??
                                      kPersonalDefaultGroupLabel;
                              return _TaxonomyTile(
                                icon: Icons.home_work_outlined,
                                title: label,
                                subtitle:
                                    '기본 그룹 · ${counts.defaultGroupCount}명',
                                onRename: () => _showNameDialog(
                                  context,
                                  title: '기본 그룹 이름 변경',
                                  initialValue: label,
                                  onSave: (name) =>
                                      PersonalMemberPreferencesService(
                                    uid: ownerUid,
                                  ).saveDefaultGroupLabel(name),
                                ),
                              );
                            },
                          ),
                        if (_isGroup) const SizedBox(height: 12),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TaxonomyTile(
                              icon: _isGroup
                                  ? Icons.folder_open_rounded
                                  : Icons.sell_outlined,
                              title: item.name,
                              subtitle: '${counts.byId[item.id] ?? 0}명',
                              onRename: () => _showNameDialog(
                                context,
                                title: _isGroup ? '그룹 이름 변경' : '태그 이름 변경',
                                initialValue: item.name,
                                onSave: (name) => service.rename(
                                  kind: kind,
                                  id: item.id,
                                  name: name,
                                ),
                              ),
                              onDelete: () => _confirmDelete(
                                context,
                                service: service,
                                item: item,
                                memberCount: counts.byId[item.id] ?? 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: tokens.gradeSheetAccent,
                            foregroundColor:
                                scheme.primary == AppColors.lululalaPrimary
                                    ? scheme.onPrimary
                                    : scheme.onSecondary,
                          ),
                          onPressed: () => _showNameDialog(
                            context,
                            title: _isGroup ? '새 그룹 만들기' : '새 태그 만들기',
                            initialValue: '',
                            onSave: (name) => service.create(
                              kind: kind,
                              idempotencyKey:
                                  'taxonomy_${kind.name}_${DateTime.now().microsecondsSinceEpoch}',
                              name: name,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            _isGroup ? '새 그룹 만들기' : '새 태그 만들기',
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required PersonalMemberTaxonomyService service,
    required PersonalMemberTaxonomyItem item,
    required int memberCount,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_isGroup ? '그룹을 삭제할까요?' : '태그를 삭제할까요?'),
            content: Text(
              _isGroup
                  ? memberCount == 0
                      ? '${item.name} 그룹을 삭제합니다.'
                      : '이 그룹의 회원 $memberCount명이 기본 그룹으로 이동합니다.'
                  : memberCount == 0
                      ? '${item.name} 태그를 삭제합니다.'
                      : '회원 $memberCount명에게서 ${item.name} 태그가 제거됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_isGroup ? '삭제하고 이동' : '태그 삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await service.delete(kind: kind, id: item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name}이(가) 삭제됐어요.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_taxonomyErrorMessage(error))),
      );
    }
  }
}

class _TaxonomyBrandedHeader extends StatelessWidget {
  const _TaxonomyBrandedHeader({
    required this.title,
    required this.onBackTap,
  });

  final String title;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.lightSurface;
    final topPadding = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        key: const ValueKey('personal_taxonomy_management_header'),
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 18),
        decoration: BoxDecoration(
          gradient: context.mtfHeaderGradient,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: '뒤로',
                child: Material(
                  color: foreground.withValues(alpha: 0.14),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: foreground.withValues(alpha: 0.20),
                    ),
                  ),
                  child: InkWell(
                    onTap: onBackTap,
                    customBorder: const CircleBorder(),
                    child: const SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: foreground,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonalTaxonomyUsageCounts {
  const PersonalTaxonomyUsageCounts({
    required this.byId,
    required this.defaultGroupCount,
  });

  final Map<String, int> byId;
  final int defaultGroupCount;
}

@visibleForTesting
PersonalTaxonomyUsageCounts personalTaxonomyUsageCounts({
  required PersonalMemberTaxonomyKind kind,
  required List<PersonalMemberTaxonomyItem> items,
  required List<Map<String, dynamic>> members,
}) {
  final validIds = items.map((item) => item.id).toSet();
  final counts = <String, int>{for (final id in validIds) id: 0};
  var defaultGroupCount = 0;
  for (final member in members) {
    if (kind == PersonalMemberTaxonomyKind.group) {
      final id = (member['personalGroupId'] ?? '').toString().trim();
      if (id.isEmpty || !validIds.contains(id)) {
        defaultGroupCount += 1;
      } else {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      continue;
    }
    final ids = member['personalTagIds'] is Iterable
        ? (member['personalTagIds'] as Iterable)
            .map((value) => value.toString().trim())
            .toSet()
        : const <String>{};
    for (final id in ids.where(validIds.contains)) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return PersonalTaxonomyUsageCounts(
    byId: Map.unmodifiable(counts),
    defaultGroupCount: defaultGroupCount,
  );
}

Future<void> _showNameDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required Future<Object?> Function(String name) onSave,
}) async {
  final controller = TextEditingController(text: initialValue);
  final focusNode = FocusNode();
  var isSaving = false;
  String? errorText;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> save() async {
          final name = normalizePersonalTaxonomyDisplayName(controller.text);
          final validationError = validatePersonalTaxonomyName(name);
          if (validationError != null) {
            setDialogState(() => errorText = validationError);
            focusNode.requestFocus();
            return;
          }
          setDialogState(() {
            isSaving = true;
            errorText = null;
          });
          try {
            await onSave(name);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          } catch (error) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              isSaving = false;
              errorText = _taxonomyErrorMessage(error);
            });
            focusNode.requestFocus();
          }
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            maxLength: kPersonalTaxonomyNameMaxLength,
            enabled: !isSaving,
            decoration: InputDecoration(
              labelText: '이름',
              errorText: errorText,
            ),
            onSubmitted: (_) => isSaving ? null : save(),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: isSaving ? null : save,
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  focusNode.dispose();
}

String _taxonomyErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'already-exists':
        return '같은 이름의 그룹 또는 태그가 이미 있어요.';
      case 'permission-denied':
        return '현재 등급이나 소유권을 확인해 주세요.';
      case 'invalid-argument':
        return '이름과 선택 내용을 다시 확인해 주세요.';
      case 'failed-precondition':
        return '안전하게 처리할 수 없는 상태예요. 회원 수를 확인해 주세요.';
    }
  }
  return '처리하지 못했어요. 입력값을 유지했으니 다시 시도해 주세요.';
}

class _TaxonomyTile extends StatelessWidget {
  const _TaxonomyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRename,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Card(
      color: tokens.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.cardBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Icon(icon),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: '이름 변경',
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: '삭제',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

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
