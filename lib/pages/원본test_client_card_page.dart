// lib/pages/원본test_client_card_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtf_app/models/member.dart';

// Firebase options (웹/멀티플랫폼 안전 초기화용)
import 'package:mtf_app/firebase_options.dart';

// 페이지 import
import 'package:mtf_app/pages/personal_training_log_page.dart'
    show PersonalTrainingLogPage;
import 'package:mtf_app/pages/client_card_page.dart'
    show ClientCardPage;

// === Touch alignment option ===
const bool kPreciseHitArea = true;

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

  // false: 목차(리스트), true: 바인더(파일)
  bool _binderMode = false;

  // 하이라이트
  String? _highlightId;
  Timer? _highlightTimer;
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

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
    _highlightTimer?.cancel();
    _qC.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  String _sortLabel(String v) {
    switch (v) {
      case 'name':
        return '이름';
      case 'recent':
        return '최근 작성';
      case 'remain':
        return '잔여 세션';
      case 'first':
        return '최초 등록일';
      case 'expire':
        return '만료일';
      default:
        return v;
    }
  }

  Future<void> _ensureFirebaseAndAuth() async {
    try {
      // 앱 전체(main)에서 이미 initializeApp을 해도, 여기서는 안전하게 가드만 둠
      try {
        Firebase.app();
      } catch (_) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final auth = fa.FirebaseAuth.instance;
      _authSub = auth.authStateChanges().listen((u) async {
        if (u == null) {
          try {
            await auth.signInAnonymously();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('로그인이 필요합니다(익명 로그인 실패): $e')),
            );
          }
        } else {
          if (!mounted) return;
          setState(() {
            _memberStream =
                FirebaseFirestore.instance.collection('members').snapshots();
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Firebase 초기화 실패: $e')));
    }
  }

  Future<void> _restorePrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
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

  List<Member> _applyFilterSort(List<Member> list) {
    final kw = _qC.text.trim().toLowerCase();
    final kwDigits = kw.replaceAll(RegExp(r'\D'), '');

    bool match(Member m) {
      if (kw.isEmpty) return true;
      final name = (m.name ?? '').toLowerCase();
      final trainer = (m.trainer ?? '').toLowerCase();
      final phoneDigits = (m.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final textHit = name.contains(kw) || trainer.contains(kw);
      final phoneHit = kwDigits.isNotEmpty && phoneDigits.contains(kwDigits);
      return textHit || phoneHit;
    }

    var out = list.where(match).toList();

    if (_expiredOnly) {
      out = out.where((m) => m.isExpired).toList();
    }

    final dir = _orderAsc ? 1 : -1;
    out.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'name':
          cmp = (a.name ?? '')
              .toLowerCase()
              .compareTo((b.name ?? '').toLowerCase());
          break;
        case 'recent':
          cmp = (a.lastLogAt ?? DateTime(0))
              .compareTo(b.lastLogAt ?? DateTime(0));
          break;
        case 'remain':
          cmp = a.remainingSessions.compareTo(b.remainingSessions);
          break;
        case 'first':
          cmp = (a.firstDate ?? DateTime(0))
              .compareTo(b.firstDate ?? DateTime(0));
          break;
        case 'expire':
          cmp = (a.expireAt ?? DateTime(9999))
              .compareTo(b.expireAt ?? DateTime(9999));
          break;
      }
      return cmp * dir;
    });

    return out;
  }

  Future<void> _handleNavigation(String memberId) async {
    if (!mounted) return;
    setState(() => _highlightId = memberId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  // 운동기록일지로 이동 (페이드)
  Future<void> _openJournal(Member m) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PersonalTrainingLogPage(
          memberId: m.id,
          memberName: m.name ?? '',
          trainerName: m.trainer ?? '',
          memberPhone: m.phone ?? '',
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    _handleNavigation(m.id);
  }

  // 고객정보 확인/수정 페이지로 이동
  Future<void> _openEdit(Member m) async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientCardPage(),
      ),
    );

    _handleNavigation(m.id);
  }

    // ✅ edit 페이지가 "saved" 반환을 안 해도, 돌아오면 하이라이트는 해준다
    _handleNavigation(m.id);
  }

  // 신규 등록
