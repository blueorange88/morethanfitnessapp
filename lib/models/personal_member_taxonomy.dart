import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const int kPersonalTaxonomyNameMaxLength = 30;
const int kPersonalMemberTagLimit = 20;

enum PersonalMemberTaxonomyKind { group, tag }

String normalizePersonalTaxonomyDisplayName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String personalTaxonomyComparisonKey(String value) {
  return normalizePersonalTaxonomyDisplayName(value).toLowerCase();
}

String? validatePersonalTaxonomyName(String value) {
  final normalized = normalizePersonalTaxonomyDisplayName(value);
  if (normalized.length < 2 ||
      normalized.length > kPersonalTaxonomyNameMaxLength) {
    return '이름은 2~$kPersonalTaxonomyNameMaxLength자로 입력해주세요.';
  }
  return null;
}

List<String> normalizePersonalTagIds(Iterable<Object?> values) {
  final ids = values
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  if (ids.length > kPersonalMemberTagLimit) {
    throw ArgumentError('personal_tag_limit_exceeded');
  }
  return List<String>.unmodifiable(ids);
}

@visibleForTesting
String? resolvePersonalMemberGroupId({
  required String? personalGroupId,
  required Set<String> availableGroupIds,
}) {
  final normalized = personalGroupId?.trim() ?? '';
  return availableGroupIds.contains(normalized) ? normalized : null;
}

@visibleForTesting
bool matchesPersonalMemberTaxonomyFilters({
  required String? personalGroupId,
  required Iterable<String> personalTagIds,
  required Set<String> availableGroupIds,
  String? selectedGroupId,
  String? selectedTagId,
}) {
  final resolvedGroupId = resolvePersonalMemberGroupId(
    personalGroupId: personalGroupId,
    availableGroupIds: availableGroupIds,
  );
  final matchesGroup = selectedGroupId == null ||
      (selectedGroupId == '__ungrouped__'
          ? resolvedGroupId == null
          : resolvedGroupId == selectedGroupId);
  final matchesTag = selectedTagId == null ||
      personalTagIds.map((id) => id.trim()).contains(selectedTagId);
  return matchesGroup && matchesTag;
}

class PersonalMemberTaxonomyItem {
  const PersonalMemberTaxonomyItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.normalizedName,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersonalMemberTaxonomyItem.fromFirestore({
    required PersonalMemberTaxonomyKind kind,
    required DocumentSnapshot<Map<String, dynamic>> document,
  }) {
    final data = document.data();
    if (!document.exists || data == null) {
      throw StateError('personal_taxonomy_not_found');
    }
    final name = normalizePersonalTaxonomyDisplayName(
      (data['name'] ?? '').toString(),
    );
    final normalizedName = (data['normalizedName'] ?? '').toString().trim();
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    if (name.isEmpty ||
        normalizedName.isEmpty ||
        data['schemaVersion'] != 1 ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw StateError('personal_taxonomy_readback_invalid');
    }
    return PersonalMemberTaxonomyItem(
      id: document.id,
      kind: kind,
      name: name,
      normalizedName: normalizedName,
      schemaVersion: 1,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }

  final String id;
  final PersonalMemberTaxonomyKind kind;
  final String name;
  final String normalizedName;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class PersonalMemberAssignmentPatch {
  const PersonalMemberAssignmentPatch({
    this.groupProvided = false,
    this.personalGroupId,
    this.tagsProvided = false,
    this.personalTagIds = const <String>[],
  });

  factory PersonalMemberAssignmentPatch.forCreate({
    String? personalGroupId,
    List<String> personalTagIds = const <String>[],
  }) {
    final normalizedTagIds = normalizePersonalTagIds(personalTagIds);
    return PersonalMemberAssignmentPatch(
      groupProvided: true,
      personalGroupId: personalGroupId,
      tagsProvided: normalizedTagIds.isNotEmpty,
      personalTagIds: normalizedTagIds,
    );
  }

  final bool groupProvided;
  final String? personalGroupId;
  final bool tagsProvided;
  final List<String> personalTagIds;

  Map<String, dynamic> toCallableMap() {
    return <String, dynamic>{
      if (groupProvided) 'personalGroupId': personalGroupId?.trim(),
      if (tagsProvided)
        'personalTagIds': normalizePersonalTagIds(personalTagIds),
    };
  }

  bool matchesMember(Map<String, dynamic> member) {
    if (groupProvided) {
      final actualGroupId = (member['personalGroupId'] ?? '').toString().trim();
      final expectedGroupId = personalGroupId?.trim() ?? '';
      if (actualGroupId != expectedGroupId) return false;
    }
    if (tagsProvided) {
      final actualTagIds = normalizePersonalTagIds(
        member['personalTagIds'] is Iterable
            ? member['personalTagIds'] as Iterable
            : const <Object?>[],
      );
      final expectedTagIds = normalizePersonalTagIds(personalTagIds);
      if (actualTagIds.length != expectedTagIds.length) return false;
      for (var index = 0; index < expectedTagIds.length; index += 1) {
        if (actualTagIds[index] != expectedTagIds[index]) return false;
      }
    }
    return true;
  }
}
