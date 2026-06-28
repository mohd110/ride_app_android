import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'order_details_screen.dart';

class TripStatsScreen extends StatelessWidget {
  const TripStatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        return DetailPageScaffold(
          title: 'Delivery Stats',
          children: [
            AppCard(
              child: Column(
                children: [
                  Text(
                    '${state.deliveriesCount}',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                  const Text('Completed deliveries', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  InfoRow(label: 'Today', value: '${state.todayOrders} deliveries'),
                  InfoRow(label: 'Today\'s earnings', value: '₹${state.todayEarnings.toStringAsFixed(2)}'),
                  InfoRow(label: 'This week', value: '₹${state.weeklyEarnings.toStringAsFixed(2)}'),
                  InfoRow(label: 'This month', value: '₹${state.monthlyEarnings.toStringAsFixed(2)}'),
                  InfoRow(label: 'Lifetime earnings', value: '₹${state.lifetimeEarnings.toStringAsFixed(2)}', valueColor: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Recent deliveries', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (state.tripsHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No deliveries yet', style: TextStyle(color: AppColors.textMuted)),
              )
            else
              ...state.tripsHistory.take(5).map((trip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailsScreen(
                            orderId: trip.id,
                            restaurantName: trip.restaurant,
                            restaurantAddress: trip.restaurantAddress,
                            dropoffAddress: trip.dropoffAddress,
                            payout: trip.payout,
                            distance: trip.distance,
                            items: trip.items,
                            isHistorical: true,
                          ),
                        ),
                      ),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trip.restaurant, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text('${trip.distance} • ${trip.time}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('₹${trip.payout.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
