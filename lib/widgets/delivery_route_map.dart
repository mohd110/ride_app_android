import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../theme/app_colors.dart';

/// Renders pickup/drop-off/rider pins on OpenStreetMap tiles — no API key,
/// billing, or Google Cloud Console setup required at all. Real turn-by-turn
/// navigation is handled separately by launching the actual Google Maps app
/// (see ActiveOrderFlow._launchNavigation), so this widget only needs to show
/// an overview, not drive real routing — a perfect fit for a free tile layer.
class DeliveryRouteMap extends StatelessWidget {
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;
  final double? riderLat;
  final double? riderLng;

  const DeliveryRouteMap({
    Key? key,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.customerLat,
    required this.customerLng,
    this.riderLat,
    this.riderLng,
  }) : super(key: key);

  static const _fallbackCenter = ll.LatLng(26.4499, 80.3319);

  ll.LatLng? get _restaurantPos =>
      restaurantLat != null && restaurantLng != null ? ll.LatLng(restaurantLat!, restaurantLng!) : null;

  ll.LatLng? get _customerPos =>
      customerLat != null && customerLng != null ? ll.LatLng(customerLat!, customerLng!) : null;

  ll.LatLng? get _riderPos => riderLat != null && riderLng != null ? ll.LatLng(riderLat!, riderLng!) : null;

  @override
  Widget build(BuildContext context) {
    final restaurantPos = _restaurantPos;
    final customerPos = _customerPos;
    final riderPos = _riderPos;

    if (restaurantPos == null && customerPos == null) {
      return Container(
        color: AppColors.surfaceAccent,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Map unavailable — this order has no saved location.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    final points = <ll.LatLng>[
      if (restaurantPos != null) restaurantPos,
      if (customerPos != null) customerPos,
      if (riderPos != null) riderPos,
    ];
    final bounds = points.length > 1 ? LatLngBounds.fromPoints(points) : null;

    return FlutterMap(
      options: MapOptions(
        initialCenter: restaurantPos ?? customerPos ?? _fallbackCenter,
        initialZoom: 14,
        initialCameraFit: bounds != null
            ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60))
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.riderapp',
        ),
        if (restaurantPos != null && customerPos != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [restaurantPos, customerPos],
                color: AppColors.primary,
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [12, 8]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (restaurantPos != null)
              Marker(
                point: restaurantPos,
                width: 36,
                height: 36,
                child: _pin(Icons.storefront_rounded, Colors.red),
              ),
            if (customerPos != null)
              Marker(
                point: customerPos,
                width: 36,
                height: 36,
                child: _pin(Icons.home_rounded, Colors.blue),
              ),
            if (riderPos != null)
              Marker(
                point: riderPos,
                width: 36,
                height: 36,
                child: _pin(Icons.two_wheeler_rounded, Colors.green),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap'),
        ),
      ],
    );
  }

  Widget _pin(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4)],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
