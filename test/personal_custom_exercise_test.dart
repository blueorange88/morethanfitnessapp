import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/personal_custom_exercise_service.dart';

void main() {
  group('내 운동 정규화', () {
    test('공백·대소문자 중복을 정리하고 빈 부위는 버린다', () {
      expect(
        normalizeCustomExercises({
          '하체': ['  힙   힌지 ', '힙 힌지', 'Deadlift', 'deadlift', ''],
          '목/어깨': ['월슬라이드'],
          '코어': [],
          ' ': ['무시'],
        }),
        {
          '하체': ['힙 힌지', 'Deadlift'],
          '목/어깨': ['월슬라이드'],
        },
      );
    });

    test('40자 초과 운동은 버리고 부위당 30개까지만 남긴다', () {
      final result = normalizeCustomExercises({
        '상체': ['가' * 41, ...List.generate(35, (index) => '운동$index')],
      });
      expect(result['상체']!.length, kCustomExerciseMaxPerPart);
      expect(result['상체']!.first, '운동0');
    });

    test('map이 아니면 빈 목록이다', () {
      expect(normalizeCustomExercises(null), isEmpty);
      expect(normalizeCustomExercises(['하체']), isEmpty);
    });
  });

  group('새 운동 검증', () {
    test('빈 값·긴 이름·기본 운동·중복을 거절한다', () {
      String? check(String name, {List<String> custom = const []}) =>
          validateNewCustomExercise(
            name: name,
            builtInExercises: const ['스쿼트', '브릿지'],
            currentCustomExercises: custom,
          );

      expect(check('  '), isNotNull);
      expect(check('가' * 41), isNotNull);
      expect(check(' 스쿼트 '), '이미 있는 운동이에요.');
      expect(check('힙힌지', custom: ['힙힌지']), '이미 있는 운동이에요.');
      expect(check('힙 힌지'), isNull);
    });

    test('부위당 30개를 넘으면 거절한다', () {
      final full = List.generate(kCustomExerciseMaxPerPart, (i) => '운동$i');
      expect(
        validateNewCustomExercise(
          name: '새 운동',
          builtInExercises: const [],
          currentCustomExercises: full,
        ),
        isNotNull,
      );
    });
  });

  test('카테고리 레슨일지는 추가 운동을 서버에 저장하고 실패하면 되돌린다', () {
    final page =
        File(
          'lib/pages/personal_training_log_category_page.dart',
        ).readAsStringSync();
    final log =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();
    final service =
        File(
          'lib/services/personal_custom_exercise_service.dart',
        ).readAsStringSync();

    expect(
      log,
      contains('personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid'),
    );
    expect(page, contains('PersonalCustomExerciseService(uid: ownerUid)'));
    expect(page, contains('onTap: _addCustomExerciseFromSearch'));
    expect(page, contains('onPressed: () => _confirmRemoveCustomExercise'));
    expect(
      RegExp(
        r'_customExercisesByPart = previous;[\s\S]*?'
        r'추가 운동을 저장하지 못했어요',
      ).hasMatch(page),
      isTrue,
    );
    expect(service, contains("'updatePersonalTrainerProfile'"));
    expect(service, contains('Source.server'));
    expect(service, contains('custom_exercises_readback_mismatch'));
  });
}
