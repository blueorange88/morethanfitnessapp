import 'package:flutter/material.dart';

import 'package:mtf_app/theme/app_colors.dart';

class HomeLessonMemberInputSection extends StatelessWidget {
  const HomeLessonMemberInputSection({
    super.key,
    required this.nameController,
    required this.sessionCountController,
    required this.onNameChanged,
    required this.onClearName,
    required this.hasLinkedMember,
    required this.onNameTap,
  });

  final TextEditingController nameController;
  final TextEditingController sessionCountController;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onClearName;
  final bool hasLinkedMember;
  final VoidCallback onNameTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: nameController,
            onTap: onNameTap,
            onChanged: onNameChanged,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: '이름 / 번호',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.lightTextHint,
              ),
              filled: true,
              fillColor: AppColors.lightSurface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorderFocus,
                  width: 1.1,
                ),
              ),
              suffixIcon: nameController.text.trim().isEmpty
                  ? null
                  : GestureDetector(
                onTap: onClearName,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.lightTextTertiary,
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 84,
          child: TextField(
            controller: sessionCountController,
            readOnly: hasLinkedMember,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: '30/12',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.lightTextHint,
              ),
              filled: true,
              fillColor: hasLinkedMember
                  ? const Color(0xFFF3F4F6)
                  : AppColors.lightSurface2,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD7DCE5),
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.lightBorderFocus,
                  width: 1.1,
                ),
              ),
            ),
          ),
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
    return TextField(
      controller: memoController,
      minLines: 1,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: '메모 (선택) — 예: 하체운동, 무릎 체크',
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.lightTextHint,
        ),
        filled: true,
        fillColor: AppColors.lightSurface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorder,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.lightBorderFocus,
            width: 1.1,
          ),
        ),
      ),
    );
  }
}