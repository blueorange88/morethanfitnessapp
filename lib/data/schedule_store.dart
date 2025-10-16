// lib/data/schedule_store.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lesson.dart';

class ScheduleStore {
  static String keyForWeek(int wo) => 'scheduleData_$wo';
  static String keyMinute(String hh) => 'minute-$hh'; // e.g. "minute-06"
  static const keyRange = 'scheduleRange';            // {"start":6,"end":21}

  Future<List<Lesson>> loadWeek(int weekOffset) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyForWeek(weekOffset));
    if (raw == null || raw.isEmpty) return [];
    try {
      return Lesson.decode(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveWeek(int weekOffset, List<Lesson> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyForWeek(weekOffset), Lesson.encode(list));
  }

  Future<void> setMinute(String hh, String mm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyMinute(hh), mm);
  }

  Future<String> getMinute(String hh) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyMinute(hh)) ?? '00';
  }

  Future<void> saveRange(int start, int end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRange, '{"start":$start,"end":$end}');
  }

  Future<({int start, int end})> loadRangeOrDefault() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyRange);
    if (raw == null) return (start: 6, end: 21);
    try {
      final m = raw.contains('"') ? raw : '{"start":6,"end":21}';
      final start = int.parse(RegExp(r'"start":\s*(\d+)').firstMatch(raw)!.group(1)!);
      final end = int.parse(RegExp(r'"end":\s*(\d+)').firstMatch(raw)!.group(1)!);
      return (start: start, end: end);
    } catch (_) {
      return (start: 6, end: 21);
    }
  }
}
