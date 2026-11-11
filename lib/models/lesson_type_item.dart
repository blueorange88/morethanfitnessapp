import 'dart:convert';

/// 홈 레슨 종류 목록을 이 기기에 저장하는 키(홈 화면과 계약서 목록이 함께 쓴다).
const String kHomeLessonTypesPrefsKey = 'home_lesson_types_v3';

/// 저장된 홈 레슨 종류 목록을 읽는다. 비었거나 깨졌으면 빈 목록.
List<LessonTypeItem> parseHomeLessonTypes(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => LessonTypeItem.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

class LessonTypeItem {
  final String id;
  final String name;
  final String colorHex;

  const LessonTypeItem({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  LessonTypeItem copyWith({String? id, String? name, String? colorHex}) {
    return LessonTypeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorHex': colorHex,
  };

  factory LessonTypeItem.fromMap(Map<String, dynamic> map) {
    return LessonTypeItem(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      colorHex: (map['colorHex'] ?? '#4F46E5').toString(),
    );
  }
}
