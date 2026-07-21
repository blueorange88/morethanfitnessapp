import 'package:shared_preferences/shared_preferences.dart';

class HomeHeaderMessageHistory {
  HomeHeaderMessageHistory({required this.scopeKey});

  final String scopeKey;

  String get _recentKey => 'home_header_recent_messages_v1_$scopeKey';
  String get _questionKey => 'home_header_question_keys_v1_$scopeKey';
  String get _questionDateKey => 'home_header_question_date_v1_$scopeKey';

  Future<({Set<String> recent, Set<String> questions})> load(
      DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(now);
    final savedDate = prefs.getString(_questionDateKey);
    if (savedDate != dateKey) {
      await prefs.setString(_questionDateKey, dateKey);
      await prefs.remove(_questionKey);
    }
    return (
      recent: (prefs.getStringList(_recentKey) ?? const <String>[]).toSet(),
      questions:
          (prefs.getStringList(_questionKey) ?? const <String>[]).toSet(),
    );
  }

  Future<void> remember(
      {required String messageKey, String? questionKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentKey) ?? <String>[];
    recent.remove(messageKey);
    recent.insert(0, messageKey);
    await prefs.setStringList(_recentKey, recent.take(5).toList());
    if (questionKey != null) {
      final questions = (prefs.getStringList(_questionKey) ?? <String>[])
          .toSet()
        ..add(questionKey);
      await prefs.setStringList(_questionKey, questions.toList());
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';
}
