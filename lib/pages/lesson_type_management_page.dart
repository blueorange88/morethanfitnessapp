import 'package:flutter/material.dart';

import '../services/personal_member_preferences_service.dart';
import '../theme.dart';
import '../widgets/aifc_interaction.dart';

const double kLessonTypeMaxContentWidth = 480;

class LessonTypeManagementPage extends StatefulWidget {
  const LessonTypeManagementPage({super.key, required this.personalOwnerUid});

  final String personalOwnerUid;

  @override
  State<LessonTypeManagementPage> createState() =>
      _LessonTypeManagementPageState();
}

class _LessonTypeManagementPageState extends State<LessonTypeManagementPage> {
  final TextEditingController _addController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<String> _customTypes = const [];

  PersonalMemberPreferencesService get _service =>
      PersonalMemberPreferencesService(uid: widget.personalOwnerUid.trim());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final preferences = await _service.loadFromServer();
      if (!mounted) return;
      setState(() {
        _customTypes = preferences.customLessonTypes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customTypes = const [];
        _loading = false;
      });
    }
  }

  void _showToast(String message) {
    AifcInteraction.toast(context: context, message: message);
  }

  Future<void> _addType() async {
    final value = normalizeCustomLessonType(_addController.text);
    if (value.isEmpty) return;

    final key = customLessonTypeComparisonKey(value);
    final builtInKeys =
        kBuiltInLessonTypes.map(customLessonTypeComparisonKey).toSet();
    if (builtInKeys.contains(key)) {
      _showToast('이미 기본 제공 종류에 있어요.');
      return;
    }
    if (_customTypes.any(
      (item) => customLessonTypeComparisonKey(item) == key,
    )) {
      _showToast('이미 추가된 종류예요.');
      return;
    }

    setState(() => _saving = true);
    try {
      final next = [..._customTypes, value];
      final result = await _service.saveCustomLessonTypes(next);
      if (!mounted) return;
      setState(() {
        _customTypes = result.customLessonTypes;
        _saving = false;
      });
      _addController.clear();
      _showToast('$value 종류를 추가했어요.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast('레슨 종류를 추가하지 못했어요.');
    }
  }

  Future<void> _deleteType(String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('레슨 종류를 삭제할까요?'),
            content: const Text('선택 목록에서만 제거되며 기존 회원과 일정의 저장값은 유지돼요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final next =
          _customTypes
              .where(
                (value) =>
                    customLessonTypeComparisonKey(value) !=
                    customLessonTypeComparisonKey(type),
              )
              .toList();
      final result = await _service.saveCustomLessonTypes(next);
      if (!mounted) return;
      setState(() {
        _customTypes = result.customLessonTypes;
        _saving = false;
      });
      _showToast('레슨 종류 목록에서 삭제했어요.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showToast('레슨 종류를 삭제하지 못했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kLessonTypeMaxContentWidth : constraints.maxWidth;
        final topPadding = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 16),
                    decoration: BoxDecoration(
                      gradient: context.mtfHeaderGradient,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).maybePop(),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.20),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '수업 유형 관리',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        _loading
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                28,
                              ),
                              child: Column(
                                children: [
                                  _LessonTypeSectionCard(
                                    title: '기본 제공 종류',
                                    subtitle: '모든 회원카드에서 바로 선택할 수 있어요',
                                    icon: Icons.check_circle_outline_rounded,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          kBuiltInLessonTypes
                                              .where((type) => type != '미입력')
                                              .map(
                                                (type) => Chip(
                                                  label: Text(type),
                                                  labelStyle: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .onSecondaryContainer,
                                                  ),
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .secondaryContainer,
                                                  side: BorderSide.none,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LessonTypeSectionCard(
                                    title: '직접 추가한 종류',
                                    subtitle: '이 목록만 삭제할 수 있어요',
                                    icon: Icons.add_circle_outline_rounded,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (_customTypes.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            child: Text(
                                              '추가한 레슨 종류가 없어요.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          )
                                        else
                                          ..._customTypes.map(
                                            (type) => ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(type),
                                              trailing: TextButton(
                                                onPressed:
                                                    _saving
                                                        ? null
                                                        : () =>
                                                            _deleteType(type),
                                                child: const Text('삭제'),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _addController,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText:
                                                          '새 레슨 종류 (예: 수중재활)',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                                onSubmitted: (_) => _addType(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton(
                                              onPressed:
                                                  _saving ? null : _addType,
                                              child: const Text('추가'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
      },
    );
  }
}

class _LessonTypeSectionCard extends StatelessWidget {
  const _LessonTypeSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.06),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
