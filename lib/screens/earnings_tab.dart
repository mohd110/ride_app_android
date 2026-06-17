import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/app_card.dart';
import '../widgets/earnings_chart.dart';
import 'delivery_history_screen.dart';
import 'order_details_screen.dart';
import 'notifications_screen.dart';
import 'income_detail_screen.dart';

class EarningsTab extends StatefulWidget {
  const EarningsTab({Key? key}) : super(key: key);

  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  String _chartType = 'daily';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeader(
                    title: 'Earnings',
                    notificationBadge: state.unreadNotifications,
                    onNotificationTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPeriodTabs(),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL EARNINGS',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\$${state.todayEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.trending_up_rounded, color: AppColors.success, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '12% higher than yesterday',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(Icons.pedal_bike_rounded, 'Deliveries', '${state.deliveriesCount}')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(Icons.access_time_rounded, 'Online Time', '6h 45m')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Hourly Trend',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                          ],
                        ),
                        EarningsChart(
                          chartType: _chartType,
                          todayEarnings: state.todayEarnings,
                          weeklyEarnings: state.weeklyEarnings,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Income Breakdown',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IncomeDetailScreen(
                          title: 'Delivery Fees',
                          amount: '\$${state.deliveryFees.toStringAsFixed(2)}',
                          description: 'Base pay for ${state.deliveriesCount} completed trips',
                          lineItems: [
                            {'label': 'Short trips (< 3 km)', 'value': '\$42.00'},
                            {'label': 'Medium trips (3–6 km)', 'value': '\$38.00'},
                            {'label': 'Long trips (> 6 km)', 'value': '\$18.00'},
                          ],
                        ),
                      ),
                    ),
                    child: _buildBreakdownItem(Icons.payments_rounded, 'Delivery Fees', 'Base pay for ${state.deliveriesCount} trips', '\$${state.deliveryFees.toStringAsFixed(2)}'),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IncomeDetailScreen(
                          title: 'Tips',
                          amount: '\$${state.tips.toStringAsFixed(2)}',
                          description: 'Customer appreciation from ${state.deliveriesCount} deliveries',
                          lineItems: [
                            {'label': 'Cash tips', 'value': '\$12.50'},
                            {'label': 'In-app tips', 'value': '\$22.00'},
                          ],
                        ),
                      ),
                    ),
                    child: _buildBreakdownItem(Icons.volunteer_activism_rounded, 'Tips', 'Customer appreciation', '\$${state.tips.toStringAsFixed(2)}', valueColor: AppColors.success),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IncomeDetailScreen(
                          title: 'Incentives',
                          amount: '\$${state.incentives.toStringAsFixed(2)}',
                          description: 'Peak hour and zone bonuses',
                          lineItems: [
                            {'label': 'Peak Hour Bonus (4–6 PM)', 'value': '\$7.00'},
                            {'label': 'Downtown surge', 'value': '\$3.00'},
                          ],
                        ),
                      ),
                    ),
                    child: _buildIncentiveCard(state.incentives),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Trips',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DeliveryHistoryScreen()),
                          );
                        },
                        child: const Text(
                          'View All →',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...state.tripsHistory.take(5).map((trip) => _buildTripCard(context, trip)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAccent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildPill('daily', 'Daily'),
          _buildPill('weekly', 'Weekly'),
          _buildPill('monthly', 'Monthly'),
        ],
      ),
    );
  }

  Widget _buildPill(String type, String title) {
    final selected = _chartType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _chartType = type),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(IconData icon, String title, String subtitle, String amount, {Color? valueColor}) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncentiveCard(double amount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Incentives', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Peak Hour Bonus (4pm - 6pm)', style: TextStyle(color: AppColors.surfaceAccent, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, TripData trip) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              orderId: trip.id,
              restaurantName: trip.restaurant,
              dropoffAddress: '402 Oakwood Residency, Block B, West End Heights',
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
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${trip.distance} • ${trip.time.split('•').last.trim()}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${trip.payout.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  trip.tip > 0 ? '+\$${trip.tip.toStringAsFixed(2)} Tip' : 'No Tip',
                  style: TextStyle(
                    color: trip.tip > 0 ? AppColors.success : AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
