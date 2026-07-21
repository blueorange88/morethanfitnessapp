import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_avatar.dart';
import '../aifc/core/aifc_typing_dots.dart';
import '../services/app_account_service.dart';
import '../services/account_claims_service.dart';
import '../services/app_workspace_mode.dart';
import '../services/firebase_emulator_config.dart';
import '../services/linked_account_access_service.dart';
import '../services/personal_profile_start_reader.dart';
import '../services/personal_start_diagnostics.dart';
import 'debug_legacy_workspace_shell.dart';
import 'home_page.dart';
import 'legacy_admin_workspace_shell.dart';
import 'linked_account_pending_page.dart';
import 'onboarding_page.dart';
import 'password_change_page.dart';
import 'platform_admin_workspace_page.dart';
import 'splash_router.dart';
import '../services/app_environment.dart';

@visibleForTesting
Widget buildCanonicalPersonalHome(
  String ownerUid, {
  Map<String, dynamic>? initialPersonalProfileData,
}) =>
    HomePage(
      personalOwnerUid: ownerUid,
      initialPersonalProfileData: initialPersonalProfileData,
    );

class AppAccountGate extends StatefulWidget {
  const AppAccountGate({
    super.key,
    this.service,
    this.accessGateway,
    this.linkedChild,
    this.personalWorkspaceChild,
    this.personalWorkspaceBuilder,
    this.claimsGateway,
    this.profileReader,
    this.nicknameGateway,
  });

  final AppAccountService? service;
  final LinkedAccountAccessGateway? accessGateway;
  final Widget? linkedChild;
  final Widget? personalWorkspaceChild;
  final Widget Function(AppAccountUser user)? personalWorkspaceBuilder;
  final AccountClaimsGateway? claimsGateway;
  final PersonalProfileStartReader? profileReader;
  final PersonalNicknameOnboardingGateway? nicknameGateway;

  @override
  State<AppAccountGate> createState() => _AppAccountGateState();
}

class _AppAccountGateState extends State<AppAccountGate> {
  bool _debugLegacyWorkspaceOpen = false;
  Future<_PersonalStartResult>? _personalStart;

  AppAccountService get _accountService =>
      widget.service ?? AppAccountService.instance;

  PersonalProfileStartReader get _profileReader =>
      widget.profileReader ?? FirebasePersonalProfileStartReader();

  Future<_PersonalStartResult> _preparePersonalStart() async {
    final user = await PersonalStartDiagnostics.run(
      PersonalStartStage.ensureAnonymousSession,
      _accountService.ensureAnonymousSession,
    );
    if (user.isAnonymous) {
      await PersonalStartDiagnostics.run(
        PersonalStartStage.bootstrapAnonymousBeginnerProfile,
        _accountService.bootstrapAnonymousBeginnerProfile,
      );
    }
    try {
      await _accountService.reconcilePersonalTier();
    } catch (_) {
      // 등급 self-heal 실패는 시작을 막지 않고 다음 재진입/저장 시 재시도한다.
    }
    final profile = await PersonalStartDiagnostics.run(
      PersonalStartStage.personalProfileRead,
      () => _profileReader.read(user),
    );
    if (kDebugMode) {
      debugPrint(
        '[MTF_PERSONAL_IDENTITY] uid=${user.uid} '
        'isAnonymous=${user.isAnonymous} profileExists=true '
        'profileSource=trainer_profiles/{uid}',
      );
    }
    return _PersonalStartResult(user: user, profile: profile);
  }

