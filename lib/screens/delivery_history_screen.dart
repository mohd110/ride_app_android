import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import 'order_details_screen.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  String _activeFilter = 'All Time';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        final rider = MockData.rider;

        List<TripData> filteredTrips = state.tripsHistory;
        double displayEarnings = state.weeklyEarnings;
        int displayDeliveries = 142;
        String displayHours = '58.5';

        if (_activeFilter == 'Today') {
          filteredTrips = state.tripsHistory.where((t) => t.time.startsWith('Today')).toList();
          displayEarnings = state.todayEarnings;
          displayDeliveries = filteredTrips.length;
          displayHours = '5.4';
        } else if (_activeFilter == 'This Week') {
          filteredTrips = state.tripsHistory;
          displayEarnings = state.weeklyEarnings;
          displayDeliveries = 142;
          displayHours = '58.5';
        } else if (_activeFilter == 'Range') {
          filteredTrips = state.tripsHistory.take(6).toList();
          displayEarnings = 86.50;
          displayDeliveries = 6;
          displayHours = '12.5';
        } else {
          filteredTrips = state.tripsHistory;
          displayEarnings = 18450.00;
          displayDeliveries = rider.completedTasks;
          displayHours = rider.activeHours;
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Delivery History'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildFilterTabs(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Column(
                          children: [
                            const Text(
                              'TOTAL EARNINGS THIS WEEK',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '\$${displayEarnings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Divider(),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatCol('$displayDeliveries', 'Deliveries'),
                                Container(width: 1, height: 30, color: AppColors.border),
                                _buildStatCol(displayHours, 'Online Hrs'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...filteredTrips.map((trip) => _buildTripTile(context, trip)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAccent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildFilter('All Time'),
          _buildFilter('Today'),
          _buildFilter('This Week'),
          _buildFilter('Range'),
        ],
      ),
    );
  }

  Widget _buildFilter(String type) {
    final selected = _activeFilter == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = type),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTripTile(BuildContext context, TripData trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(
                orderId: trip.id,
                restaurantName: trip.restaurant,
                dropoffAddress: '402 Oakwood Residency, Block B',
                payout: trip.payout,
                tip: trip.tip,
                distance: trip.distance,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.id,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      trip.restaurant,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      trip.time,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\$${trip.payout.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
