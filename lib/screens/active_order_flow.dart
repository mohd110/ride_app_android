import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/delivery_route_map.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/swipe_slider.dart';
import '../services/phone_service.dart';
import 'active_order_detail_screen.dart';
import 'chat_screen.dart';

class ActiveOrderFlow extends StatefulWidget {
  const ActiveOrderFlow({Key? key}) : super(key: key);

  @override
  State<ActiveOrderFlow> createState() => _ActiveOrderFlowState();
}

class _ActiveOrderFlowState extends State<ActiveOrderFlow> {
  final TextEditingController _recipientController = TextEditingController();

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        Widget content;
        if (state.orderState == OrderState.navToRestaurant || state.orderState == OrderState.navToCustomer) {
          content = _buildNavigationScreen(state);
        } else if (state.orderState == OrderState.verifyItems) {
          content = _buildChecklistScreen(state);
        } else if (state.orderState == OrderState.confirmDelivery) {
          content = _buildConfirmDeliveryScreen(state);
        } else {
          content = _buildSuccessScreen(state);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(child: content),
        );
      },
    );
  }

  Widget _buildNavigationScreen(AppState state) {
    final isToCustomer = state.orderState == OrderState.navToCustomer;
    final order = state.activeOrder;

    return Stack(
      children: [
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActiveOrderDetailScreen()),
              ),
              icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            ),
          ),
        ),
        Positioned.fill(
          child: DeliveryRouteMap(
            restaurantLat: order.restaurantLat,
            restaurantLng: order.restaurantLng,
            customerLat: order.customerLat,
            customerLng: order.customerLng,
            riderLat: state.riderLat,
            riderLng: state.riderLng,
            isToCustomer: isToCustomer,
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.navInstruction,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _liveDistanceLabel(state, isToCustomer),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (state.locationError != null) ...[
                const SizedBox(height: 8),
                AppCard(
                  color: AppColors.error.withOpacity(0.1),
                  borderColor: AppColors.error.withOpacity(0.4),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.locationError!,
                          style: const TextStyle(color: AppColors.error, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 200,
          child: Column(
            children: [
              _fabBtn(Icons.directions_rounded, onTap: () => _launchNavigation(
                isToCustomer ? order.customerLat : order.restaurantLat,
                isToCustomer ? order.customerLng : order.restaurantLng,
                isToCustomer ? order.customerAddress : order.restaurantAddress,
              )),
              const SizedBox(height: 10),
              _fabBtn(Icons.chat_bubble_outline_rounded, onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatScreen(
                  contactName: isToCustomer ? order.customerName : order.restaurant,
                )),
              )),
              const SizedBox(height: 10),
              _fabBtn(Icons.phone_rounded, onTap: () => PhoneService.call(
                context,
                isToCustomer ? order.customerPhone : order.restaurantPhone,
              )),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isToCustomer ? 'NAVIGATING TO CUSTOMER' : 'NAVIGATING TO PICKUP',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isToCustomer ? order.customerName : order.restaurant,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (!isToCustomer)
                  Text(
                    '₹${order.guaranteedEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (isToCustomer) {
                      state.arrivedAtCustomer();
                    } else {
                      state.arrivedAtRestaurant();
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: Text(isToCustomer ? 'ARRIVED AT LOCATION' : 'ARRIVED AT RESTAURANT'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDeliveryProof(AppState state) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null) return;

    final error = await state.uploadPhotoProof(source);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Opens real turn-by-turn navigation in the Google Maps app (or
  /// maps.google.com on web) rather than building a custom routing engine —
  /// this gets live traffic-aware ETA and automatic rerouting on deviation
  /// for free, maintained by Google instead of reimplemented here.
  ///
  /// Falls back to the saved address text when lat/lng are missing (some
  /// customer-app checkout flows don't capture GPS coordinates) — Google
  /// Maps geocodes a plain address string just fine, so this is strictly
  /// better than refusing to navigate at all.
  Future<void> _launchNavigation(double? lat, double? lng, String fallbackAddress) async {
    final Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    } else if (fallbackAddress.trim().isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(fallbackAddress)}&travelmode=driving',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No location or address saved for this stop.')),
        );
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  /// Straight-line distance/ETA to whichever leg the rider is currently on.
  /// Approximate (no live road-routing) — assumes ~25 km/h average moped speed.
  String _liveDistanceLabel(AppState state, bool isToCustomer) {
    final km = isToCustomer ? state.distanceToCustomerKm : state.distanceToRestaurantKm;
    if (km == null) {
      return isToCustomer
          ? (state.navDurationText.isNotEmpty ? state.navDurationText : 'Live GPS tracking')
          : 'Head to restaurant';
    }
    final etaMin = (km / 25 * 60).clamp(1, 999).round();
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km away • ~$etaMin min';
  }

  Widget _fabBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  Widget _buildChecklistScreen(AppState state) {
    final checkedCount = state.verifiedItems.where((x) => x).length;
    final order = state.activeOrder;
    final isReady = state.isOrderReady;
    final allVerified = state.isAllItemsVerified;
    // Both conditions must be true before the rider can start delivery.
    final canStart = isReady && allVerified;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pickup Confirmation',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.restaurant, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(order.restaurantAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(order.pickupInstruction, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          // Waiting banner — shown whenever the restaurant hasn't marked Ready yet.
          // Disappears automatically (via realtime) once they tap Mark Ready.
          if (!isReady) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                border: Border.all(color: const Color(0xFFFFD700)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.schedule_rounded, color: Color(0xFFB8860B), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Waiting for the restaurant to mark this order as Ready for Pickup. Delivery will unlock automatically.',
                      style: TextStyle(color: Color(0xFF7B6100), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VERIFY ITEMS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(
                '$checkedCount / ${state.checklistItems.length}',
                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (!allVerified && state.checklistItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state.verifyAllItems,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('SELECT ALL ITEMS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: state.checklistItems.length,
              itemBuilder: (context, index) {
                final item = state.checklistItems[index];
                final isChecked = state.verifiedItems[index];
                return InkWell(
                  onTap: () => state.toggleItemVerification(index),
                  borderRadius: BorderRadius.circular(12),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    color: isChecked ? AppColors.surfaceAccent : AppColors.surface,
                    borderColor: isChecked ? AppColors.primary.withOpacity(0.4) : AppColors.border,
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isChecked ? AppColors.primary : Colors.transparent,
                            border: Border.all(color: isChecked ? AppColors.primary : AppColors.textMuted, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isChecked ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item['name']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        Text(item['qty']!, style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: canStart
                ? () async {
                    final error = await state.startDelivery();
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.surfaceMuted,
            ),
            child: Text(
              !allVerified
                  ? 'VERIFY ALL ITEMS'
                  : !isReady
                      ? 'WAITING FOR RESTAURANT...'
                      : 'START DELIVERY',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmDeliveryScreen(AppState state) {
    final order = state.activeOrder;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Delivery',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat(label: 'EARNINGS', value: '₹${order.guaranteedEarnings.toStringAsFixed(2)}'),
                        _SummaryStat(label: 'ITEMS', value: '${order.items.length}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recipient Name', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _recipientController,
                          onChanged: state.setRecipientName,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(hintText: 'e.g. John Doe'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: const [
                            Icon(Icons.check_box_outline_blank_rounded, color: AppColors.textMuted, size: 18),
                            SizedBox(width: 8),
                            Text('Customer signature not required', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: state.isUploadingPhoto ? null : () => _pickDeliveryProof(state),
                    child: AppCard(
                      child: state.isUploadingPhoto
                          ? const SizedBox(
                              height: 140,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : state.hasPhotoProof && state.deliveryProofUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    state.deliveryProofUrl!,
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  children: const [
                                    Icon(Icons.camera_alt_rounded, color: AppColors.textMuted, size: 32),
                                    SizedBox(height: 8),
                                    Text('Take Photo of Delivery', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwipeSlider(
            onComplete: () async {
              final error = await state.completeDelivery();
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen(AppState state) {
    final payout = state.lastPayout;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceAccent,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 24),
          const Text(
            'Delivery Completed!',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Great job! The payment has been added to your balance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),
          Text(
            '+₹${payout.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => state.finishSuccessScreen(),
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
