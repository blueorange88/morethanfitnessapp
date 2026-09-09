class HomeHeaderLessonContext {
  const HomeHeaderLessonContext({required this.startAt, required this.endAt});

  final DateTime startAt;
  final DateTime endAt;
}

enum HomeMoreSenseKind {
  birthday,
  membershipExpiry,
  dDay,
  milestone,
  lowSessions
}

class HomeMoreSenseContext {
  const HomeMoreSenseContext({
    required this.key,
    required this.kind,
    this.memberName = '',
    this.days = 0,
  });

  final String key;
  final HomeMoreSenseKind kind;
  final String memberName;
  final int days;
}

class HomeWeatherContext {
  const HomeWeatherContext({
    required this.isRaining,
    required this.isSunny,
    required this.isWindy,
    required this.isHot,
    required this.isCold,
  });

  final bool isRaining;
  final bool isSunny;
  final bool isWindy;
  final bool isHot;
  final bool isCold;
}

class HomeHeaderMessageSelection {
  const HomeHeaderMessageSelection({
    required this.fcKey,
    required this.fcText,
    required this.moreSenseKey,
    required this.moreSenseText,
    required this.questionKey,
  });

  final String fcKey;
  final String fcText;
  final String moreSenseKey;
  final String moreSenseText;
  final String? questionKey;
}

enum HomeHeaderWorkloadBucket {
  loading,
  empty,
  light,
  steady,
  full,
  busy,
  veryBusy
}

class HomeHeaderWorkloadFeedback {
  const HomeHeaderWorkloadFeedback({
    required this.bucket,
    required this.messageKey,
    required this.text,
  });

  final HomeHeaderWorkloadBucket bucket;
  final String messageKey;
  final String text;
}

class HomeHeaderMessageEngine {
  const HomeHeaderMessageEngine._();

  static HomeHeaderWorkloadFeedback workloadFeedback({
    required int todayCount,
    required bool scheduleReady,
  }) {
    if (!scheduleReady) {
      return const HomeHeaderWorkloadFeedback(
        bucket: HomeHeaderWorkloadBucket.loading,
        messageKey: 'workload_loading',
        text: '오늘 일정을 살펴보고 있어요.',
      );
    }
    if (todayCount <= 0) {
      return const HomeHeaderWorkloadFeedback(
        bucket: HomeHeaderWorkloadBucket.empty,
        messageKey: 'workload_empty',
        text: '오늘은 레슨 일정에 여유가 있어요.',
      );
    }
    if (todayCount <= 3) {
      return const HomeHeaderWorkloadFeedback(
        bucket: HomeHeaderWorkloadBucket.light,
        messageKey: 'workload_light',
        text: '한 분 한 분 여유 있게 챙기기 좋은 날이에요.',
      );
    }
    if (todayCount <= 6) {
      return const HomeHeaderWorkloadFeedback(
        bucket: HomeHeaderWorkloadBucket.steady,
        messageKey: 'workload_steady',
        text: '오늘은 적당히 리듬 있는 일정이에요.',
      );
    }
    if (todayCount <= 8) {
      return const HomeHeaderWorkloadFeedback(
        bucket: HomeHeaderWorkloadBucket.full,
        messageKey: 'workload_full',
        text: '오늘은 꽤 알찬 일정이에요.',
      );
    }
    if (todayCount <= 11) {
      return const HomeHeaderWorkloadFeedback(
        bucket: HomeHeaderWorkloadBucket.busy,
        messageKey: 'workload_busy',
        text: '오늘은 레슨이 많은 날이에요. 페이스를 잘 챙겨볼게요.',
      );
    }
    return const HomeHeaderWorkloadFeedback(
      bucket: HomeHeaderWorkloadBucket.veryBusy,
      messageKey: 'workload_very_busy',
      text: '오늘은 일정이 꽉 찬 날이에요. 중요한 흐름부터 챙겨볼게요.',
    );
  }

