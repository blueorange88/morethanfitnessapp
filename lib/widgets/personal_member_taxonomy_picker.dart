import 'package:flutter/material.dart';

import '../models/personal_member_taxonomy.dart';

class PersonalGroupPickerResult {
  const PersonalGroupPickerResult(this.personalGroupId);

  final String? personalGroupId;
}

Future<PersonalGroupPickerResult?> showPersonalGroupPicker({
  required BuildContext context,
  required String defaultGroupLabel,
  required List<PersonalMemberTaxonomyItem> groups,
  required String? selectedGroupId,
}) {
  return showModalBottomSheet<PersonalGroupPickerResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text('그룹 선택', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              title: Text(defaultGroupLabel),
              leading: const Icon(Icons.home_work_outlined),
              trailing: selectedGroupId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(
                context,
                const PersonalGroupPickerResult(null),
              ),
            ),
            ...groups.map(
              (group) => ListTile(
                title: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                leading: const Icon(Icons.folder_open_rounded),
                trailing: selectedGroupId == group.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(
                  context,
                  PersonalGroupPickerResult(group.id),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<List<String>?> showPersonalTagPicker({
  required BuildContext context,
  required List<PersonalMemberTaxonomyItem> tags,
  required Iterable<String> selectedTagIds,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PersonalTagPicker(
      tags: tags,
      selectedTagIds: selectedTagIds,
    ),
  );
}

class _PersonalTagPicker extends StatefulWidget {
  const _PersonalTagPicker({
    required this.tags,
    required this.selectedTagIds,
  });

  final List<PersonalMemberTaxonomyItem> tags;
  final Iterable<String> selectedTagIds;

  @override
  State<_PersonalTagPicker> createState() => _PersonalTagPickerState();
}

class _PersonalTagPickerState extends State<_PersonalTagPicker> {
  late final Set<String> _selected = widget.selectedTagIds.toSet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('태그 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${_selected.length}/$kPersonalMemberTagLimit',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Flexible(
                child: widget.tags.isEmpty
                    ? const Center(child: Text('등록된 태그가 없어요.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.tags.length,
                        itemBuilder: (context, index) {
                          final tag = widget.tags[index];
                          final checked = _selected.contains(tag.id);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(
                              tag.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (value) {
                              if (value == true &&
                                  _selected.length >= kPersonalMemberTagLimit) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('태그는 최대 20개까지 선택할 수 있어요.'),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                value == true
                                    ? _selected.add(tag.id)
                                    : _selected.remove(tag.id);
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        normalizePersonalTagIds(_selected),
                      ),
                      child: const Text('적용'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
