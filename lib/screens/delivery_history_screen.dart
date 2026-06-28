import 'package:flutter/material.dart';
import '../app_state.dart';
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

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    // ISO weeks start Monday (weekday == 1), matching Postgres's date_trunc('week', ...).
    return startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final now = DateTime.now();
        final startOfWeek = _startOfWeek(now);

        List<TripData> filteredTrips;
        double displayEarnings;
        int displayDeliveries;

        if (_activeFilter == 'Today') {
          filteredTrips = state.tripsHistory.where((t) => t.deliveredAt != null && _isSameDay(t.deliveredAt!.toLocal(), now)).toList();
          displayEarnings = state.todayEarnings;
          displayDeliveries = state.todayOrders;
        } else if (_activeFilter == 'This Week') {
          filteredTrips = state.tripsHistory.where((t) => t.deliveredAt != null && t.deliveredAt!.toLocal().isAfter(startOfWeek)).toList();
          displayEarnings = state.weeklyEarnings;
          displayDeliveries = filteredTrips.length;
        } else if (_activeFilter == 'This Month') {
          filteredTrips = state.tripsHistory
              .where((t) => t.deliveredAt != null && t.deliveredAt!.toLocal().year == now.year && t.deliveredAt!.toLocal().month == now.month)
              .toList();
          displayEarnings = state.monthlyEarnings;
          displayDeliveries = filteredTrips.length;
        } else {
          filteredTrips = state.tripsHistory;
          displayEarnings = state.lifetimeEarnings;
          displayDeliveries = state.deliveriesCount;
        }

        final avgPerOrder = displayDeliveries > 0 ? displayEarnings / displayDeliveries : 0.0;

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
                            Text(
                              'EARNINGS — ${_activeFilter.toUpperCase()}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${displayEarnings.toStringAsFixed(2)}',
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
                                _buildStatCol('₹${avgPerOrder.toStringAsFixed(2)}', 'Avg/Order'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (filteredTrips.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No deliveries in this period', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        )
                      else
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
          _buildFilter('This Month'),
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
                restaurantAddress: trip.restaurantAddress,
                dropoffAddress: trip.dropoffAddress,
                payout: trip.payout,
                distance: trip.distance,
                items: trip.items,
                isHistorical: true,
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
                  '₹${trip.payout.toStringAsFixed(2)}',
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