Future<void> _openCreate() async {
  if (!mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const ClientCardPage(),
    ),
  );
}

    // ✅ create도 마찬가지: 반환값 의존하지 않고 새 ID를 하이라이트
    _handleNavigation(newId);
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
                await FirebaseFirestore.instance
                    .collection('members')
                    .doc(m.id)
                    .update({'memberStatus': '만료'});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.free_cancellation_outlined),
              title: const Text('휴면회원으로 분류'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('members')
                    .doc(m.id)
                    .update({'memberStatus': '휴면'});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('활성회원으로 복귀'),
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('members')
                    .doc(m.id)
                    .update({'memberStatus': '활성'});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortText = _sortLabel(_sortBy);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('고객카드'),
        actions: [
          IconButton(
            tooltip: _binderMode ? '목차로 보기' : '바인더로 보기',
            icon: Icon(_binderMode ? Icons.view_list : Icons.view_carousel),
            onPressed: () => setState(() => _binderMode = !_binderMode),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '이름 / 담당 / 연락처 검색',
                      isDense: true,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      suffixIcon: _qC.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _qC.clear();
                          _savePrefs();
                          setState(() {});
                        },
                      )
                          : null,
                    ),
                    onChanged: (_) {
                      _savePrefs();
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),

                PopupMenuButton<String>(
                  tooltip: '정렬',
                  onSelected: (v) {
                    setState(() => _sortBy = v);
                    _savePrefs();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'name', child: Text('이름')),
                    PopupMenuItem(value: 'recent', child: Text('최근 작성')),
                    PopupMenuItem(value: 'remain', child: Text('잔여 세션')),
                    PopupMenuItem(value: 'first', child: Text('최초 등록일')),
                    PopupMenuItem(value: 'expire', child: Text('만료일')),
                  ],
                  child: OutlinedButton(
                    onPressed: null,
                    child: Text('정렬: $sortText'),
                  ),
                ),
                const SizedBox(width: 8),

                IconButton(
                  tooltip: _orderAsc ? '오름차순' : '내림차순',
                  icon:
                  Icon(_orderAsc ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () {
                    setState(() => _orderAsc = !_orderAsc);
                    _savePrefs();
                  },
                ),
                const SizedBox(width: 8),

                FilterChip(
                  label: const Text('만료만'),
                  selected: _expiredOnly,
                  onSelected: (v) {
                    setState(() => _expiredOnly = v);
                    _savePrefs();
                  },
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
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final members = snap.data!.docs
                      .map((d) => Member.fromFirestore(d.id, d.data()))
                      .toList();

                  final list = _applyFilterSort(members);
                  if (list.isEmpty) {
                    return const Center(child: Text('검색 결과가 없어요.'));
                  }

                  if (_binderMode) {
                    // 바인더 가로 스크롤
                    return ListView.builder(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final m = list[i];
                        return Padding(
                          padding: EdgeInsets.only(
                              right: i == list.length - 1 ? 0 : 12),
                          child: BinderCard(
                            key: ValueKey('binder_${m.id}'),
                            member: m,
                            onOpenJournal: () => _openJournal(m),
                            onOpenEdit: () => _openEdit(m),
                            onLongPress: () => _showClassifySheet(m),
                          )._withHighlight(m.id == _highlightId),
                        );
                      },
                    );
                  } else {
                    // 목차(리스트)
                    return ListView.separated(
                      controller: _vScroll,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final m = list[i];
                        final dday = _dday(m.expireAt);

                        return ListTile(
                          tileColor: m.id == _highlightId
                              ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5)
                              : Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: (m.id == _highlightId)
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: (m.id == _highlightId) ? 2 : 1,
                            ),
                          ),
                          title: Text(
                            m.name ?? m.id,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text([
                            if (m.trainer?.isNotEmpty == true) '담당:${m.trainer}',
                            '잔여:${m.remainingSessions}/${m.totalSessions}',
                            if (m.expireAt != null)
                              '만료:${DateFormat('yy-MM-dd').format(m.expireAt!)}'
                                  ' ${dday == null ? '' : dday <= 0 ? '(D+${dday.abs()})' : '(D-$dday)'}',
                          ].join('  ·  ')),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              if (m.memberStatus == '휴면')
                                _chip('휴강', Colors.amber),
                              if (m.isExpired)
                                _chip('만료', Colors.redAccent),
                              IconButton(
                                tooltip: '일지',
                                icon: const Icon(Icons.menu_book_outlined),
                                onPressed: () => _openJournal(m),
                              ),
                              IconButton(
                                tooltip: '수정',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openEdit(m),
                              ),
                            ],
                          ),
                          onTap: () => _openJournal(m),
                          onLongPress: () => _showClassifySheet(m),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('신규 회원 등록'),
      ),
    );
  }
}

/* ─────────────  바인더 카드  ───────────── */

class BinderCard extends StatefulWidget {
  const BinderCard({
    super.key,
    required this.member,
    required this.onOpenJournal,
    required this.onOpenEdit,
    required this.onLongPress,
    this.query = '',
  });

