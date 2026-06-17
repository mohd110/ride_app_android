import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SwipeSlider extends StatefulWidget {
  final VoidCallback onComplete;
  final String text;

  const SwipeSlider({
    Key? key,
    required this.onComplete,
    this.text = 'SLIDE TO COMPLETE',
  }) : super(key: key);

  @override
  State<SwipeSlider> createState() => _SwipeSliderState();
}

class _SwipeSliderState extends State<SwipeSlider> with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isCompleted) return;
    setState(() {
      _dragPosition = (_dragPosition + details.primaryDelta!).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (_isCompleted) return;

    if (_dragPosition >= maxDrag * 0.9) {
      setState(() {
        _dragPosition = maxDrag;
        _isCompleted = true;
      });
      widget.onComplete();
    } else {
      _animation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
      )..addListener(() {
          setState(() => _dragPosition = _animation.value);
        });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double handleSize = 52.0;
        const double sliderHeight = 60.0;
        const double padding = 4.0;
        final double maxDrag = constraints.maxWidth - handleSize - (padding * 2);

        return Container(
          height: sliderHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: _dragPosition + handleSize / 2 + padding,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(30),
                      bottomLeft: const Radius.circular(30),
                      topRight: Radius.circular(_dragPosition > 15 ? 10 : 30),
                      bottomRight: Radius.circular(_dragPosition > 15 ? 10 : 30),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Positioned(
                left: _dragPosition + padding,
                top: padding,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) => _onDragEnd(details, maxDrag),
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
