import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'personal_member_status_filter.dart';
import 'personal_tag_horizontal_strip.dart';

enum PersonalTaxonomyFilterRole {
  defaultGroup,
  customGroup,
  systemGroup,
  tag,
  exampleGroup,
  exampleTag,
  all,
  statusDormant,
  statusExpired,
}

class PersonalTaxonomyFilterEntry {
  const PersonalTaxonomyFilterEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.role,
  });

  final String id;
  final String label;
  final IconData icon;
  final PersonalTaxonomyFilterRole role;

  bool get isExample =>
      role == PersonalTaxonomyFilterRole.exampleGroup ||
      role == PersonalTaxonomyFilterRole.exampleTag;

  bool get isTag =>
      role == PersonalTaxonomyFilterRole.tag ||
      role == PersonalTaxonomyFilterRole.exampleTag;

  bool get isStatus =>
      role == PersonalTaxonomyFilterRole.statusDormant ||
      role == PersonalTaxonomyFilterRole.statusExpired;
}

const String personalTaxonomyExampleGroupId = '__example_group_more_health__';
const String personalTaxonomyExampleVipTagId = '__example_tag_vip__';
const String personalTaxonomyExamplePainTagId = '__example_tag_pain__';
const String personalTaxonomyExampleDietTagId = '__example_tag_diet__';
const String personalTaxonomyDormantStatusId = '__status_dormant__';
const String personalTaxonomyExpiredStatusId = '__status_expired__';

List<PersonalTaxonomyFilterEntry> buildPersonalTaxonomyFilterEntries({
  required String defaultGroupId,
  required String defaultGroupLabel,
  required Map<String, String> customGroups,
  required Map<String, String> tags,
  required Map<String, String> visibleSystemGroups,
  required String allId,
  required int dormantCount,
  required int expiredCount,
}) {
  return <PersonalTaxonomyFilterEntry>[
    PersonalTaxonomyFilterEntry(
      id: defaultGroupId,
      label: defaultGroupLabel,
      icon: Icons.home_rounded,
      role: PersonalTaxonomyFilterRole.defaultGroup,
    ),
    if (customGroups.isEmpty)
      const PersonalTaxonomyFilterEntry(
        id: personalTaxonomyExampleGroupId,
        label: '모어헬스',
        icon: Icons.apartment_rounded,
        role: PersonalTaxonomyFilterRole.exampleGroup,
      )
    else
      ...customGroups.entries.map(
        (entry) => PersonalTaxonomyFilterEntry(
          id: entry.key,
          label: entry.value,
          icon: Icons.folder_open_rounded,
          role: PersonalTaxonomyFilterRole.customGroup,
        ),
      ),
    ...visibleSystemGroups.entries.map(
      (entry) => PersonalTaxonomyFilterEntry(
        id: entry.key,
        label: entry.value,
        icon: Icons.person_outline_rounded,
        role: PersonalTaxonomyFilterRole.systemGroup,
      ),
    ),
    if (tags.isEmpty) ...const [
      PersonalTaxonomyFilterEntry(
        id: personalTaxonomyExampleVipTagId,
        label: 'VIP',
        icon: Icons.label_outline_rounded,
        role: PersonalTaxonomyFilterRole.exampleTag,
      ),
      PersonalTaxonomyFilterEntry(
        id: personalTaxonomyExamplePainTagId,
        label: '허리통증',
        icon: Icons.label_outline_rounded,
        role: PersonalTaxonomyFilterRole.exampleTag,
      ),
      PersonalTaxonomyFilterEntry(
        id: personalTaxonomyExampleDietTagId,
        label: '다이어트',
        icon: Icons.label_outline_rounded,
        role: PersonalTaxonomyFilterRole.exampleTag,
      ),
    ] else
      ...tags.entries.map(
        (entry) => PersonalTaxonomyFilterEntry(
          id: entry.key,
          label: entry.value,
          icon: Icons.label_outline_rounded,
          role: PersonalTaxonomyFilterRole.tag,
        ),
      ),
    PersonalTaxonomyFilterEntry(
      id: allId,
      label: '전체',
      icon: Icons.dashboard_rounded,
      role: PersonalTaxonomyFilterRole.all,
    ),
    PersonalTaxonomyFilterEntry(
      id: personalTaxonomyDormantStatusId,
      label: '휴면 $dormantCount',
      icon: Icons.bedtime_outlined,
      role: PersonalTaxonomyFilterRole.statusDormant,
    ),
    PersonalTaxonomyFilterEntry(
      id: personalTaxonomyExpiredStatusId,
      label: '만료 $expiredCount',
      icon: Icons.warning_amber_rounded,
      role: PersonalTaxonomyFilterRole.statusExpired,
    ),
  ];
}

