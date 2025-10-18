import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Top-view cabinet with React/Motion-like interactions:
/// - Perspective: slight top view + right-side body (drawer slides out to the left/front)
/// - Drawer: moves forward on Z (scale up slightly + tiny rotateZ tilt)
/// - Inside: horizontal groups of mini vertical binders (indexed), with long-press status menu
/// - Double-tap on a binder opens a detailed modal
/// - Tap outside closes drawers and clears selections

// ===== Camera / perspective =====
const double kViewRotY = -0.34; // negative => right body, drawer opens to the left side
const double kViewRotX = -0.14; // slight top-view (looking down)
const double kPerspective = 0.0016;

// Drawer small Z-tilt for “card” feel
const double kDrawerRotZDeg = -2.5;

// ===== Document model =====
enum DocumentStatus { active, onHold, expired }

class Document {
  final String id;
  final String name;
  final int index; // grouping index / tab number
  DocumentStatus status;
  Document({
    required this.id,
    required this.name,
    required this.index,
    this.status = DocumentStatus.active,
  });
}

class MtfDrawerPage extends StatelessWidget {
  const MtfDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Cabinet Demo (Top-view + Motion Angle)'),
        backgroundColor: const Color(0xFF111316),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(child: Cabinet3Drawers()),
    );
  }
}

/* ──────────────────────────────────────────────────────────────
 *  Cabinet (3 drawers)
 * ────────────────────────────────────────────────────────────*/

class Cabinet3Drawers extends StatefulWidget {
  const Cabinet3Drawers({super.key});

  @override
  State<Cabinet3Drawers> createState() => _Cabinet3DrawersState();
}

class _Cabinet3DrawersState extends State<Cabinet3Drawers> {
  int openIndex = -1; // -1 = all closed

  // Demo documents (replace with your data)
  final List<Document> _docs = [
    Document(id: 'd1', name: 'PROJECTS', index: 1, status: DocumentStatus.active),
    Document(id: 'd2', name: 'INVOICE',  index: 2, status: DocumentStatus.onHold),
    Document(id: 'd3', name: 'HISTORY',  index: 3, status: DocumentStatus.active),
    Document(id: 'd4', name: 'NOTES',    index: 4, status: DocumentStatus.expired),
    Document(id: 'd5', name: 'REPORTS',  index: 1, status: DocumentStatus.active),
    Document(id: 'd6', name: 'CLIENTS',  index: 2, status: DocumentStatus.active),
  ];

  void _onStatusChange(String docId, DocumentStatus st) {
    setState(() {
      final i = _docs.indexWhere((d) => d.id == docId);
      if (i != -1) _docs[i].status = st;
    });
  }

