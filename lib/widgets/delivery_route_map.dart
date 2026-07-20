import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/directions_service.dart';
import '../theme/app_colors.dart';

/// Home/customer pin color — the app's palette (AppColors) has no blue, and
/// red/green are already claimed by restaurant/rider.
const _customerPinColor = Color(0xFF2563EB);

/// Renders rider/restaurant/customer pins on a Google Map, with the real
/// driving route (via the Google Directions API) drawn between the rider
/// and whichever stop is currently active — restaurant while heading to
/// pickup, customer after pickup.
///
/// The route is refetched only when the rider has moved meaningfully or
/// enough time has passed (see [_minRefetchInterval]/[_minMovementMeters])
/// to keep Directions API usage — a paid, per-request service — low; between
/// refetches the rider marker still moves every rebuild, it just doesn't
/// trigger a new route request.
class DeliveryRouteMap extends StatefulWidget {
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;
  final double? riderLat;
  final double? riderLng;
  final bool isToCustomer;

  const DeliveryRouteMap({
    Key? key,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.customerLat,
    required this.customerLng,
    this.riderLat,
    this.riderLng,
    this.isToCustomer = false,
  }) : super(key: key);

  @override
  State<DeliveryRouteMap> createState() => _DeliveryRouteMapState();
}

class _DeliveryRouteMapState extends State<DeliveryRouteMap> {
  static const _fallbackCenter = LatLng(26.4499, 80.3319);

  // Don't hit the (paid) Directions API more than this often...
  static const _minRefetchInterval = Duration(seconds: 45);
  // ...unless the rider has moved at least this far, in which case the
  // cached route is stale enough to be worth the request regardless of time.
  static const _minMovementMeters = 150.0;

  GoogleMapController? _controller;
  Set<Polyline> _polylines = {};
  bool _isFetchingRoute = false;
  DateTime? _lastFetchTime;
  LatLng? _lastFetchOrigin;

  // Rendered once (not per-build) and reused for every marker of that type —
  // regenerating a bitmap on every rebuild would be wasteful. Null until
  // _loadMarkerIcons() finishes; build() falls back to a default pin hue
  // until then so the map never has a blank/missing marker while these load.
  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _restaurantIcon;
  BitmapDescriptor? _customerIcon;

  LatLng? get _restaurantPos =>
      widget.restaurantLat != null && widget.restaurantLng != null
          ? LatLng(widget.restaurantLat!, widget.restaurantLng!)
          : null;

  LatLng? get _customerPos =>
      widget.customerLat != null && widget.customerLng != null
          ? LatLng(widget.customerLat!, widget.customerLng!)
          : null;

  LatLng? get _riderPos =>
      widget.riderLat != null && widget.riderLng != null ? LatLng(widget.riderLat!, widget.riderLng!) : null;

