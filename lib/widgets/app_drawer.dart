import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../screens/delivery_history_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/support_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/payment_info_screen.dart';
import '../screens/vehicle_details_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rider = AppState.instance.rider;
    final unread = MockData.notifications.where((n) => !n.isRead).length;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: AppColors.profileGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: const AssetImage('assets/images/rider_profile.png'),
                  ),
                  const SizedBox(height: 12),
                  Text(rider.displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Fleet ${rider.fleetId}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _item(context, Icons.assignment_rounded, 'Tasks', () => _goTab(context, 0)),
                  _item(context, Icons.payments_rounded, 'Earnings', () => _goTab(context, 1)),
                  _item(context, Icons.person_rounded, 'Profile', () => _goTab(context, 2)),
                  const Divider(),
                  _item(context, Icons.history_rounded, 'Delivery History', () => _push(context, const DeliveryHistoryScreen())),
                  _item(context, Icons.notifications_rounded, 'Notifications', () => _push(context, const NotificationsScreen()), badge: unread),
                  _item(context, Icons.pedal_bike_rounded, 'Vehicle Details', () => _push(context, const VehicleDetailsScreen())),
                  _item(context, Icons.account_balance_wallet_rounded, 'Payment Info', () => _push(context, const PaymentInfoScreen())),
                  _item(context, Icons.help_outline_rounded, 'Support', () => _push(context, const SupportScreen())),
                  _item(context, Icons.settings_rounded, 'Settings', () => _push(context, const SettingsScreen())),
                  const Divider(),
                  _item(context, Icons.logout_rounded, 'Logout', () {
                    Navigator.pop(context);
                    AppState.instance.logout();
                  }, color: AppColors.primary),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Rider Connect v4.2.1', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  void _goTab(BuildContext context, int index) {
    Navigator.pop(context);
    AppState.instance.setTab(index);
  }

  void _push(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback onTap, {int badge = 0, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
      title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          : null,
      onTap: onTap,
    );
  }
}
