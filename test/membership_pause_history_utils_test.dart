import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/membership_pause_history_utils.dart';
import 'package:mtf_app/utils/membership_pause_status_utils.dart';

Timestamp _ts(int y, int m, int d) => Timestamp.fromDate(DateTime(y, m, d, 9));

void main() {
  group('정지/재개 이력 줄', () {
    test('정지와 재개를 짝지어 기간·일수·재개 방식을 보여준다', () {
      final lines = membershipPauseHistoryLines([
        {
          'type': 'pause',
          'at': _ts(2026, 10, 13),
          'plannedDays': 7,
          'resumeDueAt': _ts(2026, 10, 20),
        },
        {
          'type': 'resume',
          'at': _ts(2026, 10, 20),
          'actualDays': 7,
          'plannedDays': 7,
          'extendedEndAt': _ts(2027, 1, 7),
          'source': 'auto_resume',
        },
      ]);
      expect(lines, [
        '2026.10.13 ~ 2026.10.20 · 7일 정지 · 자동 재개 · 종료일 2027.01.07로 연장',
      ]);
    });

    test('직접 재개는 직접 재개로, 최신 이력이 위에 온다', () {
      final lines = membershipPauseHistoryLines([
        {'type': 'pause', 'at': _ts(2026, 8, 1), 'plannedDays': 5},
        {
          'type': 'resume',
          'at': _ts(2026, 8, 4),
          'actualDays': 3,
          'source': 'client_card',
        },
        {
          'type': 'pause',
          'at': _ts(2026, 10, 13),
          'plannedDays': 7,
          'resumeDueAt': _ts(2026, 10, 20),
        },
      ]);
      expect(lines, [
        '2026.10.13 ~ 정지 중 · 7일 예정 · 10.20 재개 예정',
        '2026.08.01 ~ 2026.08.04 · 3일 정지 · 직접 재개',
      ]);
    });

    test('정지 기록 없이 재개만 있으면 재개일과 실제 일수만 보여준다', () {
      final lines = membershipPauseHistoryLines([
        {'type': 'resume', 'at': _ts(2026, 9, 5), 'actualDays': 4},
      ]);
      expect(lines, ['2026.09.05 재개 · 실제 4일 정지']);
    });

    test('빈 이력·날짜 없는 항목·개수 제한', () {
      expect(membershipPauseHistoryLines(const []), isEmpty);
      expect(
        membershipPauseHistoryLines([
          {'type': 'pause'},
        ]),
        isEmpty,
      );
      final many = [
        for (var i = 0; i < 15; i++) ...[
          {'type': 'pause', 'at': _ts(2026, 1, 1 + i * 2), 'plannedDays': 1},
          {'type': 'resume', 'at': _ts(2026, 1, 2 + i * 2), 'actualDays': 1},
        ],
      ];
      expect(membershipPauseHistoryLines(many).length, 10);
      expect(membershipPauseHistoryLines(many, limit: 3).length, 3);
    });
  });

  group('재개 N일 전 알림', () {
    final due = DateTime(2026, 10, 20);

    test('재개 5일 전부터 날짜와 함께 알린다', () {
      expect(
        membershipResumeCountdownText(
          isPaused: true,
          resumeDueAt: due,
          now: DateTime(2026, 10, 14, 10),
        ),
        isNull,
      );
      expect(
        membershipResumeCountdownText(
          isPaused: true,
          resumeDueAt: due,
          now: DateTime(2026, 10, 15, 10),
        ),
        '재개 5일 전 · 10.20에 자동으로 재개돼요',
      );
      expect(
        membershipResumeCountdownText(
          isPaused: true,
          resumeDueAt: due,
          now: DateTime(2026, 10, 17),
        ),
        '재개 3일 전 · 10.20에 자동으로 재개돼요',
      );
      expect(
        membershipResumeCountdownText(
          isPaused: true,
          resumeDueAt: due,
          now: DateTime(2026, 10, 19, 23, 59),
        ),
        '재개 1일 전 · 10.20에 자동으로 재개돼요',
      );
    });

    test('당일·지난 뒤·정지 중이 아니면 알리지 않는다', () {
      for (final now in [DateTime(2026, 10, 20, 8), DateTime(2026, 10, 25)]) {
        expect(
          membershipResumeCountdownText(
            isPaused: true,
            resumeDueAt: due,
            now: now,
          ),
          isNull,
        );
      }
      expect(
        membershipResumeCountdownText(
          isPaused: false,
          resumeDueAt: due,
          now: DateTime(2026, 10, 17),
        ),
        isNull,
      );
      expect(
        membershipResumeCountdownText(
          isPaused: true,
          resumeDueAt: null,
          now: DateTime(2026, 10, 17),
        ),
        isNull,
      );
    });
  });
}
