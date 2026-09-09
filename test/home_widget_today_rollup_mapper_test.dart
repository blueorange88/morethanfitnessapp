import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_widget_today_rollup_mapper.dart';

void main() {
  final now = DateTime(2026, 7, 21, 10);

  HomeWidgetTodayRollupItem item(
    int hour, {
    int durationMinutes = 50,
    String name = '회원',
    String type = 'PT',
    String status = 'scheduled',
    int? remaining,
  }) {
    final start = DateTime(2026, 7, 21, hour);
    return HomeWidgetTodayRollupItem(
      startAt: start,
      endAt: start.add(Duration(minutes: durationMinutes)),
      memberName: name,
      lessonType: type,
      ownerUid: 'uid-a',
      workspaceType: 'personal',
      status: status,
      remainingSessions: remaining,
    );
  }

  HomeWidgetTodayRollupView view(List<HomeWidgetTodayRollupItem> items) {
    return HomeWidgetTodayRollupMapper.buildView(
      snapshot: HomeWidgetTodayRollupSnapshot(
        ownerUid: 'uid-a',
        generatedAt: now,
        items: items,
      ),
      currentOwnerUid: 'uid-a',
      now: now,
    );
  }

  for (final count in [0, 1, 2, 3, 6]) {
    test('$count개 일정은 다음·다다음·세 번째 이후로 중복 없이 분리된다', () {
      final result = view([
        for (var index = 0; index < count; index++) item(11 + index),
      ]);
      expect(result.totalCount, count);
      expect(result.next, count >= 1 ? isNotNull : isNull);
      expect(result.second, count >= 2 ? isNotNull : isNull);
      expect(result.remaining, hasLength(count > 2 ? count - 2 : 0));
      final all = [
        if (result.next != null) result.next!,
        if (result.second != null) result.second!,
        ...result.remaining,
      ];
      expect(all.toSet(), hasLength(count));
    });
  }

  test('0~8개 일정의 실제 표시 수와 숨은 개수를 계산한다', () {
    for (var count = 0; count <= 8; count++) {
      final layout = HomeWidgetTodayRollupMapper.buildLayout(
        upcomingCount: count,
        remainingCapacity: 3,
      );
      final expectedTop = count > 2 ? 2 : count;
      final expectedRemaining = count - expectedTop;
      final expectedVisible = expectedRemaining > 3 ? 3 : expectedRemaining;
      expect(layout.upcomingCount, count, reason: 'count=$count');
      expect(layout.topCardCount, expectedTop, reason: 'count=$count');
      expect(layout.remainingSourceCount, expectedRemaining,
          reason: 'count=$count');
      expect(layout.visibleRemainingCount, expectedVisible,
          reason: 'count=$count');
      expect(layout.hiddenCount, expectedRemaining - expectedVisible,
          reason: 'count=$count');
    }
  });

  test('6개 일정과 하단 3행 높이는 외 1개를 예약한다', () {
    final layout = HomeWidgetTodayRollupMapper.buildLayout(
      upcomingCount: 6,
      remainingCapacity: 3,
    );
    expect(layout.topCardCount, 2);
    expect(layout.visibleRemainingCount, 3);
    expect(layout.hiddenCount, 1);
  });

  test('진행 중 레슨을 첫 번째로 두고 종료된 레슨은 제외한다', () {
    final ongoing = HomeWidgetTodayRollupItem(
      startAt: DateTime(2026, 7, 21, 9, 30),
      endAt: DateTime(2026, 7, 21, 10, 30),
      memberName: '진행 중',
      lessonType: 'PT',
      ownerUid: 'uid-a',
      workspaceType: 'personal',
    );
    final result = view([item(8), item(11), ongoing]);
    expect(result.totalCount, 2);
    expect(result.next?.memberName, '진행 중');
    expect(result.next?.isOngoingAt(now), isTrue);
  });

  test('삭제 계열 상태를 제외하고 미등록 이름과 선택 잔여 횟수를 보존한다', () {
    final result = view([
      item(11, name: '', type: '요가', remaining: 3),
      for (final status in ['deleted', 'archived', 'voided', 'tombstone'])
        item(12, status: status),
    ]);
    expect(result.totalCount, 1);
    expect(result.next?.memberName, isEmpty);
    expect(result.next?.remainingSessions, 3);
  });

  test('다른 UID, non-personal, 어제 생성 payload는 stale로 차단한다', () {
    HomeWidgetTodayRollupView build({
      String owner = 'uid-a',
      String workspace = 'personal',
      DateTime? generatedAt,
    }) =>
        HomeWidgetTodayRollupMapper.buildView(
          snapshot: HomeWidgetTodayRollupSnapshot(
            ownerUid: owner,
            workspaceType: workspace,
            generatedAt: generatedAt ?? now,
            items: [item(11)],
          ),
          currentOwnerUid: 'uid-a',
          now: now,
        );
    expect(build(owner: 'uid-b').totalCount, 0);
    expect(build(workspace: 'legacy').totalCount, 0);
    expect(build(generatedAt: now.subtract(const Duration(days: 1))).totalCount,
        0);
  });

  test('직렬화는 개인정보 제한 필드만 저장하고 긴 표시값을 손상하지 않는다', () {
    final encoded = HomeWidgetTodayRollupMapper.encode(
      HomeWidgetTodayRollupSnapshot(
        ownerUid: 'uid-a',
        generatedAt: now,
        items: [
          item(
            11,
            name: '아주 긴 회원 표시 이름 테스트',
            type: '아주 긴 레슨 종류 테스트',
          ),
        ],
      ),
    );
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    final saved = (json['items'] as List).single as Map<String, dynamic>;
    expect(json['schemaVersion'], 2);
    expect(json['timezone'], 'Asia/Seoul');
    expect(json['localDate'], '2026-07-21');
    expect(json['payloadRevision'], now.millisecondsSinceEpoch);
    expect(saved['displayName'], '아주 긴 회원 표시 이름 테스트');
    expect(saved['startAtEpochMs'], isA<int>());
    expect(saved['endAtEpochMs'], isA<int>());
    expect(saved['lessonType'], '아주 긴 레슨 종류 테스트');
    expect(saved.keys, isNot(contains('memo')));
    expect(saved.keys, isNot(contains('phone')));
  });

  test('180건 원본에서 현재 UID의 오늘 personal 정상 일정만 payload에 남긴다', () {
    HomeWidgetTodayRollupItem source(
      int index, {
      String owner = 'uid-a',
      String workspace = 'personal',
      String status = 'scheduled',
      int dayOffset = 0,
    }) {
      final start =
          DateTime(2026, 7, 21 + dayOffset, 11).add(Duration(minutes: index));
      return HomeWidgetTodayRollupItem(
        startAt: start,
        endAt: start.add(const Duration(minutes: 50)),
        memberName: index.isEven ? '' : '회원',
        lessonType: 'PT',
        ownerUid: owner,
        workspaceType: workspace,
        status: status,
      );
    }

    final sourceItems = <HomeWidgetTodayRollupItem>[
      for (var index = 0; index < 10; index++) source(index),
      for (var index = 10; index < 180; index++)
        source(
          index,
          owner: index % 3 == 0 ? 'uid-b' : 'uid-a',
          workspace: index % 3 == 1 ? 'legacy' : 'personal',
          status: index % 3 == 2 ? 'pending_delete' : 'scheduled',
          dayOffset: 1,
        ),
    ];
    final selected = HomeWidgetTodayRollupMapper.selectTodayPayload(
      sourceItems: sourceItems,
      currentOwnerUid: 'uid-a',
      generatedAt: now,
    );
    expect(selected.todayCandidateCount, 10);
    expect(selected.items, hasLength(10));
    expect(
        selected.items.where((entry) => entry.memberName.isEmpty), isNotEmpty);
  });

  test('한국 날짜 경계는 기기 timezone 대신 Asia/Seoul 기준을 사용한다', () {
    final generatedAt = DateTime.utc(2026, 7, 20, 15, 5);
    final start = DateTime.utc(2026, 7, 20, 16);
    final selected = HomeWidgetTodayRollupMapper.selectTodayPayload(
      sourceItems: [
        HomeWidgetTodayRollupItem(
          startAt: start,
          endAt: start.add(const Duration(minutes: 50)),
          memberName: '회원',
          lessonType: 'PT',
          ownerUid: 'uid-a',
          workspaceType: 'personal',
        ),
      ],
      currentOwnerUid: 'uid-a',
      generatedAt: generatedAt,
    );
    expect(HomeWidgetTodayRollupMapper.seoulDateKey(generatedAt), '2026-07-21');
    expect(selected.items, hasLength(1));
  });

  test('10개 일정은 상단 2개, 하단 4개, 외 4개로 계산한다', () {
    final layout = HomeWidgetTodayRollupMapper.buildLayout(
      upcomingCount: 10,
      remainingCapacity: 4,
    );
    expect(layout.topCardCount, 2);
    expect(layout.visibleRemainingCount, 4);
    expect(layout.hiddenCount, 4);
  });
}
