import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GuestScheduleRecord {
  const GuestScheduleRecord({
    required this.guestScheduleId,
    required this.nameOrAlias,
    required this.lessonType,
    required this.startAt,
    required this.endAt,
    required this.memo,
    required this.colorHex,
    required this.createdAtLocal,
    required this.updatedAtLocal,
  });

  final String guestScheduleId;
  final String nameOrAlias;
  final String lessonType;
  final DateTime startAt;
  final DateTime endAt;
  final String memo;
  final String colorHex;
  final DateTime createdAtLocal;
  final DateTime updatedAtLocal;

  GuestScheduleRecord copyWith({
    String? nameOrAlias,
    String? lessonType,
    DateTime? startAt,
    DateTime? endAt,
    String? memo,
    String? colorHex,
    DateTime? updatedAtLocal,
  }) {
    return GuestScheduleRecord(
      guestScheduleId: guestScheduleId,
      nameOrAlias: nameOrAlias ?? this.nameOrAlias,
      lessonType: lessonType ?? this.lessonType,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      memo: memo ?? this.memo,
      colorHex: colorHex ?? this.colorHex,
      createdAtLocal: createdAtLocal,
      updatedAtLocal: updatedAtLocal ?? this.updatedAtLocal,
    );
  }

  Map<String, dynamic> toJson() => {
        'guestScheduleId': guestScheduleId,
        'nameOrAlias': nameOrAlias,
        'lessonType': lessonType,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'memo': memo,
        'colorHex': colorHex,
        'createdAtLocal': createdAtLocal.toIso8601String(),
        'updatedAtLocal': updatedAtLocal.toIso8601String(),
      };

  factory GuestScheduleRecord.fromJson(Map<String, dynamic> json) {
    return GuestScheduleRecord(
      guestScheduleId: (json['guestScheduleId'] ?? '').toString(),
      nameOrAlias: (json['nameOrAlias'] ?? '').toString(),
      lessonType: (json['lessonType'] ?? 'PT').toString(),
      startAt: DateTime.parse(json['startAt'].toString()),
      endAt: DateTime.parse(json['endAt'].toString()),
      memo: (json['memo'] ?? '').toString(),
      colorHex: (json['colorHex'] ?? '#4F46E5').toString(),
      createdAtLocal: DateTime.parse(json['createdAtLocal'].toString()),
      updatedAtLocal: DateTime.parse(json['updatedAtLocal'].toString()),
    );
  }

  Map<String, dynamic> toScheduleMap() => {
        'docId': guestScheduleId,
        'guestScheduleId': guestScheduleId,
        'name': nameOrAlias,
        'typeName': lessonType,
        'startAt': startAt,
        'endAt': endAt,
        'memo': memo,
        'typeColorHex': colorHex,
        'isGuestLocal': true,
      };
}

enum GuestScheduleSaveStatus { saved, limitReached }

class GuestScheduleSaveResult {
  const GuestScheduleSaveResult(this.status, {this.record});

  final GuestScheduleSaveStatus status;
  final GuestScheduleRecord? record;
}

class GuestScheduleRepository {
  GuestScheduleRepository({
    this.limit = 5,
    SharedPreferences? preferences,
    DateTime Function()? now,
  })  : _preferences = preferences,
        _now = now ?? DateTime.now;

  static const storageKey = 'guest_home_schedules_v1';

  final int limit;
  final SharedPreferences? _preferences;
  final DateTime Function() _now;
  Future<void> _operationTail = Future<void>.value();
  int _idSequence = 0;

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<List<GuestScheduleRecord>> load() async {
    final preferences = await _prefs();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final records = decoded
          .whereType<Map>()
          .map((item) => GuestScheduleRecord.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((record) => record.guestScheduleId.isNotEmpty)
          .toList()
        ..sort((left, right) => left.startAt.compareTo(right.startAt));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<GuestScheduleSaveResult> save({
    String? guestScheduleId,
    required String nameOrAlias,
    required String lessonType,
    required DateTime startAt,
    required DateTime endAt,
    required String memo,
    required String colorHex,
  }) {
    return _locked(() async {
      final records = await load();
      final cleanId = guestScheduleId?.trim() ?? '';
      final existingIndex = cleanId.isEmpty
          ? -1
          : records.indexWhere(
              (record) => record.guestScheduleId == cleanId,
            );
      if (existingIndex < 0 && records.length >= limit) {
        return const GuestScheduleSaveResult(
          GuestScheduleSaveStatus.limitReached,
        );
      }

      final now = _now();
      final record = existingIndex >= 0
          ? records[existingIndex].copyWith(
              nameOrAlias: nameOrAlias.trim(),
              lessonType: lessonType.trim(),
              startAt: startAt,
              endAt: endAt,
              memo: memo.trim(),
              colorHex: colorHex,
              updatedAtLocal: now,
            )
          : GuestScheduleRecord(
              guestScheduleId:
                  'guest-${now.microsecondsSinceEpoch}-${_idSequence++}',
              nameOrAlias: nameOrAlias.trim(),
              lessonType: lessonType.trim(),
              startAt: startAt,
              endAt: endAt,
              memo: memo.trim(),
              colorHex: colorHex,
              createdAtLocal: now,
              updatedAtLocal: now,
            );

      if (existingIndex >= 0) {
        records[existingIndex] = record;
      } else {
        records.add(record);
      }
      await _write(records);
      return GuestScheduleSaveResult(
        GuestScheduleSaveStatus.saved,
        record: record,
      );
    });
  }

  Future<bool> delete(String guestScheduleId) {
    return _locked(() async {
      final records = await load();
      final previousLength = records.length;
      records.removeWhere(
        (record) => record.guestScheduleId == guestScheduleId,
      );
      if (records.length == previousLength) return false;
      await _write(records);
      return true;
    });
  }

  Future<void> _write(List<GuestScheduleRecord> records) async {
    final preferences = await _prefs();
    await preferences.setString(
      storageKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  Future<T> _locked<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