  void _retryPersonalStart() {
    final start = _preparePersonalStart();
    setState(() {
      _personalStart = start;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppEnvironmentConfig.debugLogLegacyWorkspaceAccess('directGate');
    if (AppEnvironmentConfig.canOpenDebugLegacyWorkspace &&
        _debugLegacyWorkspaceOpen) {
      return AppWorkspaceScope(
        key: const ValueKey(AppWorkspaceMode.legacyDeveloper),
        mode: AppWorkspaceMode.legacyDeveloper,
        child: DebugLegacyWorkspaceShell(
          onExit: () => setState(() => _debugLegacyWorkspaceOpen = false),
          child: widget.linkedChild ?? const HomePage(),
        ),
      );
    }

    final accountService = _accountService;
    return StreamBuilder<AppAccountUser?>(
      stream: accountService.userChanges(),
      initialData: accountService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null || user.isAnonymous) {
          final start = _personalStart ??= _preparePersonalStart();
          return FutureBuilder<_PersonalStartResult>(
            future: start,
            builder: (context, startSnapshot) {
              if (startSnapshot.connectionState != ConnectionState.done) {
                return const _PersonalStartProgress();
              }
              if (startSnapshot.hasError || !startSnapshot.hasData) {
                return _PersonalStartError(
                  error: startSnapshot.error,
                  onRetry: _retryPersonalStart,
                );
              }
              final result = startSnapshot.data!;
              return _buildPersonalEntry(
                accountService,
                result.user,
                result.profile,
              );
            },
          );
        }
        _personalStart = null;
        return _LinkedAccountGate(
          service: accountService,
          user: user,
          accessGateway:
              widget.accessGateway ?? FirebaseLinkedAccountAccessGateway(),
          linkedChild: widget.linkedChild,
          personalWorkspaceChild: widget.personalWorkspaceChild,
          personalWorkspaceBuilder: widget.personalWorkspaceBuilder,
          claimsGateway: widget.claimsGateway ?? FirebaseAccountClaimsGateway(),
          profileReader: _profileReader,
          nicknameGateway: widget.nicknameGateway ??
              FirebasePersonalNicknameOnboardingGateway(),
        );
      },
    );
  }

