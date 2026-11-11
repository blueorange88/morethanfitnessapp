import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/disk_cached_network_image.dart';

// 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const _url =
    'https://firebasestorage.googleapis.com/v0/b/app.firebasestorage.app/o/'
    'trainer_photos%2Fuid1%2Fphoto_1760000000000.jpg?alt=media&token=abc';

void main() {
  late Directory dir;
  late int fetchCount;

  DiskImageCache makeCache({
    Future<Uint8List> Function(String url)? fetch,
    int maxFiles = 20,
  }) => DiskImageCache(
    directory: () async => dir,
    fetch:
        fetch ??
        (url) async {
          fetchCount += 1;
          return _png;
        },
    maxFiles: maxFiles,
  );

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    fetchCount = 0;
    dir = await Directory.systemTemp.createTemp('mtf_image_cache_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('캐시 키', () {
    test('URL 끝의 파일 이름을 쓰고 위험한 글자는 바꾼다', () {
      expect(DiskImageCache.keyFor(_url), 'photo_1760000000000.jpg');
      expect(
        DiskImageCache.keyFor('https://x.com/o/a%2F..%2Fevil.jpg?alt=media'),
        'evil.jpg',
      );
      expect(DiskImageCache.keyFor(''), isNull);
      expect(DiskImageCache.keyFor('https://x.com'), isNull);
    });

    test('올릴 때마다 이름이 다른 사진은 서로 다른 키다', () {
      expect(
        DiskImageCache.keyFor(
          _url.replaceAll('1760000000000', '1760000000001'),
        ),
        isNot(DiskImageCache.keyFor(_url)),
      );
    });
  });

  group('폰에 저장', () {
    test('처음에는 내려받고 저장하며, 앱을 다시 켠 것처럼 새 캐시로 열어도 내려받지 않는다', () async {
      final first = makeCache();
      expect(await first.readOrFetch(_url), _png);
      expect(fetchCount, 1);

      // 앱 재실행: 같은 폴더를 새 캐시 객체로 연다.
      final restarted = makeCache();
      expect(await restarted.readOrFetch(_url), _png);
      expect(fetchCount, 1, reason: '두 번째부터는 폰에 저장된 파일을 읽는다');
    });

    test('올린 사진을 바로 저장해 두면 다운로드가 필요 없다', () async {
      final cache = makeCache();
      await cache.write(_url, _png);
      expect(await cache.readOrFetch(_url), _png);
      expect(fetchCount, 0);
    });

    test('같은 사진을 동시에 요청해도 한 번만 받는다', () async {
      final cache = makeCache();
      final results = await Future.wait([
        cache.readOrFetch(_url),
        cache.readOrFetch(_url),
        cache.readOrFetch(_url),
      ]);
      expect(results.every((r) => r.length == _png.length), isTrue);
      expect(fetchCount, 1);
    });

    test('인터넷이 없어도 저장된 사진은 뜨고, 저장된 게 없으면 실패한다', () async {
      await makeCache().write(_url, _png);
      final offline = makeCache(
        fetch: (_) async => throw const SocketException('offline'),
      );
      expect(await offline.readOrFetch(_url), _png);

      final other = _url.replaceAll('1760000000000', '1');
      await expectLater(
        offline.readOrFetch(other),
        throwsA(isA<SocketException>()),
      );
    });

    test('받다 실패한 사진은 저장하지 않는다', () async {
      final failing = makeCache(fetch: (_) async => throw StateError('boom'));
      await expectLater(failing.readOrFetch(_url), throwsStateError);
      expect(await makeCache().read(_url), isNull);
      // 실패 뒤 다시 시도하면 새로 받는다.
      expect(await makeCache().readOrFetch(_url), _png);
      expect(fetchCount, 1);
    });

    test('파일이 maxFiles를 넘으면 오래된 것부터 지운다', () async {
      final cache = makeCache(maxFiles: 2);
      for (var i = 1; i <= 3; i++) {
        await cache.write('https://x.com/o/photo_$i.jpg', _png);
        // 수정 시각이 겹치지 않게 한다.
        await File(
          '${dir.path}/photo_$i.jpg',
        ).setLastModified(DateTime(2026, 1, i));
      }
      await cache.write('https://x.com/o/photo_4.jpg', _png);
      final names = [for (final f in dir.listSync()) f.uri.pathSegments.last]
        ..sort();
      expect(names.length, 2);
      expect(names, contains('photo_4.jpg'));
      expect(names, isNot(contains('photo_1.jpg')));
    });
  });

  group('DiskCachedNetworkImage', () {
    testWidgets('이미지로 불러오고 두 번째는 폰에 저장된 파일에서 읽는다', (tester) async {
      await tester.runAsync(() async {
        final cache = makeCache();
        final provider = DiskCachedNetworkImage(_url, cache: cache);
        final stream = provider.resolve(ImageConfiguration.empty);
        final done = Future<void>(() async {
          final completer = _Waiter();
          stream.addListener(
            ImageStreamListener(
              (info, _) => completer.complete(info.image.width),
            ),
          );
          expect(await completer.future, 1);
        });
        await done;
        expect(fetchCount, 1);

        // 다른 캐시 객체(앱 재실행)로 다시 불러온다.
        final again = DiskCachedNetworkImage(_url, cache: makeCache());
        final waiter = _Waiter();
        again
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (info, _) => waiter.complete(info.image.width),
              ),
            );
        expect(await waiter.future, 1);
        expect(fetchCount, 1);
      });
    });

    testWidgets('저장된 파일이 깨져 있으면 지우고 다음에는 새로 받는다', (tester) async {
      await tester.runAsync(() async {
        final cache = makeCache();
        await cache.write(_url, Uint8List.fromList([1, 2, 3, 4]));

        final provider = DiskCachedNetworkImage(_url, cache: cache);
        final failed = _Waiter();
        provider
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (info, _) => failed.complete(0),
                onError: (error, stack) => failed.completeError(error),
              ),
            );
        await expectLater(failed.future, throwsA(anything));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(await cache.read(_url), isNull, reason: '깨진 파일은 지운다');

        // 새로 받아 정상으로 뜬다.
        final retry = _Waiter();
        DiskCachedNetworkImage(_url, cache: makeCache(), scale: 2)
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (info, _) => retry.complete(info.image.width),
              ),
            );
        expect(await retry.future, 1);
        expect(fetchCount, 1);
      });
    });

    test('주소와 배율이 같으면 같은 이미지로 취급한다', () {
      expect(
        const DiskCachedNetworkImage(_url),
        const DiskCachedNetworkImage(_url),
      );
      expect(
        const DiskCachedNetworkImage(_url),
        isNot(const DiskCachedNetworkImage('$_url&x=1')),
      );
    });
  });
}

/// 이미지 로딩 결과(가로 길이)나 오류를 기다린다.
class _Waiter {
  final Completer<int> _completer = Completer<int>();

  Future<int> get future => _completer.future;

  void complete(int value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void completeError(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