class PersonalTaxonomyFilterStrip extends StatelessWidget {
  const PersonalTaxonomyFilterStrip({
    super.key,
    required this.entries,
    required this.selectedGroupId,
    required this.selectedTagId,
    required this.selectedStatus,
    required this.onManage,
    required this.onSelected,
  });

  final List<PersonalTaxonomyFilterEntry> entries;
  final String? selectedGroupId;
  final String? selectedTagId;
  final PersonalMemberStatusFilter selectedStatus;
  final VoidCallback onManage;
  final ValueChanged<PersonalTaxonomyFilterEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    return PersonalTagHorizontalStrip(
      height: 32,
      scrollKey: const ValueKey('client_list_personal_taxonomy_scroll'),
      fixedLeading: PersonalTagManagementButton(
        onPressed: onManage,
        dimension: 32,
        semanticLabel: '분류 관리',
      ),
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: _PersonalTaxonomyFilterChip(
              key: ValueKey('personal_taxonomy_filter_${entry.id}'),
              entry: entry,
              isSelected: isPersonalTaxonomyFilterEntrySelected(
                entry: entry,
                selectedGroupId: selectedGroupId,
                selectedTagId: selectedTagId,
                selectedStatus: selectedStatus,
              ),
              onTap: () => onSelected(entry),
            ),
          ),
      ],
    );
  }
}

bool isPersonalTaxonomyFilterEntrySelected({
  required PersonalTaxonomyFilterEntry entry,
  required String? selectedGroupId,
  required String? selectedTagId,
  required PersonalMemberStatusFilter selectedStatus,
}) {
  if (entry.role == PersonalTaxonomyFilterRole.all) {
    return selectedGroupId == null &&
        selectedTagId == null &&
        selectedStatus == PersonalMemberStatusFilter.all;
  }
  if (entry.role == PersonalTaxonomyFilterRole.statusDormant) {
    return selectedStatus == PersonalMemberStatusFilter.dormant;
  }
  if (entry.role == PersonalTaxonomyFilterRole.statusExpired) {
    return selectedStatus == PersonalMemberStatusFilter.expired;
  }
  if (entry.isTag) return selectedTagId == entry.id;
  if (entry.isExample) return false;
  return selectedGroupId == entry.id;
}

class _PersonalTaxonomyFilterChip extends StatelessWidget {
  const _PersonalTaxonomyFilterChip({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final PersonalTaxonomyFilterEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    final isTag = entry.isTag;
    final isAll = entry.role == PersonalTaxonomyFilterRole.all;
    final isDormant = entry.role == PersonalTaxonomyFilterRole.statusDormant;
    final isExpired = entry.role == PersonalTaxonomyFilterRole.statusExpired;
    final background = isSelected
        ? isExpired
            ? scheme.errorContainer
            : isDormant
                ? scheme.surfaceContainerHighest
                : isAll
                    ? scheme.primaryContainer
                    : isTag
                        ? scheme.secondaryContainer
                        : Color.alphaBlend(
                            scheme.secondary.withValues(alpha: 0.18),
                            tokens.memberListCard,
                          )
        : isExpired
            ? scheme.errorContainer.withValues(alpha: 0.42)
            : isDormant
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.72)
                : isTag
                    ? scheme.secondaryContainer.withValues(alpha: 0.62)
                    : tokens.memberListCard;
    final foreground = isSelected
        ? isExpired
            ? scheme.onErrorContainer
            : isAll
                ? scheme.onPrimaryContainer
                : isDormant
                    ? scheme.onSurface
                    : scheme.onSecondaryContainer
        : isExpired
            ? scheme.onErrorContainer
            : isTag
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant;
    final border = isSelected
        ? isExpired
            ? scheme.error
            : isDormant
                ? scheme.outline
                : isAll
                    ? scheme.primary
                    : scheme.secondary
        : isExpired
            ? scheme.error.withValues(alpha: 0.42)
            : isDormant
                ? scheme.outlineVariant
                : isTag
                    ? scheme.secondary.withValues(alpha: 0.34)
                    : tokens.memberListCardBorder;
    final chip = Opacity(
      opacity: entry.isExample ? 0.58 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border, width: isSelected ? 1.4 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.icon, size: 14, color: foreground),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: entry.isExample
                          ? FontWeight.w700
                          : isSelected
                              ? FontWeight.w900
                              : FontWeight.w800,
                      color: foreground,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final semanticChip = Semantics(
      button: true,
      selected: isSelected,
      label: entry.isExample ? '${entry.label} 예시' : entry.label,
      child: chip,
    );
    if (!entry.isExample) return semanticChip;
    return Tooltip(message: '${entry.label} 예시', child: semanticChip);
  }
}
