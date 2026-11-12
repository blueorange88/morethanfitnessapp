import 'package:flutter/material.dart';

/// 홈 레슨 종류 색과 계약서 바인더 색이 함께 쓰는 팔레트.
const List<Color> kLessonTypePalette = [
  Color(0xFF4F46E5), // indigo
  Color(0xFF7C3AED), // purple
  Color(0xFF2563EB), // blue
  Color(0xFF0F766E), // teal
  Color(0xFF16A34A), // green
  Color(0xFFF97316), // orange
  Color(0xFFDB2777), // pink
  Color(0xFFD64545), // red
  Color(0xFF8B5E3C), // brown
  Color(0xFF1F3A8A), // navy
];

/// `#RRGGBB`(또는 `RRGGBB`, `AARRGGBB`)를 색으로. 읽을 수 없으면 null.
Color? lessonTypeColorTryParse(String hex) {
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// 레슨 종류 색 위에 올리는 글씨 색: 흰 글씨와 짙은 글씨 중 바탕색과 대비가 더 큰 쪽.
Color lessonTypeInkColor(Color base) {
  const dark = Color(0xFF1F2937);
  final l = base.computeLuminance();
  final whiteContrast = 1.05 / (l + 0.05);
  final darkContrast = (l + 0.05) / (dark.computeLuminance() + 0.05);
  return whiteContrast >= darkContrast ? Colors.white : dark;
}

String lessonTypeColorToHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return '#${hex.toUpperCase()}';
}

/// 레슨 종류 색을 직접 고르는 대화상자: 색상·선명도·밝기 막대와 `#RRGGBB` 입력.
class LessonTypeColorDialog extends StatefulWidget {
  const LessonTypeColorDialog({
    super.key,
    required this.title,
    required this.initial,
  });

  final String title;
  final Color initial;

  @override
  State<LessonTypeColorDialog> createState() => _LessonTypeColorDialogState();
}

class _LessonTypeColorDialogState extends State<LessonTypeColorDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hex = TextEditingController(text: _hexOf(_hsv.toColor()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  static String _hexOf(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _setHsv(HSVColor next) {
    setState(() {
      _hsv = next;
      _hexError = null;
      _hex.text = _hexOf(next.toColor());
    });
  }

  void _onHexChanged(String text) {
    final cleaned = text.replaceFirst('#', '').trim();
    final value =
        RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)
            ? int.tryParse(cleaned, radix: 16)
            : null;
    setState(() {
      if (value == null) {
        _hexError = '6자리 색 코드(예: 2F6FD6)';
        return;
      }
      _hexError = null;
      _hsv = HSVColor.fromColor(Color(0xFF000000 | value));
    });
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged, {
    Key? key,
  }) {
    return Row(
      children: [
        SizedBox(width: 44, child: Text(label)),
        Expanded(
          child: Slider(
            key: key,
            value: value.clamp(0, max).toDouble(),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey<String>('lesson_type_color_preview'),
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 8),
            _slider(
              '색상',
              _hsv.hue,
              360,
              (v) => _setHsv(_hsv.withHue(v == 360 ? 359.99 : v)),
              key: const ValueKey<String>('lesson_type_color_hue'),
            ),
            _slider(
              '선명도',
              _hsv.saturation,
              1,
              (v) => _setHsv(_hsv.withSaturation(v)),
              key: const ValueKey<String>('lesson_type_color_sat'),
            ),
            _slider(
              '밝기',
              _hsv.value,
              1,
              (v) => _setHsv(_hsv.withValue(v)),
              key: const ValueKey<String>('lesson_type_color_val'),
            ),
            TextField(
              key: const ValueKey<String>('lesson_type_color_hex'),
              controller: _hex,
              onChanged: _onHexChanged,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                prefixText: '#',
                labelText: '색 코드',
                errorText: _hexError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey<String>('lesson_type_color_apply'),
          onPressed:
              _hexError == null ? () => Navigator.of(context).pop(color) : null,
          child: const Text('적용'),
        ),
      ],
    );
  }
}
