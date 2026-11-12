import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 화면 아래에 겹쳐 떠 있는 바. 내용을 아래로 내리면 숨고, 위로 올리면 다시 나타난다.
///
/// - 바가 내용 위에 겹쳐 있어서 나타나고 사라져도 내용이 밀리지 않는다. 마지막 항목이 바에 가리지
///   않도록 [body] 쪽 스크롤 목록의 아래 여백을 바 높이만큼 두어야 한다.
/// - 맨 위나 맨 아래 끝에 닿으면 항상 보인다(저장 같은 마지막 동작을 못 찾지 않도록).
/// - 키보드가 올라오면 숨는다. [forceVisible]이 true면(저장 중 등) 늘 보인다.
/// - 가장 바깥쪽 세로 스크롤만 본다(안쪽 가로 목록·페이지 넘김은 무시).
class ScrollRevealBottomBar extends StatefulWidget {
  const ScrollRevealBottomBar({
    super.key,
    required this.body,
    required this.bar,
    this.forceVisible = false,
  });

  final Widget body;
  final Widget bar;
  final bool forceVisible;

  @override
  State<ScrollRevealBottomBar> createState() => _ScrollRevealBottomBarState();
}

class _ScrollRevealBottomBarState extends State<ScrollRevealBottomBar>
    with WidgetsBindingObserver {
  bool _scrollVisible = true;
  ScrollDirection _direction = ScrollDirection.idle;
  bool _keyboardOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Scaffold는 본문 쪽 MediaQuery에서 키보드 높이를 지우므로 화면(View)에서 직접 읽는다.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final open = View.of(context).viewInsets.bottom > 0;
    if (open != _keyboardOpen) setState(() => _keyboardOpen = open);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification) {
      _direction = notification.direction;
    }
    final metrics = notification.metrics;
    final atEdge = metrics.extentBefore <= 8 || metrics.extentAfter <= 24;

    final bool next;
    if (atEdge) {
      next = true;
    } else if (_direction == ScrollDirection.reverse) {
      next = false; // 내용을 아래로 내리는 중
    } else if (_direction == ScrollDirection.forward) {
      next = true; // 내용을 위로 올리는 중
    } else {
      next = _scrollVisible;
    }
    if (next != _scrollVisible) setState(() => _scrollVisible = next);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.forceVisible || (_scrollVisible && !_keyboardOpen);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.body,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              key: const Key('scroll_reveal_bottom_bar_slide'),
              offset: visible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: widget.bar,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
