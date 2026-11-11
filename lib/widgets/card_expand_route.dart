import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 황금색 등록 카드 바탕. 카드 본체와 전환 효과가 같은 색을 쓴다.
const LinearGradient kMemberAddCardGradient = LinearGradient(
  colors: [
    Color(0xFFF7E3A0),
    Color(0xFFE9C25A),
    Color(0xFFFBE9AE),
    Color(0xFFC8962B),
  ],
  stops: [0.0, 0.42, 0.6, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// 금빛 번짐(글로우) 색.
const Color kMemberAddCardGlow = Color(0xFFE9C25A);

/// 카드를 누르면 그 자리에서 카드가 떠올라 화면 전체로 부드럽게 커지고,
/// 금색 위로 새 화면이 서서히 나타난다. 뒤로 가면 거꾸로 줄어들어 카드 자리로 돌아간다.
///
/// [originFace]는 누른 순간의 카드 얼굴(질감·글자)이다. 전환이 시작될 때 원래 카드와 똑같이 보이도록
/// 같은 크기로 그려서 서서히 지운다.
class CardExpandRoute<T> extends PageRouteBuilder<T> {
  CardExpandRoute({
    required WidgetBuilder builder,
    required Rect originRect,
    required Widget originFace,
  }) : super(
         transitionDuration: const Duration(milliseconds: 760),
         reverseTransitionDuration: const Duration(milliseconds: 520),
         pageBuilder: (context, animation, secondaryAnimation) {
           return builder(context);
         },
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return CardExpandTransition(
             animation: animation,
             originRect: originRect,
             originFace: originFace,
             child: child,
           );
         },
       );
}

/// 새 화면은 처음부터 전체 화면 크기로 만들어 두고 카드 모양 틀로 잘라 보여 주므로,
/// 전환 중에 다시 배치되거나 상태가 사라지지 않는다.
/// 금색 판은 끝까지 불투명하게 두고 그 위로 새 화면이 나타나므로 뒤의 목록이 비치지 않는다.
class CardExpandTransition extends StatelessWidget {
  const CardExpandTransition({
    super.key,
    required this.animation,
    required this.originRect,
    required this.originFace,
    required this.child,
  });

  final Animation<double> animation;
  final Rect originRect;
  final Widget originFace;
  final Widget child;

  static const double _cardRadius = 18;

  /// 열릴 때: 누르자마자 움직이기 시작해 처음에 빠르고 끝에서 길게 가라앉는다.
  static const Curve openCurve = Cubic(0.05, 0.7, 0.1, 1.0);

  /// 닫힐 때: 천천히 시작해 가운데에서 빨라졌다 멈춘다.
  static const Curve closeCurve = Curves.easeInOutCubicEmphasized;

  /// [from]~[to] 구간을 0~1로 매끄럽게 바꾼다.
  static double _smooth(double value, double from, double to) {
    final x = ((value - from) / (to - from)).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  Widget build(BuildContext context) {
    final screen = Offset.zero & MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, page) {
        final completed = animation.status == AnimationStatus.completed;
        final curve =
            animation.status == AnimationStatus.reverse
                ? closeCurve
                : openCurve;
        final t = curve.transform(animation.value.clamp(0.0, 1.0));

        final rect = Rect.lerp(originRect, screen, t) ?? screen;
        final radius = lerpDouble(_cardRadius, 0, _smooth(t, 0.0, 0.9))!;
        final faceOpacity = 1 - _smooth(t, 0.0, 0.28);
        final pageOpacity = _smooth(t, 0.34, 0.84);
        final dimAlpha = 0.4 * _smooth(t, 0.0, 0.5);
        final glowAlpha = 0.45 * (1 - _smooth(t, 0.0, 0.6));
        final borderRadius = BorderRadius.circular(radius);

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: dimAlpha),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30 * (1 - t)),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: kMemberAddCardGlow.withValues(alpha: glowAlpha),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  clipBehavior: completed ? Clip.none : Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: kMemberAddCardGradient,
                        ),
                        child: Opacity(
                          opacity: faceOpacity,
                          child: OverflowBox(
                            alignment: Alignment.center,
                            minWidth: originRect.width,
                            maxWidth: originRect.width,
                            minHeight: originRect.height,
                            maxHeight: originRect.height,
                            child: originFace,
                          ),
                        ),
                      ),
                      IgnorePointer(
                        ignoring: !completed,
                        child: Opacity(
                          opacity: pageOpacity,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: screen.width,
                            maxWidth: screen.width,
                            minHeight: screen.height,
                            maxHeight: screen.height,
                            child: page,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
