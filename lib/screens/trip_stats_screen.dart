import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'order_details_screen.dart';

class TripStatsScreen extends StatelessWidget {
  const TripStatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rider = MockData.rider;

    return DetailPageScaffold(
      title: 'Delivery Stats',
      children: [
        AppCard(
          child: Column(
            children: [
              Text(
                '${rider.completedTasks}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const Text('Completed deliveries', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: const [
              InfoRow(label: 'Acceptance rate', value: '94%'),
              InfoRow(label: 'On-time rate', value: '97%'),
              InfoRow(label: 'Avg. rating', value: '4.98 ★'),
              InfoRow(label: 'Total active hours', value: '498 hrs'),
              InfoRow(label: 'Lifetime earnings', value: '₹18,450.00', valueColor: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Recent milestones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        ...MockData.allTrips.take(5).map((trip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(
                      orderId: trip.id,
                      restaurantName: trip.restaurant,
                      dropoffAddress: '742 Evergreen Terrace, Block B',
                      payout: trip.payout,
                      tip: trip.tip,
                      distance: trip.distance,
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
                            Text('${trip.distance} • ${trip.duration}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
  }
}
