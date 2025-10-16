import 'dart:async';
import 'dart:math' as math;
import 'package:animations/animations.dart';
import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* ─────────────────────────  서랍 분류 타입  ───────────────────────── */

enum DrawerType { ko, en, etc }

/* ─────────────────────────  메인 페이지  ───────────────────────── */

class ClientCardPage extends StatefulWidget {
  const ClientCardPage({super.key});
  @override
  State<ClientCardPage> createState() => _ClientCardPageState();
}

class _ClientCardPageState extends State<ClientCardPage> {
  final _qC = TextEditingController();
  String _sortBy = 'name';
  bool _orderAsc = true;
  bool _expiredOnly = false;
  DrawerType _lastOpen = DrawerType.ko; // 마지막으로 연 서랍 기억

  static const _kPrefQ = 'cc_q';
  static const _kPrefSort = 'cc_sort';
  static const _kPrefAsc = 'cc_asc';
  static const _kPrefExp = 'cc_exp';
  static const _kPrefDrawer = 'cc_drawer';

  StreamSubscription<fa.User?>? _authSub;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _memberStream;

  @override
  void initState() {
    super.initState();
    _restorePrefs();
    _ensureFirebaseAndAuth();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _qC.dispose();
    super.dispose();
  }

  Future<void> _ensureFirebaseAndAuth() async {
    try {
      try { Firebase.app(); } catch (_) { await Firebase.initializeApp(); }
      final auth = fa.FirebaseAuth.instance;
      _authSub = auth.authStateChanges().listen((u) async {
        if (u == null) {
          await auth.signInAnonymously();
        } else {
          setState(() {
            _memberStream = FirebaseFirestore.instance.collection('members').snapshots();
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase 초기화 실패: $e')));
    }
  }

  Future<void> _restorePrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _qC.text = sp.getString(_kPrefQ) ?? '';
      _sortBy = sp.getString(_kPrefSort) ?? 'name';
      _orderAsc = sp.getBool(_kPrefAsc) ?? true;
      _expiredOnly = sp.getBool(_kPrefExp) ?? false;
      final idx = (sp.getInt(_kPrefDrawer) ?? 0).clamp(0, DrawerType.values.length - 1);
      _lastOpen = DrawerType.values[idx];
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPrefQ, _qC.text);
    await sp.setString(_kPrefSort, _sortBy);
    await sp.setBool(_kPrefAsc, _orderAsc);
    await sp.setBool(_kPrefExp, _expiredOnly);
    await sp.setInt(_kPrefDrawer, _lastOpen.index);
  }

  /* ───── 이름 분류 유틸 ───── */

  bool _isHangulFirst(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final first = s.trim().characters.first;
    final cp = first.codeUnitAt(0);
    return (cp >= 0xAC00 && cp <= 0xD7A3) || (cp >= 0x1100 && cp <= 0x11FF) || (cp >= 0x3130 && cp <= 0x318F);
  }

  bool _isEnglishFirst(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final ch = s.trim()[0];
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  ({List<Member> ko, List<Member> en, List<Member> etc}) _partition(List<Member> src) {
    final ko = <Member>[];
    final en = <Member>[];
    final etc = <Member>[];
    for (final m in src) {
      final nm = (m.name ?? m.id).trim();
      if (_isHangulFirst(nm)) {
        ko.add(m);
      } else if (_isEnglishFirst(nm)) {
        en.add(m);
      } else {
        etc.add(m);
      }
    }
    return (ko: ko, en: en, etc: etc);
  }

  /* ───── 필터/정렬 ───── */

  List<Member> _applyFilterSort(List<Member> list) {
    final kw = _qC.text.trim().toLowerCase();
    bool match(Member m) {
      if (kw.isEmpty) return true;
      final name = (m.name ?? '').toLowerCase();
      final trainer = (m.trainer ?? '').toLowerCase();
      final grade = (m.level ?? m.grade ?? '').toLowerCase();
      return name.contains(kw) || trainer.contains(kw) || grade.contains(kw);
    }

    var out = list.where(match).toList();
    if (_expiredOnly) out = out.where((m) => m.isExpired).toList();

    final dir = _orderAsc ? 1 : -1;
    out.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'name':
          cmp = (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
          break;
        case 'recent':
          cmp = (a.lastLogAt ?? DateTime(1970)).compareTo(b.lastLogAt ?? DateTime(1970));
          break;
        case 'remain':
          cmp = a.remainingSessions.compareTo(b.remainingSessions);
          break;
        case 'first':
          cmp = (a.firstDate ?? DateTime(1970)).compareTo(b.firstDate ?? DateTime(1970));
          break;
        case 'expire':
          cmp = (a.expireAt ?? DateTime(2500)).compareTo(b.expireAt ?? DateTime(2500));
          break;
      }
      return cmp * dir;
    });
    return out;
  }

  /* ───── 상세 및 시트 ───── */

  void _openDetail(Member m) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => MemberDetailPage(member: m),
    ));
  }

  void _showClassifySheet(Member m) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('만료회원으로 분류'),
              onTap: () async {
                await FirebaseFirestore.instance.collection('members').doc(m.id).update({'expiredFlag': true});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.free_cancellation_outlined),
              title: const Text('휴강회원으로 분류'),
              onTap: () async {
                await FirebaseFirestore.instance.collection('members').doc(m.id).update({'pausedFlag': true});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /* ───── UI ───── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('고객카드')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 검색/정렬/필터
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qC,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '이름 / 담당 / 등급 검색',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    onChanged: (_) { _savePrefs(); setState(() {}); },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: '정렬',
                  onSelected: (v) { setState(() => _sortBy = v); _savePrefs(); },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'name', child: Text('이름')),
                    PopupMenuItem(value: 'recent', child: Text('최근 작성')),
                    PopupMenuItem(value: 'remain', child: Text('잔여 세션')),
                    PopupMenuItem(value: 'first', child: Text('최초 등록일')),
                    PopupMenuItem(value: 'expire', child: Text('만료일')),
                  ],
                  child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.tune), label: Text('정렬: $_sortBy')),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () { setState(() => _orderAsc = !_orderAsc); _savePrefs(); },
                  child: Text(_orderAsc ? '오름차순 ↑' : '내림차순 ↓'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('만료만'),
                  selected: _expiredOnly,
                  onSelected: (v) { setState(() => _expiredOnly = v); _savePrefs(); },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 데이터 로딩
            Expanded(
              child: _memberStream == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _memberStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('불러오기 실패: ${snap.error}'));
                  }
                  final members = snap.data!.docs.map((d) => Member.fromFirestore(d.id, d.data())).toList();
                  final filtered = _applyFilterSort(members);
                  if (filtered.isEmpty) return const Center(child: Text('검색 결과가 없어요.'));

                  final p = _partition(filtered);

                  return DrawerCabinet(
                    lastOpen: _lastOpen,
                    onDrawerChanged: (t) { _lastOpen = t; _savePrefs(); },
                    lists: {
                      DrawerType.ko: p.ko,
                      DrawerType.en: p.en,
                      DrawerType.etc: p.etc,
                    },
                    onOpenMember: _openDetail,
                    onLongPressMember: _showClassifySheet,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────  서랍장 위젯  ─────────────────────────
   - 사진처럼 "오른쪽→왼쪽" 시점(우측이 가까움): rotateY(+12°), alignment: centerRight
   - 서랍문은 밖으로 살짝 '튀어나오고', 내부 바인더는 순차 등장
   - 스크롤 가능한 세로 캐비넷
*/

class DrawerCabinet extends StatefulWidget {
  const DrawerCabinet({
    super.key,
    required this.lists,
    required this.onOpenMember,
    required this.onLongPressMember,
    required this.lastOpen,
    required this.onDrawerChanged,
  });

  final Map<DrawerType, List<Member>> lists;
  final ValueChanged<Member> onOpenMember;
  final ValueChanged<Member> onLongPressMember;
  final DrawerType lastOpen;
  final ValueChanged<DrawerType> onDrawerChanged;

  @override
  State<DrawerCabinet> createState() => _DrawerCabinetState();
}

class _DrawerCabinetState extends State<DrawerCabinet> with TickerProviderStateMixin {
  DrawerType? _open;
  late final Map<DrawerType, AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final t in DrawerType.values)
        t: AnimationController(vsync: this, duration: const Duration(milliseconds: 380)),
    };
    // 마지막으로 열었던 서랍 자동 오픈
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toggle(widget.lastOpen, initial: true);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  void _toggle(DrawerType type, {bool initial = false}) {
    if (_open == type) {
      _ctrls[type]!.reverse();
      _open = null;
      widget.onDrawerChanged(type);
      return;
    }
    if (_open != null) {
      _ctrls[_open]!.reverse();
    }
    _open = type;
    if (initial) {
      _ctrls[type]!.value = 1.0; // 처음 진입 시 바로 펼쳐진 상태
    } else {
      _ctrls[type]!.forward();
    }
    widget.onDrawerChanged(type);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    // 우측 퍼스펙티브 (오른쪽이 더 가까운 시점)
    final cabinetPerspective = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateY(12 * math.pi / 180); // +각도 → 오른쪽이 앞으로

    return Transform(
      transform: cabinetPerspective,
      alignment: Alignment.centerRight,
      transformHitTests: true,
      child: ListView(
        padding: const EdgeInsets.only(right: 2, left: 8, bottom: 8, top: 4),
        children: [
          _Drawer3D(
            label: '한글',
            sub: 'ㄱ~ㅎ / 가~힣',
            color: c.primary,
            members: widget.lists[DrawerType.ko] ?? const [],
            controller: _ctrls[DrawerType.ko]!,
            opened: _open == DrawerType.ko,
            onTap: () => _toggle(DrawerType.ko),
            onOpenMember: widget.onOpenMember,
            onLongPressMember: widget.onLongPressMember,
          ),
          _Drawer3D(
            label: '영문',
            sub: 'A–Z',
            color: Colors.indigo,
            members: widget.lists[DrawerType.en] ?? const [],
            controller: _ctrls[DrawerType.en]!,
            opened: _open == DrawerType.en,
            onTap: () => _toggle(DrawerType.en),
            onOpenMember: widget.onOpenMember,
            onLongPressMember: widget.onLongPressMember,
          ),
          _Drawer3D(
            label: '기타',
            sub: '숫자·특수',
            color: Colors.teal,
            members: widget.lists[DrawerType.etc] ?? const [],
            controller: _ctrls[DrawerType.etc]!,
            opened: _open == DrawerType.etc,
            onTap: () => _toggle(DrawerType.etc),
            onOpenMember: widget.onOpenMember,
            onLongPressMember: widget.onLongPressMember,
          ),
        ],
      ),
    );
  }
}

