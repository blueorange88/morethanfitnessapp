import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/registration_chip.dart';

void main() {
  final now = DateTime(2026, 10, 23);

  RegistrationChipStyle style({
    int total = 30,
    int remain = 12,
    bool notRegistered = false,
    int added = 0,
    DateTime? addedAt,
  }) => registrationChipStyle(
    total: total,
    remain: remain,
    notRegistered: notRegistered,
    added: added,
    addedAt: addedAt,
    now: now,
  );

  test('평소에는 총/잔여만 보이고 강조 색이 없다(회원카드는 길게, 홈은 짧게)', () {
    final s = style();
    expect(s.label, '총 30회 · 잔여 12회');
    expect(s.compactLabel, '총 30 / 잔여 12');
    expect(s.color, isNull);
  });

  test('재등록 직후에는 추가재등록 횟수가 붙고 30일이 지나면 사라진다', () {
    final fresh = style(
      total: 60,
      remain: 31,
      added: 30,
      addedAt: now.subtract(const Duration(days: 2)),
    );
    expect(fresh.label, '총 60회 · 잔여 31회 · 추가재등록 30회');
    expect(fresh.compactLabel, '총 60 / 잔여 31 (+30)');
    expect(fresh.color, isNull);

    final edge = style(
      total: 60,
      remain: 31,
      added: 30,
      addedAt: now.subtract(const Duration(days: 30)),
    );
    expect(edge.compactLabel, contains('(+30)'));
    final old = style(
      total: 60,
      remain: 31,
      added: 30,
      addedAt: now.subtract(const Duration(days: 31)),
    );
    expect(old.label, '총 60회 · 잔여 31회');
    expect(old.compactLabel, '총 60 / 잔여 31');
    // 정정으로 횟수가 줄었거나(음수) 기록이 없으면 붙이지 않는다.
    expect(
      style(total: 8, remain: 8, added: -2, addedAt: now).compactLabel,
      '총 8 / 잔여 8',
    );
    expect(style(total: 10, remain: 10, added: 10).label, '총 10회 · 잔여 10회');
  });

  test('잔여가 1~5회면 주황, 소진하면 빨강으로 강조한다', () {
    for (final remain in [1, 5]) {
      expect(
        style(remain: remain).color,
        const Color(0xFFEA580C),
        reason: '잔여 $remain',
      );
    }
    expect(style(remain: 6).color, isNull);
    final done = style(remain: 0);
    expect(done.label, '총 30회 · 잔여 0회 · 소진');
    expect(done.compactLabel, '총 30 / 잔여 0 · 소진');
    expect(done.color, const Color(0xFFDC2626));
  });

  test('재등록하면 잔여가 늘어 강조가 사라지고, 소진 상태에서도 추가 횟수를 보여 준다', () {
    expect(style(total: 30, remain: 1).color, const Color(0xFFEA580C));
    expect(style(total: 60, remain: 31, added: 30, addedAt: now).color, isNull);
    expect(
      style(remain: 0, added: 30, addedAt: now).label,
      '총 30회 · 잔여 0회 · 소진 · 추가재등록 30회',
    );
  });

  test('레슨 미등록이면 미등록으로 보이고 강조하지 않는다', () {
    final s = style(total: 5, remain: 0, notRegistered: true);
    expect(s.label, '미등록');
    expect(s.compactLabel, '미등록');
    expect(s.color, isNull);
  });

  group('MemberRegistrationInfo.fromMemberData', () {
    test('총·잔여를 홈 확정과 같은 순서로 읽는다', () {
      final info = MemberRegistrationInfo.fromMemberData({
        'sessions': {'total': 30, 'remain': 12, 'notRegistered': false},
      });
      expect((info.total, info.remain, info.notRegistered), (30, 12, false));
      final root = MemberRegistrationInfo.fromMemberData({
        'totalSessions': '20',
        'remainingSessions': 7,
        'sessions': {'total': 99, 'remain': 99},
      });
      expect((root.total, root.remain), (20, 7));
    });

    test('횟수가 없거나 미등록 표시면 미등록이다', () {
      expect(MemberRegistrationInfo.fromMemberData({}).notRegistered, isTrue);
      expect(
        MemberRegistrationInfo.fromMemberData({
          'totalSessions': 10,
          'remainSessions': 10,
          'lessonsNotRegistered': true,
        }).notRegistered,
        isTrue,
      );
      expect(
        MemberRegistrationInfo.fromMemberData({
          'sessions': {'total': 0, 'remain': 0, 'notRegistered': false},
        }).notRegistered,
        isTrue,
      );
    });

    test('마지막 등록(추가 횟수·시각)을 읽는다', () {
      final at = DateTime(2026, 10, 20);
      final info = MemberRegistrationInfo.fromMemberData({
        'totalSessions': 40,
        'remainSessions': 11,
        'lastRegistration': {'added': 10, 'at': at},
      });
      expect(info.added, 10);
      expect(info.addedAt, at);
      expect(MemberRegistrationInfo.fromMemberData({}).addedAt, isNull);
    });
  });
}
