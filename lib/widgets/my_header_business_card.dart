import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MyHeaderBusinessCard extends StatelessWidget {
  const MyHeaderBusinessCard({
    required this.name,
    required this.nameEn,
    required this.gymName,
    required this.specialty,
    required this.phone,
    required this.address,
    this.photoBytes,
    this.photoUrl,
    this.photoAlignX = 0,
    this.photoAlignY = 0,
    this.photoScale = 1.0,
    this.onTapPhoto,
    this.onLongPressPhoto,
    this.onScaleGestureStart,
    this.onDragPhoto,
    this.showPositionHint = true,
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
  final double photoAlignX;
  final double photoAlignY;
  final double photoScale;
  final VoidCallback? onTapPhoto;
  final VoidCallback? onLongPressPhoto;
  final VoidCallback? onScaleGestureStart;
  final void Function(double dx, double dy, double cumulativeScale)?
  onDragPhoto;
  final bool showPositionHint;

  ImageProvider<Object>? get _photoImage {
    if (photoBytes != null) return MemoryImage(photoBytes!);
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return NetworkImage(photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.78,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF0D1117)),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MyHeaderPhotoAreaPainter(
                  photoBg: const Color(0xFF1A2332),
                ),
              ),
            ),
            if (_photoImage != null)
              Positioned.fill(
                child: ClipPath(
                  clipper: const _MyHeaderPhotoAreaClipper(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      return Transform.translate(
                        offset: Offset(
                          photoAlignX * size.width,
                          photoAlignY * size.height,
                        ),
                        child: Transform.scale(
                          scale: photoScale,
                          child: Image(
                            image: _photoImage!,
                            fit: BoxFit.contain,
                            width: size.width,
                            height: size.height,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(painter: _MyHeaderSlashLinePainter()),
            ),
            if (onTapPhoto != null)
              Positioned.fill(
                child: ClipPath(
                  clipper: const _MyHeaderPhotoAreaClipper(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      final canDrag =
                          _photoImage != null && onDragPhoto != null;
                      return GestureDetector(
                        onScaleStart:
                            !canDrag
                                ? null
                                : (_) => onScaleGestureStart?.call(),
                        onScaleUpdate:
                            !canDrag
                                ? null
                                : (details) {
                                  final dx =
                                      size.width > 0
                                          ? details.focalPointDelta.dx /
                                              size.width
                                          : 0.0;
                                  final dy =
                                      size.height > 0
                                          ? details.focalPointDelta.dy /
                                              size.height
                                          : 0.0;
                                  onDragPhoto!(dx, dy, details.scale);
                                },
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onTapPhoto,
                            onLongPress: onLongPressPhoto,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (onTapPhoto != null && _photoImage == null)
              Positioned(
                right: 18,
                bottom: 18,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.36),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: Colors.white70,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '사진 추가',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (showPositionHint && onTapPhoto != null && _photoImage != null)
              Positioned(
                right: 18,
                bottom: 18,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.36),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '탭하여 위치 조정',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 0, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (gymName.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              gymName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        if (nameEn.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            nameEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        if (specialty.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(
                                  0xFF38BDF8,
                                ).withOpacity(0.28),
                              ),
                            ),
                            child: Text(
                              specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF7DD3FC),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          color: Colors.white.withOpacity(0.12),
                          thickness: 0.5,
                        ),
                        const SizedBox(height: 8),
                        if (phone.isNotEmpty)
                          _MyHeaderContactRow(label: 'TEL', value: phone),
                        if (address.isNotEmpty)
                          _MyHeaderContactRow(label: 'ADD', value: address),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 18,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyHeaderContactRow extends StatelessWidget {
  const _MyHeaderContactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyHeaderPhotoAreaClipper extends CustomClipper<Path> {
  const _MyHeaderPhotoAreaClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.64, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.55, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MyHeaderPhotoAreaPainter extends CustomPainter {
  const _MyHeaderPhotoAreaPainter({required this.photoBg});

  final Color photoBg;

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(size.width * 0.64, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width * 0.55, size.height)
          ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = photoBg
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _MyHeaderPhotoAreaPainter oldDelegate) {
    return oldDelegate.photoBg != photoBg;
  }
}

class _MyHeaderSlashLinePainter extends CustomPainter {
  const _MyHeaderSlashLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x1 = size.width * 0.64;
    final x2 = size.width * 0.55;

    final paint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x1, 0),
            Offset(x2, size.height),
            [
              const Color(0xFF38BDF8).withOpacity(0.1),
              const Color(0xFF38BDF8),
              const Color(0xFF9333EA),
              const Color(0xFF38BDF8).withOpacity(0.1),
            ],
            [0.0, 0.28, 0.72, 1.0],
          )
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x1, 0), Offset(x2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
