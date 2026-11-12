import 'package:flutter/material.dart';

class HomeLessonMemberInputSection extends StatefulWidget {
  const HomeLessonMemberInputSection({
    super.key,
    required this.nameController,
    required this.sessionCountController,
    required this.onNameChanged,
    required this.onClearName,
    required this.hasLinkedMember,
    required this.onNameTap,
    required this.showAutocompleteDropdown,
    this.autocompleteDropdown,
    this.nameFocusNode,
    this.sessionCountBuilder,
  });

  final TextEditingController nameController;
  final TextEditingController sessionCountController;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onClearName;
  final bool hasLinkedMember;
  final VoidCallback onNameTap;
  final bool showAutocompleteDropdown;
  final Widget? autocompleteDropdown;

  /// 저장할 때 이름이 비어 있으면 바깥에서 이 칸에 커서를 놓을 수 있도록 넘겨 받는 포커스.
  /// 넘기지 않으면 이 위젯이 자체 포커스를 만들어 쓴다.
  final FocusNode? nameFocusNode;

  /// 이름 옆 횟수 칸을 바꿔 그릴 때 쓴다(기본 입력 칸이 [defaultField]로 넘어온다). 연결된 회원의
  /// `총 N / 잔여 M (+X)`를 이 자리에 보여 주는 데 쓴다.
  final Widget Function(BuildContext context, Widget defaultField)?
  sessionCountBuilder;

  @override
  State<HomeLessonMemberInputSection> createState() =>
      _HomeLessonMemberInputSectionState();
}

class _HomeLessonMemberInputSectionState
    extends State<HomeLessonMemberInputSection> {
  final LayerLink _nameFieldLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();
  late final bool _ownsNameFocusNode = widget.nameFocusNode == null;
  late final FocusNode _nameFocusNode = widget.nameFocusNode ?? FocusNode();
  OverlayEntry? _autocompleteEntry;

  bool get _shouldShowAutocomplete =>
      widget.showAutocompleteDropdown &&
      widget.autocompleteDropdown != null &&
      _nameFocusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_scheduleAutocompleteSync);
  }

  @override
  void didUpdateWidget(covariant HomeLessonMemberInputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleAutocompleteSync();
  }

  void _scheduleAutocompleteSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAutocompleteOverlay();
    });
  }

  void _syncAutocompleteOverlay() {
    if (!_shouldShowAutocomplete) {
      _removeAutocompleteOverlay();
      return;
    }

    if (_autocompleteEntry != null) {
      _autocompleteEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context);
    _autocompleteEntry = OverlayEntry(
      builder: (context) {
        final fieldBox =
            _nameFieldKey.currentContext?.findRenderObject() as RenderBox?;
        final fieldWidth = fieldBox?.size.width ?? 0;

        if (fieldWidth <= 0 || widget.autocompleteDropdown == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          width: fieldWidth,
          child: CompositedTransformFollower(
            link: _nameFieldLayerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: widget.autocompleteDropdown!,
          ),
        );
      },
    );
    overlay.insert(_autocompleteEntry!);
  }

  void _removeAutocompleteOverlay() {
    _autocompleteEntry?.remove();
    _autocompleteEntry = null;
  }

  @override
  void dispose() {
    _removeAutocompleteOverlay();
    _nameFocusNode.removeListener(_scheduleAutocompleteSync);
    if (_ownsNameFocusNode) _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final defaultCountField = TextField(
      controller: widget.sessionCountController,
      readOnly: widget.hasLinkedMember,
      keyboardType: TextInputType.text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        // 예시 숫자 대신 형식만 알려 준다(회원이 연결돼 횟수가 있으면 값이 채워진다).
        hintText: '총/잔여횟수',
        hintStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        fillColor:
            widget.hasLinkedMember
                ? colors.surfaceContainerHigh
                : theme.inputDecorationTheme.fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: CompositedTransformTarget(
                link: _nameFieldLayerLink,
                child: SizedBox(
                  key: _nameFieldKey,
                  child: TextField(
                    key: const Key('home_lesson_member_name_field'),
                    controller: widget.nameController,
                    focusNode: _nameFocusNode,
                    onTap: widget.onNameTap,
                    onChanged: (value) {
                      widget.onNameChanged(value);
                      _scheduleAutocompleteSync();
                    },
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: '이름 / 번호',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      suffixIcon:
                          widget.nameController.text.trim().isEmpty
                              ? null
                              : GestureDetector(
                                onTap: widget.onClearName,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: 3,
              child:
                  widget.sessionCountBuilder?.call(
                    context,
                    defaultCountField,
                  ) ??
                  defaultCountField,
            ),
          ],
        ),
      ],
    );
  }
}

class HomeLessonMemoSection extends StatelessWidget {
  const HomeLessonMemoSection({super.key, required this.memoController});

  final TextEditingController memoController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: memoController,
      minLines: 1,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      style: TextStyle(fontSize: 13, color: colors.onSurface),
      decoration: InputDecoration(
        hintText: '메모 (선택) — 예: 하체운동, 무릎 체크',
        hintStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 10,
        ),
      ),
    );
  }
}