  Widget _buildPersonalWorkspace(
    AppAccountService accountService,
    AppAccountUser user,
    PersonalProfileStartResult profile,
  ) {
    AppEnvironmentConfig.debugLogLegacyWorkspaceAccess('personalHome');
    late final Widget workspace;
    try {
      workspace = PersonalStartDiagnostics.runSync(
        PersonalStartStage.personalWorkspace,
        () =>
            widget.personalWorkspaceBuilder?.call(user) ??
            widget.personalWorkspaceChild ??
            buildCanonicalPersonalHome(
              user.uid,
              initialPersonalProfileData: profile.profileData,
            ),
      );
    } on PersonalStartException catch (error) {
      return _PersonalStartError(
        error: error,
        onRetry: _retryPersonalStart,
      );
    }
    if (kDebugMode) {
      debugPrint('[MTF_APP_START] destination=canonicalHome');
      debugPrint(
        '[MTF_APP_START] canonicalHome=home_page.dart',
      );
      debugPrint('[MTF_APP_START] workspaceType=personal');
    }
    return Stack(
      key: ValueKey('personal_workspace_${user.uid}'),
      fit: StackFit.expand,
      children: [
        AppWorkspaceScope(
          mode: AppWorkspaceMode.personal,
          child: workspace,
        ),
        if (AppEnvironmentConfig.canOpenDebugLegacyWorkspace)
          Positioned(
            top: 6,
            right: 56,
            child: SafeArea(
              child: IconButton.filledTonal(
                key: const Key('open_debug_legacy_workspace'),
                tooltip: '기존 개발 데이터 열기',
                onPressed: () =>
                    setState(() => _debugLegacyWorkspaceOpen = true),
                icon: const Icon(Icons.developer_mode_rounded),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalEntry(
    AppAccountService accountService,
    AppAccountUser user,
    PersonalProfileStartResult profile,
  ) {
    if (profile.needsNicknameOnboarding) {
      var confirmedNickname = '';
      if (kDebugMode) {
        debugPrint('[MTF_APP_START] destination=nicknameOnboarding');
      }
      return OnboardingPage(
        key: ValueKey('nickname_onboarding_${user.uid}'),
        onSave: (nickname) async {
          await (widget.nicknameGateway ??
                  FirebasePersonalNicknameOnboardingGateway())
              .saveNickname(uid: user.uid, nickname: nickname);
          confirmedNickname = nickname.trim();
        },
        onCompleted: () => setState(() {
          if (confirmedNickname.isEmpty) return;
          _personalStart = Future.value(
            _PersonalStartResult(
              user: user,
              profile: PersonalProfileStartResult(
                nickname: confirmedNickname,
                onboardingCompleted: true,
                profileData: <String, dynamic>{
                  ...profile.profileData,
                  'nickname': confirmedNickname,
                  'onboardingCompleted': true,
                },
              ),
            ),
          );
        }),
      );
    }
    return _buildPersonalWorkspace(accountService, user, profile);
  }
}

class _PersonalStartResult {
  const _PersonalStartResult({required this.user, required this.profile});

  final AppAccountUser user;
  final PersonalProfileStartResult profile;
}

class _PersonalStartProgress extends StatefulWidget {
  const _PersonalStartProgress();

  @override
  State<_PersonalStartProgress> createState() => _PersonalStartProgressState();
}

class _PersonalStartProgressState extends State<_PersonalStartProgress> {
  static const _messages = <String>[
    'AI FC 모어댄이 오늘을 먼저 살펴보고 있어요.',
    '모어댄이 오늘의 흐름을 먼저 살펴보고 있어요.',
    'AI FC 모어댄이 놓치기 쉬운 순간을 확인하고 있어요.',
    '모어댄은 더 나은 피트니스를 지향합니다.',
    '관리 그 이상의 피트니스를 준비하고 있어요.',
    '오늘도 MORE THAN답게 준비하고 있어요.',
    '잠시만요, 금방 나갈게요.',
    '잠시만요, 머리만 빗고 바로 나갈게요.',
    '신발 끈만 묶고 바로 갈게요.',
    '마지막으로 한 번만 확인하고 갈게요.',
  ];
  static const _weightedIndexes = <int>[
    0,
    0,
    1,
    1,
    2,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
  ];
  static int? _lastMessageIndex;

  Timer? _messageTimer;
  late int _messageIndex;

  @override
  void initState() {
    super.initState();
    _messageIndex = _nextMessageIndex();
    _lastMessageIndex = _messageIndex;
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = _nextMessageIndex();
        _lastMessageIndex = _messageIndex;
      });
    });
  }

  int _nextMessageIndex() {
    final candidates = _weightedIndexes
        .where((index) => index != _lastMessageIndex)
        .toList(growable: false);
    return candidates[math.Random().nextInt(candidates.length)];
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: kOnboardingBg,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: kOnboardingBg,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        key: const Key('personal_start_progress'),
        backgroundColor: kOnboardingBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '모어댄',
                    key: Key('personal_start_brand_name'),
                    style: TextStyle(
                      color: kOnboardingText,
                      fontSize: 34,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'MORE THAN',
                    key: Key('personal_start_brand_english'),
                    style: TextStyle(
                      color: kOnboardingMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.3,
                    ),
                  ),
                  const SizedBox(height: 38),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const AifcAvatar(
                        key: Key('personal_start_aifc_avatar'),
                        size: 68,
                        isAnimating: true,
                        backgroundColor: kOnboardingBg,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: Text(
                                _messages[_messageIndex],
                                key: ValueKey(_messageIndex),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: kOnboardingText,
                                  fontSize: 15,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const AifcTypingDots(
                              key: Key('personal_start_typing_dots'),
                              color: kOnboardingPrimary,
                            ),
                          ],
                        ),
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

class _PersonalStartError extends StatelessWidget {
  const _PersonalStartError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const emulatorMode = FirebaseEmulatorConfig.isEnabled;
    final failureKind = PersonalStartDiagnostics.failureKind(error);
    final failureLabel = switch (failureKind) {
      PersonalStartFailureKind.anonymousAccount => '익명 계정 준비 실패',
      PersonalStartFailureKind.profile => '프로필 준비 실패',
      PersonalStartFailureKind.functionsEmulator =>
        emulatorMode ? 'Functions Emulator 연결 실패' : '프로필 준비 실패',
      PersonalStartFailureKind.firestore => 'Firestore 준비 실패',
      PersonalStartFailureKind.workspace => '프로필 준비 실패',
    };
    return Scaffold(
      key: const Key('personal_start_error'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 16),
              const Text(
                '시작 준비 중 문제가 생겼어요.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                failureLabel,
                key: const Key('personal_start_failure_kind'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                emulatorMode
                    ? 'Local Emulator Suite와 USB 포트 연결을 확인해주세요.'
                    : '네트워크를 확인한 뒤 다시 시도해주세요.',
                key: emulatorMode
                    ? Key('firebase_emulator_connection_error')
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('retry_personal_start'),
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedAccountGate extends StatefulWidget {
  const _LinkedAccountGate({
    required this.service,
    required this.user,
    required this.accessGateway,
    required this.claimsGateway,
    required this.profileReader,
    required this.nicknameGateway,
    this.linkedChild,
    this.personalWorkspaceChild,
    this.personalWorkspaceBuilder,
  });

  final AppAccountService service;
  final AppAccountUser user;
  final LinkedAccountAccessGateway accessGateway;
  final AccountClaimsGateway claimsGateway;
  final PersonalProfileStartReader profileReader;
  final PersonalNicknameOnboardingGateway nicknameGateway;
  final Widget? linkedChild;
  final Widget? personalWorkspaceChild;
  final Widget Function(AppAccountUser user)? personalWorkspaceBuilder;

  @override
  State<_LinkedAccountGate> createState() => _LinkedAccountGateState();
}

class _LinkedAccountGateState extends State<_LinkedAccountGate> {
  late Future<_LinkedGateResult> _check;
  _AdminWorkspaceSelection? _adminWorkspaceSelection;
  Future<PersonalProfileStartResult>? _personalProfile;

  @override
  void initState() {
    super.initState();
    _check = _load();
  }

  void _retry() => setState(() {
        _adminWorkspaceSelection = null;
        _check = _load();
      });

  @override
  void didUpdateWidget(covariant _LinkedAccountGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid == widget.user.uid) return;
    _adminWorkspaceSelection = null;
    _check = _load();
    _personalProfile = null;
  }

  Future<_LinkedGateResult> _load() async {
    final status = await widget.accessGateway.check(widget.user);
    PlatformAccountClaims claims;
    try {
      claims = await widget.claimsGateway.read(forceRefresh: true);
    } catch (_) {
      claims = const PlatformAccountClaims();
    }
    PersonalProfileStartResult? personalProfile;
    if (status == LinkedAccountAccessStatus.personalWorkspaceReady) {
      try {
        await widget.service.reconcilePersonalTier();
      } catch (_) {
        // 등급 reconcile은 best effort이며 workspace 시작을 차단하지 않는다.
      }
      personalProfile = await widget.profileReader.read(widget.user);
    }
    return _LinkedGateResult(
      status: status,
      claims: claims,
      personalProfile: personalProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LinkedGateResult>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data ??
            const _LinkedGateResult(
              status: LinkedAccountAccessStatus.unknown,
              claims: PlatformAccountClaims(),
              personalProfile: null,
            );
        final status = result.status;
        if (status == LinkedAccountAccessStatus.passwordChangeRequired) {
          return PasswordChangePage(
            forced: true,
            accountService: widget.service,
            onCompleted: _retry,
          );
        }
        Widget resolvedWorkspace(PersonalProfileStartResult profile) =>
            widget.personalWorkspaceBuilder?.call(widget.user) ??
            widget.personalWorkspaceChild ??
            buildCanonicalPersonalHome(
              widget.user.uid,
              initialPersonalProfileData: profile.profileData,
            );
        Widget personalWorkspace() {
          final profile = result.personalProfile;
          if (profile != null && !profile.needsNicknameOnboarding) {
            return resolvedWorkspace(profile);
          }
          return _LinkedPersonalEntry(
            user: widget.user,
            service: widget.service,
            profileFuture: _personalProfile ??= profile == null
                ? widget.profileReader.read(widget.user)
                : Future.value(profile),
            nicknameGateway: widget.nicknameGateway,
            workspaceBuilder: widget.personalWorkspaceBuilder,
            workspaceChild: widget.personalWorkspaceChild,
          );
        }

        final legacyWorkspace = widget.linkedChild ?? const SplashRouter();
        if (result.claims.platformAdmin &&
            (status == LinkedAccountAccessStatus.personalWorkspaceReady ||
                status == LinkedAccountAccessStatus.legacyAccessReady)) {
          if (_adminWorkspaceSelection == _AdminWorkspaceSelection.personal) {
            return AppWorkspaceScope(
              key: ValueKey('personal_workspace_${widget.user.uid}'),
              mode: AppWorkspaceMode.personal,
              child: personalWorkspace(),
            );
          }
          if (result.claims.legacyDataAccessApproved &&
              (_adminWorkspaceSelection == _AdminWorkspaceSelection.legacy ||
                  (_adminWorkspaceSelection == null &&
                      status == LinkedAccountAccessStatus.legacyAccessReady))) {
            return AppWorkspaceScope(
              key: const ValueKey(AppWorkspaceMode.legacyAdmin),
              mode: AppWorkspaceMode.legacyAdmin,
              child: LegacyAdminWorkspaceShell(
                onOpenPersonalWorkspace: () => setState(
                  () => _adminWorkspaceSelection =
                      _AdminWorkspaceSelection.personal,
                ),
                child: legacyWorkspace,
              ),
            );
          }
          return PlatformAdminWorkspacePage(
            canOpenLegacyWorkspace: result.claims.legacyDataAccessApproved,
            onOpenPersonalWorkspace: () => setState(
              () =>
                  _adminWorkspaceSelection = _AdminWorkspaceSelection.personal,
            ),
            onOpenLegacyWorkspace: () => setState(
              () => _adminWorkspaceSelection = _AdminWorkspaceSelection.legacy,
            ),
          );
        }
        if (status == LinkedAccountAccessStatus.personalWorkspaceReady) {
          return AppWorkspaceScope(
            key: ValueKey('personal_workspace_${widget.user.uid}'),
            mode: AppWorkspaceMode.personal,
            child: personalWorkspace(),
          );
        }
        return LinkedAccountPendingPage(
          service: widget.service,
          status: status,
          onRetry: _retry,
        );
      },
    );
  }
}

class _LinkedPersonalEntry extends StatefulWidget {
  const _LinkedPersonalEntry({
    required this.user,
    required this.service,
    required this.profileFuture,
    required this.nicknameGateway,
    this.workspaceBuilder,
    this.workspaceChild,
  });

  final AppAccountUser user;
  final AppAccountService service;
  final Future<PersonalProfileStartResult> profileFuture;
  final PersonalNicknameOnboardingGateway nicknameGateway;
  final Widget Function(AppAccountUser user)? workspaceBuilder;
  final Widget? workspaceChild;

  @override
  State<_LinkedPersonalEntry> createState() => _LinkedPersonalEntryState();
}

class _LinkedPersonalEntryState extends State<_LinkedPersonalEntry> {
  bool _completedInSession = false;
  String _confirmedNickname = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PersonalProfileStartResult>(
      future: widget.profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PersonalStartProgress();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _PersonalStartError(error: snapshot.error, onRetry: () {});
        }
        if (snapshot.data!.needsNicknameOnboarding && !_completedInSession) {
          if (kDebugMode) {
            debugPrint('[MTF_APP_START] destination=nicknameOnboarding');
          }
          return OnboardingPage(
            key: ValueKey('nickname_onboarding_${widget.user.uid}'),
            onSave: (nickname) async {
              await widget.nicknameGateway.saveNickname(
                uid: widget.user.uid,
                nickname: nickname,
              );
              _confirmedNickname = nickname.trim();
            },
            onCompleted: () {
              if (_confirmedNickname.isEmpty) return;
              setState(() => _completedInSession = true);
            },
          );
        }
        if (kDebugMode) {
          debugPrint('[MTF_APP_START] destination=canonicalHome');
          debugPrint(
            '[MTF_APP_START] canonicalHome=home_page.dart',
          );
          debugPrint('[MTF_APP_START] workspaceType=personal');
        }
        return widget.workspaceBuilder?.call(widget.user) ??
            widget.workspaceChild ??
            buildCanonicalPersonalHome(
              widget.user.uid,
              initialPersonalProfileData: <String, dynamic>{
                ...snapshot.data!.profileData,
                if (_confirmedNickname.isNotEmpty)
                  'nickname': _confirmedNickname,
                if (_completedInSession) 'onboardingCompleted': true,
              },
            );
      },
    );
  }
}

enum _AdminWorkspaceSelection { personal, legacy }

class _LinkedGateResult {
  const _LinkedGateResult({
    required this.status,
    required this.claims,
    required this.personalProfile,
  });

  final LinkedAccountAccessStatus status;
  final PlatformAccountClaims claims;
  final PersonalProfileStartResult? personalProfile;
}
