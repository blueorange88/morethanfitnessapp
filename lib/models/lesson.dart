// lib/models/lesson.dart
import 'dart:convert';

class Lesson {
  final int di;        // 1~7 (월~일)
  final String time;   // "HH:MM"
  final String name;   // 회원 이름
  final int enrolled;  // 소진/수강한 회차
  final int cap;       // 총 회차
  final String? memberId;

  Lesson({
    required this.di,
    required this.time,
    required this.name,
    required this.enrolled,
    required this.cap,
    this.memberId,
  });

  Map<String, dynamic> toMap() => {
    'di': di,
    'time': time,
    'name': name,
    'enrolled': enrolled,
    'cap': cap,
    'memberId': memberId,
  };

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
    di: m['di'] as int,
    time: m['time'] as String,
    name: (m['name'] as String?) ?? '',
    enrolled: (m['enrolled'] as num?)?.toInt() ?? 0,
    cap: (m['cap'] as num?)?.toInt() ?? 0,
    memberId: m['memberId'] as String?,
  );

  static String encode(List<Lesson> list) =>
      jsonEncode(list.map((e) => e.toMap()).toList());

  static List<Lesson> decode(String raw) {
    final List data = jsonDecode(raw) as List;
    return data.map((e) => Lesson.fromMap((e as Map).cast())).toList();
  }
}
