import 'dart:convert';

const Set<String> _excludedTodayRollupStatuses = {
  'deleted',
  'archived',
  'voided',
  'tombstone',
};

class HomeWidgetTodayRollupItem {
  const HomeWidgetTodayRollupItem({
    required this.startAt,
    required this.endAt,
    required this.memberName,
    required this.lessonType,
    this.remainingSessions,
    this.status = 'scheduled',
  });

  final DateTime startAt;
  final DateTime endAt;
  final String memberName;
  final String lessonType;
  final int? remainingSessions;
  final String status;

  bool isOngoingAt(DateTime now) => !startAt.isAfter(now) && endAt.isAfter(now);

  Map<String, Object?> toJson() => {
        'startAtMillis': startAt.millisecondsSinceEpoch,
        'endAtMillis': endAt.millisecondsSinceEpoch,
        'memberName': memberName.trim(),
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
  });

  final String ownerUid;
  final String workspaceType;
  final DateTime generatedAt;
  final List<HomeWidgetTodayRollupItem> items;
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

class HomeWidgetTodayRollupMapper {
  const HomeWidgetTodayRollupMapper._();

  static String encode(HomeWidgetTodayRollupSnapshot snapshot) {
    final sorted = List<HomeWidgetTodayRollupItem>.of(snapshot.items)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return jsonEncode({
      'ownerUid': snapshot.ownerUid.trim(),
      'workspaceType': snapshot.workspaceType.trim(),
      'generatedDate': _dateKey(snapshot.generatedAt),
      'generatedAtMillis': snapshot.generatedAt.millisecondsSinceEpoch,
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
        _dateKey(snapshot.generatedAt) != _dateKey(now)) {
      return const HomeWidgetTodayRollupView(
        next: null,
        second: null,
        remaining: [],
        totalCount: 0,
      );
    }

    final visible = snapshot.items.where((item) {
      final status = item.status.trim().toLowerCase();
      return _dateKey(item.startAt) == _dateKey(now) &&
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

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
