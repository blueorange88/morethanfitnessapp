import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../aifc/core/aifc_avatar.dart';
import '../../mtf_header_neon_overlay.dart';
import 'home_circle_icon_button.dart';
import 'home_header_stat_card.dart';
import '../../aifc_interaction.dart';

const String _kHomeHeaderCustomGreetingKey = 'home_header_custom_greeting_v1';
const Set<String> _kAutomaticLegacyGreetings = {
  '안녕하세요 강사님',
  '안녕하세요, 강사님',
  '안녕하세요 강사님!',
  '안녕하세요, 강사님!',
};

final Map<String, ValueNotifier<String?>> _homeHeaderGreetingNotifiers = {};
final Set<String> _loadedHomeHeaderGreetingScopes = {};

String homeGreetingTextForHour(int hour) {
  if (hour < 5) return '좋은 아침이에요';
  if (hour < 9) return '오늘도 시작해볼까요';
  if (hour < 12) return '숨을 고르고 시작해볼까요?';
  if (hour < 14) return '점심은 드셨어요?';
  if (hour < 17) return '내일은 더 힘이 날꺼에요!';
  if (hour < 19) return '오늘 하루도 저물어가네요';
  if (hour < 21) return '조금만 더 힘내세요!';
  if (hour < 23) return '오늘도 수고 많으셨어요';
  return '늦은 시간까지 고생 많으셨어요';
}

String homeHeaderNicknameLabel(String value) {
  final nickname = value.trim();
  if (nickname.isEmpty) return '';
  return nickname.endsWith('님') ? nickname : '$nickname님';
}

bool homeHeaderGreetingIncludesNickname(String greeting, String nickname) {
  final cleanGreeting = greeting.trim();
  final cleanNickname = nickname.trim();
  if (cleanGreeting.isEmpty || cleanNickname.isEmpty) return false;
  return cleanGreeting.contains(cleanNickname);
}

String homeHeaderFirstLine(String greeting, String nickname) {
  final cleanGreeting = greeting.trim();
  final nicknameLabel = homeHeaderNicknameLabel(nickname);
  if (nicknameLabel.isEmpty) return cleanGreeting;
  return cleanGreeting
      .replaceAll(nicknameLabel, '')
      .replaceAll(' ?', '?')
      .replaceAll(' !', '!')
      .trim();
}

String homeHeaderGreetingPreferenceKey(String scopeKey) {
  final cleanScope = scopeKey.trim();
  if (cleanScope.isEmpty || cleanScope == 'legacy') {
    return _kHomeHeaderCustomGreetingKey;
  }
  return '${_kHomeHeaderCustomGreetingKey}_$cleanScope';
}

bool isAutomaticHomeHeaderGreeting(String value) =>
    _kAutomaticLegacyGreetings.contains(value.trim());

ValueNotifier<String?> _homeHeaderGreetingNotifier(String scopeKey) =>
    _homeHeaderGreetingNotifiers.putIfAbsent(
      scopeKey,
      () => ValueNotifier<String?>(null),
    );

Future<void> _ensureHomeHeaderCustomGreetingLoaded(String scopeKey) async {
  if (!_loadedHomeHeaderGreetingScopes.add(scopeKey)) return;

  final prefs = await SharedPreferences.getInstance();
  final saved =
      prefs.getString(homeHeaderGreetingPreferenceKey(scopeKey))?.trim();

  if (saved != null &&
      saved.isNotEmpty &&
      !isAutomaticHomeHeaderGreeting(saved)) {
    _homeHeaderGreetingNotifier(scopeKey).value = saved;
  }
}

Future<void> _saveHomeHeaderCustomGreeting(
  String scopeKey,
  String value,
) async {
  final prefs = await SharedPreferences.getInstance();
  final clean = value.trim();
  final key = homeHeaderGreetingPreferenceKey(scopeKey);

  if (clean.isEmpty || isAutomaticHomeHeaderGreeting(clean)) {
    await prefs.remove(key);
    _homeHeaderGreetingNotifier(scopeKey).value = null;
    return;
  }

  await prefs.setString(key, clean);
  _homeHeaderGreetingNotifier(scopeKey).value = clean;
}

