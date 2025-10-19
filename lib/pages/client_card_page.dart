import 'dart:async';
import 'dart:math' as math;
// animations 패키지 사용 안 함
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const _kPrefQ = 'cc_q';
  static const _kPrefSort = 'cc_sort';
  static const _kPrefAsc = 'cc_asc';
  static const _kPrefExp = 'cc_exp';

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
      try {
        Firebase.app();
      } catch (_) {
        await Firebase.initializeApp();
      }
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
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPrefQ, _qC.text);
    await sp.setString(_kPrefSort, _sortBy);
    await sp.setBool(_kPrefAsc, _orderAsc);
    await sp.setBool(_kPrefExp, _expiredOnly);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('고객카드')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
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
            const SizedBox(height: 12),
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
                  final list = _applyFilterSort(members);
                  if (list.isEmpty) return const Center(child: Text('검색 결과가 없어요.'));

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[i];
                      return Padding(
                        padding: EdgeInsets.only(right: i == list.length - 1 ? 0 : 12),
                        child: BinderCard(
                          key: ValueKey('binder_${m.id}'),
                          member: m,
                          onOpenDetail: () => _openDetail(m),
                          onConsumeOne: () async {
                            if (m.remainingSessions <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('잔여 세션이 없습니다')));
                              return;
                            }
                            await FirebaseFirestore.instance.collection('members').doc(m.id).update({'remainingSessions': FieldValue.increment(-1)});
                          },
                          onLongPress: () => _showClassifySheet(m),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        case 'name':   cmp = (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()); break;
        case 'recent': cmp = (a.lastLogAt ?? DateTime(1970)).compareTo(b.lastLogAt ?? DateTime(1970)); break;
        case 'remain': cmp = a.remainingSessions.compareTo(b.remainingSessions); break;
        case 'first':  cmp = (a.firstDate ?? DateTime(1970)).compareTo(b.firstDate ?? DateTime(1970)); break;
        case 'expire': cmp = (a.expireAt ?? DateTime(2500)).compareTo(b.expireAt ?? DateTime(2500)); break;
      }
      return cmp * dir;
    });
    return out;
  }

  Future<void> _openDetail(Member m) {
    return Navigator.of(context).push(PageRouteBuilder(
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
}

/* ─────────────  상세 페이지(그대로 유지) ───────────── */

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
                  child: Icon(member.gender == Gender.female ? Icons.female : Icons.male, color: _genderColor(member.gender)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${member.name ?? member.id} 고객님\n담당: ${member.trainer ?? '-'} · 등급: ${member.level ?? member.grade ?? '-'}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _ProgressRing(progress: pct, color: low ? Colors.redAccent : theme.colorScheme.primary, label: '${member.remainingSessions}/${member.totalSessions}'),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow('최근등록', member.recentReg != null ? fmt.format(member.recentReg!) : '-'),
            _InfoRow('만료일', member.expireAt != null ? fmt.format(member.expireAt!) : '-'),
            _InfoRow('최근 작성', member.lastLogAt != null ? fmt.format(member.lastLogAt!) : '-'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('운동일지 열기'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('운동일지 화면으로 연결(추가 예정)'))),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('연장/수정'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원 편집 화면으로 연결(추가 예정)'))),
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
                await FirebaseFirestore.instance.collection('members').doc(member.id).update({'remainingSessions': FieldValue.increment(-1)});
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ─────────────  모델  ───────────── */

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
      totalSessions: (d['totalSessionsPurchased'] as num?)?.toInt() ?? (d['totalSessions'] as num?)?.toInt() ?? 0,
      firstDate: d['startDate'] != null ? _toDate(d['startDate']) : _toDate(d['createdAt']),
      recentReg: _toDate(d['recentRegistrationAt']) ?? _toDate(d['lastRegisterAt']) ?? _toDate(d['lastReenrollAt']) ?? _toDate(d['lastPurchaseAt']),
      expireAt: _toDate(d['expireAt']),
      lastLogAt: _toDate(d['lastLogAt']) ?? _toDate(d['lastPurchaseAt']),
      expiredFlag: (d['expiredFlag'] as bool?) ?? false,
      gender: _normGender(d['gender'] as String?),
    );
  }
}

/* ─────────────  바인더 카드 (1/3 스케일 + 2단계 종이) ───────────── */

class BinderCard extends StatefulWidget {
  const BinderCard({
    super.key,
    required this.member,
    required this.onOpenDetail,
    required this.onConsumeOne,
    required this.onLongPress,
    this.query = '',
  });

  final Member member;
  final Future<void> Function() onOpenDetail; // 상세 이동(필요시 버튼에서 사용)
  final Future<void> Function() onConsumeOne;
  final VoidCallback onLongPress;
  final String query;

  @override
  State<BinderCard> createState() => _BinderCardState();
}

class _BinderCardState extends State<BinderCard> with TickerProviderStateMixin {
  // 커버 여닫이
  late final AnimationController _coverCtrl;
  // 종이(서류) 단계 0~1 (0: 없음, 0.6: 미리보기, 1: 전체)
  late final AnimationController _paperCtrl;

  // 단계 상태 추적
  // 0 → 1(미리보기) → 2(전체) → 0(닫힘) 순환
  int _stage = 0;

  static const double _scale = 1 / 3; // ← 요청: 1/3 축소(비율 유지)

  @override
  void initState() {
    super.initState();
    _coverCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _paperCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  }

  @override
  void dispose() {
    _coverCtrl.dispose();
    _paperCtrl.dispose();
    super.dispose();
  }

  Future<void> _cycle() async {
    HapticFeedback.selectionClick();
    if (_stage == 0) {
      // 닫힘 → 열림 + 종이 미리보기
      await _coverCtrl.animateTo(1.0, curve: Curves.easeOutBack);
      await _paperCtrl.animateTo(0.6, curve: Curves.easeOutCubic);
      setState(() => _stage = 1);
      return;
    }
    if (_stage == 1) {
      // 미리보기 → 전체
      await _paperCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
      setState(() => _stage = 2);
      return;
    }
    // 전체 → 닫힘
    await _paperCtrl.animateBack(0.0, curve: Curves.easeInQuad);
    await _coverCtrl.animateBack(0.0, curve: Curves.easeInQuad);
    setState(() => _stage = 0);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;

    // 원래 비율 유지하면서 전체 1/3 축소
    final fullW = math.min(MediaQuery.sizeOf(context).width * .86, 420.0);
    final w = fullW * _scale;
    final hitWidth = w + 18; // 터치 여유
    final overlap = -(w * 0.70);
    final baseColor = _genderColor(m.gender);
    final isExpired = m.isExpired;

    final gradient = isExpired
        ? const LinearGradient(colors: [Color(0xFFE6E7EA), Color(0xFFCfd2D6), Color(0xFFA8ACB1)])
        : (m.gender == Gender.female
        ? const LinearGradient(colors: [Color(0xFFFFE0EE), Color(0xFFFFC2DA), Color(0xFFFF97BD)])
        : const LinearGradient(colors: [Color(0xFFD9ECFF), Color(0xFFBFE0FF), Color(0xFF8CC4FF)]));

    final bookTilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(-12 * math.pi / 180)
      ..translate(0.0, 3.0);

    // 커버 각도: 0 → -115deg
    final coverAngle = Tween(begin: 0.0, end: -115 * math.pi / 180).animate(CurvedAnimation(
      parent: _coverCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInQuad,
    ));

    return SizedBox(
      width: hitWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cycle,
        onLongPress: widget.onLongPress,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Transform(
            transform: bookTilt,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(overlap, 0),
              child: _BinderVisual(
                width: w,
                scale: _scale, // 내부 치수에 참고용
                spineColor: baseColor,
                cardGradient: gradient,
                isExpired: isExpired,
                member: m,
                coverAngle: coverAngle,
                paperProgress: _paperCtrl,
                onOpenDetail: widget.onOpenDetail,
                onConsumeOne: widget.onConsumeOne,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BinderVisual extends StatelessWidget {
  const _BinderVisual({
    required this.width,
    required this.scale,
    required this.spineColor,
    required this.cardGradient,
    required this.isExpired,
    required this.member,
    required this.coverAngle,
    required this.paperProgress,
    required this.onOpenDetail,
    required this.onConsumeOne,
  });

  final double width;
  final double scale;
  final Color spineColor;
  final Gradient cardGradient;
  final bool isExpired;
  final Member member;
  final Animation<double> coverAngle;
  final Animation<double> paperProgress; // 0~1
  final Future<void> Function() onOpenDetail;
  final Future<void> Function() onConsumeOne;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const endAngle = -115 * math.pi / 180;

    return AnimatedBuilder(
      animation: Listenable.merge([coverAngle, paperProgress]),
      builder: (context, _) {
        // 커버 열림 비율
        final t = (coverAngle.value / endAngle).clamp(0.0, 1.0).abs();

        // 내부가 살짝 올라오는 연출
        final contentOpacity = Curves.easeOut.transform(t);
        final contentDx = (1 - contentOpacity) * 10;
        final contentScale = 0.985 + 0.015 * contentOpacity;

        // 종이(서류) 위치: 0 → 카드 내부, 0.6(미리보기) → 상단으로 조금, 1.0(전체) → 더 위로 + 커짐
        final paperT = paperProgress.value;
        final paperOffsetY = lerpDouble(28 * scale, -2 * scale, paperT)!; // 살짝 위로
        final paperElev = lerpDouble(2, 10, paperT)!;
        final paperOpacity = lerpDouble(0, 1, paperT)!;
        final paperScale = lerpDouble(.98, 1.0, paperT)!;

        return Container(
          width: width,
          height: width * 0.73, // 기존 비율 유지
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: Colors.black.withOpacity(.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isExpired ? .25 : .08),
                blurRadius: isExpired ? 22 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 유광
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.centerLeft,
                        colors: [Colors.white.withOpacity(.0), Colors.white.withOpacity(.16), Colors.white.withOpacity(.0)],
                        stops: const [0.0, 0.3, 0.6],
                      ),
                    ),
                  ),
                ),
              ),

              // 스파인
              Positioned(
                left: 6 * scale,
                top: 36 * scale,
                child: Container(
                  width: 22 * scale,
                  height: 92 * scale,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [spineColor.withOpacity(.55), spineColor.withOpacity(.85)],
                    ),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(10 * scale)),
                    border: Border.all(color: spineColor.withOpacity(.85), width: 2 * scale),
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      '${member.name ?? member.id} 고객님',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11 * scale),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // 내부 기본 텍스트(커버 열림과 함께 등장)
              Transform.translate(
                offset: Offset(36 * scale + contentDx, 0),
                child: Transform.scale(
                  scale: contentScale,
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 8 * scale, 8 * scale, 8 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${member.name ?? member.id} 고객님',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14 * scale,
                              color: isExpired ? Colors.black87 : const Color(0xFF0B1220),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 종이(서류) - 2단계
              Positioned(
                left: 32 * scale,
                right: 10 * scale,
                bottom: 8 * scale,
                child: Opacity(
                  opacity: paperOpacity,
                  child: Transform.translate(
                    offset: Offset(0, paperOffsetY),
                    child: Transform.scale(
                      scale: paperScale,
                      alignment: Alignment.bottomCenter,
                      child: Material(
                        elevation: paperElev,
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10 * scale),
                        shadowColor: Colors.black.withOpacity(.18),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
                          child: _PaperContent(
                            scale: scale,
                            member: member,
                            progress: paperProgress.value,
                            onOpenDetail: onOpenDetail,
                            onConsumeOne: onConsumeOne,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 커버(표지)
              Positioned.fill(
                child: _BinderCover(angle: coverAngle.value, hingeX: 36 * scale, scale: scale),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaperContent extends StatelessWidget {
  const _PaperContent({
    required this.scale,
    required this.member,
    required this.progress,
    required this.onOpenDetail,
    required this.onConsumeOne,
  });

  final double scale;
  final Member member;
  final double progress; // 0.0~1.0 (0.0~0.6 preview, 1.0 full)
  final Future<void> Function() onOpenDetail;
  final Future<void> Function() onConsumeOne;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final isFull = progress >= .999; // 전체 단계

    // 공통: 상단 줄(고객명 + 최근작성)
    final header = Row(
      children: [
        Expanded(
          child: Text(
            '${member.name ?? member.id} 고객님',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13 * scale),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '최근 작성: ${member.lastLogAt != null ? fmt.format(member.lastLogAt!) : '-'}',
          style: TextStyle(fontSize: 11 * scale, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
        ),
      ],
    );

    if (!isFull) {
      // 미리보기 단계: 헤더만
      return header;
    }

    // 전체 단계: 액션 버튼들 노출
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            _PaperActionButton(
              scale: scale,
              icon: Icons.menu_book_outlined,
              label: '운동기록일지 보기',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('운동일지 화면으로 연결(추가 예정)'))),
            ),
            _PaperActionButton(
              scale: scale,
              icon: Icons.badge_outlined,
              label: '회원정보 확인/변경',
              onTap: onOpenDetail,
            ),
            _PaperActionButton(
              scale: scale,
              icon: Icons.remove_circle_outline,
              label: '–1 소진',
              danger: true,
              onTap: onConsumeOne,
            ),
          ],
        ),
      ],
    );
  }
}

class _PaperActionButton extends StatelessWidget {
  const _PaperActionButton({
    required this.scale,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final double scale;
  final IconData icon;
  final String label;
  final FutureOr<void> Function() onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: danger ? Colors.red.withOpacity(.08) : c.primary.withOpacity(.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          HapticFeedback.selectionClick();
          await onTap();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14 * scale, color: danger ? Colors.redAccent : c.primary),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w800,
                  color: danger ? Colors.redAccent : c.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BinderCover extends StatelessWidget {
  const _BinderCover({required this.angle, required this.hingeX, required this.scale});
  final double angle; // 라디안
  final double hingeX;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cover = Container(
      margin: EdgeInsets.only(left: hingeX - 2 * scale, right: 6 * scale, top: 6 * scale, bottom: 6 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.55),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12 * scale, offset: const Offset(0, 6))],
      ),
    );

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..translate(hingeX, 0.0)
      ..rotateY(angle)
      ..translate(-hingeX, 0.0);

    return Transform(transform: m, alignment: Alignment.centerLeft, child: cover);
  }
}

/* ─────────────  공용 위젯  ───────────── */

String? _fmt(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);

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
        CustomPaint(painter: _RingPainter(progress: progress, color: color), child: const SizedBox(width: 66, height: 66)),
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

    final bg = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = Colors.grey.shade300;
    final fg = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = stroke..shader = SweepGradient(colors: [color, color.withOpacity(.85)]).createShader(rect);

    canvas.drawArc(Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke), -math.pi / 2, math.pi * 2, false, bg);
    canvas.drawArc(Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke), -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}
