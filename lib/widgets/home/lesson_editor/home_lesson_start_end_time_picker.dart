import 'package:flutter/material.dart';

import 'home_single_lesson_time_dialog.dart';

enum HomeLessonTimePickerInitialFocus {
  start,
  end,
}

class HomeLessonStartEndTimeResult {
  const HomeLessonStartEndTimeResult({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  final String startTime;
  final String endTime;
  final int durationMinutes;
}

class HomeLessonStartEndTimePicker {
  const HomeLessonStartEndTimePicker._();

  static String _timeStringFromDateTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  static DateTime _baseDateFromTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    return DateTime(2000, 1, 1, hour, minute);
  }

  static String _fallbackEndTime({
    required String startTime,
    required String initialEndTime,
    required int preferredDurationMinutes,
  }) {
    final cleanEndTime = initialEndTime.trim();
    if (cleanEndTime.isNotEmpty) {
      return cleanEndTime;
    }

    final startBase = _baseDateFromTime(startTime);
    return _timeStringFromDateTime(
      startBase.add(
        Duration(minutes: preferredDurationMinutes),
      ),
    );
  }

  static int _nextPreferredDuration({
    required DateTime startBase,
    required DateTime endBase,
    required int selectedDuration,
  }) {
    final diff = endBase.difference(startBase).inMinutes;

    return (diff == 30 || diff == 50 || diff == 60)
        ? diff
        : selectedDuration;
  }

  static Future<HomeLessonStartEndTimeResult?> show({
    required BuildContext context,
    required String initialStartTime,
    required String initialEndTime,
    required int preferredDurationMinutes,
    required ValueChanged<String> onError,
    HomeLessonTimePickerInitialFocus initialFocus =
        HomeLessonTimePickerInitialFocus.start,
  }) async {
    if (initialFocus == HomeLessonTimePickerInitialFocus.end) {
      final start = initialStartTime.trim();
      if (start.isEmpty) return null;

      final startBase = _baseDateFromTime(start);

      final initialEnd = _fallbackEndTime(
        startTime: start,
        initialEndTime: initialEndTime,
        preferredDurationMinutes: preferredDurationMinutes,
      );

      final endResult = await HomeSingleLessonTimeDialog.show(
        context: context,
        initialTime: initialEnd,
        title: '종료시간 변경',
        selectedDurationMinutes: preferredDurationMinutes,
        startPreviewTime: start,
      );

      if (endResult == null) return null;

      final end = (endResult['time'] ?? '').toString();
      if (end.isEmpty) return null;

      final endBase = _baseDateFromTime(end);

      if (!endBase.isAfter(startBase)) {
        onError('종료 시간은 시작 시간보다 늦어야 해요.');
        return null;
      }

      final nextDuration = _nextPreferredDuration(
        startBase: startBase,
        endBase: endBase,
        selectedDuration: preferredDurationMinutes,
      );

      return HomeLessonStartEndTimeResult(
        startTime: start,
        endTime: end,
        durationMinutes: nextDuration,
      );
    }

    final startResult = await HomeSingleLessonTimeDialog.show(
      context: context,
      initialTime: initialStartTime,
      title: '시작시간 변경',
      selectedDurationMinutes: preferredDurationMinutes,
      showUnsetPreview: true,
    );

    if (startResult == null) return null;

    final start = (startResult['time'] ?? '').toString();
    if (start.isEmpty) return null;

    FocusManager.instance.primaryFocus?.unfocus();

    await Future.delayed(const Duration(milliseconds: 100));

    if (!context.mounted) return null;

    final pickedDuration = startResult['duration'];

    final selectedDuration = pickedDuration is int
        ? pickedDuration
        : preferredDurationMinutes;

    final startBase = _baseDateFromTime(start);

    final fallbackEndTime = initialEndTime.trim();

    final autoEnd = selectedDuration > 0
        ? _timeStringFromDateTime(
      startBase.add(Duration(minutes: selectedDuration)),
    )
        : fallbackEndTime;

    final endResult = await HomeSingleLessonTimeDialog.show(
      context: context,
      initialTime: autoEnd,
      title: '종료시간 변경',
      selectedDurationMinutes: selectedDuration,
      startPreviewTime: start,
    );

    if (endResult == null) return null;

    final end = (endResult['time'] ?? '').toString();
    if (end.isEmpty) return null;

    final endBase = _baseDateFromTime(end);

    if (!endBase.isAfter(startBase)) {
      onError('종료 시간은 시작 시간보다 늦어야 해요.');
      return null;
    }

    final nextDuration = _nextPreferredDuration(
      startBase: startBase,
      endBase: endBase,
      selectedDuration: selectedDuration,
    );

    return HomeLessonStartEndTimeResult(
      startTime: start,
      endTime: end,
      durationMinutes: nextDuration,
    );
  }
}