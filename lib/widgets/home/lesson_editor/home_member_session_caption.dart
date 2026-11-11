import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/registration_chip.dart';

/// 회원의 등록 현황을 불러오는 함수(테스트용 교체). 회원이 없거나 불러오지 못하면 null.
typedef MemberRegistrationLoader =
    Future<MemberRegistrationInfo?> Function(String memberId);

/// 홈 레슨 시트의 이름 옆 횟수 칸에 `총 N / 잔여 M (+횟수)`를 보여 준다.
/// 연결된 회원의 문서(회원카드·계약서가 쓰는 같은 필드)를 읽고, 잔여가 적으면 주황·소진이면 빨강,
/// 레슨이 등록되지 않았거나 회원이 연결되지 않았으면 [fallback](기본 입력 칸, 안내 글자 `총/잔여횟수`)을 그린다.
class HomeMemberSessionCaption extends StatefulWidget {
  const HomeMemberSessionCaption({
    super.key,
    required this.memberId,
    this.ownerUid,
    this.loader,
    this.fallback,
  });

  final String? memberId;

  /// 개인 워크스페이스면 이 회원이 내 회원인지 확인하는 데 쓴다.
  final String? ownerUid;
  final MemberRegistrationLoader? loader;

  /// 연결된 회원의 등록 현황이 없을 때(미연결·미등록·불러오는 중) 대신 보여 줄 위젯(기본 입력 칸).
  final Widget? fallback;

  @override
  State<HomeMemberSessionCaption> createState() =>
      _HomeMemberSessionCaptionState();
}

class _HomeMemberSessionCaptionState extends State<HomeMemberSessionCaption> {
  String _loadedFor = '';
  MemberRegistrationInfo? _info;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant HomeMemberSessionCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.memberId ?? '').trim() != _loadedFor) _reload();
  }

  Future<MemberRegistrationInfo?> _defaultLoad(String memberId) async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('members')
              .doc(memberId)
              .get();
      final data = snap.data();
      if (data == null) return null;
      final owner = (widget.ownerUid ?? '').trim();
      if (owner.isNotEmpty && (data['trainerId'] ?? '').toString() != owner) {
        return null;
      }
      return MemberRegistrationInfo.fromMemberData(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _reload() async {
    final id = (widget.memberId ?? '').trim();
    _loadedFor = id;
    if (id.isEmpty) {
      if (_info != null) setState(() => _info = null);
      return;
    }
    final info = await (widget.loader ?? _defaultLoad)(id);
    if (!mounted || _loadedFor != id) return;
    setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final fallback = widget.fallback ?? const SizedBox.shrink();
    if ((widget.memberId ?? '').trim().isEmpty ||
        info == null ||
        info.notRegistered) {
      return fallback;
    }
    final style = registrationChipStyleFor(info);
    final colors = Theme.of(context).colorScheme;
    // 입력 칸과 같은 모양·높이의 읽기 전용 칸. 글이 길면 칸 안에서 줄여 맞춘다.
    return InputDecorator(
      key: const Key('home_member_session_field'),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          style.compactLabel,
          key: const Key('home_member_session_caption'),
          maxLines: 1,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: style.color ?? colors.onSurface,
          ),
        ),
      ),
    );
  }
}