  static String normalizeNicknameLabel(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty || clean == '강사님') return '선생님';
    return clean.endsWith('님') ? clean : '$clean님';
  }

  static String greeting({required DateTime now, required String nickname}) {
    final label = normalizeNicknameLabel(nickname);
    final hour = now.hour;
    if (hour < 5) return '늦은 시간까지 고생 많으셨어요, $label';
    if (hour < 9) return '좋은 아침이에요, $label';
    if (hour < 12) return '오늘도 잘 시작해볼까요, $label?';
    if (hour < 14) return '점심은 드셨어요, $label?';
    if (hour < 17) return '나른한 오후예요, $label';
    if (hour < 19) return '오늘 하루도 저물어가네요, $label';
    if (hour < 21) return '여유로운 저녁이길 바라요, $label';
    if (hour < 23) return '오늘도 수고 많으셨어요, $label';
    return '늦은 시간까지 고생 많으셨어요, $label';
  }

  static HomeHeaderMessageSelection select({
    required DateTime now,
    required List<HomeHeaderLessonContext> lessons,
    required List<HomeMoreSenseContext> moreSenseItems,
    required int moreSenseCount,
    required int memberCount,
    required int entrySerial,
    required Set<String> recentKeys,
    required Set<String> askedQuestionKeysToday,
    HomeWeatherContext? weather,
  }) {
    final candidates = <_Candidate>[];
    final sorted = [...lessons]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final future = sorted.where((item) => item.endAt.isAfter(now)).toList();

    void add(String key, String text,
        {String? eventKey, bool question = false}) {
      if (question && askedQuestionKeysToday.contains(key)) return;
      candidates
          .add(_Candidate(key, text, eventKey: eventKey, question: question));
    }

    add('mood_future', '오늘은 어떤 하루가 될까요?', question: true);
    add('mood_good', '기분 좋은 일이 하나쯤 생기면 좋겠어요.');
    add('mood_self', '오늘도 선생님다운 하루를 만들어봐요.');
    add('mood_slow', '오늘은 조금 천천히 시작해도 괜찮겠어요.');
    add('mood_breathe', '잠깐 숨을 고르고 다시 시작해볼까요?');
    add('mood_together', '오늘도 한 걸음씩 같이 가볼게요.');

    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      add('weekend_slow', '조금은 여유로운 주말이에요.');
      add('weekend_rhythm', '오늘도 선생님만의 리듬을 지켜가고 있네요.');
      add('weekend_self', '선생님을 위한 시간도 있었으면 좋겠어요.');
    }

    if (weather != null) {
      if (weather.isRaining) {
        add('weather_rain', '비가 와요. 이동하실 때 조심하세요.');
        add('weather_umbrella', '우산은 챙기셨나요?', question: true);
      }
      if (weather.isSunny) add('weather_sunny', '햇살이 좋은 날이에요.');
      if (weather.isWindy) add('weather_wind', '바람이 기분 좋게 불어요.');
      if (weather.isHot) add('weather_hot', '조금 더워요. 수분도 챙겨주세요.');
      if (weather.isCold) add('weather_cold', '공기가 차가워졌어요. 따뜻하게 입으세요.');
    }

    if (sorted.isEmpty) {
      add('lesson_none', '오늘은 예정된 레슨이 없어요.');
      add('lesson_relaxed', '오늘은 조금 여유로운 하루예요.');
    } else if (future.isEmpty) {
      add('lesson_done', '오늘 예정된 레슨을 모두 마쳤어요.');
    } else {
      final next = future.first;
      final minutes = next.startAt.difference(now).inMinutes;
      if (sorted.first == next && minutes >= 0) {
        add('lesson_first', '오늘 첫 레슨은 ${_time(next.startAt)}이에요.');
      }
      if (sorted.length >= 6) add('lesson_many', '오늘은 레슨이 조금 많은 날이에요.');
      if (minutes >= 0 && minutes <= 90) {
        add('lesson_next_minutes', '다음 레슨까지 $minutes분 남았어요.');
      }
      if (future.length == 1 && sorted.length > 1) {
        add('lesson_last', '오늘 마지막 레슨이 남아 있어요.');
      }

      final completed =
          sorted.where((item) => !item.endAt.isAfter(now)).toList();
      final previous = completed.isEmpty ? null : completed.last;
      if (previous != null && next.startAt.isAfter(now)) {
        final gap = next.startAt.difference(previous.endAt).inMinutes;
        if (gap >= 120) {
          add('gap_long_question', '레슨 사이에 여유가 있네요. 운동하실 예정인가요?',
              question: true);
          add('gap_long_coffee', '커피 한잔하며 정리할 시간이 있겠는데요.');
          add('gap_long_log', '미뤄둔 레슨일지를 정리하기 좋은 시간이네요.');
          if (now.hour >= 11 && now.hour < 14) {
            add('gap_meal', '다음 레슨까지 여유가 있어요. 식사는 챙기셨나요?', question: true);
          }
        } else if (gap <= 75 && minutes >= 0) {
          add('gap_short_breathe', '잠깐 숨을 돌리고 다음 레슨을 준비해요.');
          add('gap_short_water', '물 한잔하기에는 충분한 시간이에요.');
        }
      }
    }

    for (final item in moreSenseItems) {
      final name = item.memberName.trim();
      final eventKey = item.key;
      switch (item.kind) {
        case HomeMoreSenseKind.birthday:
          add('sense_birthday_$eventKey',
              name.isEmpty ? '오늘 생일인 회원님이 있어요.' : '오늘은 $name 회원님의 생일이에요.',
              eventKey: eventKey);
        case HomeMoreSenseKind.membershipExpiry:
          add('sense_expiry_$eventKey',
              name.isEmpty ? '오늘 만료되는 회원권이 있어요.' : '$name 회원권이 오늘 만료돼요.',
              eventKey: eventKey);
        case HomeMoreSenseKind.dDay:
          add('sense_dday_$eventKey',
              name.isEmpty ? '오늘 챙길 회원 일정이 있어요.' : '$name 회원님의 D-DAY예요.',
              eventKey: eventKey);
        case HomeMoreSenseKind.milestone:
          add(
              'sense_milestone_$eventKey',
              name.isEmpty
                  ? '의미 있는 회원 마일스톤이 도착했어요.'
                  : '$name 회원님과 함께한 지 ${item.days}일이에요.',
              eventKey: eventKey);
        case HomeMoreSenseKind.lowSessions:
          add('sense_low_$eventKey',
              name.isEmpty ? '재등록을 살펴볼 회원님이 있어요.' : '$name 회원님의 잔여 레슨이 적어요.',
              eventKey: eventKey);
      }
    }

    if (memberCount <= 1) {
      add('card_birthday', '생년월일을 등록하면 회원님생일을 알려드려요.');
      add('card_membership', '회원권을 등록하면 만료일을 먼저 알려드려요.');
    }

    final available =
        candidates.where((item) => !recentKeys.contains(item.key)).toList();
    final pool = available.isEmpty ? candidates : available;
    final fc = pool[_stableIndex(now, entrySerial, pool.length)];
    final more = _selectMoreSense(
      now: now,
      items: moreSenseItems,
      count: moreSenseCount,
      excludedEventKey: fc.eventKey,
      entrySerial: entrySerial,
    );
    return HomeHeaderMessageSelection(
      fcKey: fc.key,
      fcText: fc.text,
      moreSenseKey: more.key,
      moreSenseText: more.text,
      questionKey: fc.question ? fc.key : null,
    );
  }

  static _Candidate _selectMoreSense({
    required DateTime now,
    required List<HomeMoreSenseContext> items,
    required int count,
    required String? excludedEventKey,
    required int entrySerial,
  }) {
    final available =
        items.where((item) => item.key != excludedEventKey).toList();
    if (available.isNotEmpty) {
      final item =
          available[_stableIndex(now, entrySerial + 19, available.length)];
      final name = item.memberName.trim();
      switch (item.kind) {
        case HomeMoreSenseKind.birthday:
          return _Candidate('expanded_${item.key}',
              name.isEmpty ? '오늘 생일인 회원님이 있어요.' : '오늘은 $name 회원님의 생일이에요.',
              eventKey: item.key);
        case HomeMoreSenseKind.membershipExpiry:
          return _Candidate('expanded_${item.key}',
              name.isEmpty ? '오늘 만료되는 회원권이 있어요.' : '$name 회원권이 오늘 만료돼요.',
              eventKey: item.key);
        case HomeMoreSenseKind.dDay:
          return _Candidate('expanded_${item.key}',
              name.isEmpty ? '오늘 챙길 회원 일정이 있어요.' : '$name 회원님의 D-DAY예요.',
              eventKey: item.key);
        case HomeMoreSenseKind.milestone:
          return _Candidate(
              'expanded_${item.key}',
              name.isEmpty
                  ? '의미 있는 마일스톤이 도착했어요.'
                  : '$name 회원님과 함께한 지 ${item.days}일이에요.',
              eventKey: item.key);
        case HomeMoreSenseKind.lowSessions:
          return _Candidate('expanded_${item.key}',
              name.isEmpty ? '재등록을 살펴볼 회원님이 있어요.' : '$name 회원님의 잔여 레슨이 적어요.',
              eventKey: item.key);
      }
    }
    if (count > 0) {
      return _Candidate('expanded_count', 'MORE 센스 $count개도 같이 챙겨볼게요.');
    }
    const empty = [
      _Candidate('expanded_empty_calm', '오늘은 급하게 챙길 항목이 없어요.'),
      _Candidate('expanded_empty_flow', '오늘 회원 흐름은 비교적 편안해 보여요.'),
      _Candidate('expanded_empty_lesson', '오늘은 레슨 흐름에 집중해도 괜찮겠어요.'),
    ];
    return empty[_stableIndex(now, entrySerial + 31, empty.length)];
  }

  static int _stableIndex(DateTime now, int serial, int length) {
    final seed = now.year * 10000 + now.month * 100 + now.day + serial * 37;
    return seed.abs() % length;
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _Candidate {
  const _Candidate(this.key, this.text, {this.eventKey, this.question = false});
  final String key;
  final String text;
  final String? eventKey;
  final bool question;
}
