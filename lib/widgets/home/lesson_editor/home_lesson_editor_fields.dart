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
  });

  final TextEditingController nameController;
  final TextEditingController sessionCountController;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onClearName;
  final bool hasLinkedMember;
  final VoidCallback onNameTap;
  final bool showAutocompleteDropdown;
  final Widget? autocompleteDropdown;

  @override
  State<HomeLessonMemberInputSection> createState() =>
      _HomeLessonMemberInputSectionState();
}

class _HomeLessonMemberInputSectionState
    extends State<HomeLessonMemberInputSection> {
  final LayerLink _nameFieldLayerLink = LayerLink();
  final GlobalKey _nameFieldKey = GlobalKey();
  final FocusNode _nameFocusNode = FocusNode();
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
    _nameFocusNode
      ..removeListener(_scheduleAutocompleteSync)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                      suffixIcon: widget.nameController.text.trim().isEmpty
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
            SizedBox(
              width: 84,
              child: TextField(
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
                  hintText: '30/12',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                  fillColor: widget.hasLinkedMember
                      ? colors.surfaceContainerHigh
                      : theme.inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HomeLessonMemoSection extends StatelessWidget {
  const HomeLessonMemoSection({
    super.key,
    required this.memoController,
  });

  final TextEditingController memoController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: memoController,
      minLines: 1,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontSize: 13,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: '메모 (선택) — 예: 하체운동, 무릎 체크',
        hintStyle: TextStyle(
          fontSize: 12,
          color: colors.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 10,
        ),
      ),
    );
  }
}
