import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/app_card.dart';
import '../widgets/photo_source_sheet.dart';
import 'company_info_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'vehicle_details_screen.dart';
import 'payment_info_screen.dart';
import 'support_screen.dart';
import 'trip_stats_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final rider = state.rider;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeader(
                    title: 'Rider Connect',
                    notificationBadge: state.unreadNotifications,
                    onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                  const SizedBox(height: 12),
                  _buildProfileHeader(context, state, rider),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TripStatsScreen())),
                          borderRadius: BorderRadius.circular(16),
                          child: _buildStatCard('COMPLETED TASKS', '${rider.completedTasks}', Icons.check_circle_outline_rounded),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => state.setTab(1),
                          borderRadius: BorderRadius.circular(16),
                          child: _buildStatCard("TODAY'S EARNINGS", '₹${state.todayEarnings.toStringAsFixed(2)}', Icons.trending_up_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleDetailsScreen())),
                    borderRadius: BorderRadius.circular(16),
                    child: _buildVehicleCard(state),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SETTINGS & PREFERENCES',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildMenuItem(context, Icons.person_outline_rounded, 'Edit Profile', 'Name, phone, vehicle & more', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
                        const Divider(height: 1),
                        _buildMenuItem(context, Icons.local_shipping_outlined, 'Vehicle Type', rider.vehicleType ?? 'Not set', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
                        const Divider(height: 1),
                        _buildMenuItem(context, Icons.account_balance_wallet_outlined, 'Payment Info', 'Payout every Monday', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentInfoScreen()))),
                        const Divider(height: 1),
                        _buildMenuItem(context, Icons.help_outline_rounded, 'Support & Help Center', '24/7 Agent Availability', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
                        const Divider(height: 1),
                        _buildMenuItem(context, Icons.business_outlined, 'Company Information', 'About, terms & policies', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyInfoScreen()))),
                        const Divider(height: 1),
                        _buildMenuItem(context, Icons.logout_rounded, 'Logout Session', null, () => state.logout(), isLogout: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data;
                      return Text(
                        version != null ? 'Rider Connect v${version.version}+${version.buildNumber}' : ' ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      );
                    },
                  ),
                  Text('DEVICE ID: ${rider.deviceId}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppState state, RiderProfile rider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: AppColors.profileGradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  image: DecorationImage(
                    image: rider.avatarUrl != null
                        ? NetworkImage(rider.avatarUrl!)
                        : const AssetImage('assets/images/rider_profile.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                child: state.isUploadingPhoto
                    ? const CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: state.isUploadingPhoto
                      ? null
                      : () async {
                          final source = await showPhotoSourceSheet(context);
                          if (source == null) return;
                          final error = await state.uploadProfilePhoto(source);
                          if (error != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                          }
                        },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(rider.displayName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                const SizedBox(width: 4),
                Text('${rider.rating} Rating', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Member since ${rider.memberSince} • Fleet ID: ${rider.fleetId}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              Icon(icon, color: AppColors.primary, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(AppState state) {
    final rider = state.rider;
    final model = rider.vehicleModel?.isNotEmpty == true ? rider.vehicleModel! : 'No vehicle info yet';
    final reg = rider.vehicleRegistrationNumber?.isNotEmpty == true
        ? 'Reg: ${rider.vehicleRegistrationNumber}'
        : 'Tap to add your vehicle details';

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.pedal_bike_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(reg, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String? subtitle, VoidCallback onTap, {bool isLogout = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: AppColors.surfaceAccent, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isLogout ? AppColors.primary : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (subtitle != null) Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (!isLogout) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
