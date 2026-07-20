import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Compact pill badge showing Online (green, pulsing "live" dot) or Offline
/// (red, static dot) — used anywhere the status just needs to be glanced at
/// (e.g. the available-orders header). Color and layout animate smoothly
/// when [online] flips, rather than snapping instantly.
class OnlineStatusBadge extends StatefulWidget {
  final bool online;

  const OnlineStatusBadge({Key? key, required this.online}) : super(key: key);

  @override
  State<OnlineStatusBadge> createState() => _OnlineStatusBadgeState();
}

class _OnlineStatusBadgeState extends State<OnlineStatusBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.online) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant OnlineStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.online && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.online) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.online ? AppColors.success : AppColors.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
        boxShadow: widget.online
            ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: widget.online
                ? AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final ringScale = 1.0 + _pulse.value * 1.4;
                      final ringOpacity = (1 - _pulse.value).clamp(0.0, 1.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: ringScale,
                            child: Opacity(
                              opacity: ringOpacity,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                        ],
                      );
                    },
                  )
                : Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 350),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
            child: Text(widget.online ? 'ONLINE' : 'OFFLINE'),
          ),
        ],
      ),
    );
  }
}

/// Large tappable status card — the rider's main Go Online control. Shows a
/// glowing, pulsing icon badge with a gradient background that smoothly
/// morphs between the offline (dark/red) and online (green) look, plus a
/// press-scale for tactile feedback.
class OnlineToggleCard extends StatefulWidget {
  final bool online;
  final VoidCallback? onTap;

  const OnlineToggleCard({Key? key, required this.online, this.onTap}) : super(key: key);

  @override
  State<OnlineToggleCard> createState() => _OnlineToggleCardState();
}

class _OnlineToggleCardState extends State<OnlineToggleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    if (widget.online) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant OnlineToggleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.online && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.online) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.online;
    final accent = online ? AppColors.success : AppColors.error;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: online
                  ? [const Color(0xFF16A34A), const Color(0xFF0D7A37)]
                  : [const Color(0xFF2A211F), const Color(0xFF1E1E1E)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(online ? 0.35 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (online)
                          for (final delay in [0.0, 0.5])
                            Builder(builder: (context) {
                              final t = (_pulse.value + delay) % 1.0;
                              return Opacity(
                                opacity: (1 - t) * 0.5,
                                child: Container(
                                  width: 100 * (0.6 + t * 0.5),
                                  height: 100 * (0.6 + t * 0.5),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }),
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              online ? Icons.wifi_rounded : Icons.power_settings_new_rounded,
                              key: ValueKey(online),
                              color: accent,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  online ? "YOU'RE ONLINE" : 'GO ONLINE',
                  key: ValueKey(online),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                online ? 'Watching for new delivery orders' : 'Tap to start receiving orders',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
