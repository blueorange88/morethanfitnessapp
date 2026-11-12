import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// 회원권 정지/재개 이력(`membershipPauseHistory`)을 한 줄씩 읽기 쉬운 글로 바꾼다.
/// 정지와 그다음 재개를 짝지어 `정지 시작 ~ 재개일 · N일 정지 · 자동/직접 재개` 로 보여주고,
/// 아직 재개하지 않은 정지는 `정지 중 · N일 예정 · MM.DD 재개 예정` 으로 보여준다.
/// 최신 이력이 위에 오고 [limit]개까지 돌려준다.
List<String> membershipPauseHistoryLines(
  List<Map<String, dynamic>> history, {
  int limit = 10,
}) {
  DateTime? dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  int? intOf(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  String full(DateTime? date) =>
      date == null ? '-' : DateFormat('yyyy.MM.dd').format(date);
  String short(DateTime date) => DateFormat('MM.dd').format(date);

  final items =
      history.where((item) => dateOf(item['at']) != null).toList()
        ..sort((a, b) => dateOf(a['at'])!.compareTo(dateOf(b['at'])!));

  final lines = <String>[];
  Map<String, dynamic>? open;

  String ongoing(Map<String, dynamic> pause) {
    final start = full(dateOf(pause['at']));
    final planned = intOf(pause['plannedDays']);
    final due = dateOf(pause['resumeDueAt']);
    return [
      '$start ~ 정지 중',
      if (planned != null) '$planned일 예정',
      if (due != null) '${short(due)} 재개 예정',
    ].join(' · ');
  }

  for (final item in items) {
    final type = (item['type'] ?? '').toString().trim();
    if (type == 'pause') {
      if (open != null) lines.add(ongoing(open));
      open = item;
    } else if (type == 'resume') {
      final end = dateOf(item['at']);
      final days =
          intOf(item['actualDays']) ??
          (open == null ? null : intOf(open['plannedDays']));
      final auto = (item['source'] ?? '').toString() == 'auto_resume';
      final extended = dateOf(item['extendedEndAt']);
      if (open != null) {
        lines.add(
          [
            '${full(dateOf(open['at']))} ~ ${full(end)}',
            if (days != null) '$days일 정지',
            auto ? '자동 재개' : '직접 재개',
            if (extended != null) '종료일 ${full(extended)}로 연장',
          ].join(' · '),
        );
        open = null;
      } else {
        lines.add(
          [
            '${full(end)} 재개',
            if (days != null) '실제 $days일 정지',
            if (auto) '자동 재개',
          ].join(' · '),
        );
      }
    }
  }
  if (open != null) lines.add(ongoing(open));

  return lines.reversed.take(limit).toList();
}