  final Member member;
  final Future<void> Function() onOpenJournal;
  final Future<void> Function() onOpenEdit;
  final VoidCallback onLongPress;
  final String query;

  @override
  State<BinderCard> createState() => _BinderCardState();
}

enum _OpenState { closed, peek }

class _BinderCardState extends State<BinderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  _OpenState _state = _OpenState.closed;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: const Cubic(0.22, 0.61, 0.36, 1.0),
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enterPeek() async {
    if (_isAnimating || _state == _OpenState.peek) return;
    _isAnimating = true;
    HapticFeedback.selectionClick();
    try {
      await _ctrl.animateTo(
        0.38,
        duration: const Duration(milliseconds: 200),
        curve: const Cubic(0.18, 0.7, 0.28, 1.0),
      );
      _state = _OpenState.peek;
    } finally {
      _isAnimating = false;
    }
  }

  Future<void> _closePeek() async {
    if (_isAnimating || _state == _OpenState.closed) return;
    _isAnimating = true;
    try {
      await _ctrl.animateBack(
        0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      _state = _OpenState.closed;
    } finally {
      _isAnimating = false;
    }
  }

  Future<void> _goJournal() async {
    if (_isAnimating) return;
    _isAnimating = true;
    HapticFeedback.mediumImpact();
    try {
      await _ctrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      if (mounted) {
        await widget.onOpenJournal();
      }
    } finally {
      if (mounted) {
        await _ctrl.animateBack(
          0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      _state = _OpenState.closed;
      _isAnimating = false;
    }
  }

  void _onTap() {
    if (_state == _OpenState.closed) {
      _enterPeek();
    } else {
      _goJournal();
    }
  }

  void _onDoubleTap() => _goJournal();

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final w = math.min(MediaQuery.sizeOf(context).width * .86, 420.0);
    final hitWidth = kPreciseHitArea ? w : w + 28;
    final baseColor = _genderColor(m.gender);
    final isExpired = m.isExpired;

    final gradient = isExpired
        ? const LinearGradient(
      colors: [Color(0xFFE6E7EA), Color(0xFFCfd2D6), Color(0xFFA8ACB1)],
    )
        : (m.gender == Gender.female
        ? const LinearGradient(
      colors: [Color(0xFFFFE0EE), Color(0xFFFFC2DA), Color(0xFFFF97BD)],
    )
        : const LinearGradient(
      colors: [Color(0xFFD9ECFF), Color(0xFFBFE0FF), Color(0xFF8CC4FF)],
    ));

    final bookTilt = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateY(-10 * math.pi / 180)
      ..translate(0.0, 6.0);

    final coverAngle =
    Tween(begin: 0.0, end: -100 * math.pi / 180).animate(_t);

    return SizedBox(
      width: hitWidth,
      child: TapRegion(
        groupId: this,
        onTapOutside: (_) {
          if (_state == _OpenState.peek) _closePeek();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onDoubleTap: _onDoubleTap,
          onLongPress: widget.onLongPress,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform(
              transform: bookTilt,
              alignment: Alignment.centerLeft,
              child: _BinderVisual(
                width: w,
                spineColor: baseColor,
                cardGradient: gradient,
                isExpired: isExpired,
                member: m,
                t: _t,
                coverAngle: coverAngle,
                onOpenEdit: widget.onOpenEdit,
                onOpenJournal: widget.onOpenJournal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────────  바인더 시각요소들 (원본 그대로)  ───────────────────────── */

class _BinderVisual extends StatelessWidget {
  const _BinderVisual({
    required this.width,
    required this.spineColor,
    required this.cardGradient,
    required this.isExpired,
    required this.member,
    required this.t,
    required this.coverAngle,
    required this.onOpenEdit,
    required this.onOpenJournal,
  });

  final double width;
  final Color spineColor;
  final Gradient cardGradient;
  final bool isExpired;
  final Member member;
  final Animation<double> t;
  final Animation<double> coverAngle;
  final Future<void> Function() onOpenEdit;
  final Future<void> Function() onOpenJournal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const endAngle = -100 * math.pi / 180;

    Widget paper(double k) {
      final fmt = DateFormat('yyyy-MM-dd');
      final opacity = Curves.easeOut.transform(((k - 0.15) / 0.35).clamp(0.0, 1.0));
      final slideY = (1 - opacity) * 18;

      final dday = _dday(member.expireAt);
      final ddayText = dday == null
          ? '-'
          : (dday == 0 ? 'D-Day' : (dday > 0 ? 'D-$dday' : 'D+${dday.abs()}'));

      final total = member.totalSessions;
      final remain = member.remainingSessions;
      final p = total > 0 ? (remain / total).clamp(0.0, 1.0) : 0.0;
      final low = remain <= 3;

      return Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, slideY),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.fromLTRB(36, 8, 10, 10),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _genderColor(member.gender).withOpacity(.15),
                        child: Icon(
                          member.gender == Gender.female
                              ? Icons.female
                              : member.gender == Gender.male
                              ? Icons.male
                              : Icons.person_outline,
                          color: _genderColor(member.gender),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${member.name ?? member.id} 고객정보',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ProgressRing(
                        progress: p,
                        color: low ? Colors.redAccent : theme.colorScheme.primary,
                        label: '$remain/$total',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _InfoRow('마지막 등록일', member.recentReg != null ? fmt.format(member.recentReg!) : '-'),
                  _InfoRow('만료일', member.expireAt != null ? fmt.format(member.expireAt!) : '-'),
                  _InfoRow('D-day', ddayText),
                  _InfoRow('최근 작성', member.lastLogAt != null ? fmt.format(member.lastLogAt!) : '-'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('운동기록일지'),
                          onPressed: onOpenJournal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('고객정보 확인/수정'),
                          onPressed: onOpenEdit,
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

    return AnimatedBuilder(
      animation: Listenable.merge([t, coverAngle]),
      builder: (context, _) {
        final k = (coverAngle.value / endAngle).clamp(0.0, 1.0).abs();
        final forward = Curves.easeOut.transform(t.value.clamp(0.0, 1.0));
        final scale = 1.0 + 0.12 * forward;
        final lift = 10.0 * forward;

        return Transform.translate(
          offset: Offset(0, -lift),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: width,
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isExpired ? .25 : .08),
                    blurRadius: isExpired ? 28 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.white.withOpacity(.0),
                              Colors.white.withOpacity(.16),
                              Colors.white.withOpacity(.0),
                            ],
                            stops: const [0.0, 0.3, 0.6],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 46,
                    child: Container(
                      width: 22,
                      height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [spineColor.withOpacity(.55), spineColor.withOpacity(.85)],
                        ),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                        border: Border.all(color: spineColor.withOpacity(.85), width: 2),
                      ),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          '${member.name ?? member.id} 고객님',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  paper(k),
                  if (member.isExpired || member.memberStatus == '휴면')
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: member.isExpired
                              ? Colors.redAccent.withOpacity(.95)
                              : Colors.amber.withOpacity(.95),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 10)],
                        ),
                        child: Text(
                          member.isExpired ? '만료' : '휴강',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: _BinderCover(
                      angle: coverAngle.value,
                      hingeX: 36,
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

class _BinderCover extends StatelessWidget {
  const _BinderCover({required this.angle, required this.hingeX});
  final double angle;
  final double hingeX;

  @override
  Widget build(BuildContext context) {
    final cover = Container(
      margin: EdgeInsets.only(left: hingeX - 2, right: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );

    final wobble = math.sin(angle.abs() * 1.2) * 0.6;

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0018)
      ..translate(hingeX, wobble)
      ..rotateY(angle)
      ..translate(-hingeX, 0.0);

    return Transform(transform: m, alignment: Alignment.centerLeft, child: cover);
  }
}

/* ─────────────────────────  공용 위젯/함수  ───────────────────────── */

Color _genderColor(Gender g) {
  switch (g) {
    case Gender.female:
      return const Color(0xFFFF6FA4);
    case Gender.male:
      return const Color(0xFF2E6DD8);
    case Gender.unknown:
      return Colors.teal;
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
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.label,
  });
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
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
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

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.shade300;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(colors: [color, color.withOpacity(.85)]).createShader(Offset.zero & size);

    canvas.drawArc(
      Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke),
      -math.pi / 2,
      math.pi * 2,
      false,
      bg,
    );
    canvas.drawArc(
      Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

extension _Highlight on Widget {
  Widget _withHighlight(bool highlight) {
    if (!highlight) return this;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orangeAccent.withOpacity(0.8 * (1 - value)),
                blurRadius: 12 * (1 - value),
                spreadRadius: 4 * (1 - value),
              )
            ],
          ),
          child: child,
        );
      },
      child: this,
    );
  }
}

int? _dday(DateTime? target) {
  if (target == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(target.year, target.month, target.day);
  return d.difference(today).inDays;
}

Widget _chip(String text, Color color) => Container(
  margin: const EdgeInsets.only(right: 6),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: color.withOpacity(.14),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: color.withOpacity(.7)),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontWeight: FontWeight.w800),
  ),
);