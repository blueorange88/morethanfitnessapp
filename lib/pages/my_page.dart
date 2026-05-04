import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_page.dart';

const Color kMyPrimary = Color(0xFF4F46E5);
const Color kMyPrimary2 = Color(0xFF9333EA);
const Color kMyBg = Color(0xFFF3F4F6);
const Color kMyCard = Colors.white;
const Color kMyBorder = Color(0xFFE5E7EB);
const Color kMyText = Color(0xFF111827);
const Color kMyMuted = Color(0xFF6B7280);
const double kMyMaxContentWidth = 480;

const Color kLuxuryDark = Color(0xFF0F1020);
const Color kLuxuryViolet = Color(0xFF7C3AED);
const Color kLuxuryBlue = Color(0xFF38BDF8);
const Color kLuxuryPink = Color(0xFFEC4899);

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _gymNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _introController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  OverlayEntry? _actionToastEntry;
  Timer? _actionToastTimer;

  static const String _docPathCollection = 'trainer_profile';
  static const String _docPathId = 'me';

  @override
  void initState() {
    super.initState();

    _loadProfile();

    for (final controller in [
      _nameController,
      _displayNameController,
      _gymNameController,
      _phoneController,
      _introController,
    ]) {
      controller.addListener(_refreshPreview);
    }
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(),
      ),
    );
  }

  @override
  void dispose() {
    _hideActionToast();

    for (final controller in [
      _nameController,
      _displayNameController,
      _gymNameController,
      _phoneController,
      _introController,
    ]) {
      controller.removeListener(_refreshPreview);
    }

    _nameController.dispose();
    _displayNameController.dispose();
    _gymNameController.dispose();
    _phoneController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_docPathCollection)
          .doc(_docPathId)
          .get();

      final data = doc.data();
      if (data != null) {
        _nameController.text = (data['name'] ?? '').toString();
        _displayNameController.text = (data['displayName'] ?? '').toString();
        _gymNameController.text = (data['gymName'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        _introController.text = (data['intro'] ?? '').toString();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('내 정보 불러오기에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final displayName = _displayNameController.text.trim();
      final gymName = _gymNameController.text.trim();
      final phone = _normalizePhone(_phoneController.text);
      final intro = _introController.text.trim();

      final shortName = _buildShortName(
        displayName.isNotEmpty ? displayName : name,
      );

      await FirebaseFirestore.instance
          .collection(_docPathCollection)
          .doc(_docPathId)
          .set({
        'name': name,
        'displayName': displayName,
        'gymName': gymName,
        'phone': phone,
        'intro': intro,
        'shortName': shortName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showSnack('내 정보를 저장했어요.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('저장에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _formatPhoneDisplay(String value) {
    final digits = _normalizePhone(value);

    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }

    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }

    return value.trim();
  }

  String _buildShortName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '트';

    final normalized =
    text.endsWith('강사') ? text.replaceAll('강사', '').trim() : text;

    if (normalized.isEmpty) {
      return text.length <= 2 ? text : text.substring(0, 2);
    }

    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }

  void _hideActionToast() {
    _actionToastTimer?.cancel();
    _actionToastTimer = null;
    _actionToastEntry?.remove();
    _actionToastEntry = null;
  }

  void _showActionToast(
      String message, {
        double bottomOffset = 76,
        Duration duration = const Duration(milliseconds: 1400),
      }) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _hideActionToast();

    _actionToastEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: bottomOffset,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withOpacity(0.94),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_actionToastEntry!);
    _actionToastTimer = Timer(duration, _hideActionToast);
  }

  void _showSnack(String msg) {
    _showActionToast(msg);
  }

  void _showPreparingSnack(String label) {
    _showSnack('$label 기능은 준비중입니다.');
  }

  void _showQuickRegisterBubblePopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '빠른등록',
      barrierColor: Colors.black.withOpacity(0.34),
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeInBack,
        );

        return Center(
          child: Transform.scale(
            scale: curved.value,
            child: Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: _QuickRegisterBubblePopup(
                onClose: () => Navigator.of(context).pop(),
                onMemberTap: () {
                  Navigator.of(context).pop();
                  _showPreparingSnack('회원 빠른등록');
                },
                onContractTap: () {
                  Navigator.of(context).pop();
                  _showPreparingSnack('계약서 빠른등록');
                },
                onScheduleTap: () {
                  Navigator.of(context).pop();
                  _showPreparingSnack('일정 빠른등록');
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyPrimary, width: 1.3),
        ),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : _nameController.text.trim();

    final previewShort = _buildShortName(previewName);
    final gymName = _gymNameController.text.trim();
    final intro = _introController.text.trim();
    final phone = _formatPhoneDisplay(_phoneController.text);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
        isTablet ? kMyMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: kMyBg,
          body: Center(
            child: SizedBox(
              width: width,
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: kMyPrimary,
                ),
              )
                  : Column(
                children: [
                  _buildHeader(
                    previewName: previewName,
                    previewShort: previewShort,
                    gymName: gymName,
                    intro: intro,
                    phone: phone,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileFormCard(),
                            const SizedBox(height: 14),
                            _buildPremiumBanner(),
                            const SizedBox(height: 14),
                            _buildMenuSection(
                              title: '관리',
                              items: [
                                _MyMenuItem(
                                  icon: Icons.settings_outlined,
                                  title: '설정',
                                  subtitle: '운영 설정, 위젯, 앱 정보를 관리합니다',
                                  onTap: _openSettingsPage,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildMenuSection(
                              title: '문서 / 내 회원 관리',
                              items: [
                                _MyMenuItem(
                                  icon: Icons.description_outlined,
                                  title: '계약서 관리',
                                  subtitle: '내 회원 계약서 작성과 지난 계약서 확인',
                                  onTap: () =>
                                      _showPreparingSnack('계약서 관리'),
                                ),
                                _MyMenuItem(
                                  icon: Icons.privacy_tip_outlined,
                                  title: '개인정보동의서 관리',
                                  subtitle: '수업일지 사용 동의서 관리',
                                  onTap: () => _showPreparingSnack(
                                    '개인정보동의서 관리',
                                  ),
                                ),
                                _MyMenuItem(
                                  icon:
                                  Icons.restore_from_trash_rounded,
                                  title: '삭제 대기 회원 복구',
                                  subtitle: '삭제 후 7일 내 복구 요청 관리',
                                  onTap: () => _showPreparingSnack(
                                    '삭제 대기 회원 복구',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
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

  Widget _buildHeader({
    required String previewName,
    required String previewShort,
    required String gymName,
    required String intro,
    required String phone,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPadding + 10, 12, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: kLuxuryViolet.withOpacity(0.22),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF111827),
                        Color(0xFF312E81),
                        Color(0xFF7C3AED),
                        Color(0xFFEC4899),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -90,
                left: -40,
                child: _GlossyBlob(
                  size: 210,
                  color: Colors.white,
                  opacity: 0.18,
                ),
              ),
              Positioned(
                right: -70,
                bottom: -80,
                child: _GlossyBlob(
                  size: 230,
                  color: kLuxuryBlue,
                  opacity: 0.20,
                ),
              ),
              Positioned(
                right: 26,
                top: 74,
                child: _GlossyBlob(
                  size: 86,
                  color: kLuxuryPink,
                  opacity: 0.18,
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.20),
                          Colors.white.withOpacity(0.04),
                          Colors.black.withOpacity(0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 12,
                child: Container(
                  height: 1.2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.75),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 46,
                      child: Row(
                        children: [
                          _GlassCircleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '마이페이지',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                shadows: [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const _LuxuryBadge(text: 'BASIC'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.10),
                            blurRadius: 18,
                            offset: const Offset(-6, -6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _GlossyAvatar(text: previewShort),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '홈 헤더 미리보기',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  previewName.isEmpty
                                      ? '강사님'
                                      : '$previewName님',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  gymName.isEmpty ? '센터명을 입력해보세요' : gymName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.78),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (intro.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    intro,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.68),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.62),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    WaterDropQuickButton(
                      text: '빠른등록',
                      icon: Icons.add_rounded,
                      onTap: _showQuickRegisterBubblePopup,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFormCard() {
    return _MySectionCard(
      title: '내 정보관리',
      subtitle: '홈 화면과 앱 안에서 보여질 강사 정보를 관리합니다',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _buildField(
            controller: _nameController,
            label: '실명',
            hint: '예: 모어댄',
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return '이름을 입력해주세요.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _displayNameController,
            label: '표시 이름',
            hint: '예: 김쌤',
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _gymNameController,
            label: '센터명',
            hint: '예: MORE THAN GYM',
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _phoneController,
            label: '연락처',
            hint: '01012345678',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _introController,
            label: '한줄 소개',
            hint: '예: 재활과 체형교정 중심 PT',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: kMyPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                '저장',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return InkWell(
      onTap: () => _showPreparingSnack('프리미엄 업그레이드'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF111827),
              Color(0xFF4F46E5),
              Color(0xFFF97316),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kMyPrimary.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFBBF24),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '프리미엄으로 업그레이드',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'AI 인사이트, 운영통계, 계약 관리 기능을 활용해보세요.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required List<_MyMenuItem> items,
  }) {
    return _MySectionCard(
      title: title,
      icon: Icons.tune_rounded,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];

          return Column(
            children: [
              _MyMenuTile(item: item),
              if (index != items.length - 1)
                const Divider(
                  height: 1,
                  color: kMyBorder,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _MySectionCard extends StatelessWidget {
  const _MySectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: kMyCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kMyBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: kMyPrimary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kMyText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: kMyMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MyMenuItem {
  const _MyMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingText;
  final bool danger;
}

class _MyMenuTile extends StatelessWidget {
  const _MyMenuTile({
    required this.item,
  });

  final _MyMenuItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? const Color(0xFFDC2626) : kMyPrimary;
    final titleColor = item.danger ? const Color(0xFFDC2626) : kMyText;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: kMyMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.trailingText != null)
              Text(
                item.trailingText!,
                style: const TextStyle(
                  color: kMyMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlossyBlob extends StatelessWidget {
  const _GlossyBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(opacity * 0.35),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.28),
                Colors.white.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _LuxuryBadge extends StatelessWidget {
  const _LuxuryBadge({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.30),
            Colors.white.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GlossyAvatar extends StatelessWidget {
  const _GlossyAvatar({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFEDE9FE),
            Color(0xFFC4B5FD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.42),
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            left: 14,
            child: Container(
              width: 22,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF4C1D95),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class WaterDropQuickButton extends StatefulWidget {
  const WaterDropQuickButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<WaterDropQuickButton> createState() => _WaterDropQuickButtonState();
}

class _WaterDropQuickButtonState extends State<WaterDropQuickButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: double.infinity,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE0F2FE),
                  Color(0xFF38BDF8),
                  Color(0xFF7C3AED),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withOpacity(0.36),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.28),
                  blurRadius: 10,
                  offset: const Offset(-4, -4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.38),
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 20,
                  right: 80,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.70),
                          Colors.white.withOpacity(0.10),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.28),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.bubble_chart_rounded,
                      color: Colors.white,
                      size: 22,
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

class _QuickRegisterBubblePopup extends StatelessWidget {
  const _QuickRegisterBubblePopup({
    required this.onClose,
    required this.onMemberTap,
    required this.onContractTap,
    required this.onScheduleTap,
  });

  final VoidCallback onClose;
  final VoidCallback onMemberTap;
  final VoidCallback onContractTap;
  final VoidCallback onScheduleTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.92),
                    const Color(0xFFE0F2FE).withOpacity(0.86),
                    const Color(0xFFEDE9FE).withOpacity(0.90),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.72),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.25),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -22,
                    left: 20,
                    child: Container(
                      width: 92,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF38BDF8),
                                  Color(0xFF7C3AED),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  const Color(0xFF7C3AED).withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '빠른등록',
                                  style: TextStyle(
                                    color: kMyText,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '자주 쓰는 등록을 빠르게 시작하세요',
                                  style: TextStyle(
                                    color: kMyMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _BubbleActionTile(
                        icon: Icons.person_add_alt_1_rounded,
                        title: '회원 빠른등록',
                        subtitle: '신규 회원 정보를 바로 입력합니다',
                        onTap: onMemberTap,
                      ),
                      const SizedBox(height: 10),
                      _BubbleActionTile(
                        icon: Icons.description_rounded,
                        title: '계약서 빠른등록',
                        subtitle: '계약서 작성을 바로 시작합니다',
                        onTap: onContractTap,
                      ),
                      const SizedBox(height: 10),
                      _BubbleActionTile(
                        icon: Icons.calendar_month_rounded,
                        title: '일정 빠른등록',
                        subtitle: '수업 일정을 빠르게 추가합니다',
                        onTap: onScheduleTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleActionTile extends StatelessWidget {
  const _BubbleActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.64),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF38BDF8).withOpacity(0.95),
                      const Color(0xFF7C3AED).withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kMyText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: kMyMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}