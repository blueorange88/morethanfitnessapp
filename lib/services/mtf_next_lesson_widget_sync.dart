import 'mtf_home_widget_service.dart';

class WidgetLessonEvent {
  final DateTime startAt;
  final String memberName;
  final String lessonType;
  final String memo;

  const WidgetLessonEvent({
    required this.startAt,
    required this.memberName,
    required this.lessonType,
    required this.memo,
  });
}

Future<void> syncNextLessonWidgetFromEvents(
    List<WidgetLessonEvent> events,
    ) async {
  final now = DateTime.now();

  final upcoming = events
      .where((event) {
    final visibleUntil = event.startAt.add(const Duration(hours: 2));
    return visibleUntil.isAfter(now);
  })
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));

  final next = upcoming.isNotEmpty ? upcoming[0] : null;
  final second = upcoming.length >= 2 ? upcoming[1] : null;

  await MtfHomeWidgetService.syncNextLessons(
    nextTime: next == null ? '' : _formatWidgetTime(next.startAt),
    nextName: next?.memberName ?? '',
    nextType: next?.lessonType ?? '',
    nextMemo: next == null ? '' : _compactMemo(next.memo),
    secondTime: second == null ? '' : _formatWidgetTime(second.startAt),
    secondName: second?.memberName ?? '',
    secondType: second?.lessonType ?? '',
    secondMemo: second == null ? '' : _compactMemo(second.memo),
  );
}

String _formatWidgetTime(DateTime value) {
  final h = value.hour.toString().padLeft(2, '0');
  final m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _compactMemo(String value) {
  final text = value.trim().replaceAll('\n', ' ');
  if (text.length <= 36) return text;
  return '${text.substring(0, 36)}…';
}