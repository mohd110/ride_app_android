import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/maps_config.dart';

/// A successfully-decoded road route between two points.
class RouteResult {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;

  const RouteResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });
}

/// Thin wrapper around the Google Directions API (via flutter_polyline_points)
/// with the error handling spelled out: unavailable API, bad key,
/// REQUEST_DENIED, ZERO_RESULTS, and plain network failures all resolve to
/// `null` rather than throwing, so a rider's navigation screen never breaks
/// because a route couldn't be fetched — it just falls back to showing
/// markers only.
class DirectionsService {
  DirectionsService._();

  static final PolylinePoints _polylinePoints = PolylinePoints.legacy(MapsConfig.apiKey);

  static Future<RouteResult?> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final result = await _polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
        timeout: const Duration(seconds: 12),
      );

      if (result.status != 'OK' || result.points.isEmpty) {
        // Covers REQUEST_DENIED (bad/unauthorized key, Directions API not
        // enabled), ZERO_RESULTS (no drivable route between the points),
        // OVER_QUERY_LIMIT, INVALID_REQUEST, UNKNOWN_ERROR, etc.
        debugPrint(
          'Directions API returned ${result.status}: ${result.errorMessage ?? "no route"}',
        );
        return null;
      }

      return RouteResult(
        points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        distanceText: (result.distanceTexts?.isNotEmpty ?? false) ? result.distanceTexts!.first : '',
        durationText: (result.durationTexts?.isNotEmpty ?? false) ? result.durationTexts!.first : '',
      );
    } catch (e) {
      // Network errors, timeouts, malformed responses — the package throws
      // HttpException for these rather than returning a status.
      debugPrint('Directions API request failed: $e');
      return null;
    }
  }
}
