import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/anatomy_log.dart';
import '../models/body_map_data.dart';
import 'body_map_canvas.dart';

/// 회원에게 보낼 이미지에 넣을 수 있는 기록만 남긴다. 통증·주의·가동성과 내부 메모는
/// 건강 정보라 이미지에 들어가면 안 되므로 운동 기록만 통과시킨다.
List<AnatomyLogRecord> shareSafeRecords(Iterable<AnatomyLogRecord> records) => [
  for (final record in records)
    if (record.recordType == AnatomyRecordType.exercise) record,
];

/// 공유 이미지의 운동 한 줄(이름 + `5 X 60kg | 15회`).
class ShareExerciseLine {
  const ShareExerciseLine({required this.name, required this.summary});

  final String name;
  final String summary;
}

/// 같은 운동의 세트를 합쳐 기록한 순서대로 한 줄씩 만든다.
List<ShareExerciseLine> shareExerciseLines(Iterable<AnatomyLogRecord> records) {
  final ordered =
      shareSafeRecords(records).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final setsByName = <String, List<AnatomySet>>{};
  for (final record in ordered) {
    final name = record.exerciseName.trim();
    if (name.isEmpty) continue;
    setsByName.putIfAbsent(name, () => <AnatomySet>[]).addAll(record.sets);
  }
  return [
    for (final entry in setsByName.entries)
      ShareExerciseLine(
        name: entry.key,
        summary: anatomySetsSummary(entry.value),
      ),
  ];
}

/// 회원에게 보내는 레슨 요약 이미지(어두운 배경, 운동 목록 + 운동한 부위 앞·뒤).
/// 통증·주의·가동성은 넣지 않는다.
class LessonShareCard extends StatelessWidget {
  const LessonShareCard({
    super.key,
    required this.dateText,
    required this.timeText,
    required this.subtitle,
    required this.lines,
    this.records = const <AnatomyLogRecord>[],
    this.gender = BodyGender.unspecified,
    this.mapData,
    this.bodyText = '',
    this.memo = '',
  });

  static const double width = 360;
  static const int maxLines = 8;

  final String dateText;
  final String timeText;
  final String subtitle;
  final List<ShareExerciseLine> lines;

  /// 몸 그림에 칠할 기록. 안전을 위해 이 위젯에서도 운동 기록만 쓴다.
  final List<AnatomyLogRecord> records;
  final BodyGender gender;

  /// 몸 그림 데이터. 없으면(텍스트·카테고리 레슨) 몸 그림을 그리지 않는다.
  final BodyMapData? mapData;

  /// 운동 목록 아래에 보여줄 글(텍스트 레슨의 공개 내용 등).
  final String bodyText;
  final String memo;

