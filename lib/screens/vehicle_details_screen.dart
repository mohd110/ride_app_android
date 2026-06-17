import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

class VehicleDetailsScreen extends StatelessWidget {
  const VehicleDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
  return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final v = MockData.vehicle;

        return DetailPageScaffold(
          title: 'Vehicle Details',
          children: [
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
                        Text(v['model'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('ID: ${v['id']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(v['type'] as String, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        const Text('Battery', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text('${state.batteryLevel}%', style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        const Text('Range left', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text('${v['rangeKm']} km', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Diagnostics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  InfoRow(label: 'Temperature', value: v['temperature'] as String),
                  InfoRow(label: 'Charge cycles', value: '${v['chargeCycles']}'),
                  InfoRow(label: 'Last serviced', value: v['lastServiced'] as String),
                  InfoRow(label: 'Status', value: 'Healthy', valueColor: AppColors.success),
                ],
              ),
            ),
          ],
          bottomAction: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Service appointment booked for Jun 20, 10:00 AM')),
              );
            },
            child: const Text('Book Maintenance'),
          ),
        );
      },
    );
  }
}

class VehicleTypeScreen extends StatelessWidget {
  const VehicleTypeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final types = [
      {'name': 'Electric Bicycle', 'selected': true, 'icon': Icons.pedal_bike_rounded},
      {'name': 'Electric Scooter', 'selected': false, 'icon': Icons.electric_scooter_rounded},
      {'name': 'Motorcycle', 'selected': false, 'icon': Icons.two_wheeler_rounded},
      {'name': 'Car', 'selected': false, 'icon': Icons.directions_car_rounded},
    ];

    return DetailPageScaffold(
      title: 'Vehicle Type',
      children: [
        const Text(
          'Select the vehicle you use for deliveries. Hub manager approval required for changes.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        ...types.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${t['name']} selected — pending approval')),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: AppCard(
                  borderColor: t['selected'] == true ? AppColors.primary : AppColors.border,
                  child: Row(
                    children: [
                      Icon(t['icon'] as IconData, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (t['selected'] == true)
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}
