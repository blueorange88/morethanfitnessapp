import 'package:flutter/material.dart';

/// 앱 전체 헤더의 뒤로가기 버튼. `내 회원 관리` 헤더의 `<` 모양에서 원(테두리)만 뺀 형태.
///
/// 페이지마다 제각각이던 뒤로가기(원형 테두리·화살표·꺾쇠)를 이것 하나로 통일한다.
/// 누르는 영역은 [size]×[size]이고, 색은 헤더 바탕에 맞춰 [color]로 넘긴다(기본은 흰색).
class MtfBackButton extends StatelessWidget {
  const MtfBackButton({
    super.key,
    required this.onTap,
    this.color = Colors.white,
    this.size = 42,
    this.tooltip = '뒤로',
  });

  /// `null`이면 눌러도 아무 일도 하지 않는다.
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final String tooltip;

  /// 글자 `<`가 아이콘보다 가늘고 키가 큰 이 모양이 기준 디자인이다.
  static TextStyle glyphStyle(Color color) => TextStyle(
    color: color,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Center(child: Text('<', style: glyphStyle(color))),
        ),
      ),
    );
  }
}