class HomeHeaderSection extends StatelessWidget {
  const HomeHeaderSection({
    super.key,
    required this.isExpanded,
    required this.todayCount,
    required this.weekCount,
    required this.moreSenseCount,
    required this.aiFcHeaderNotice,
    required this.notificationsOn,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onToggleExpanded,
    required this.onQuickMemberTap,
    required this.onNotificationTap,
    required this.onTodayTap,
    required this.onMoreSenseTap,
    required this.onWeekTap,
    this.loadProfileFromFirestore = true,
    this.profileDisplayName,
    this.headerGreetingText,
    this.expandedSupportNotice,
    this.allowGreetingEdit = true,
    this.greetingScopeKey = 'legacy',
  });

  final bool isExpanded;
  final int todayCount;
  final int weekCount;
  final int moreSenseCount;
  final String aiFcHeaderNotice;
  final bool notificationsOn;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onToggleExpanded;
  final VoidCallback onQuickMemberTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onTodayTap;
  final VoidCallback onMoreSenseTap;
  final VoidCallback onWeekTap;
  final bool loadProfileFromFirestore;
  final String? profileDisplayName;
  final String? headerGreetingText;
  final String? expandedSupportNotice;
  final bool allowGreetingEdit;
  final String greetingScopeKey;

  String _trainerHeaderNameFromData(Map<String, dynamic>? data) {
    final displayName = (data?['displayName'] ?? '').toString().trim();
    final name = (data?['name'] ?? '').toString().trim();

    return displayName.isNotEmpty ? displayName : name;
  }

  // ignore: unused_element
  _HomeHeaderGreetingCopy _buildHomeHeaderGreeting(
    Map<String, dynamic>? data,
  ) {
    final hour = DateTime.now().hour;
    final label = _trainerHeaderNameFromData(data).trim();
    if (label.isEmpty) {
      return const _HomeHeaderGreetingCopy(title: '안녕하세요');
    }
    final safeLabel = label.endsWith('님') ? label : '$label님';
    if (hour < 5)
      return _HomeHeaderGreetingCopy(title: '늦은 시간까지 고생 많으셨어요, $safeLabel');
    if (hour < 9) return _HomeHeaderGreetingCopy(title: '좋은 아침이에요, $safeLabel');
    if (hour < 12)
      return _HomeHeaderGreetingCopy(title: '오늘도 잘 시작해볼까요, $safeLabel?');
    if (hour < 14)
      return _HomeHeaderGreetingCopy(title: '점심은 드셨어요, $safeLabel?');
    if (hour < 17)
      return _HomeHeaderGreetingCopy(title: '나른한 오후예요, $safeLabel');
    if (hour < 19)
      return _HomeHeaderGreetingCopy(title: '오늘 하루도 저물어가네요, $safeLabel');
    if (hour < 21)
      return _HomeHeaderGreetingCopy(title: '여유로운 저녁이길 바라요, $safeLabel');
    if (hour < 23)
      return _HomeHeaderGreetingCopy(title: '오늘도 수고 많으셨어요, $safeLabel');
    return _HomeHeaderGreetingCopy(title: '늦은 시간까지 고생 많으셨어요, $safeLabel');
  }

  String _compactHomeHeaderGreeting(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return '';
    }

    final chars = clean.runes.toList();

    // 홈헤더는 좁아서 10자까지만 저장합니다.
    if (chars.length <= 12) {
      return clean;
    }

