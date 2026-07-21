import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/membership_pause_status_utils.dart';

void main() {
  group('회원권 정지 상태 라벨', () {
    test('정지 중이며 예정 재개일이 있으면 두 라벨을 표시한다', () {
      expect(
        membershipPauseElapsedLabel(
          isPaused: true,
          pausedAt: DateTime(2026, 7, 10),
          now: DateTime(2026, 7, 12),
        ),
        '정지 2일째',
      );
      expect(
        membershipResumeDueLabel(
          isPaused: true,
          resumeDueAt: DateTime(2026, 7, 25),
        ),
        '재개 예정 07.25',
      );
    });

    test('예정 재개일이 없는 정지 회원은 재개 예정 라벨을 표시하지 않는다', () {
      expect(
        membershipResumeDueLabel(isPaused: true, resumeDueAt: null),
        isNull,
      );
    });

    test('회원권 정지 데이터가 없는 휴면회원에게 날짜를 만들지 않는다', () {
      expect(
        membershipPauseElapsedLabel(isPaused: false, pausedAt: null),
        isNull,
      );
      expect(
        membershipResumeDueLabel(isPaused: false, resumeDueAt: null),
        isNull,
      );
    });

    test('회원권 재개 후에는 기존 날짜가 남아도 라벨을 표시하지 않는다', () {
      expect(
        membershipPauseElapsedLabel(
          isPaused: false,
          pausedAt: DateTime(2026, 7, 10),
        ),
        isNull,
      );
      expect(
        membershipResumeDueLabel(
          isPaused: false,
          resumeDueAt: DateTime(2026, 7, 25),
        ),
        isNull,
      );
    });
  });
}
