import 'dart:math' as math;

class HomeHeaderGreetingCopy {
  const HomeHeaderGreetingCopy({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class HomeHeaderGreetingCopyBuilder {
  const HomeHeaderGreetingCopyBuilder._();

  static HomeHeaderGreetingCopy build({
    required String trainerName,
    required int todayLessonCount,
    required int variantSeed,
    DateTime? now,
    DateTime? firstLessonAt,
    DateTime? lastLessonAt,
    bool weatherEnabled = false,
    String? weatherLine,
    int? scheduleStartHour,
    int? scheduleEndHour,
  }) {
    final current = now ?? DateTime.now();
    final name = _trainerName(trainerName);
    final variant = _variant(
      seed: variantSeed,
      now: current,
      todayLessonCount: todayLessonCount,
    );

    final isNightPattern = _isNightWorkPattern(
      firstLessonAt: firstLessonAt,
      lastLessonAt: lastLessonAt,
      scheduleStartHour: scheduleStartHour,
      scheduleEndHour: scheduleEndHour,
    );

    final base = _buildBaseCopy(
      name: name,
      now: current,
      todayLessonCount: todayLessonCount,
      variant: variant,
      isNightPattern: isNightPattern,
    );

    final weather = weatherEnabled ? weatherLine?.trim() ?? '' : '';

    if (weather.isEmpty) {
      return base;
    }

    return HomeHeaderGreetingCopy(
      title: base.title,
      subtitle: '${base.subtitle} $weather',
    );
  }

  static String _trainerName(String rawName) {
    final clean = rawName.trim();

    if (clean.isEmpty) {
      return '강사님';
    }

    if (clean.endsWith('님')) {
      return clean;
    }

    return '$clean님';
  }

  static int _variant({
    required int seed,
    required DateTime now,
    required int todayLessonCount,
  }) {
    // 3가지 문구 중 하나.
    // 완전 랜덤이 아니라 홈 진입 seed + 시간대 + 레슨 수로 안정적으로 선택.
    final value = seed + now.day + now.hour + todayLessonCount;
    return value.abs() % 3;
  }

  static bool _isNightWorkPattern({
    DateTime? firstLessonAt,
    DateTime? lastLessonAt,
    int? scheduleStartHour,
    int? scheduleEndHour,
  }) {
    final firstHour = firstLessonAt?.hour;
    final lastHour = lastLessonAt?.hour;

    if (firstHour != null && firstHour < 5) {
      return true;
    }

    if (lastHour != null && lastHour >= 22) {
      return true;
    }

    if (scheduleStartHour != null && scheduleEndHour != null) {
      if (scheduleStartHour >= 16 && scheduleEndHour >= 22) {
        return true;
      }

      if (scheduleStartHour <= 3 || scheduleEndHour <= 5) {
        return true;
      }
    }

    return false;
  }

  static HomeHeaderGreetingCopy _buildBaseCopy({
    required String name,
    required DateTime now,
    required int todayLessonCount,
    required int variant,
    required bool isNightPattern,
  }) {
    final hour = now.hour;

    if (isNightPattern && (hour >= 21 || hour < 5)) {
      return _nightWorkCopy(name: name, count: todayLessonCount, variant: variant);
    }

    if (hour >= 5 && hour < 11) {
      return _morningCopy(name: name, count: todayLessonCount, variant: variant);
    }

    if (hour >= 11 && hour < 14) {
      return _lunchCopy(name: name, count: todayLessonCount, variant: variant);
    }

    if (hour >= 14 && hour < 17) {
      return _afternoonCopy(name: name, count: todayLessonCount, variant: variant);
    }

    if (hour >= 17 && hour < 21) {
      return _eveningCopy(name: name, count: todayLessonCount, variant: variant);
    }

    return _nightCopy(name: name, count: todayLessonCount, variant: variant);
  }

  static HomeHeaderGreetingCopy _morningCopy({
    required String name,
    required int count,
    required int variant,
  }) {
    if (count >= 6) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '오늘 정말 바쁜 하루죠, $name',
            subtitle: '레슨 사이사이 놓치기 쉬운 관리도 같이 챙겨볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '힘차게 시작해볼까요, $name',
            subtitle: '오늘 레슨이 많은 만큼 흐름을 한눈에 정리해둘게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '바쁜 하루가 시작됐어요, $name',
            subtitle: '오늘은 일정 사이 빈틈 관리가 중요해 보여요.',
          ),
        ],
      );
    }

