import 'dart:convert';

const Set<String> _excludedTodayRollupStatuses = {
  'deleted',
  'archived',
  'voided',
  'tombstone',
  'pending-delete',
  'pendingdelete',
  'rollback',
  'failed',
  'temp',
  'example',
};

const int kHomeWidgetTodayRollupSchemaVersion = 2;
const String kHomeWidgetTodayRollupTimezone = 'Asia/Seoul';

class HomeWidgetTodayRollupItem {
  const HomeWidgetTodayRollupItem({
    required this.startAt,
    required this.endAt,
    required this.memberName,
    required this.lessonType,
    required this.ownerUid,
    required this.workspaceType,
    this.remainingSessions,
    this.status = 'scheduled',
  });

  final DateTime startAt;
  final DateTime endAt;
  final String memberName;
  final String lessonType;
  final String ownerUid;
  final String workspaceType;
  final int? remainingSessions;
  final String status;

  bool isOngoingAt(DateTime now) => !startAt.isAfter(now) && endAt.isAfter(now);

  Map<String, Object?> toJson() => {
        'startAtEpochMs': startAt.millisecondsSinceEpoch,
        'endAtEpochMs': endAt.millisecondsSinceEpoch,
        'displayName': memberName.trim(),
        'lessonType': lessonType.trim(),
        if (remainingSessions != null) 'remainingSessions': remainingSessions,
        'status': status.trim().toLowerCase(),
      };
}

class HomeWidgetTodayRollupSnapshot {
  const HomeWidgetTodayRollupSnapshot({
    required this.ownerUid,
    required this.generatedAt,
    required this.items,
    this.workspaceType = 'personal',
    this.environment = '',
    this.projectId = '',
    this.payloadRevision,
  });

  final String ownerUid;
  final String workspaceType;
  final String environment;
  final String projectId;
  final DateTime generatedAt;
  final List<HomeWidgetTodayRollupItem> items;
  final int? payloadRevision;

  int get effectivePayloadRevision =>
      payloadRevision ?? generatedAt.millisecondsSinceEpoch;
}

class HomeWidgetTodayRollupSelection {
  const HomeWidgetTodayRollupSelection({
    required this.items,
    required this.todayCandidateCount,
  });

  final List<HomeWidgetTodayRollupItem> items;
  final int todayCandidateCount;
}

class HomeWidgetTodayRollupView {
  const HomeWidgetTodayRollupView({
    required this.next,
    required this.second,
    required this.remaining,
    required this.totalCount,
  });

  final HomeWidgetTodayRollupItem? next;
  final HomeWidgetTodayRollupItem? second;
  final List<HomeWidgetTodayRollupItem> remaining;
  final int totalCount;
}

class HomeWidgetTodayRollupLayout {
  const HomeWidgetTodayRollupLayout({
    required this.upcomingCount,
    required this.topCardCount,
    required this.remainingSourceCount,
    required this.visibleRemainingCount,
    required this.hiddenCount,
  });

  final int upcomingCount;
  final int topCardCount;
  final int remainingSourceCount;
  final int visibleRemainingCount;
  final int hiddenCount;
}

class HomeWidgetTodayRollupMapper {
  const HomeWidgetTodayRollupMapper._();