  @override
  Widget build(BuildContext context) {
    final visible = lines.take(maxLines).toList();
    final hidden = lines.length - visible.length;
    final safe = shareSafeRecords(records);
    final trimmedMemo = memo.trim();
    final trimmedBody = bodyText.trim();
    final map = mapData;
    return Theme(
      data: ThemeData.dark(),
      child: Container(
        key: const ValueKey<String>('share_card'),
        width: width,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        color: const Color(0xFF0B0F17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'More Than Fitness',
                  style: TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFB6BDC9), fontSize: 13),
            ),
            const SizedBox(height: 18),
            for (final line in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      line.summary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '외 $hidden개 운동',
                  style: const TextStyle(
                    color: Color(0xFFB6BDC9),
                    fontSize: 12,
                  ),
                ),
              ),
            if (trimmedBody.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                trimmedBody,
                key: const ValueKey<String>('share_card_body'),
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (map != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final view in BodyView.values) ...[
                    SizedBox(
                      width: 150,
                      child: IgnorePointer(
                        child: BodyMapCanvas(
                          key: ValueKey<String>('share_map_${view.name}'),
                          scene: map.sceneFor(gender, view),
                          viewBox: map.viewBox,
                          records: safe,
                          onTapped: (_) {},
                          pinsOnly: true,
                        ),
                      ),
                    ),
                    if (view == BodyView.front) const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
            if (trimmedMemo.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                key: const ValueKey<String>('share_card_memo'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trimmedMemo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 공유 이미지 미리보기와 짧은 메모(20자) 입력, 공유 버튼이 있는 시트.
Future<void> showLessonShareSheet(
  BuildContext context, {
  required String dateText,
  required String timeText,
  required String subtitle,
  List<AnatomyLogRecord> records = const <AnatomyLogRecord>[],
  List<ShareExerciseLine>? lines,
  String bodyText = '',
  String notice = '운동 내용만 이미지로 보내요. 통증·주의·가동성은 들어가지 않아요.',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (_) => LessonShareSheet(
          dateText: dateText,
          timeText: timeText,
          subtitle: subtitle,
          records: records,
          lines: lines,
          bodyText: bodyText,
          notice: notice,
        ),
  );
}

class LessonShareSheet extends StatefulWidget {
  const LessonShareSheet({
    super.key,
    required this.dateText,
    required this.timeText,
    required this.subtitle,
    this.records = const <AnatomyLogRecord>[],
    this.lines,
    this.bodyText = '',
    this.notice = '운동 내용만 이미지로 보내요. 통증·주의·가동성은 들어가지 않아요.',
    this.shareImage,
  });

  final String dateText;
  final String timeText;
  final String subtitle;
  final List<AnatomyLogRecord> records;

  /// 운동 줄을 직접 줄 때(카테고리 레슨). 없으면 [records] 로 만든다.
  final List<ShareExerciseLine>? lines;

  /// 운동 목록 아래에 보여줄 글(텍스트 레슨).
  final String bodyText;

  /// 시트 위쪽 안내 문구.
  final String notice;

  /// 만든 이미지를 보내는 동작(PNG 바이트). 기본은 휴대폰 공유 창이고, 테스트에서 바꾼다.
  final Future<void> Function(List<int> pngBytes)? shareImage;

  static const int memoMaxLength = 20;

  @override
  State<LessonShareSheet> createState() => _LessonShareSheetState();
}

class _LessonShareSheetState extends State<LessonShareSheet> {
  final GlobalKey _captureKey = GlobalKey();
  final TextEditingController _memo = TextEditingController();
  // 몸 그림은 아나토미 기록이 있을 때만 쓴다(텍스트·카테고리 레슨은 불러오지 않는다).
  late final Future<BodyMapData>? _mapFuture =
      widget.records.isEmpty ? null : BodyMapData.load();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _memo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  BodyGender get _gender {
    for (final record in widget.records) {
      if (record.bodyGender != BodyGender.unspecified) return record.bodyGender;
    }
    return BodyGender.unspecified;
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      final bytes = data.buffer.asUint8List();
      final custom = widget.shareImage;
      if (custom != null) {
        await custom(bytes);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/lesson_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 보내지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _capture(BodyMapData? data) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: RepaintBoundary(
          key: _captureKey,
          child: LessonShareCard(
            dateText: widget.dateText,
            timeText: widget.timeText,
            subtitle: widget.subtitle,
            lines: widget.lines ?? shareExerciseLines(widget.records),
            records: widget.records,
            gender: _gender,
            mapData: data,
            bodyText: widget.bodyText,
            memo: _memo.text,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '회원에게 레슨일지 보내기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              widget.notice,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (_mapFuture == null)
              _capture(null)
            else
              FutureBuilder<BodyMapData>(
                future: _mapFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) {
                    return const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _capture(data);
                },
              ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey<String>('share_memo'),
              controller: _memo,
              maxLength: LessonShareSheet.memoMaxLength,
              decoration: const InputDecoration(
                labelText: '한마디 (선택)',
                hintText: '오늘 무릎 컨디션 좋았어요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey<String>('share_send'),
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(_sending ? '만드는 중…' : '이미지 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