    return String.fromCharCodes(chars.take(12));
  }

  Future<void> _openHomeHeaderGreetingEditSheet({
    required BuildContext context,
    required String currentText,
  }) async {
    final result = await AifcInteraction.ask(
      context: context,
      question: '홈에 보여드릴 짧은 인사말을 정해볼까요?\n비워두고 저장하면 기본 문구로 돌아가요.',
      inputLabel: '예: 오늘도 힘내보자!!',
      initialValue: currentText,
      maxLines: 1,
      skipLabel: '닫기',
      onSkip: () {},
      onSave: (value) async {
        final compact = _compactHomeHeaderGreeting(value);

        if (compact.isEmpty) {
          await _saveHomeHeaderCustomGreeting(greetingScopeKey, '');
          return '기본 인사말로 다시 보여드릴게요.';
        }

        await _saveHomeHeaderCustomGreeting(greetingScopeKey, compact);

        if (compact != value.trim()) {
          return '$compact 으로 짧게 저장했어요.\n홈헤더에서 더 깔끔하게 보여드릴게요.';
        }

        return '$compact 으로 저장했어요.';
      },
    );

    if (result == null || result.trim().isEmpty) {
      return;
    }
  }

  String _pickExpandedHeaderMessage(
    List<String> messages, {
    int salt = 0,
  }) {
    if (messages.isEmpty) return '';

    final now = DateTime.now();

    final seed = now.year +
        now.month +
        now.day +
        (now.hour ~/ 2) +
        todayCount +
        weekCount +
        moreSenseCount +
        salt;

    return messages[seed.abs() % messages.length];
  }

  String _buildExpandedHeaderSupportNotice() {
    if (moreSenseCount > 0) {
      if (todayCount >= 9) {
        return _pickExpandedHeaderMessage(
          [
            '오늘은 바쁜 날이에요. MORE 센스 $moreSenseCount개는 제가 먼저 접어둘게요.',
            '레슨 흐름이 묵직한 날이에요. 놓치기 쉬운 관리 포인트 $moreSenseCount개만 챙겨볼까요?',
            '오늘 일정이 꽉 찼어요. MORE 센스 $moreSenseCount개는 필요할 때 바로 열어볼 수 있어요.',
          ],
          salt: 90,
        );
      }

      if (todayCount == 0) {
        return _pickExpandedHeaderMessage(
          [
            '레슨은 없지만 MORE 센스 $moreSenseCount개가 있어요. 시간 괜찮을 때만 가볍게 봐도 좋아요.',
            '오늘은 여유 있는 날이에요. MORE 센스 $moreSenseCount개만 슬쩍 훑어볼까요?',
            '쉬는 날엔 무리하지 말고, 관리 포인트 $moreSenseCount개만 가볍게 확인해도 좋아요.',
            '평온한 하루 보내고 계신가요? 잠깐 시간 나면 MORE 센스도 한 번 둘러보세요.',
          ],
          salt: 20,
        );
      }

      if (todayCount <= 4) {
        return _pickExpandedHeaderMessage(
          [
            '오늘 레슨 흐름은 여유 있어요. MORE 센스 $moreSenseCount개까지 챙기기 좋은 날이에요.',
            '레슨 사이에 볼 만한 관리 포인트 $moreSenseCount개가 있어요.',
            '오늘은 회원님 한 분 한 분 보기 좋은 날이에요. MORE 센스 $moreSenseCount개도 같이 볼까요?',
          ],
          salt: 40,
        );
      }

      return _pickExpandedHeaderMessage(
        [
          '오늘 챙기면 좋은 MORE 센스 $moreSenseCount개가 있어요.',
          '놓치기 쉬운 회원 관리 포인트 $moreSenseCount개를 모아뒀어요.',
          '레슨 흐름 보면서 MORE 센스 $moreSenseCount개도 같이 챙겨볼게요.',
          '작은 관심이 필요한 회원님 $moreSenseCount명이 있어요.',
        ],
        salt: 60,
      );
    }

    if (weekCount == 0) {
      return _pickExpandedHeaderMessage(
        [
          '아직 이번 주 레슨이 없어요. 첫 레슨 하나부터 가볍게 시작해볼까요?',
          '이번 주 시간표가 깨끗해요. 빈 칸을 누르면 바로 시작할 수 있어요.',
          '첫 일정만 넣어도 모어댄이 흐름을 같이 챙겨볼게요.',
        ],
        salt: 10,
      );
    }

    if (todayCount == 0) {
      return _pickExpandedHeaderMessage(
        [
          '오늘은 쉬는 날인가 봐요. 무리하지 말고 평온한 하루 보내세요.',
          '오늘은 여유롭게 일상에서 살짝 벗어나 볼까요?',
          '힐링하는 하루 보내고 계신가요? 오늘은 천천히 가도 괜찮아요.',
          '좋은 하루 보내고 계신가요? 레슨 없는 날엔 컨디션도 챙겨주세요.',
          '오늘도 힘나는 하루 보내세요. 다시 달릴 체력도 이런 날 비축하는 거죠.',
        ],
        salt: 30,
      );
    }

    if (todayCount <= 2) {
      return _pickExpandedHeaderMessage(
        [
          '오늘은 한 명 한 명 깊게 보기 좋은 스케줄이에요.',
          '레슨 $todayCount개, 디테일 챙기기 좋은 날이에요.',
          '오늘은 속도보다 깊이로 가기 좋은 하루예요.',
        ],
        salt: 50,
      );
    }

    if (todayCount <= 6) {
      return _pickExpandedHeaderMessage(
        [
          '오늘 레슨 $todayCount개, 무리 없이 레슨 리듬 타기 좋은 날이에요.',
          '레슨 흐름이 적당해요. 중간중간 체크포인트도 같이 볼게요.',
          '오늘은 꽉 차진 않았지만 충분히 일하는 맛 나는 날이에요.',
        ],
        salt: 70,
      );
    }

    return _pickExpandedHeaderMessage(
      [
        '오늘 레슨 $todayCount개, 딱 일하는 맛 나는 스케줄이에요.',
        '꽤 꽉 찬 하루예요. 레슨 사이 흐름을 같이 챙겨볼게요.',
        '오늘은 트레이너다운 하루네요. 순서와 페이스만 잘 잡아볼까요?',
      ],
      salt: 80,
    );
  }

  String _trainerShortNameFromData(Map<String, dynamic>? data) {
    final savedShortName = (data?['shortName'] ?? '').toString().trim();
    if (savedShortName.isNotEmpty) return savedShortName;

    final headerName = _trainerHeaderNameFromData(data);
    return _buildTrainerShortName(headerName);
  }

  String _buildTrainerShortName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final normalized =
        text.endsWith('강사님') ? text.replaceAll('강사님', '').trim() : text;

    if (normalized.isEmpty) {
      return text.length <= 2 ? text : text.substring(0, 2);
    }

    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    _ensureHomeHeaderCustomGreetingLoaded(greetingScopeKey);

    final topInset = MediaQuery.of(context).padding.top;
    final noticeText = aiFcHeaderNotice.trim().isEmpty
        ? '오늘도 모어댄이 옆에서 흐름을 같이 챙겨볼게요.'
        : aiFcHeaderNotice.trim();

    return MtfHeaderNeonOverlay(
      isExpanded: isExpanded,
      bottomRadius: 32,
      lineColor: const Color(0xFFD8B4FE),
      glowColor: const Color(0xFF7C3AED),
      strokeWidth: 2.3,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.only(
          top: topInset + 16,
          left: 24,
          right: 24,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor,
              secondaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggleExpanded,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child:
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: loadProfileFromFirestore
                          ? FirebaseFirestore.instance
                              .collection('trainer_profile')
                              .doc('me')
                              .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        final data = loadProfileFromFirestore
                            ? snapshot.data?.data()
                            : <String, dynamic>{
                                'displayName': profileDisplayName ?? '',
                              };

                        final shortName = _trainerShortNameFromData(data);
                        final nickname = _trainerHeaderNameFromData(data);
                        final greetingText = nickname.trim().isEmpty
                            ? '안녕하세요'
                            : homeGreetingTextForHour(DateTime.now().hour);
                        final nicknameLabel = homeHeaderNicknameLabel(nickname);

                        return Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  shortName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ValueListenableBuilder<String?>(
                                    valueListenable:
                                        _homeHeaderGreetingNotifier(
                                      greetingScopeKey,
                                    ),
                                    builder: (context, customGreeting, _) {
                                      final customText =
                                          customGreeting?.trim() ?? '';
                                      final fixedGreeting =
                                          headerGreetingText?.trim() ?? '';
                                      final displayText =
                                          fixedGreeting.isNotEmpty
                                              ? fixedGreeting
                                              : customText.isNotEmpty
                                                  ? customText
                                                  : greetingText;
                                      final completeFixedGreeting =
                                          (fixedGreeting.isNotEmpty ||
                                                  customText.isNotEmpty) &&
                                              homeHeaderGreetingIncludesNickname(
                                                displayText,
                                                nickname,
                                              );
                                      final firstLine = completeFixedGreeting
                                          ? displayText
                                          : homeHeaderFirstLine(
                                              displayText,
                                              nickname,
                                            );

                                      return GestureDetector(
                                        onLongPress: allowGreetingEdit
                                            ? () {
                                                _openHomeHeaderGreetingEditSheet(
                                                  context: context,
                                                  currentText: displayText,
                                                );
                                              }
                                            : null,
                                        behavior: HitTestBehavior.opaque,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              firstLine,
                                              key: const Key(
                                                'home_header_greeting_line',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                height: 1.15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.1,
                                              ),
                                            ),
                                            if (!completeFixedGreeting &&
                                                nicknameLabel.isNotEmpty)
                                              Text(
                                                nicknameLabel,
                                                key: const Key(
                                                  'home_header_nickname_line',
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 17,
                                                  height: 1.12,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.25,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      HomeCircleIconButton(
                        icon: Icons.note_add,
                        onTap: onQuickMemberTap,
                      ),
                      const SizedBox(width: 6),
                      HomeCircleIconButton(
                        icon: notificationsOn
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none_rounded,
                        onTap: onNotificationTap,
                      ),
                      const SizedBox(width: 6),
                      Builder(
                        builder: (innerContext) {
                          return HomeCircleIconButton(
                            icon: Icons.menu,
                            onTap: () {
                              Scaffold.of(innerContext).openEndDrawer();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const AifcAvatar(
                      size: 24,
                      isAnimating: true,
                      backgroundColor: Color(0xFF5B4BDB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        noticeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.3,
                          fontWeight: FontWeight.w700,
                          height: 1.38,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.topCenter,
                heightFactor: isExpanded ? 1.0 : 0.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: isExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: HomeHeaderStatCard(
                              key: const Key('home_header_stat_today'),
                              icon: Icons.calendar_today,
                              label: '오늘',
                              value: '$todayCount',
                              onTap: onTodayTap,
                              semanticLabel: '오늘 일정으로 이동',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: HomeHeaderStatCard(
                              key: const Key('home_header_stat_more_sense'),
                              icon: Icons.auto_awesome_rounded,
                              label: 'MORE 센스',
                              value: '$moreSenseCount',
                              onTap: onMoreSenseTap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: HomeHeaderStatCard(
                              key: const Key('home_header_stat_week'),
                              icon: Icons.trending_up,
                              label: '이번 주',
                              value: '$weekCount',
                              onTap: onWeekTap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: moreSenseCount > 0 ? onMoreSenseTap : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              moreSenseCount > 0
                                  ? Icons.auto_awesome_rounded
                                  : Icons.self_improvement_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                expandedSupportNotice?.trim().isNotEmpty == true
                                    ? expandedSupportNotice!.trim()
                                    : _buildExpandedHeaderSupportNotice(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.28,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (moreSenseCount > 0)
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeaderGreetingCopy {
  const _HomeHeaderGreetingCopy({
    required this.title,
  });

  final String title;
}