  LatLng? get _activeDestination => widget.isToCustomer ? _customerPos : _restaurantPos;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _maybeRefetchRoute(force: true);
  }

  Future<void> _loadMarkerIcons() async {
    final icons = await Future.wait([
      _renderPinIcon(icon: Icons.two_wheeler_rounded, color: AppColors.success),
      _renderPinIcon(icon: Icons.storefront_rounded, color: AppColors.primary),
      _renderPinIcon(icon: Icons.home_rounded, color: _customerPinColor),
    ]);
    if (!mounted) return;
    setState(() {
      _riderIcon = icons[0];
      _restaurantIcon = icons[1];
      _customerIcon = icons[2];
    });
  }

  /// Rasterizes a Material Icon glyph inside a white, colored-border circle
  /// (same look as the pins the old OSM-based map used) into a PNG bitmap
  /// suitable for [Marker.icon] — google_maps_flutter has no built-in way to
  /// use an IconData directly, only bitmaps/assets.
  Future<BitmapDescriptor> _renderPinIcon({required IconData icon, required Color color}) async {
    const logicalSize = 44.0;
    final density = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final pixelSize = (logicalSize * density).round();
    final radius = pixelSize / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Soft drop shadow, then the white circle, then a colored ring — matches
    // the pin style used elsewhere in this app.
    canvas.drawCircle(
      Offset(radius, radius + density),
      radius - (2 * density),
      Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(radius, radius), radius - (3 * density), Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(radius, radius),
      radius - (3 * density),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * density,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: logicalSize * 0.5 * density,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      )
      ..layout();
    textPainter.paint(canvas, Offset(radius - textPainter.width / 2, radius - textPainter.height / 2));

    final image = await recorder.endRecording().toImage(pixelSize, pixelSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: density);
  }

  @override
  void didUpdateWidget(covariant DeliveryRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final destinationChanged = oldWidget.isToCustomer != widget.isToCustomer;
    final riderMoved = oldWidget.riderLat != widget.riderLat || oldWidget.riderLng != widget.riderLng;

    if (destinationChanged) {
      // A new leg of the trip (pickup done, now heading to the customer) —
      // the old route no longer applies, and forcing a refetch bypasses the
      // throttle since this genuinely is a new route, not just movement.
      setState(() => _polylines = {});
      _maybeRefetchRoute(force: true);
    } else if (riderMoved) {
      _maybeRefetchRoute(); // Throttled internally.
    }
  }

  Future<void> _maybeRefetchRoute({bool force = false}) async {
    final origin = _riderPos;
    final destination = _activeDestination;
    if (origin == null || destination == null) return;
    if (_isFetchingRoute) return;

    if (!force && _lastFetchTime != null && _lastFetchOrigin != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      final movedMeters = Geolocator.distanceBetween(
        _lastFetchOrigin!.latitude,
        _lastFetchOrigin!.longitude,
        origin.latitude,
        origin.longitude,
      );
      if (elapsed < _minRefetchInterval && movedMeters < _minMovementMeters) {
        return; // Too soon and hasn't moved enough — the marker still moves via build().
      }
    }

    _isFetchingRoute = true;
    final result = await DirectionsService.fetchDrivingRoute(origin: origin, destination: destination);
    _isFetchingRoute = false;
    if (!mounted) return;

    _lastFetchTime = DateTime.now();
    _lastFetchOrigin = origin;

    if (result == null) {
      // Directions API unavailable/denied/no-route/network error — keep
      // whatever polyline (if any) was already showing rather than clearing
      // a still-valid route just because a refresh failed, and keep the
      // markers up either way so navigation can continue.
      return;
    }

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('active_route'),
          points: result.points,
          color: AppColors.primary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });

    _animateToBounds(_boundsFor([origin, destination, ...result.points]));
  }

  void _fitToAvailablePoints() {
    final points = [_restaurantPos, _customerPos, _riderPos].whereType<LatLng>().toList();
    if (points.length < 2) return;
    _animateToBounds(_boundsFor(points));
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  Future<void> _animateToBounds(LatLngBounds bounds) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      // Bounds too small (e.g. rider is essentially at the destination) or
      // the map isn't laid out yet — non-fatal, camera just stays put.
    }
  }

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

    final initialCenter = _activeDestination ?? restaurantPos ?? customerPos ?? riderPos ?? _fallbackCenter;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: 14),
      onMapCreated: (controller) {
        _controller = controller;
        _fitToAvailablePoints();
      },
      markers: {
        if (restaurantPos != null)
          Marker(
            markerId: const MarkerId('restaurant'),
            position: restaurantPos,
            icon: _restaurantIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Restaurant'),
          ),
        if (customerPos != null)
          Marker(
            markerId: const MarkerId('customer'),
            position: customerPos,
            icon: _customerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Customer'),
          ),
        if (riderPos != null)
          Marker(
            markerId: const MarkerId('rider'),
            position: riderPos,
            icon: _riderIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'You'),
            anchor: const Offset(0.5, 0.5),
          ),
      },
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }
}
