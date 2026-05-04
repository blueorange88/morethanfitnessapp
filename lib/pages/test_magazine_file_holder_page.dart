import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

class TestMagazineFileHolderPage extends StatefulWidget {
  const TestMagazineFileHolderPage({super.key});

  @override
  State<TestMagazineFileHolderPage> createState() =>
      _TestMagazineFileHolderPageState();
}

/* -------------------- Demo Models -------------------- */

enum Gender { male, female, unknown }

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.gender,
  });

  final String id;
  final String name;
  final Gender gender;
}

class Group {
  Group({
    required this.id,
    required this.name,
    required this.color,
    List<Member>? members,
  }) : members = members ?? [];

  final String id;
  final String name;
  final Color color;
  final List<Member> members;
}

/* -------------------- Page -------------------- */

class _TestMagazineFileHolderPageState
    extends State<TestMagazineFileHolderPage> {
  late final List<Group> _groups = [
    Group(id: 'g1', name: '그룹 1', color: const Color(0xFF6E8FB0)),
    Group(id: 'g2', name: '그룹 2', color: const Color(0xFF7C6FB8)),
    Group(id: 'g3', name: '그룹 3', color: const Color(0xFF5E9A8B)),
    Group(id: 'g4', name: '그룹 4', color: const Color(0xFFC98B45)),
    Group(id: 'g5', name: '그룹 5', color: const Color(0xFF8A96A7)),
  ];

  late final List<Member> _unassignedMembers = List.generate(
    14,
        (i) => Member(
      id: 'm$i',
      name: '회원 ${i + 1}',
      gender: i % 3 == 0
          ? Gender.female
          : i % 3 == 1
          ? Gender.male
          : Gender.unknown,
    ),
  );

  String? _lastDroppedGroupId;
  String? _lastDroppedMemberId;
  int _dropToken = 0;

  void _moveMemberToGroup(Member member, Group targetGroup) {
    setState(() {
      for (final g in _groups) {
        g.members.removeWhere((m) => m.id == member.id);
      }
      _unassignedMembers.removeWhere((m) => m.id == member.id);

      targetGroup.members.add(member);
      _lastDroppedGroupId = targetGroup.id;
      _lastDroppedMemberId = member.id;
      _dropToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 338,
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE4EB).withOpacity(0.42),
                border: Border(
                  right: BorderSide(
                    color: Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const _LeftHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      children: _groups.map((group) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: DragTarget<Member>(
                              onWillAccept: (data) => data != null,
                              onAccept: (member) =>
                                  _moveMemberToGroup(member, group),
                              builder: (context, candidateData, rejectedData) {
                                return MagazineRackHolder(
                                  group: group,
                                  isHovered: candidateData.isNotEmpty,
                                  lastDroppedGroupId: _lastDroppedGroupId,
                                  lastDroppedMemberId: _lastDroppedMemberId,
                                  dropToken: _dropToken,
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const _RightHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                      itemCount: _unassignedMembers.length,
                      itemBuilder: (context, index) {
                        final member = _unassignedMembers[index];
                        return _DraggableBinderCard(member: member);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Headers -------------------- */

class _LeftHeader extends StatelessWidget {
  const _LeftHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: const Icon(Icons.folder_copy_outlined, size: 19),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '매거진 홀더',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF24323C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightHeader extends StatelessWidget {
  const _RightHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Row(
        children: [
          const Text(
            '바인더 목록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24323C),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Text(
              'LONG PRESS TO DROP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.62),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- Holder -------------------- */

class MagazineRackHolder extends StatelessWidget {
  const MagazineRackHolder({
    super.key,
    required this.group,
    required this.isHovered,
    required this.lastDroppedGroupId,
    required this.lastDroppedMemberId,
    required this.dropToken,
  });

  final Group group;
  final bool isHovered;
  final String? lastDroppedGroupId;
  final String? lastDroppedMemberId;
  final int dropToken;

  @override
  Widget build(BuildContext context) {
    final count = group.members.length;

    return AnimatedScale(
      scale: isHovered ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = math.min(c.maxWidth, 292.0);
          final h = c.maxHeight.clamp(114.0, 136.0);

          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 56,
                    right: 16,
                    bottom: 6,
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color:
                            Colors.black.withOpacity(isHovered ? 0.17 : 0.12),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(10, 9),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HolderBodyPainter(
                        color: group.color,
                        hovered: isHovered,
                      ),
                    ),
                  ),

                  ..._buildVisibleFiles(),

                  Positioned(
                    left: 20,
                    bottom: 22,
                    child: _FrontLabel(
                      name: group.name,
                      count: count,
                    ),
                  ),

                  Positioned(
                    right: 8,
                    top: 8,
                    child: _HolderStatusBadge(
                      text: count == 0
                          ? 'EMPTY'
                          : count < 5
                          ? 'FILED'
                          : 'STACKED',
                    ),
                  ),

                  if (count > 9)
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.90),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          '+${count - 9}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  if (isHovered)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildVisibleFiles() {
    final count = group.members.length;
    if (count == 0) return [];

    final isStacked = count >= 5;
    final visibleCount = math.min(count, 9);

    return List.generate(visibleCount, (index) {
      final member = group.members[index];
      final isNewlyDropped =
          member.id == lastDroppedMemberId && group.id == lastDroppedGroupId;

      final x = isStacked ? 102.0 + index * 8.0 : 96.0 + index * 14.0;
      final y = isStacked ? 22.0 : 20.0 + (index % 3) * 1.6;
      final spineH = isStacked ? 72.0 : 69.0 + (index.isEven ? 4.0 : 0.0);
      final width = isStacked ? 13.0 : 15.0;
      final rotation = isStacked ? 0.0 : (index.isEven ? 0.022 : -0.018);

      return AnimatedPositioned(
        key: ValueKey('${group.id}_${member.id}_$dropToken'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        left: isNewlyDropped ? x - 16 : x,
        bottom: y,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          offset: isNewlyDropped ? const Offset(0.16, 0) : Offset.zero,
          child: Transform.rotate(
            angle: rotation,
            alignment: Alignment.bottomCenter,
            child: _MiniFileSpine(
              width: width,
              height: spineH,
              color: _spineColorFor(member),
              compressed: isStacked,
            ),
          ),
        ),
      );
    });
  }

  static Color _spineColorFor(Member member) {
    const palette = [
      Color(0xFFCAD8E8),
      Color(0xFFB1C7E8),
      Color(0xFFD8D0EF),
      Color(0xFFC9E7DE),
      Color(0xFFEFDAB0),
      Color(0xFFE5C0BC),
    ];
    final hash = member.id.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }
}

/* -------------------- Painters -------------------- */

class _HolderBodyPainter extends CustomPainter {
  _HolderBodyPainter({
    required this.color,
    required this.hovered,
  });

  final Color color;
  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final outerLight = Color.lerp(color, Colors.white, hovered ? 0.22 : 0.16)!;
    final outerMid = Color.lerp(color, Colors.white, 0.05)!;
    final outerDark = Color.lerp(color, Colors.black, 0.16)!;
    final innerDark = Color.lerp(color, Colors.black, 0.28)!;
    final innerDeep = Color.lerp(color, Colors.black, 0.38)!;

    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 뒤판
    final backPanel = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.74,
        size.height * 0.08,
        size.width * 0.15,
        size.height * 0.80,
      ),
      const Radius.circular(5),
    );

    canvas.drawRRect(
      backPanel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [outerLight, outerMid, outerDark],
          stops: const [0.0, 0.56, 1.0],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(backPanel, borderPaint);

    // 바닥판
    final floorPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.86)
      ..lineTo(size.width * 0.74, size.height * 0.86)
      ..lineTo(size.width * 0.89, size.height * 0.88)
      ..lineTo(size.width * 0.19, size.height * 0.88)
      ..close();

    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [innerDark, innerDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(floorPath, borderPaint);

    // 메인 측면 바디 - 박스형 + 사선 상단 컷
    final sideBody = Path()
      ..moveTo(size.width * 0.08, size.height * 0.86)
      ..lineTo(size.width * 0.08, size.height * 0.78)
      ..lineTo(size.width * 0.58, size.height * 0.18)
      ..lineTo(size.width * 0.74, size.height * 0.08)
      ..lineTo(size.width * 0.74, size.height * 0.86)
      ..close();

    canvas.drawPath(
      sideBody,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            outerLight,
            color,
            outerDark,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(sideBody, borderPaint);

    // 내부 공간 어둠
    final interior = Path()
      ..moveTo(size.width * 0.14, size.height * 0.80)
      ..lineTo(size.width * 0.60, size.height * 0.23)
      ..lineTo(size.width * 0.81, size.height * 0.23)
      ..lineTo(size.width * 0.81, size.height * 0.81)
      ..lineTo(size.width * 0.24, size.height * 0.81)
      ..close();

    canvas.drawPath(
      interior,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(hovered ? 0.10 : 0.15),
            Colors.black.withOpacity(hovered ? 0.18 : 0.24),
          ],
        ).createShader(Offset.zero & size),
    );

    // 앞턱
    final frontLip = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..lineTo(size.width * 0.14, size.height * 0.86)
      ..lineTo(size.width * 0.20, size.height * 0.86)
      ..lineTo(size.width * 0.14, size.height * 0.78)
      ..close();

    canvas.drawPath(
      frontLip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, hovered ? 0.24 : 0.18)!,
            Color.lerp(color, Colors.white, 0.06)!,
            Color.lerp(color, Colors.black, 0.14)!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(frontLip, borderPaint);

    // 뒤판 슬롯
    _drawBackSlots(canvas, size);

    // 측면 슬롯
    _drawSlopeSlots(canvas, size);

    // 상단 하이라이트
    final rimPaint = Paint()
      ..color = Colors.white.withOpacity(hovered ? 0.40 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.18),
      Offset(size.width * 0.74, size.height * 0.08),
      rimPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.08),
      Offset(size.width * 0.89, size.height * 0.08),
      rimPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.78),
      Offset(size.width * 0.14, size.height * 0.78),
      rimPaint,
    );
  }

  void _drawBackSlots(Canvas canvas, Size size) {
    final slotPaint = Paint()
      ..color = Colors.black.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    final startX = size.width * 0.785;
    final startY = size.height * 0.18;
    final slotW = size.width * 0.024;
    final slotH = size.height * 0.10;
    final dx = size.width * 0.036;
    final dy = size.height * 0.135;

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        final rect = Rect.fromLTWH(
          startX + col * dx,
          startY + row * dy,
          slotW,
          slotH,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          slotPaint,
        );
      }
    }
  }

  void _drawSlopeSlots(Canvas canvas, Size size) {
    final slotPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      final t = i / 5;
      final x = lerpDouble(size.width * 0.26, size.width * 0.54, t)!;
      final y = lerpDouble(size.height * 0.72, size.height * 0.30, t)!;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-0.87);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.11,
            height: 7,
          ),
          const Radius.circular(999),
        ),
        slotPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HolderBodyPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.hovered != hovered;
  }
}

/* -------------------- File Spine -------------------- */

class _MiniFileSpine extends StatelessWidget {
  const _MiniFileSpine({
    required this.width,
    required this.height,
    required this.color,
    required this.compressed,
  });

  final double width;
  final double height;
  final Color color;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(color, Colors.white, 0.24)!,
            color,
            Color.lerp(color, Colors.black, 0.10)!,
          ],
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(compressed ? 0.05 : 0.10),
            blurRadius: compressed ? 2 : 4,
            offset: const Offset(-1, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 2,
            top: 8,
            bottom: 8,
            child: Container(
              width: 1.6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.58),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (!compressed)
            Positioned(
              left: -3,
              top: 10,
              child: Container(
                width: 8,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------- Holder Info -------------------- */

class _FrontLabel extends StatelessWidget {
  const _FrontLabel({
    required this.name,
    required this.count,
  });

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.94),
              shadows: const [
                Shadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Text(
              '$count FILES',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HolderStatusBadge extends StatelessWidget {
  const _HolderStatusBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Color(0xFF25323B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/* -------------------- Draggable Card -------------------- */

class _DraggableBinderCard extends StatelessWidget {
  const _DraggableBinderCard({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final accent = switch (member.gender) {
      Gender.male => const Color(0xFFCAE0FF),
      Gender.female => const Color(0xFFFFD5E4),
      Gender.unknown => const Color(0xFFD8F4E8),
    };

    final card = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, 0.15)!,
                  accent,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Icon(
              member.gender == Gender.male
                  ? Icons.person
                  : member.gender == Gender.female
                  ? Icons.person_2
                  : Icons.perm_identity,
              color: Colors.black.withOpacity(0.64),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              member.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            Icons.drag_indicator,
            color: Colors.black.withOpacity(0.22),
          ),
        ],
      ),
    );

    return LongPressDraggable<Member>(
      data: member,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: Opacity(
            opacity: 0.88,
            child: Transform.scale(
              scale: 1.02,
              child: card,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.30,
        child: card,
      ),
      child: card,
    );
  }
}