import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/app_card.dart';
import '../widgets/new_order_flash_overlay.dart';
import 'notifications_screen.dart';
import 'support_screen.dart';
import 'trip_stats_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppHeader(
                        title: 'Rider Connect',
                        notificationBadge: state.unreadNotifications,
                        onNotificationTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: state.isOnline && !state.hasActiveOrder
                            ? _buildAvailableOrders(context, state)
                            : _buildOfflineDashboard(context, state),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                    ),
                    backgroundColor: AppColors.primaryDark,
                    child: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                  ),
                ),
                Positioned.fill(
                  child: NewOrderFlashOverlay(pulse: state.newOrderPulse),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfflineDashboard(BuildContext context, AppState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildStatusBadge(state.isOnline),
          const SizedBox(height: 12),
          Text(
            state.isOnline
                ? 'You are online and ready for orders.'
                : 'You are currently offline. Tap the button below to start receiving delivery orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: state.isOnline ? null : () => state.goOnline(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: state.isOnline ? AppColors.primary : AppColors.goOnlineButton,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      state.isOnline ? Icons.wifi_rounded : Icons.power_settings_new_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.isOnline ? 'ONLINE' : 'GO ONLINE',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => AppState.instance.setTab(1),
            borderRadius: BorderRadius.circular(16),
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TODAY'S EARNINGS",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${state.todayEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TripStatsScreen()),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMiniStat(Icons.access_time_rounded, 'Online', MockData.todayStats['onlineTime'] as String),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => AppState.instance.setTab(1),
                  borderRadius: BorderRadius.circular(16),
                  child: _buildMiniStat(Icons.local_shipping_rounded, 'Orders', '${MockData.todayStats['orders']}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            dashed: true,
            child: Column(
              children: const [
                Icon(Icons.location_off_rounded, color: AppColors.textMuted, size: 36),
                SizedBox(height: 12),
                Text(
                  'No active orders',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Go online to see available deliveries ready for pickup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAvailableOrders(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildStatusBadge(true),
            const Spacer(),
            TextButton.icon(
              onPressed: () => state.goOffline(),
              icon: const Icon(Icons.power_settings_new_rounded, size: 16),
              label: const Text('Go Offline'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Available Orders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Restaurant-accepted orders waiting for a rider. Tap Accept to claim.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            state.errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: state.availableOrders.isEmpty
              ? Center(
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inbox_rounded, color: AppColors.textMuted, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'No orders available',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Orders show up after the restaurant accepts them on the dashboard. Pull down to refresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: state.goOnline,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: state.availableOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = state.availableOrders[index];
                      return _buildOrderCard(context, state, order);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, AppState state, AvailableOrderSummary order) {
    final claiming = state.isClaimingOrder(order.id);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(order.status),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '₹${order.estimatedEarnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRouteRow(Icons.store_rounded, 'PICKUP', order.restaurantName),
          const SizedBox(height: 8),
          _buildRouteRow(Icons.location_on_rounded, 'DROPOFF', order.dropoffAddress),
          const SizedBox(height: 8),
          Text(
            order.customerName,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: claiming
                ? null
                : () async {
                    final error = await state.claimOrder(order.id);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                    }
                  },
            child: claiming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ACCEPT ORDER'),
                      SizedBox(width: 8),
                      Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: online ? AppColors.primary.withOpacity(0.12) : AppColors.offlineBadge,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? AppColors.primary : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            online ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: online ? AppColors.primary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ready':
        return AppColors.success;
      case 'preparing':
        return const Color(0xFFE85D2C);
      default:
        return AppColors.primary;
    }
  }
}
