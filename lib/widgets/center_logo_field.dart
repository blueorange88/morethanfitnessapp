import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/personal_contract_gateway.dart';

typedef CenterLogoPicker = Future<Uint8List?> Function();
typedef CenterLogoUploader = Future<String> Function(Uint8List png);

Future<Uint8List?> _pickLogoBytes() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
  );
  return picked?.readAsBytes();
}

/// 마이페이지 `센터 위치` 아래에 놓는 센터 로고 입력. 올리면 바로 저장되고, 레슨계약서
/// 맨 위의 당사자 표시에 쓰인다.
class CenterLogoField extends StatefulWidget {
  const CenterLogoField({
    super.key,
    required this.uid,
    required this.initialPath,
    this.gateway,
    this.pickLogo,
    this.uploadLogo,
    this.prepareLogo,
    this.loadPreview,
    this.onToast,
    this.textColor,
    this.mutedColor,
    this.borderColor,
  });

  final String uid;
  final String initialPath;
  final PersonalContractGateway? gateway;
  final CenterLogoPicker? pickLogo;
  final CenterLogoUploader? uploadLogo;

  /// 선택한 이미지를 PNG로 바꾸는 함수(테스트용 교체). 기본은 512px 이하 PNG 변환.
  final Future<Uint8List> Function(Uint8List source)? prepareLogo;

  /// 저장된 로고 이미지를 읽는 함수(테스트용 교체). 기본은 Storage 읽기.
  final Future<Uint8List?> Function(String path)? loadPreview;

  /// 결과 안내 문구를 보여 주는 함수. 없으면 SnackBar.
  final void Function(String message)? onToast;

  /// 글씨·테두리 색. 고정 색을 쓰는 화면에서 배경과 맞춰 넘긴다(기본은 앱 테마).
  final Color? textColor;
  final Color? mutedColor;
  final Color? borderColor;

  @override
  State<CenterLogoField> createState() => _CenterLogoFieldState();
}

class _CenterLogoFieldState extends State<CenterLogoField> {
  late final PersonalContractGateway _gateway =
      widget.gateway ?? PersonalContractGateway();
  late String _path = widget.initialPath.trim();
  Uint8List? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (_path.isEmpty) return;
    final bytes = await (widget.loadPreview ?? loadContractLogo)(_path);
    if (!mounted) return;
    setState(() => _preview = bytes);
  }

  void _say(String message) {
    final toast = widget.onToast;
    if (toast != null) {
      toast(message);
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.pickLogo ?? _pickLogoBytes)();
      if (bytes == null) return;
      final png = await (widget.prepareLogo ?? preparePngLogo)(bytes);
      final path = await (widget.uploadLogo ??
          (data) => uploadContractLogo(uid: widget.uid, png: data))(png);
      await _gateway.saveCenterLogo(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _preview = png;
      });
      _say('센터 로고를 저장했어요.');
    } catch (error) {
      if (mounted) {
        _say(
          error is FormatException
              ? '로고 이미지를 읽지 못했어요. 다른 이미지로 시도해 주세요.'
              : contractErrorMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _gateway.saveCenterLogo('');
      if (!mounted) return;
      setState(() {
        _path = '';
        _preview = null;
      });
      _say('센터 로고를 지웠어요.');
    } catch (error) {
      if (mounted) _say(contractErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.textColor ?? theme.colorScheme.onSurface;
    final muted = widget.mutedColor ?? theme.colorScheme.onSurfaceVariant;
    final border = widget.borderColor ?? theme.colorScheme.outlineVariant;
    final hasLogo = _path.isNotEmpty;
    return Row(
      key: const ValueKey<String>('center_logo_field'),
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          alignment: Alignment.center,
          child:
              _preview != null
                  ? Image.memory(
                    _preview!,
                    key: const ValueKey<String>('center_logo_preview'),
                    fit: BoxFit.contain,
                  )
                  : Icon(
                    hasLogo
                        ? Icons.image_outlined
                        : Icons.add_photo_alternate_outlined,
                    color: muted,
                  ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '센터 로고 (선택)',
                style: TextStyle(fontWeight: FontWeight.w800, color: text),
              ),
              const SizedBox(height: 2),
              Text(
                hasLogo ? '레슨계약서 맨 위에 표시돼요.' : '올리면 레슨계약서 맨 위에 표시돼요.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        if (_busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          TextButton(
            key: const ValueKey<String>('center_logo_pick'),
            onPressed: _choose,
            child: Text(hasLogo ? '바꾸기' : '올리기'),
          ),
          if (hasLogo)
            TextButton(
              key: const ValueKey<String>('center_logo_remove'),
              onPressed: _remove,
              child: const Text('지우기'),
            ),
        ],
      ],
    );
  }
}