  void _onOpenDocument(Document doc) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _DocumentDetailCard(doc: doc, onClose: () => Navigator.pop(context)),
      ),
    );
  }

  void _closeAll() {
    setState(() {
      openIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    const shell = Color(0xFF161A20);
    const face = Color(0xFF1E232B);

    const width = 300.0;
    const height = 460.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _closeAll, // tap outside => close everything
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, kPerspective)
          ..rotateY(kViewRotY)
          ..rotateX(kViewRotX),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: shell,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 20)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: List.generate(3, (i) {
                final slotH = (height - 36) / 3;
                final top = 12 + i * slotH;
                final faceH = slotH - 12;

                // Lower drawers come out a bit further (depth perspective)
                final depthMax = 116.0 - i * 8.0;

                return Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: _DrawerRail(
                    faceHeight: faceH,
                    colorFace: face,
                    depthMax: depthMax,
                    isOpen: openIndex == i,
                    onTap: () {
                      setState(() {
                        openIndex = (openIndex == i) ? -1 : i;
                      });
                    },
                    builder: (progress) => _InsideBinders(
                      progress: progress,
                      docs: _docs,
                      onStatusChange: _onStatusChange,
                      onOpen: _onOpenDocument,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/* ─ Drawer Rail (each drawer face and motion) ─ */

class _DrawerRail extends StatefulWidget {
  const _DrawerRail({
    required this.faceHeight,
    required this.colorFace,
    required this.depthMax,
    required this.isOpen,
    required this.onTap,
    required this.builder,
  });

  final double faceHeight;
  final Color colorFace;
  final double depthMax;
  final bool isOpen;
  final VoidCallback onTap;
  final Widget Function(double progress) builder; // 0..1

  @override
  State<_DrawerRail> createState() => _DrawerRailState();
}

class _DrawerRailState extends State<_DrawerRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _t = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    if (widget.isOpen) _ac.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _DrawerRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      widget.isOpen ? _ac.forward() : _ac.reverse();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(10);

    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final p = _t.value;                 // 0..1
        final depth = -widget.depthMax * p; // toward camera
        final scale = 1.0 + 0.07 * p;       // slight enlarge
        final liftY = -3.0 * p;             // small lift
        final tiltX = -0.012 * p;           // tiny friction feel
        final shadow = [
          BoxShadow(
            color: Colors.black.withOpacity(0.14 + 0.16 * p),
            blurRadius: 10 + 24 * p,
            offset: Offset(0, 8 + 12 * p),
          ),
        ];

        final m = Matrix4.identity()
          ..setEntry(3, 2, kPerspective)
          ..translate(0.0, liftY, depth)
          ..scale(scale)
          ..rotateX(tiltX)
          ..rotateZ(kDrawerRotZDeg * math.pi / 180); // subtle Z-tilt

        return GestureDetector(
          onTap: widget.onTap,
          child: Transform(
            alignment: Alignment.center,
            transform: m,
            child: Container(
              height: widget.faceHeight,
              decoration: BoxDecoration(
                color: widget.colorFace,
                borderRadius: r,
                border: Border.all(color: const Color(0xFF2B3038)),
                boxShadow: shadow,
              ),
              child: Stack(
                children: [
                  const Align(alignment: Alignment.center, child: _Handle()),
                  const Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: ColoredBox(color: Color(0xFF232831), child: SizedBox(height: 2)),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: widget.builder(p), // pass progress into inside view
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF20252D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E343E)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFB9C2CE),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/* ─ Inside view: horizontal grouped mini binders (React Drawer.tsx parity) ─ */

class _InsideBinders extends StatelessWidget {
  const _InsideBinders({
    required this.progress,       // 0..1 drawer open
    required this.docs,
    required this.onStatusChange,
    required this.onOpen,
  });

  final double progress;
  final List<Document> docs;
  final void Function(String, DocumentStatus) onStatusChange;
  final void Function(Document) onOpen;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.25) return const SizedBox.shrink();

    // Group by index (like React)
    final Map<int, List<Document>> grouped = {};
    for (final d in docs) {
      grouped.putIfAbsent(d.index, () => []).add(d);
    }
    final keys = grouped.keys.toList()..sort();

    // Fade/appear timing based on progress (stagger-ish)
    final fade = Curves.easeOut.transform(((progress - 0.25) / 0.20).clamp(0.0, 1.0));

    return Opacity(
      opacity: fade,
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemCount: keys.length,
          itemBuilder: (context, groupIdx) {
            final key = keys[groupIdx];
            final list = grouped[key]!;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(list.length, (i) {
                final doc = list[i];
                final delay = i * 0.05; // small stagger per group
                final lift = 6.0 * i;   // stacked height

                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: _MiniBinderTile(
                    doc: doc,
                    showIndex: i == 0,
                    delay: delay,
                    onTap: () => onOpen(doc),
                    onStatus: (st) => onStatusChange(doc.id, st),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/* ─ Small vertical binder tile (React DocumentFile.tsx parity) ─ */

class _MiniBinderTile extends StatefulWidget {
  const _MiniBinderTile({
    required this.doc,
    required this.onTap,
    required this.onStatus,
    required this.delay,
    required this.showIndex,
  });

  final Document doc;
  final VoidCallback onTap;
  final void Function(DocumentStatus) onStatus;
  final double delay;     // seconds-like (e.g., 0.05)
  final bool showIndex;

  @override
  State<_MiniBinderTile> createState() => _MiniBinderTileState();
}

class _MiniBinderTileState extends State<_MiniBinderTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController ac;
  late final Animation<double> t;
  bool hovered = false;

  @override
  void initState() {
    super.initState();
    ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    t = CurvedAnimation(parent: ac, curve: Curves.easeOutBack);
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) ac.forward();
    });
  }

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  Color _start(DocumentStatus s) => switch (s) {
    DocumentStatus.expired => const Color(0xFFEF5350),
    DocumentStatus.onHold  => const Color(0xFFFFD54F),
    _                      => const Color(0xFF42A5F5),
  };
  Color _end(DocumentStatus s) => switch (s) {
    DocumentStatus.expired => const Color(0xFFE53935),
    DocumentStatus.onHold  => const Color(0xFFFBC02D),
    _                      => const Color(0xFF1E88E5),
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.doc.status;

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit:  (_) => setState(() => hovered = false),
      child: ScaleTransition(
        scale: Tween(begin: 0.0, end: 1.0).animate(t),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPressStart: (d) async {
            // long-press context menu (status change)
            final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
            final pos = RelativeRect.fromLTRB(
              d.globalPosition.dx, d.globalPosition.dy,
              overlay.size.width - d.globalPosition.dx,
              overlay.size.height - d.globalPosition.dy,
            );
            final pick = await showMenu<DocumentStatus>(
              context: context,
              position: pos,
              items: const [
                PopupMenuItem(value: DocumentStatus.expired, child: _MenuItem(icon: Icons.cancel, text: '만료회원', color: Colors.red)),
                PopupMenuItem(value: DocumentStatus.onHold,  child: _MenuItem(icon: Icons.schedule, text: '휴강회원', color: Colors.orange)),
                PopupMenuItem(value: DocumentStatus.active,  child: _MenuItem(icon: Icons.check_circle, text: '활성 복구', color: Colors.blue)),
              ],
            );
            if (pick != null) widget.onStatus(pick);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.identity()..translate(0.0, hovered ? -6.0 : 0.0),
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_start(s), _end(s)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(6), bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(hovered ? 0.35 : 0.25),
                  blurRadius: hovered ? 14 : 8,
                  offset: const Offset(0, 6),
                )
              ],
              border: Border.all(color: Colors.black12, width: 0.8),
            ),
            child: Stack(children: [
              // left spine shading
              const Positioned(
                left: 0, top: 0, bottom: 0, width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x4D000000), Colors.transparent],
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              // index tab (first of group)
              if (widget.showIndex)
                Positioned(
                  top: -8, left: 6, right: 6,
                  child: Container(
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3), topRight: Radius.circular(3),
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
                    ),
                    child: Text('${widget.doc.index}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                  ),
                ),
              // label
              Center(
                child: Text(
                  widget.doc.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9, color: Colors.white, height: 1.05, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // shine
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/* ─ Document detail modal (React BinderDocument.tsx parity) ─ */

class _DocumentDetailCard extends StatelessWidget {
  const _DocumentDetailCard({required this.doc, required this.onClose});
  final Document doc;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    (String, Color, IconData) statusTuple = switch (doc.status) {
      DocumentStatus.expired => ('만료 회원', Colors.red, Icons.cancel),
      DocumentStatus.onHold  => ('휴강 회원', Colors.orange, Icons.schedule),
      _                      => ('활성 회원', Colors.green, Icons.description),
    };

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(-0.10), // slight card tilt in
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20))],
          gradient: const LinearGradient(
            colors: [Color(0xFF303743), Color(0xFF252A33)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          // Light content page
          Container(
            margin: const EdgeInsets.only(left: 30),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(18), bottomRight: Radius.circular(18),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFFFFFBEB), Colors.white, Color(0xFFFFFBEB)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade600,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Text('회원 정보', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ]),
                    const Spacer(),
                    IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusTuple.$2.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusTuple.$3, size: 16, color: statusTuple.$2),
                      const SizedBox(width: 6),
                      Text(statusTuple.$1,
                          style: TextStyle(color: statusTuple.$2, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const Divider(height: 18),
                  _infoRow(Icons.phone, '연락처', '010-1234-5678', color: Colors.green),
                  _infoRow(Icons.mail, '이메일', '${doc.name.toLowerCase()}@example.com', color: Colors.purple),
                  _infoRow(Icons.calendar_today, '가입일', '2024-01-15', color: Colors.amber),
                  _infoRow(Icons.place, '주소', '서울시 강남구', color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7CC),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6), bottomRight: Radius.circular(6),
                      ),
                      border: Border(left: BorderSide(color: Color(0xFFF6C700), width: 4)),
                    ),
                    child: const Text(
                      '정기 회원으로 등록. 매주 화/목 수업 참여중입니다.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5C5300)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('ID: ${doc.id}', style: const TextStyle(fontSize: 12, color: Colors.black38)),
                    const Text('카테고리: 기타', style: TextStyle(fontSize: 12, color: Colors.black38)),
                  ]),
                ],
              ),
            ),
          ),
          // Left ring spine
          Positioned.fill(
            left: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 30,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18), bottomLeft: Radius.circular(18),
                  ),
                  gradient: LinearGradient(colors: [Color(0xFF1D232C), Color(0xFF262C36)]),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                        (i) => Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFFB0B7C1), Color(0xFF8F98A6)]),
                        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData ic, String label, String value, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        CircleAvatar(radius: 14, backgroundColor: color, child: const Icon(Icons.circle, size: 10, color: Colors.white)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

/* ─ Small menu item used in popup menus ─ */

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}
