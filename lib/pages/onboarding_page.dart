import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../aifc/core/aifc_nickname.dart';

import 'home_page.dart';

const Color kOnboardingPrimary = Color(0xFF4F46E5);
const Color kOnboardingPrimary2 = Color(0xFF9333EA);
const Color kOnboardingBg = Color(0xFFF3F4F6);
const Color kOnboardingText = Color(0xFF111827);
const Color kOnboardingMuted = Color(0xFF6B7280);
const Color kOnboardingBorder = Color(0xFFE5E7EB);

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.onSave,
    this.onCompleted,
  });

  final Future<void> Function(String nickname)? onSave;
  final VoidCallback? onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _nicknameController = TextEditingController();

  int _currentStep = 0;
  bool _isSaving = false;

  static const String _profileCollection = 'trainer_profile';
  static const String _profileDocId = 'me';

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_refresh);
    _nicknameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _canStart => _nicknameController.text.trim().isNotEmpty;

  Future<void> _goToNicknameStep() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _currentStep = 1;
    });

    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _saveAndEnter() async {
    if (!_canStart || _isSaving) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final nickname = _nicknameController.text.trim();
      final save = widget.onSave;
      if (save != null) {
        await save(nickname);
        if (!mounted) return;
        widget.onCompleted?.call();
        return;
      }
      final shortName = _buildShortName(nickname);

      await FirebaseFirestore.instance
          .collection(_profileCollection)
          .doc(_profileDocId)
          .set({
        'displayName': nickname,
        'shortName': shortName,
        'onboardingCompleted': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),

        // 나중에 AI FC 넛지 흐름에서 사용
        'aiFcNudge': {
          'firstLessonGuideShown': false,
          'notificationPromptShown': false,
          'customerCardPromptShown': false,
          'contractPromptShown': false,
          'kakaoConnectPromptShown': false,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('시작 정보를 저장하지 못했어요. 잠시 후 다시 시도해주세요.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildShortName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '쌤';

    final normalized =
        text.endsWith('강사') ? text.replaceAll('강사', '').trim() : text;

    final target = normalized.isEmpty ? text : normalized;

    return target.length <= 2 ? target : target.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOnboardingBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const SizedBox(height: 18),
                _buildStepDots(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildIntroStep(),
                      _buildNicknameStep(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _currentStep == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? kOnboardingPrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildIntroStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    kOnboardingPrimary,
                    kOnboardingPrimary2,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: kOnboardingPrimary.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '만나서 반가워요.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '저는 강사님만을 위한\nAI 피트니스 카운셀러예요.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                      ),
                    ),
                    child: const Text(
                      '편하게 AI FC라고 불러주세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '정확한 스케줄 관리,\n세심한 회원관리,\n계약서와 수업 포인트까지\n더 체계적으로 관리할 수 있도록\n도와드릴게요.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.55,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const Key('onboarding_intro_continue'),
              onPressed: _goToNicknameStep,
              style: FilledButton.styleFrom(
                backgroundColor: kOnboardingPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '좋아요, 시작할게요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameStep() {
    final nickname = _nicknameController.text.trim();
    final nicknameLabel = aifcNicknameLabel(nickname);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '제가 어떻게\n불러드릴까요?',
            style: TextStyle(
              color: kOnboardingText,
              fontSize: 28,
              height: 1.22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '앱 안에서 AI FC가 사용할 편한 이름을 알려주세요.',
            style: TextStyle(
              color: kOnboardingMuted,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            key: const Key('onboarding_nickname'),
            controller: _nicknameController,
            maxLength: 6,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveAndEnter(),
            decoration: InputDecoration(
              labelText: '닉네임',
              hintText: '예: 민수쌤 / 김팀장 / MAX',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: kOnboardingBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: kOnboardingBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: kOnboardingPrimary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: nickname.isEmpty
                ? const _AiFcMiniMessage(
                    key: ValueKey('empty'),
                    message: '편한 이름만 알려주시면 바로 시작할게요.',
                  )
                : _AiFcMiniMessage(
                    key: const ValueKey('filled'),
                    message: '좋아요. 앞으로 $nicknameLabel께 맞춰 도와드릴게요.',
                  ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              key: const Key('onboarding_save_nickname'),
              onPressed: _canStart && !_isSaving ? _saveAndEnter : null,
              style: FilledButton.styleFrom(
                backgroundColor: kOnboardingPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiFcMiniMessage extends StatelessWidget {
  const _AiFcMiniMessage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC7D2FE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: kOnboardingPrimary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: kOnboardingText,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
