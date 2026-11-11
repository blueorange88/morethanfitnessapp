import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// 내려받은 사진을 폰에 파일로 저장해 두는 간단한 캐시.
///
/// `NetworkImage`는 앱을 켜는 동안만 메모리에 기억해서 앱을 다시 켤 때마다 사진을 처음부터 다시
/// 받는다. 이 캐시는 한 번 받은 사진을 폰에 남겨 두어 두 번째부터는 인터넷 없이 바로 읽는다.
///
/// - 키는 URL 맨 끝의 파일 이름이다. 명함 사진은 올릴 때마다 `photo_<시각>.jpg`로 이름이 달라서
///   새 사진을 올리면 자동으로 새로 받는다.
/// - 파일이 [maxFiles]개를 넘으면 오래된 것부터 지운다.
class DiskImageCache {
  DiskImageCache({
    Future<Directory> Function()? directory,
    Future<Uint8List> Function(String url)? fetch,
    this.maxFiles = 20,
  }) : _directory = directory ?? _defaultDirectory,
       _fetch = fetch ?? _defaultFetch;

  /// 앱 전체에서 쓰는 기본 캐시.
  static final DiskImageCache instance = DiskImageCache();

  final Future<Directory> Function() _directory;
  final Future<Uint8List> Function(String url) _fetch;
  final int maxFiles;

  final Map<String, Future<Uint8List>> _inFlight = {};

  static Future<Directory> _defaultDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/image_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Uint8List> _defaultFetch(String url) async {
    final client =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw HttpException(
          'status ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      return await consolidateHttpClientResponseBytes(response);
    } finally {
      client.close(force: true);
    }
  }

  /// 캐시 파일 이름. URL의 마지막 경로(`photo_123.jpg`)에서 안전한 글자만 남긴다. 만들 수 없으면 null.
  static String? keyFor(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final last = uri.pathSegments.last.split('/').last;
    final safe = last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') return null;
    return safe;
  }

  Future<File?> _fileFor(String url) async {
    final key = keyFor(url);
    if (key == null) return null;
    final dir = await _directory();
    return File('${dir.path}/$key');
  }

  /// 폰에 저장된 사진. 없으면 null.
  Future<Uint8List?> read(String url) async {
    try {
      final file = await _fileFor(url);
      if (file == null || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  /// 사진을 폰에 저장한다. 실패해도 화면 표시에는 영향이 없다.
  Future<void> write(String url, Uint8List bytes) async {
    try {
      final file = await _fileFor(url);
      if (file == null || bytes.isEmpty) return;
      // 쓰다 멈춘 파일을 읽지 않도록 임시 파일에 쓴 뒤 옮긴다.
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      await _trim();
    } catch (_) {
      // 저장하지 못해도 다음에 다시 받으면 된다.
    }
  }

  /// 폰에 있으면 그것을, 없으면 내려받아 저장한 뒤 돌려준다. 같은 사진을 동시에 받지 않는다.
  Future<Uint8List> readOrFetch(String url) {
    return _inFlight.putIfAbsent(url, () async {
      try {
        final cached = await read(url);
        if (cached != null) return cached;
        final bytes = await _fetch(url);
        await write(url, bytes);
        return bytes;
      } finally {
        // 다음 호출이 다시 확인할 수 있게 진행 기록은 끝나면 지운다.
        // (블록으로 감싸 remove가 돌려주는 진행 중인 작업을 따로 기다리지 않게 한다)
        scheduleMicrotask(() {
          _inFlight.remove(url);
        });
      }
    });
  }

  Future<void> _trim() async {
    final dir = await _directory();
    final files = <File>[
      await for (final entity in dir.list())
        if (entity is File && !entity.path.endsWith('.part')) entity,
    ];
    if (files.length <= maxFiles) return;
    final stats = <File, DateTime>{
      for (final file in files) file: (await file.stat()).modified,
    };
    files.sort((a, b) => stats[a]!.compareTo(stats[b]!));
    for (final file in files.take(files.length - maxFiles)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}

/// 폰에 저장해 두고 쓰는 네트워크 이미지. `NetworkImage` 대신 쓰면 두 번째부터 바로 뜬다.
@immutable
class DiskCachedNetworkImage extends ImageProvider<DiskCachedNetworkImage> {
  const DiskCachedNetworkImage(this.url, {this.scale = 1.0, this.cache});

  final String url;
  final double scale;

  /// 테스트에서 바꿔 끼우기 위한 것. 기본은 [DiskImageCache.instance].
  final DiskImageCache? cache;

  @override
  Future<DiskCachedNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<DiskCachedNetworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector:
          () => <DiagnosticsNode>[
            DiagnosticsProperty<String>('사진 주소', key.url),
          ],
    );
  }

  Future<ui.Codec> _load(
    DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await (key.cache ?? DiskImageCache.instance).readOrFetch(
      key.url,
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      return await decode(buffer);
    } catch (_) {
      // 저장된 파일이 깨져 있으면 지워서 다음에는 새로 받게 한다.
      unawaited(_evict(key));
      rethrow;
    }
  }

  Future<void> _evict(DiskCachedNetworkImage key) async {
    try {
      final cacheInstance = key.cache ?? DiskImageCache.instance;
      final dir = await cacheInstance._directory();
      final name = DiskImageCache.keyFor(key.url);
      if (name == null) return;
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  bool operator ==(Object other) =>
      other is DiskCachedNetworkImage &&
      other.url == url &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'DiskCachedNetworkImage("$url", scale: $scale)';
}