  static HomeWidgetTodayRollupSelection selectTodayPayload({
    required List<HomeWidgetTodayRollupItem> sourceItems,
    required String currentOwnerUid,
    required DateTime generatedAt,
  }) {
    final cleanOwnerUid = currentOwnerUid.trim();
    final today = seoulDateKey(generatedAt);
    final todayCandidates = sourceItems.where((item) {
      return cleanOwnerUid.isNotEmpty &&
          item.ownerUid.trim() == cleanOwnerUid &&
          item.workspaceType.trim() == 'personal' &&
          seoulDateKey(item.startAt) == today;
    }).toList(growable: false);
    final selected = todayCandidates.where((item) {
      return item.endAt.isAfter(item.startAt) &&
          !_excludedTodayRollupStatuses.contains(
            _normalizedStatus(item.status),
          );
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return HomeWidgetTodayRollupSelection(
      items: List.unmodifiable(selected),
      todayCandidateCount: todayCandidates.length,
    );
  }

  static HomeWidgetTodayRollupLayout buildLayout({
    required int upcomingCount,
    required int remainingCapacity,
  }) {
    final safeUpcomingCount = upcomingCount < 0 ? 0 : upcomingCount;
    final safeRemainingCapacity = remainingCapacity < 0 ? 0 : remainingCapacity;
    final topCardCount = safeUpcomingCount > 2 ? 2 : safeUpcomingCount;
    final remainingSourceCount = safeUpcomingCount - topCardCount;
    final visibleRemainingCount = remainingSourceCount > safeRemainingCapacity
        ? safeRemainingCapacity
        : remainingSourceCount;
    return HomeWidgetTodayRollupLayout(
      upcomingCount: safeUpcomingCount,
      topCardCount: topCardCount,
      remainingSourceCount: remainingSourceCount,
      visibleRemainingCount: visibleRemainingCount,
      hiddenCount: remainingSourceCount - visibleRemainingCount,
    );
  }

  static String encode(HomeWidgetTodayRollupSnapshot snapshot) {
    final sorted = List<HomeWidgetTodayRollupItem>.of(snapshot.items)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return jsonEncode({
      'schemaVersion': kHomeWidgetTodayRollupSchemaVersion,
      'ownerUid': snapshot.ownerUid.trim(),
      'workspaceType': snapshot.workspaceType.trim(),
      'environment': snapshot.environment.trim(),
      'projectId': snapshot.projectId.trim(),
      'timezone': kHomeWidgetTodayRollupTimezone,
      'localDate': seoulDateKey(snapshot.generatedAt),
      'generatedAtEpochMs': snapshot.generatedAt.millisecondsSinceEpoch,
      'payloadRevision': snapshot.effectivePayloadRevision,
      'items': sorted.map((item) => item.toJson()).toList(),
    });
  }

  static HomeWidgetTodayRollupView buildView({
    required HomeWidgetTodayRollupSnapshot snapshot,
    required String currentOwnerUid,
    required DateTime now,
  }) {
    if (snapshot.ownerUid.trim().isEmpty ||
        snapshot.ownerUid.trim() != currentOwnerUid.trim() ||
        snapshot.workspaceType != 'personal' ||
        seoulDateKey(snapshot.generatedAt) != seoulDateKey(now)) {
      return const HomeWidgetTodayRollupView(
        next: null,
        second: null,
        remaining: [],
        totalCount: 0,
      );
    }

    final visible = snapshot.items.where((item) {
      final status = _normalizedStatus(item.status);
      return seoulDateKey(item.startAt) == seoulDateKey(now) &&
          item.endAt.isAfter(now) &&
          item.endAt.isAfter(item.startAt) &&
          !_excludedTodayRollupStatuses.contains(status);
    }).toList()
      ..sort((a, b) {
        final aOngoing = a.isOngoingAt(now);
        final bOngoing = b.isOngoingAt(now);
        if (aOngoing != bOngoing) return aOngoing ? -1 : 1;
        return a.startAt.compareTo(b.startAt);
      });

    return HomeWidgetTodayRollupView(
      next: visible.isEmpty ? null : visible.first,
      second: visible.length < 2 ? null : visible[1],
      remaining:
          visible.length < 3 ? const [] : List.unmodifiable(visible.skip(2)),
      totalCount: visible.length,
    );
  }

  static String seoulDateKey(DateTime value) {
    final seoul = value.toUtc().add(const Duration(hours: 9));
    return '${seoul.year.toString().padLeft(4, '0')}-'
        '${seoul.month.toString().padLeft(2, '0')}-'
        '${seoul.day.toString().padLeft(2, '0')}';
  }

  static String _normalizedStatus(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
}
