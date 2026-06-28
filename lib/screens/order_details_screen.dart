import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  final String restaurantName;
  final String dropoffAddress;
  final double payout;
  final double tip;
  final String distance;
  final String status;
  final bool isCompleted;
  // Set when viewing a past delivery from history — uses the real address/
  // items captured for that specific order instead of falling back to
  // whatever the rider's current active order happens to be (which made
  // every historical order look identical and showed a fake hardcoded
  // item list).
  final bool isHistorical;
  final String? restaurantAddress;
  final List<OrderLineItem>? items;

  const OrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.restaurantName,
    required this.dropoffAddress,
    required this.payout,
    this.tip = 0,
    required this.distance,
    this.status = 'COMPLETED',
    this.isCompleted = true,
    this.isHistorical = false,
    this.restaurantAddress,
    this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final active = !isHistorical && AppState.instance.hasActiveOrder ? AppState.instance.activeOrder : null;
    final orderItems = items ?? const <OrderLineItem>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORDER ID', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                    Text(orderId, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EST. EARNINGS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                      Text(
                        '₹${payout.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('DISTANCE: $distance', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      if (tip > 0)
                        Text(
                          'Includes ₹${tip.toStringAsFixed(2)} Tip',
                          style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('PICKUP', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurantName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    restaurantAddress ?? active?.restaurantAddress ?? 'Restaurant address',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  if (!isHistorical) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _actionBtn(Icons.phone_rounded, 'Call Restaurant', context, phone: active?.restaurantPhone ?? '')),
                        const SizedBox(width: 12),
                        Expanded(child: _actionBtn(Icons.navigation_rounded, 'Navigate', context)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('DELIVER', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(active?.customerName ?? 'Customer', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(dropoffAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  if ((active?.deliveryNote ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '"${active!.deliveryNote}"',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                  if (!isHistorical) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _actionBtn(Icons.message_rounded, 'Message', context, chatName: active?.customerName ?? 'Customer')),
                        const SizedBox(width: 12),
                        Expanded(child: _actionBtn(Icons.phone_rounded, 'Call Customer', context, phone: active?.customerPhone ?? '')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('ORDER ITEMS', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            if (orderItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No item details available', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              )
            else
              ...orderItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.qty,
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                if (item.subtitle.isNotEmpty)
                                  Text(item.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
            if (!isCompleted)
              ElevatedButton(
                onPressed: () {},
                child: const Text('Mark as Picked Up'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, BuildContext context, {String? phone, String? chatName}) {
    return OutlinedButton(
      onPressed: () {
        if (icon == Icons.phone_rounded && phone != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(contactName: label, phone: phone)));
        } else if (icon == Icons.message_rounded) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(contactName: chatName ?? label)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $label...')));
        }
      },
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
