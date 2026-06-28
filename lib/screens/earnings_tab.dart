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
import 'payment_info_screen.dart';

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

        final periodLabel = switch (_chartType) {
          'weekly' => 'THIS WEEK',
          'monthly' => 'THIS MONTH',
          _ => 'TODAY',
        };
        final periodEarnings = switch (_chartType) {
          'weekly' => state.weeklyEarnings,
          'monthly' => state.monthlyEarnings,
          _ => state.todayEarnings,
        };

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
                        Text(
                          periodLabel,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${periodEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.todayOrders} deliveries today • ${state.deliveriesCount} total',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(Icons.pedal_bike_rounded, 'Total Deliveries', '${state.deliveriesCount}')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(Icons.account_balance_wallet_rounded, 'Wallet Balance', '₹${state.walletBalance.toStringAsFixed(2)}')),
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
                              'Earnings Trend',
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
                          dailyEarnings: state.dailyEarnings,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Income Summary',
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
                          title: 'Trip Earnings',
                          amount: '₹${state.lifetimeEarnings.toStringAsFixed(2)}',
                          description: 'Lifetime earnings across ${state.deliveriesCount} completed deliveries',
                          lineItems: [
                            {'label': 'Today', 'value': '₹${state.todayEarnings.toStringAsFixed(2)}'},
                            {'label': 'This week', 'value': '₹${state.weeklyEarnings.toStringAsFixed(2)}'},
                            {'label': 'This month', 'value': '₹${state.monthlyEarnings.toStringAsFixed(2)}'},
                          ],
                        ),
                      ),
                    ),
                    child: _buildBreakdownItem(
                      Icons.payments_rounded,
                      'Trip Earnings (Lifetime)',
                      '${state.deliveriesCount} completed deliveries',
                      '₹${state.lifetimeEarnings.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaymentInfoScreen()),
                    ),
                    child: _buildBreakdownItem(
                      Icons.account_balance_wallet_rounded,
                      'Wallet Balance',
                      'Not yet included in a payout',
                      '₹${state.walletBalance.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                    ),
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
                  if (state.tripsHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No deliveries yet', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
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

  Widget _buildTripCard(BuildContext context, TripData trip) {
    return InkWell(
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
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${trip.distance} • ${trip.time.split('•').last.trim()}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              '₹${trip.payout.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
