class LessonTypeItem {
  final String id;
  final String name;
  final String colorHex;

  const LessonTypeItem({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  LessonTypeItem copyWith({
    String? id,
    String? name,
    String? colorHex,
  }) {
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