    if (count >= 3) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '좋은 아침이에요, $name',
            subtitle: '오늘 레슨 흐름을 보면서 차분히 시작해볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '오늘도 힘차게 가볼까요, $name',
            subtitle: '중간중간 필요한 회원 관리도 같이 챙겨볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '하루를 열어볼 시간이에요, $name',
            subtitle: '오늘 일정은 무리 없이 이어갈 수 있게 정리해둘게요.',
          ),
        ],
      );
    }

    if (count >= 1) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '좋은 아침이에요, $name',
            subtitle: '오늘은 천천히 일정부터 확인해볼까요.',
          ),
          HomeHeaderGreetingCopy(
            title: '가볍게 시작해볼까요, $name',
            subtitle: '오늘 레슨 흐름은 여유 있게 챙겨도 좋아 보여요.',
          ),
          HomeHeaderGreetingCopy(
            title: '오늘은 천천히 가볼까요, $name',
            subtitle: '급하지 않게 첫 일정부터 같이 확인해볼게요.',
          ),
        ],
      );
    }

    return _pick(
      variant,
      [
        HomeHeaderGreetingCopy(
          title: '좋은 아침이에요, $name',
          subtitle: '오늘은 급하지 않으니 MORE 센스도 한 번 둘러보세요.',
        ),
        HomeHeaderGreetingCopy(
          title: '여유 있는 하루로 시작해볼까요, $name',
          subtitle: '비어 있는 시간에는 회원 정리도 가볍게 해볼 수 있어요.',
        ),
        HomeHeaderGreetingCopy(
          title: '오늘은 조금 숨 고를 수 있겠어요, $name',
          subtitle: '레슨이 없는 날도 관리 흐름은 제가 곁에서 정리해둘게요.',
        ),
      ],
    );
  }

  static HomeHeaderGreetingCopy _lunchCopy({
    required String name,
    required int count,
    required int variant,
  }) {
    if (count >= 6) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '점심은 챙기셨나요, $name',
            subtitle: '오늘은 바쁜 흐름이라 잠깐 쉬는 타이밍도 중요해요.',
          ),
          HomeHeaderGreetingCopy(
            title: '바쁜 하루 중간이에요, $name',
            subtitle: '남은 레슨도 흐름이 끊기지 않게 같이 볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '잠깐 숨 고를 시간이네요, $name',
            subtitle: '오늘은 레슨 사이 관리 포인트를 놓치지 않는 게 좋아요.',
          ),
        ],
      );
    }

    if (count >= 1) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '점심은 챙기셨나요, $name',
            subtitle: '남은 일정도 차분히 이어가볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '오후 준비해볼까요, $name',
            subtitle: '오늘 레슨 흐름을 다시 한 번 확인해둘게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '잠깐 숨 고르기 좋은 시간이네요, $name',
            subtitle: '이제 남은 일정만 차분히 이어가면 돼요.',
          ),
        ],
      );
    }

    return _pick(
      variant,
      [
        HomeHeaderGreetingCopy(
          title: '점심은 챙기셨나요, $name',
          subtitle: '오늘은 여유가 있으니 필요한 정보만 가볍게 정리해보세요.',
        ),
        HomeHeaderGreetingCopy(
          title: '잠깐 쉬어가기 좋은 시간이네요, $name',
          subtitle: '급한 일정이 없다면 MORE 센스도 천천히 둘러보세요.',
        ),
        HomeHeaderGreetingCopy(
          title: '오후를 준비해볼까요, $name',
          subtitle: '오늘은 무리 없이 정리하는 하루로 가져가도 좋아요.',
        ),
      ],
    );
  }

  static HomeHeaderGreetingCopy _afternoonCopy({
    required String name,
    required int count,
    required int variant,
  }) {
    if (count >= 6) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '오늘 정말 바쁜 하루죠, $name',
            subtitle: '남은 일정도 놓치지 않게 제가 흐름을 잡아둘게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '오후도 꽉 찬 하루예요, $name',
            subtitle: '레슨 사이 회원 관리 포인트를 같이 챙겨볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '조금만 더 힘내볼까요, $name',
            subtitle: '오늘 같은 날은 자동 정리가 더 든든해질 거예요.',
          ),
        ],
      );
    }

    if (count >= 3) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '오후도 차분히 가볼까요, $name',
            subtitle: '남은 레슨 흐름을 다시 한 번 확인해둘게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '오늘의 중간 흐름이에요, $name',
            subtitle: '일정은 무리 없이 이어갈 수 있게 정리해둘게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '남은 오후도 힘내볼까요, $name',
            subtitle: '회원별 필요한 관리만 빠르게 챙겨볼게요.',
          ),
        ],
      );
    }

    return _pick(
      variant,
      [
        HomeHeaderGreetingCopy(
          title: '오후도 차분히 가볼까요, $name',
          subtitle: '오늘은 천천히 가도 괜찮은 흐름이에요.',
        ),
        HomeHeaderGreetingCopy(
          title: '오늘은 천천히 가볼까요, $name',
          subtitle: '급하지 않게 필요한 일정만 확인해볼게요.',
        ),
        HomeHeaderGreetingCopy(
          title: '남은 오후도 무리 없이 이어가요, $name',
          subtitle: '여유가 있다면 회원 정리도 가볍게 챙겨보세요.',
        ),
      ],
    );
  }

  static HomeHeaderGreetingCopy _eveningCopy({
    required String name,
    required int count,
    required int variant,
  }) {
    if (count >= 4) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '오늘도 하루가 저물어가네요, $name',
            subtitle: '남은 레슨까지 흐름이 끊기지 않게 같이 볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '아직 바쁜 저녁이에요, $name',
            subtitle: '마지막 일정까지 차분히 이어갈 수 있게 정리해둘게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '저녁 레슨 흐름도 챙겨볼게요, $name',
            subtitle: '오늘 마무리까지 필요한 관리만 빠르게 확인해요.',
          ),
        ],
      );
    }

    if (count >= 1) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '오늘도 하루가 저물어가네요, $name',
            subtitle: '남은 일정만 차분히 마무리해볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '저녁이 천천히 내려앉고 있어요, $name',
            subtitle: '오늘 레슨 흐름도 거의 마무리 단계예요.',
          ),
          HomeHeaderGreetingCopy(
            title: '마무리까지 천천히 가볼까요, $name',
            subtitle: '남은 일정과 회원 기록을 같이 챙겨볼게요.',
          ),
        ],
      );
    }

    return _pick(
      variant,
      [
        HomeHeaderGreetingCopy(
          title: '오늘도 하루가 저물어가네요, $name',
          subtitle: '오늘은 차분히 정리하는 저녁으로 가져가도 좋아요.',
        ),
        HomeHeaderGreetingCopy(
          title: '저녁이 천천히 내려앉고 있어요, $name',
          subtitle: '급한 일정이 없다면 오늘 관리 흐름만 확인해볼게요.',
        ),
        HomeHeaderGreetingCopy(
          title: '하루를 정리하기 좋은 시간이네요, $name',
          subtitle: '내일을 위해 필요한 것만 가볍게 챙겨보세요.',
        ),
      ],
    );
  }

  static HomeHeaderGreetingCopy _nightCopy({
    required String name,
    required int count,
    required int variant,
  }) {
    if (count >= 1) {
      return _pick(
        variant,
        [
          HomeHeaderGreetingCopy(
            title: '늦은 시간까지 고생 많으세요, $name',
            subtitle: '남은 레슨도 무리 없이 이어갈 수 있게 같이 볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '오늘 하루도 정말 수고 많으셨어요, $name',
            subtitle: '늦은 일정까지 차분히 마무리해볼게요.',
          ),
          HomeHeaderGreetingCopy(
            title: '밤 일정도 함께 정리해볼게요, $name',
            subtitle: '이 시간엔 필요한 것만 간단히 확인해도 충분해요.',
          ),
        ],
      );
    }

    return _pick(
      variant,
      [
        HomeHeaderGreetingCopy(
          title: '오늘 하루도 고생 많으셨어요, $name',
          subtitle: '내일 일정도 제가 차분히 정리해둘게요.',
        ),
        HomeHeaderGreetingCopy(
          title: '오늘도 정말 수고 많으셨어요, $name',
          subtitle: '편안히 쉬고 내일도 좋은 흐름으로 이어가요.',
        ),
        HomeHeaderGreetingCopy(
          title: '하루를 마무리할 시간이네요, $name',
          subtitle: '오늘은 여기까지 해도 충분히 잘 해오셨어요.',
        ),
      ],
    );
  }

  static HomeHeaderGreetingCopy _nightWorkCopy({
    required String name,
    required int count,
    required int variant,
  }) {
    return _pick(
      variant,
      [
        HomeHeaderGreetingCopy(
          title: '늦은 시간까지 이어가고 계시네요, $name',
          subtitle: '야간 레슨 흐름도 차분히 정리해둘게요.',
        ),
        HomeHeaderGreetingCopy(
          title: '오늘도 늦게까지 고생 많으세요, $name',
          subtitle: '마지막 일정까지 무리 없이 이어가볼게요.',
        ),
        HomeHeaderGreetingCopy(
          title: '밤 레슨도 함께 챙겨볼게요, $name',
          subtitle: '필요한 관리만 간단히 확인해도 충분해요.',
        ),
      ],
    );
  }

  static HomeHeaderGreetingCopy _pick(
      int variant,
      List<HomeHeaderGreetingCopy> items,
      ) {
    final index = math.max(0, variant) % items.length;
    return items[index];
  }
}