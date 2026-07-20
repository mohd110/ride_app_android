import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'edit_profile_screen.dart';

/// Real vehicle info from the rider's profile — previously this screen was
/// 100% MockData (fake battery %, charge cycles, service dates) with a
/// "Book Maintenance" button that only showed a SnackBar. There's no IoT/
/// telemetry integration behind any of that, so it's gone rather than kept
/// as decoration; this now just displays what the rider actually entered
/// and lets them edit it.
class VehicleDetailsScreen extends StatelessWidget {
  const VehicleDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final rider = AppState.instance.rider;
        final hasAnyInfo = [
          rider.vehicleType,
          rider.vehicleModel,
          rider.vehicleRegistrationNumber,
          rider.licenseNumber,
        ].any((v) => v?.isNotEmpty == true);

        return DetailPageScaffold(
          title: 'Vehicle Details',
          children: [
            if (!hasAnyInfo)
              AppCard(
                dashed: true,
                child: Column(
                  children: const [
                    Icon(Icons.two_wheeler_rounded, color: AppColors.textMuted, size: 36),
                    SizedBox(height: 12),
                    Text(
                      'No vehicle info yet',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add your vehicle type, model, registration, and license number.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              )
            else
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.pedal_bike_rounded, size: 36, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rider.vehicleModel?.isNotEmpty == true ? rider.vehicleModel! : 'Model not set',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          if (rider.vehicleRegistrationNumber?.isNotEmpty == true)
                            Text('Reg: ${rider.vehicleRegistrationNumber}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          if (rider.vehicleType?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(rider.vehicleType!, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  InfoRow(label: 'Vehicle Type', value: rider.vehicleType?.isNotEmpty == true ? rider.vehicleType! : '—'),
                  InfoRow(label: 'Model', value: rider.vehicleModel?.isNotEmpty == true ? rider.vehicleModel! : '—'),
                  InfoRow(label: 'Registration Number', value: rider.vehicleRegistrationNumber?.isNotEmpty == true ? rider.vehicleRegistrationNumber! : '—'),
                  InfoRow(label: 'License Number', value: rider.licenseNumber?.isNotEmpty == true ? rider.licenseNumber! : '—'),
                ],
              ),
            ),
          ],
          bottomAction: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            child: const Text('Edit Vehicle Info'),
          ),
        );
      },
    );
  }
}
