enum HomeRepeatLessonGroupingMode {
  none,
  sameMemberSameTime,
  sameMemberAnyTime,
}

const String kHomeRepeatLessonGroupingModePrefsKey =
    'home_repeat_lesson_grouping_mode_v1';

extension HomeRepeatLessonGroupingModeLabel on HomeRepeatLessonGroupingMode {
  String get storageValue {
    switch (this) {
      case HomeRepeatLessonGroupingMode.none:
        return 'none';
      case HomeRepeatLessonGroupingMode.sameMemberSameTime:
        return 'sameMemberSameTime';
      case HomeRepeatLessonGroupingMode.sameMemberAnyTime:
        return 'sameMemberAnyTime';
    }
  }

  String get title {
    switch (this) {
      case HomeRepeatLessonGroupingMode.none:
        return '묶지 않음';
      case HomeRepeatLessonGroupingMode.sameMemberSameTime:
        return '같은 회원 + 같은 시간대';
      case HomeRepeatLessonGroupingMode.sameMemberAnyTime:
        return '같은 회원 전체';
    }
  }

  String get description {
    switch (this) {
      case HomeRepeatLessonGroupingMode.none:
        return '같은 회원이어도 현재 선택한 레슨만 수정해요.';
      case HomeRepeatLessonGroupingMode.sameMemberSameTime:
        return '같은 회원이 같은 시간대로 등록된 반복 레슨만 함께 체크해요.';
      case HomeRepeatLessonGroupingMode.sameMemberAnyTime:
        return '같은 주의 같은 회원 레슨을 시간대와 관계없이 함께 체크해요.';
    }
  }

  String get shortLabel {
    switch (this) {
      case HomeRepeatLessonGroupingMode.none:
        return '묶지 않음';
      case HomeRepeatLessonGroupingMode.sameMemberSameTime:
        return '같은 시간대';
      case HomeRepeatLessonGroupingMode.sameMemberAnyTime:
        return '같은 회원 전체';
    }
  }
}

HomeRepeatLessonGroupingMode homeRepeatLessonGroupingModeFromString(
    String? value,
    ) {
  switch ((value ?? '').trim()) {
    case 'sameMemberSameTime':
      return HomeRepeatLessonGroupingMode.sameMemberSameTime;
    case 'sameMemberAnyTime':
      return HomeRepeatLessonGroupingMode.sameMemberAnyTime;
    case 'none':
    default:
      return HomeRepeatLessonGroupingMode.none;
  }
}