class _Drawer3D extends StatelessWidget {
  const _Drawer3D({
    required this.label,
    required this.sub,
    required this.color,
    required this.members,
    required this.controller,
    required this.onTap,
    required this.onOpenMember,
    required this.onLongPressMember,
    required this.opened,
  });

  final String label;
  final String sub;
  final Color color;
  final List<Member> members;
  final AnimationController controller;
  final VoidCallback onTap;
  final bool opened;
  final ValueChanged<Member> onOpenMember;
  final ValueChanged<Member> onLongPressMember;

  @override
  Widget build(BuildContext context) {
    final tOpen = CurvedAnimation(parent: controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeInQuad);
    final lift = Tween<double>(begin: 0, end: 16).animate(tOpen); // 서랍문 돌출
    final rise = Tween<double>(begin: 0, end: -8).animate(tOpen); // 약간 위로
    final shadow = Tween<double>(begin: 4, end: 18).animate(tOpen);
    final innerH = Tween<double>(begin: 0, end: math.min(260, 92.0 + 96.0 * ((members.length + 1) ~/ 2))).animate(tOpen);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 내부 공간 (서랍 안)
              Positioned.fill(
                top: 76, // 서랍문 높이
                child: IgnorePointer(
                  ignoring: controller.value == 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    height: innerH.value,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(.06)),
                    ),
                    child: Opacity(
                      opacity: controller.value,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        // 바인더 카드 그리드 (순차 등장 느낌)
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: members.length,
                          itemBuilder: (context, i) {
                            // stagger: index마다 시작 지연
                            final start = (i * 0.06).clamp(0.0, 0.6);
                            final appear = CurvedAnimation(
                              parent: controller,
                              curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
                            );
                            return FadeTransition(
                              opacity: appear,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: .94, end: 1).animate(appear),
                                child: BinderCard(
                                  member: members[i],
                                  onTapOpen: () => onOpenMember(members[i]),
                                  onLongPress: () => onLongPressMember(members[i]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 서랍문 (라벨 + 핸들)
              Transform.translate(
                offset: Offset(-lift.value, rise.value), // 오른쪽→왼쪽 시점이므로 X축 음수로 돌출
                child: _DrawerFace(
                  color: color,
                  label: label,
                  sub: sub,
                  count: members.length,
                  shadow: shadow.value,
                  opened: opened,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DrawerFace extends StatelessWidget {
  const _DrawerFace({
    required this.color,
    required this.label,
    required this.sub,
    required this.count,
    required this.shadow,
    required this.opened,
    required this.onTap,
  });

  final Color color;
  final String label;
  final String sub;
  final int count;
  final double shadow;
  final bool opened;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final face = Container(
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(opened ? .22 : .12),
            blurRadius: shadow,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 컬러 탭 (서랍 테두리 느낌)
          Container(
            width: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          const SizedBox(width: 12),
          // 라벨
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const Spacer(),
          // 뱃지
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              border: Border.all(color: color.withOpacity(.30)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ),
          // 핸들(손잡이)
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 40,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: face,
      ),
    );
  }
}

/* ─────────────────────────  모델  ───────────────────────── */

enum Gender { male, female, unknown }

class Member {
  final String id;
  final String? name;
  final String? trainer;
  final String? grade;
  final String? level;
  final int remainingSessions;
  final int totalSessions;
  final DateTime? firstDate;
  final DateTime? recentReg;
  final DateTime? expireAt;
  final DateTime? lastLogAt;
  final bool expiredFlag;
  final Gender gender;

  const Member({
    required this.id,
    required this.name,
    required this.trainer,
    required this.grade,
    required this.level,
    required this.remainingSessions,
    required this.totalSessions,
    required this.firstDate,
    required this.recentReg,
    required this.expireAt,
    required this.lastLogAt,
    required this.expiredFlag,
    required this.gender,
  });

  bool get isExpired {
    if (expiredFlag) return true;
    if (expireAt == null) return false;
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day);
    final x = DateTime(expireAt!.year, expireAt!.month, expireAt!.day);
    return x.isBefore(d);
  }

  static Gender _normGender(String? g) {
    final s = (g ?? '').toLowerCase().trim();
    if (RegExp(r'^(f|여|female|woman|girl)').hasMatch(s)) return Gender.female;
    if (RegExp(r'^(m|남|male|man|boy)').hasMatch(s)) return Gender.male;
    return Gender.unknown;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) { try { return DateTime.parse(v); } catch (_) {} }
    return null;
  }

  factory Member.fromFirestore(String id, Map<String, dynamic> d) {
    return Member(
      id: id,
      name: d['name'] as String?,
      trainer: d['trainer'] as String?,
      grade: (d['level'] as String?) ?? d['grade'] as String?,
      level: d['level'] as String?,
      remainingSessions: (d['remainingSessions'] as num?)?.toInt() ?? 0,
      totalSessions: (d['totalSessionsPurchased'] as num?)?.toInt() ??
          (d['totalSessions'] as num?)?.toInt() ?? 0,
      firstDate: d['startDate'] != null ? _toDate(d['startDate']) : _toDate(d['createdAt']),
      recentReg: _toDate(d['recentRegistrationAt']) ??
          _toDate(d['lastRegisterAt']) ??
          _toDate(d['lastReenrollAt']) ??
          _toDate(d['lastPurchaseAt']),
      expireAt: _toDate(d['expireAt']),
      lastLogAt: _toDate(d['lastLogAt']) ?? _toDate(d['lastPurchaseAt']),
      expiredFlag: (d['expiredFlag'] as bool?) ?? false,
      gender: _normGender(d['gender'] as String?),
    );
  }
}

/* ─────────────────────────  바인더 카드  ─────────────────────────
   - 기존 카드 스타일 유지
   - 캐비넷의 "오른쪽→왼쪽" 시점과 어울리게 약간의 Y 회전(-12° → 카드 자체는 좌측이 멀게)
*/

class BinderCard extends StatelessWidget {
  const BinderCard({
    super.key,
    required this.member,
    required this.onTapOpen,
    required this.onLongPress,
    this.query = '',
  });

  final Member member;
  final VoidCallback onTapOpen;
  final VoidCallback onLongPress;
  final String query;

  @override
  Widget build(BuildContext context) {
    final baseColor = _genderColor(member.gender);
    final isExpired = member.isExpired;

    final gradient = isExpired
        ? const LinearGradient(colors: [Color(0xFFE6E7EA), Color(0xFFCfd2D6), Color(0xFFA8ACB1)])
        : (member.gender == Gender.female
        ? const LinearGradient(colors: [Color(0xFFFFE0EE), Color(0xFFFFC2DA), Color(0xFFFF97BD)])
        : const LinearGradient(colors: [Color(0xFFD9ECFF), Color(0xFFBFE0FF), Color(0xFF8CC4FF)]));

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(-12 * math.pi / 180) // 카드 자체는 살짝 좌측 원근
      ..translate(0.0, 4.0);

    return Transform(
      transform: matrix,
      alignment: Alignment.centerLeft,
      transformHitTests: true,
      child: Container(
        width: 220,
        height: 160,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpired ? .25 : .08),
              blurRadius: isExpired ? 24 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () { HapticFeedback.selectionClick(); onTapOpen(); },
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Positioned(
                left: 6, top: 42,
                child: Container(
                  width: 22, height: 92, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [baseColor.withOpacity(.55), baseColor.withOpacity(.85)],
                    ),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                    border: Border.all(color: baseColor.withOpacity(.85), width: 2),
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      '${member.name ?? member.id} 고객님',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10, left: 36, right: 10,
                child: Text(
                  '${member.name ?? member.id} 고객님',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isExpired ? Colors.black87 : const Color(0xFF0B1220),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                left: 36, right: 10, bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.86),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        '최근 등록: ${_fmt(member.recentReg) ?? _fmt(member.firstDate) ?? '-'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _fmt(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);
}

/* ─────────────────────────  상세 페이지  ───────────────────────── */

class MemberDetailPage extends StatelessWidget {
  const MemberDetailPage({super.key, required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy-MM-dd');
    final double pct = member.totalSessions > 0
        ? (member.remainingSessions / member.totalSessions).clamp(0.0, 1.0)
        : 0.0;
    final low = member.remainingSessions <= 3;

    return Scaffold(
      appBar: AppBar(title: Text(member.name ?? member.id)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _genderColor(member.gender).withOpacity(.15),
                  child: Icon(
                    member.gender == Gender.female ? Icons.female : Icons.male,
                    color: _genderColor(member.gender),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${member.name ?? member.id} 고객님\n담당: ${member.trainer ?? '-'} · 등급: ${member.level ?? member.grade ?? '-'}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _ProgressRing(
                  progress: pct,
                  color: low ? Colors.redAccent : theme.colorScheme.primary,
                  label: '${member.remainingSessions}/${member.totalSessions}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow('최근등록', member.recentReg != null ? fmt.format(member.recentReg!) : '-'),
            _InfoRow('만료일',   member.expireAt   != null ? fmt.format(member.expireAt!)   : '-'),
            _InfoRow('최근 작성', member.lastLogAt  != null ? fmt.format(member.lastLogAt!)  : '-'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('운동일지 열기'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('운동일지 화면으로 연결(추가 예정)')),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('연장/수정'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회원 편집 화면으로 연결(추가 예정)')),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('–1 소진'),
              onPressed: () async {
                if (member.remainingSessions <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('잔여 세션이 없습니다')));
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('members')
                    .doc(member.id)
                    .update({'remainingSessions': FieldValue.increment(-1)});
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────────────────  공용 위젯  ───────────────────────── */

Color _genderColor(Gender g) {
  switch (g) {
    case Gender.female: return const Color(0xFFFF6FA4);
    case Gender.male:   return const Color(0xFF2E6DD8);
    case Gender.unknown:return Colors.teal;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress, required this.color, required this.label});
  final double progress;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: _RingPainter(progress: progress, color: color),
          child: const SizedBox(width: 66, height: 66),
        ),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const stroke = 8.0;
    final rect = Offset.zero & size;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.shade300;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(colors: [color, color.withOpacity(.85)]).createShader(rect);

    canvas.drawArc(Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke), -math.pi / 2, math.pi * 2, false, bg);
    canvas.drawArc(Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke), -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}
