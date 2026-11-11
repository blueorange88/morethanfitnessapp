import 'package:flutter/material.dart';

import '../utils/lesson_contract/signature_strokes.dart';

/// 계약서 서명판을 띄우고 서명(획)을 돌려준다. 취소하면 null.
typedef ContractSignatureCapture =
    Future<Strokes?> Function(BuildContext context, {required String title});

Future<Strokes?> showContractSignaturePad(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<Strokes>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (_) => _SignaturePadSheet(title: title),
  );
}

/// 손가락으로 서명하는 판. 서명 칸은 흰 바탕에 검은 글씨로 고정한다.
class _SignaturePadSheet extends StatefulWidget {
  const _SignaturePadSheet({required this.title});

  final String title;

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  final List<Offset?> _points = [];
  Size _canvas = Size.zero;

  Strokes get _strokes => strokesFromOffsets(_points, _canvas);

  bool get _ready => isMeaningfulSignature(_strokes);

  void _add(Offset position) {
    final size = _canvas;
    if (size.isEmpty) return;
    setState(() {
      _points.add(
        Offset(
          position.dx.clamp(0, size.width),
          position.dy.clamp(0, size.height),
        ),
      );
    });
  }

  void _end() => setState(() => _points.add(null));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = (MediaQuery.of(context).size.width - 32).clamp(240.0, 480.0);
    final height = width * 0.45;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text('아래 칸에 손가락으로 서명해 주세요.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Center(
              child: Container(
                key: const ValueKey<String>('signature_pad_canvas'),
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF3A3A3A)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _canvas = constraints.biggest;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _add(d.localPosition),
                      onPanUpdate: (d) => _add(d.localPosition),
                      onPanEnd: (_) => _end(),
                      onTapUp: (d) {
                        _add(d.localPosition);
                        _end();
                      },
                      child: Stack(
                        children: [
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 24,
                            child: Container(
                              height: 1,
                              color: const Color(0xFFD1D5DB),
                            ),
                          ),
                          CustomPaint(
                            painter: _PadPainter(List<Offset?>.of(_points)),
                            child: const SizedBox.expand(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  key: const ValueKey<String>('signature_pad_cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey<String>('signature_pad_clear'),
                  onPressed:
                      _points.isEmpty ? null : () => setState(_points.clear),
                  child: const Text('지우기'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey<String>('signature_pad_confirm'),
                  onPressed:
                      _ready ? () => Navigator.of(context).pop(_strokes) : null,
                  child: const Text('서명 완료'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF111111)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      if (current == null) continue;
      final next = i + 1 < points.length ? points[i + 1] : null;
      if (next != null) {
        canvas.drawLine(current, next, paint);
      } else if (i == 0 || points[i - 1] == null) {
        canvas.drawCircle(current, 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PadPainter oldDelegate) => true;
}
