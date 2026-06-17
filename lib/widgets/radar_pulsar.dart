import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RadarPulsar extends StatefulWidget {
  const RadarPulsar({Key? key}) : super(key: key);

  @override
  State<RadarPulsar> createState() => _RadarPulsarState();
}

class _RadarPulsarState extends State<RadarPulsar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildPulseRing(0.0),
              _buildPulseRing(0.33),
              _buildPulseRing(0.66),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPulseRing(double delay) {
    double progress = (_controller.value + delay) % 1.0;
    double scale = 0.5 + (progress * 0.7);
    double opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.5),
          ),
        ),
      ),
    );
  }
}
