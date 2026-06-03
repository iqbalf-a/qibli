import 'package:flutter/material.dart';

/// Wraps a bottom sheet with animated backdrop (fade) + sheet (slide up).
/// The [builder] receives a [close] callback — call it from inside the sheet
/// to trigger the exit animation before [onDismiss] fires.
class AnimatedSheet extends StatefulWidget {
  final Widget Function(VoidCallback close) builder;
  final VoidCallback onDismiss;

  const AnimatedSheet({
    super.key,
    required this.builder,
    required this.onDismiss,
  });

  @override
  State<AnimatedSheet> createState() => _AnimatedSheetState();
}

class _AnimatedSheetState extends State<AnimatedSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _backdropFade;
  late final Animation<Offset> _sheetSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _backdropFade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void close() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: close,
      child: FadeTransition(
        opacity: _backdropFade,
        child: Container(
          color: const Color(0x8C000000),
          child: GestureDetector(
            onTap: () {},
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _sheetSlide,
                child: widget.builder(close),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
