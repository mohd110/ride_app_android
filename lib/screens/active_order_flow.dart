import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/swipe_slider.dart';
import 'active_order_detail_screen.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class ActiveOrderFlow extends StatefulWidget {
  const ActiveOrderFlow({Key? key}) : super(key: key);

  @override
  State<ActiveOrderFlow> createState() => _ActiveOrderFlowState();
}

class _ActiveOrderFlowState extends State<ActiveOrderFlow> {
  final TextEditingController _recipientController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        Widget content;
        if (state.orderState == OrderState.navToRestaurant || state.orderState == OrderState.navToCustomer) {
          content = _buildNavigationScreen(state);
        } else if (state.orderState == OrderState.verifyItems) {
          content = _buildChecklistScreen(state);
        } else if (state.orderState == OrderState.confirmDelivery) {
          content = _buildConfirmDeliveryScreen(state);
        } else {
          content = _buildSuccessScreen(state);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(child: content),
        );
      },
    );
  }

  Widget _buildNavigationScreen(AppState state) {
    final isToCustomer = state.orderState == OrderState.navToCustomer;
    final order = state.activeOrder;

    return Stack(
      children: [
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActiveOrderDetailScreen()),
              ),
              icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _MapPainter(progress: state.gpsProgress, isToCustomer: isToCustomer),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.navInstruction,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isToCustomer
                            ? (state.navDurationText.isNotEmpty ? state.navDurationText : 'Live GPS tracking')
                            : 'Head to restaurant',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isToCustomer)
          Positioned(
            right: 20,
            bottom: 200,
            child: Column(
              children: [
                _fabBtn(Icons.chat_bubble_outline_rounded, onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(contactName: order.customerName)),
                )),
                const SizedBox(height: 10),
                _fabBtn(Icons.phone_rounded, onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CallScreen(contactName: order.customerName, phone: order.customerPhone)),
                )),
              ],
            ),
          ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isToCustomer ? 'NAVIGATING TO CUSTOMER' : 'NAVIGATING TO PICKUP',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isToCustomer ? order.customerName : order.restaurant,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (!isToCustomer)
                  Text(
                    '₹${order.guaranteedEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (isToCustomer) {
                      state.arrivedAtCustomer();
                    } else {
                      state.arrivedAtRestaurant();
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: Text(isToCustomer ? 'ARRIVED AT LOCATION' : 'ARRIVED AT RESTAURANT'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fabBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  Widget _buildChecklistScreen(AppState state) {
    final checkedCount = state.verifiedItems.where((x) => x).length;
    final order = state.activeOrder;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pickup Confirmation',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.restaurant, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(order.restaurantAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(order.pickupInstruction, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VERIFY ITEMS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(
                '$checkedCount / ${state.checklistItems.length}',
                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: state.checklistItems.length,
              itemBuilder: (context, index) {
                final item = state.checklistItems[index];
                final isChecked = state.verifiedItems[index];
                return InkWell(
                  onTap: () => state.toggleItemVerification(index),
                  borderRadius: BorderRadius.circular(12),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    color: isChecked ? AppColors.surfaceAccent : AppColors.surface,
                    borderColor: isChecked ? AppColors.primary.withOpacity(0.4) : AppColors.border,
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isChecked ? AppColors.primary : Colors.transparent,
                            border: Border.all(color: isChecked ? AppColors.primary : AppColors.textMuted, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isChecked ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item['name']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        Text(item['qty']!, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: state.isAllItemsVerified
                ? () async {
                    final error = await state.startDelivery();
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.surfaceMuted,
            ),
            child: Text(state.isAllItemsVerified ? 'START DELIVERY' : 'VERIFY ALL ITEMS'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmDeliveryScreen(AppState state) {
    final order = state.activeOrder;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Delivery',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat(label: 'EARNINGS', value: '₹${order.guaranteedEarnings.toStringAsFixed(2)}'),
                        _SummaryStat(label: 'ITEMS', value: '${order.items.length}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recipient Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _recipientController,
                          onChanged: state.setRecipientName,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(hintText: 'e.g. John Doe'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: const [
                            Icon(Icons.check_box_outline_blank_rounded, color: AppColors.textMuted, size: 18),
                            SizedBox(width: 8),
                            Text('Customer signature not required', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => state.uploadPhotoProof(),
                    child: AppCard(
                      child: state.hasPhotoProof
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset('assets/images/delivery_proof.png', height: 140, width: double.infinity, fit: BoxFit.cover),
                            )
                          : Column(
                              children: const [
                                Icon(Icons.camera_alt_rounded, color: AppColors.textMuted, size: 32),
                                SizedBox(height: 8),
                                Text('Take Photo of Delivery', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwipeSlider(
            onComplete: () async {
              final error = await state.completeDelivery();
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen(AppState state) {
    final payout = state.activeOrder.guaranteedEarnings;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceAccent,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 24),
          const Text(
            'Delivery Completed!',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Great job! The payment has been added to your balance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Text(
            '+₹${payout.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => state.finishSuccessScreen(),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  final double progress;
  final bool isToCustomer;

  _MapPainter({required this.progress, required this.isToCustomer});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.surfaceAccent;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.6)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final start = Offset(size.width * 0.3, size.height * 0.75);
    final end = Offset(size.width * 0.7, isToCustomer ? size.height * 0.3 : size.height * 0.35);
    canvas.drawLine(start, end, routePaint);

    final riderPos = Offset.lerp(start, end, progress.clamp(0.0, 1.0))!;
    canvas.drawCircle(end, 12, Paint()..color = AppColors.primary);
    canvas.drawCircle(riderPos, 10, Paint()..color = Colors.white);
    canvas.drawCircle(riderPos, 10, Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isToCustomer != isToCustomer;
  }
}
