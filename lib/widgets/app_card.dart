import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final bool dashed;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.dashed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (dashed) {
      return CustomPaint(
        painter: _DashedBorderPainter(color: borderColor ?? AppColors.borderLight),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppColors.surfaceAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
