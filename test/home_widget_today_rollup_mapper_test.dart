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

  test('진행 중 레슨을 첫 번째로 두고 종료된 레슨은 제외한다', () {
    final ongoing = HomeWidgetTodayRollupItem(
      startAt: DateTime(2026, 7, 21, 9, 30),
      endAt: DateTime(2026, 7, 21, 10, 30),
      memberName: '진행 중',
      lessonType: 'PT',
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
    expect(saved['memberName'], '아주 긴 회원 표시 이름 테스트');
    expect(saved['lessonType'], '아주 긴 레슨 종류 테스트');
    expect(saved.keys, isNot(contains('memo')));
    expect(saved.keys, isNot(contains('phone')));
  });
}
