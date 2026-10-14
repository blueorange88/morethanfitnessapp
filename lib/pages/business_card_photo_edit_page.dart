import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/my_header_business_card.dart';

class BusinessCardPhotoResult {
  const BusinessCardPhotoResult({
    required this.alignX,
    required this.alignY,
    required this.scale,
    this.newPhotoBytes,
  });

  final double alignX;
  final double alignY;
  final double scale;
  final Uint8List? newPhotoBytes;
}

Future<BusinessCardPhotoResult?> showBusinessCardPhotoEditSheet(
  BuildContext context, {
  required String name,
  required String nameEn,
  required String gymName,
  required String specialty,
  required String phone,
  required String address,
  Uint8List? photoBytes,
  String? photoUrl,
  double initialAlignX = 0,
  double initialAlignY = 0,
  double initialScale = 1.0,
}) {
  return showModalBottomSheet<BusinessCardPhotoResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.1,
          ),
          child: BusinessCardPhotoEditSheet(
            name: name,
            nameEn: nameEn,
            gymName: gymName,
            specialty: specialty,
            phone: phone,
            address: address,
            photoBytes: photoBytes,
            photoUrl: photoUrl,
            initialAlignX: initialAlignX,
            initialAlignY: initialAlignY,
            initialScale: initialScale,
          ),
        ),
  );
}

class BusinessCardPhotoEditSheet extends StatefulWidget {
  const BusinessCardPhotoEditSheet({
    required this.name,
    required this.nameEn,
    required this.gymName,
    required this.specialty,
    required this.phone,
    required this.address,
    this.photoBytes,
    this.photoUrl,
    this.initialAlignX = 0,
    this.initialAlignY = 0,
    this.initialScale = 1.0,
    super.key,
  });

  final String name;
  final String nameEn;
  final String gymName;
  final String specialty;
  final String phone;
  final String address;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final double initialAlignX;
  final double initialAlignY;
  final double initialScale;

  @override
  State<BusinessCardPhotoEditSheet> createState() =>
      _BusinessCardPhotoEditSheetState();
}

class _BusinessCardPhotoEditSheetState
    extends State<BusinessCardPhotoEditSheet> {
  static const double _minScale = 0.4;
  static const double _maxScale = 4.0;

  final _picker = ImagePicker();

  late Uint8List? _photoBytes = widget.photoBytes;
  late String? _photoUrl = widget.photoUrl;
  late double _alignX = widget.initialAlignX;
  late double _alignY = widget.initialAlignY;
  late double _scale = widget.initialScale;
  double? _scaleGestureStart;
  bool _photoChanged = false;

  void _handleScaleStart() {
    _scaleGestureStart = _scale;
  }

  void _handleDrag(double dx, double dy, double cumulativeScale) {
    setState(() {
      _alignX = (_alignX + dx).clamp(-1.0, 1.0);
      _alignY = (_alignY + dy).clamp(-1.0, 1.0);
      final base = _scaleGestureStart ?? _scale;
      _scale = (base * cumulativeScale).clamp(_minScale, _maxScale);
    });
  }

  void _resetAdjustment() {
    setState(() {
      _alignX = widget.initialAlignX;
      _alignY = widget.initialAlignY;
      _scale = widget.initialScale;
    });
  }

  Future<void> _pickDifferentPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() {
      _photoBytes = bytes;
      _photoUrl = null;
      _photoChanged = true;
      _alignX = 0;
      _alignY = 0;
      _scale = 1.0;
    });
  }

  void _save() {
    Navigator.of(context).pop(
      BusinessCardPhotoResult(
        alignX: _alignX,
        alignY: _alignY,
        scale: _scale,
        newPhotoBytes: _photoChanged ? _photoBytes : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: const Color(0xFF0B1220),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        '사진 위치 조정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MyHeaderBusinessCard(
                  name: widget.name,
                  nameEn: widget.nameEn,
                  gymName: widget.gymName,
                  specialty: widget.specialty,
                  phone: widget.phone,
                  address: widget.address,
                  photoBytes: _photoBytes,
                  photoUrl: _photoUrl,
                  photoAlignX: _alignX,
                  photoAlignY: _alignY,
                  photoScale: _scale,
                  onTapPhoto: () {},
                  onScaleGestureStart: _handleScaleStart,
                  onDragPhoto: _handleDrag,
                  showPositionHint: false,
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pan_tool_alt_outlined,
                      color: Colors.white54,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '드래그로 위치를, 두 손가락으로 축소·확대를 조정하세요',
                        style: TextStyle(color: Colors.white54, fontSize: 12.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDifferentPhoto,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('다른 사진 선택'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: _resetAdjustment,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('원래대로'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
