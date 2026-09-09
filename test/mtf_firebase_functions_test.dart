import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/mtf_firebase_functions.dart';

void main() {
  test('callable Functions 리전은 Firestore와 같은 서울 리전이다', () {
    expect(MtfFirebaseFunctions.region, 'asia-northeast3');
  });

  test('lib의 Functions 생성, Emulator 연결, callable 생성은 공통 파일에만 있다', () {
    final directUsages = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.endsWith('/services/mtf_firebase_functions.dart')) {
        continue;
      }
      final source = entity
          .readAsStringSync()
          .replaceAll('MtfFirebaseFunctions.instance', '');
      for (final pattern in [
        'FirebaseFunctions.instanceFor',
        'FirebaseFunctions.instance',
        'useFunctionsEmulator',
        '.httpsCallable(',
      ]) {
        if (source.contains(pattern)) {
          directUsages.add('$normalized: $pattern');
        }
      }
    }

    expect(directUsages, isEmpty);
  });
}
