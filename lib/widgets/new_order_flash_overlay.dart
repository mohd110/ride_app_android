import 'dart:async';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';

/// Full-screen alert overlay that appears when new orders come in.
/// Shows order details, a 10-second countdown ring, and Accept / Dismiss buttons.
/// The audio (managed by NotificationService) rings for the same 10 seconds.
class NewOrderFlashOverlay extends StatefulWidget {
  final int pulse;

  const NewOrderFlashOverlay({Key? key, required this.pulse}) : super(key: key);

  @override
  State<NewOrderFlashOverlay> createState() => _NewOrderFlashOverlayState();
}

class _NewOrderFlashOverlayState extends State<NewOrderFlashOverlay>
    with SingleTickerProviderStateMixin {
  // Flash animation (kept for the brief red-pulse effect at alert start).
  late final AnimationController _flashController;
  late final Animation<double> _flashOpacity;

  // Countdown state.
  static const _totalSeconds = 10;
  int _secondsLeft = _totalSeconds;
  Timer? _countdownTimer;
  bool _alertVisible = false;
  List<AvailableOrderSummary> _shownOrders = [];

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.45), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.45, end: 0.0), weight: 1),
    ]).animate(_flashController);
  }

  @override
  void didUpdateWidget(NewOrderFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse && widget.pulse != 0) {
      _triggerAlert();
    }
  }

  void _triggerAlert() {
    final orders = AppState.instance.pendingAlertOrders;
    if (orders.isEmpty) return;

    setState(() {
      _alertVisible = true;
      _shownOrders = List.from(orders);
      _secondsLeft = _totalSeconds;
    });

    // Brief red flash.
    _flashController.forward(from: 0);

    // Countdown timer – ticks every second, auto-dismisses at 0.
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        t.cancel();
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    AppState.instance.dismissAlert();
    if (mounted) {
      setState(() {
        _alertVisible = false;
        _shownOrders = [];
      });
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) {
      setState(() {
        _alertVisible = false;
        _shownOrders = [];
      });
    }
    // claimOrder also calls stopAlert + clears pendingAlertOrders.
    final error = await AppState.instance.claimOrder(orderId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Subtle red flash at alert start.
        AnimatedBuilder(
          animation: _flashOpacity,
          builder: (_, __) => IgnorePointer(
            child: Container(
              color: AppColors.primary.withOpacity(_flashOpacity.value),
            ),
          ),
        ),

        // Full-screen alert panel.
        if (_alertVisible) _buildAlertPanel(context),
      ],
    );
  }

  Widget _buildAlertPanel(BuildContext context) {
    final first = _shownOrders.isNotEmpty ? _shownOrders.first : null;
    final count = _shownOrders.length;
    final progress = _secondsLeft / _totalSeconds;

    return Container(
      color: Colors.black.withOpacity(0.65),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A0F0D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top header bar.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, const Color(0xFFB82A10)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count == 1 ? 'NEW ORDER!' : '$count NEW ORDERS!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              'A delivery is waiting for you',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Countdown ring.
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            Text(
                              '$_secondsLeft',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Order details.
                if (first != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.store_rounded,
                          'PICKUP',
                          first.restaurantName,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.location_on_rounded,
                          'DROPOFF',
                          first.dropoffAddress,
                        ),
                        const SizedBox(height: 16),
                        // Earnings badge.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '₹${first.deliveryFee.toStringAsFixed(2)} delivery fee',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Action buttons.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      // Dismiss.
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: _dismiss,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.25)),
                            foregroundColor: Colors.white60,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Accept.
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: first == null
                              ? null
                              : () => _acceptOrder(first.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 6,
                            shadowColor:
                                AppColors.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'ACCEPT',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9E8E88),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
