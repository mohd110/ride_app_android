import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NewOrderFlashOverlay extends StatefulWidget {
  final int pulse;

  const NewOrderFlashOverlay({Key? key, required this.pulse}) : super(key: key);

  @override
  State<NewOrderFlashOverlay> createState() => _NewOrderFlashOverlayState();
}

class _NewOrderFlashOverlayState extends State<NewOrderFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.55), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.55), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.55, end: 0.0), weight: 1),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(NewOrderFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse && widget.pulse != 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => IgnorePointer(
        child: Container(color: AppColors.primary.withOpacity(_opacity.value)),
      ),
    );
  }
}
