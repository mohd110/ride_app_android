import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_colors.dart';

class DeliveryRouteMap extends StatefulWidget {
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;

  const DeliveryRouteMap({
    Key? key,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.customerLat,
    required this.customerLng,
  }) : super(key: key);

  @override
  State<DeliveryRouteMap> createState() => _DeliveryRouteMapState();
}

class _DeliveryRouteMapState extends State<DeliveryRouteMap> {
  GoogleMapController? _controller;

  // Matches the fallback center used by the customer-facing web app's LiveMap.
  static const _fallbackCenter = LatLng(26.4499, 80.3319);

  LatLng? get _restaurantPos => widget.restaurantLat != null && widget.restaurantLng != null
      ? LatLng(widget.restaurantLat!, widget.restaurantLng!)
      : null;

  LatLng? get _customerPos => widget.customerLat != null && widget.customerLng != null
      ? LatLng(widget.customerLat!, widget.customerLng!)
      : null;

  @override
  Widget build(BuildContext context) {
    final restaurantPos = _restaurantPos;
    final customerPos = _customerPos;

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

    final markers = <Marker>{
      if (restaurantPos != null)
        Marker(
          markerId: const MarkerId('restaurant'),
          position: restaurantPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (customerPos != null)
        Marker(
          markerId: const MarkerId('customer'),
          position: customerPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Drop-off'),
        ),
    };

    final polylines = <Polyline>{
      if (restaurantPos != null && customerPos != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: [restaurantPos, customerPos],
          color: AppColors.primary,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: restaurantPos ?? customerPos ?? _fallbackCenter,
        zoom: 14,
      ),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        if (restaurantPos != null && customerPos != null) {
          _fitBounds(restaurantPos, customerPos);
        }
      },
    );
  }

  Future<void> _fitBounds(LatLng a, LatLng b) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final controller = _controller;
    if (controller == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }
}
