import 'package:flutter/material.dart';
import '../models/anatomy_log.dart';
import '../models/body_part.dart';

class Step1BodyPartSelector extends StatelessWidget {
  const Step1BodyPartSelector({
    super.key,
    required this.selectedView,
    required this.selectedPartIds,
    required this.onViewChanged,
    required this.onPartToggled,
    required this.selectedGender,
    required this.selectedSide,
    required this.onGenderChanged,
    required this.onSideChanged,
  });

  final BodyView selectedView;
  final List<String> selectedPartIds;
  final ValueChanged<BodyView> onViewChanged;
  final ValueChanged<String> onPartToggled;
  final BodyGender selectedGender;
  final BodySide selectedSide;
  final ValueChanged<BodyGender> onGenderChanged;
  final ValueChanged<BodySide> onSideChanged;

  @override
  Widget build(BuildContext context) {
    final visibleParts =
        kBodyParts.where((p) => p.view == selectedView).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('바디 기준',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BodyGender.values.map((value) {
            final labels = {
              BodyGender.male: '남성',
              BodyGender.female: '여성',
              BodyGender.unspecified: '미지정',
            };
            return ChoiceChip(
              label: Text(labels[value]!),
              selected: selectedGender == value,
              onSelected: (_) => onGenderChanged(value),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BodySide.values.map((value) {
            final labels = {
              BodySide.left: '왼쪽',
              BodySide.right: '오른쪽',
              BodySide.center: '중앙',
              BodySide.both: '양측',
            };
            return ChoiceChip(
              label: Text(labels[value]!),
              selected: selectedSide == value,
              onSelected: (_) => onSideChanged(value),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        // 앞면 / 뒷면 토글
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _ViewToggleChip(
                label: '앞면',
                icon: Icons.person_outline_rounded,
                isSelected: selectedView == BodyView.front,
                onTap: () => onViewChanged(BodyView.front),
              ),
              const SizedBox(width: 4),
              _ViewToggleChip(
                label: '뒷면',
                icon: Icons.person_rounded,
                isSelected: selectedView == BodyView.back,
                onTap: () => onViewChanged(BodyView.back),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 바디 실루엣 + 부위 표시
        _BodySilhouette(
          view: selectedView,
          selectedPartIds: selectedPartIds,
          onPartToggled: onPartToggled,
          parts: visibleParts,
        ),
        const SizedBox(height: 20),

        // 부위 칩 선택
        const Text(
          '부위 선택',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visibleParts.map((part) {
            final isSelected = selectedPartIds.contains(part.id);
            return _PartChip(
              label: part.label,
              isSelected: isSelected,
              onTap: () => onPartToggled(part.id),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 선택된 부위 요약
        if (selectedPartIds.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLabels(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              '오늘 레슨할 부위를 선택해주세요. 여러 부위 동시 선택 가능해요.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _selectedLabels() {
    final selected = kBodyParts
        .where((p) => selectedPartIds.contains(p.id))
        .map((p) => p.label)
        .toList();
    return '선택된 부위: ${selected.join(' · ')}';
  }
}

// 바디 실루엣 (SVG 대신 시각적 레이아웃으로 부위 배치)
class _BodySilhouette extends StatelessWidget {
  const _BodySilhouette({
    required this.view,
    required this.selectedPartIds,
    required this.onPartToggled,
    required this.parts,
  });

  final BodyView view;
  final List<String> selectedPartIds;
  final ValueChanged<String> onPartToggled;
  final List<BodyPart> parts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 실루엣 배경
          const Opacity(
            opacity: 0.06,
            child: Icon(
              Icons.accessibility_new_rounded,
              size: 220,
              color: Color(0xFF4F46E5),
            ),
          ),
          // 부위 버튼 오버레이
          ..._buildPartButtons(context),
        ],
      ),
    );
  }

  List<Widget> _buildPartButtons(BuildContext context) {
    // 앞면 / 뒷면에 따라 부위 위치 정의
    final positions = view == BodyView.front ? _frontPositions : _backPositions;

    return parts.map((part) {
      final pos = positions[part.id];
      if (pos == null) return const SizedBox.shrink();

      final isSelected = selectedPartIds.contains(part.id);

      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: GestureDetector(
          onTap: () => onPartToggled(part.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFD1D5DB),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              part.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // 앞면 부위 위치 (300px 높이 기준)
  static const Map<String, Offset> _frontPositions = {
    'chest': Offset(110, 60),
    'shoulder': Offset(30, 55),
    'biceps': Offset(18, 100),
    'abs': Offset(110, 120),
    'quad': Offset(85, 190),
    'adductor': Offset(130, 195),
  };

  // 뒷면 부위 위치
  static const Map<String, Offset> _backPositions = {
    'trapezius': Offset(100, 45),
    'lat': Offset(35, 90),
    'triceps': Offset(15, 100),
    'lower_back': Offset(100, 135),
    'glute': Offset(95, 185),
    'hamstring': Offset(85, 225),
    'calf': Offset(110, 265),
  };
}

class _ViewToggleChip extends StatelessWidget {
  const _ViewToggleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
