import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'call_screen.dart';
import 'chat_screen.dart';

class ActiveOrderDetailScreen extends StatelessWidget {
  const ActiveOrderDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final order = AppState.instance.activeOrder;

    return DetailPageScaffold(
      title: 'Active Order',
      children: [
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.id, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(
                    '₹${order.guaranteedEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(order.distance, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('ETA ${order.eta}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PICKUP', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(order.restaurant, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(order.restaurantAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(contactName: order.restaurant, phone: order.restaurantPhone))),
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen(contactName: 'Restaurant'))),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text('Chat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DELIVER TO', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(order.customerAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(10)),
                child: Text(order.deliveryNote, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Order items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(item.qty, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(item.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
