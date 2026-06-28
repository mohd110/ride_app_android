import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_client.dart';
import '../data/mock_data.dart';

const _orderSelect =
    '*, order_items(quantity, price_at_order, products(name)), restaurants(name, address, phone, latitude, longitude)';

class AvailableOrderSummary {
  final String id;
  final String restaurantName;
  final String restaurantAddress;
  final String dropoffAddress;
  final String customerName;
  final double deliveryFee;
  final double estimatedEarnings;
  final String status;

  const AvailableOrderSummary({
    required this.id,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.dropoffAddress,
    required this.customerName,
    required this.deliveryFee,
    required this.estimatedEarnings,
    required this.status,
  });

  factory AvailableOrderSummary.fromJson(Map<String, dynamic> json, {double pricePerKm = 10.0}) {
    final restaurant = json['restaurants'] as Map<String, dynamic>?;
    final delivery = json['delivery_address'] as Map<String, dynamic>? ?? {};
    final fee = (json['delivery_fee'] as num?)?.toInt() ?? 0;

    final restaurantLat = (restaurant?['latitude'] as num?)?.toDouble();
    final restaurantLng = (restaurant?['longitude'] as num?)?.toDouble();
    final customerLat = (json['delivery_latitude'] as num?)?.toDouble();
    final customerLng = (json['delivery_longitude'] as num?)?.toDouble();

    // What the rider will actually be paid — restaurant→customer distance ×
    // the current rate, the same figure shown after accepting and the same
    // figure the server computes on delivery. Showing the customer's
    // delivery_fee here instead was misleading: it doesn't match what the
    // rider earns, and the two numbers can differ wildly.
    double estimatedEarnings;
    if (restaurantLat != null && restaurantLng != null && customerLat != null && customerLng != null) {
      final distanceKm = Geolocator.distanceBetween(restaurantLat, restaurantLng, customerLat, customerLng) / 1000.0;
      estimatedEarnings = distanceKm * pricePerKm;
    } else {
      estimatedEarnings = fee.toDouble();
    }

    return AvailableOrderSummary(
      id: json['id'] as String,
      restaurantName: restaurant?['name'] as String? ?? 'Restaurant',
      restaurantAddress: restaurant?['address'] as String? ?? '',
      dropoffAddress: delivery['address'] as String? ?? '',
      customerName: delivery['name'] as String? ?? 'Customer',
      // delivery_fee is stored as plain rupees (e.g. 30 = ₹30, confirmed
      // against real order math: item prices + delivery_fee = total, all
      // in the same unit) — not paise, so no /100 conversion belongs here.
      deliveryFee: fee.toDouble(),
      estimatedEarnings: estimatedEarnings,
      status: json['status'] as String? ?? '',
    );
  }
}

class OrderService {
  Future<List<AvailableOrderSummary>> fetchAvailableOrders({double pricePerKm = 10.0}) async {
    try {
      return await _mapAvailableRows(await _queryAvailableOrders(_orderSelect), pricePerKm);
    } on PostgrestException {
      const fallbackSelect =
          'id, status, delivery_fee, delivery_address, restaurants(name, address, phone)';
      return await _mapAvailableRows(await _queryAvailableOrders(fallbackSelect), pricePerKm);
    }
  }

  Future<List<dynamic>> _queryAvailableOrders(String select) async {
    final rows = await supabase
        .from('orders')
        .select(select)
        .isFilter('rider_id', null)
        .eq('payment_status', 'verified')
        .inFilter('status', ['accepted', 'preparing', 'ready'])
        .order('created_at');

    return rows as List<dynamic>;
  }

  List<AvailableOrderSummary> _mapAvailableRows(List<dynamic> rows, double pricePerKm) {
    return rows
        .map((row) => AvailableOrderSummary.fromJson(row as Map<String, dynamic>, pricePerKm: pricePerKm))
        .toList();
  }

  /// A rider should only ever have one order in flight, but this is
  /// defensive against that invariant being violated (e.g. a claim that
  /// got interrupted before completion) — picks the most recent rather
  /// than using maybeSingle(), which throws outright if more than one
  /// row matches instead of just picking one.
  Future<ActiveOrderData?> fetchActiveOrder(String riderId, {double pricePerKm = 10.0}) async {
    final rows = await supabase
        .from('orders')
        .select(_orderSelect)
        .eq('rider_id', riderId)
        .not('status', 'in', ['delivered', 'cancelled'])
        .order('created_at', ascending: false)
        .limit(1);

    if ((rows as List).isEmpty) return null;
    return ActiveOrderData.fromSupabase(rows.first as Map<String, dynamic>, pricePerKm: pricePerKm);
  }

  /// Returns null on success, or an error message.
  Future<String?> claimOrder(String orderId, String riderId) async {
    final claimed = await supabase
        .from('orders')
        .update({'rider_id': riderId})
        .eq('id', orderId)
        .filter('rider_id', 'is', null)
        .select();

    if ((claimed as List).isEmpty) {
      return 'Order already taken by another rider';
    }
    return null;
  }

  Future<void> markOutForDelivery(String orderId) async {
    await supabase.from('orders').update({'status': 'out_for_delivery'}).eq('id', orderId);
  }

  /// Returns the authoritative rider_payment computed server-side by the
  /// finalize_delivery_payment trigger (restaurant→customer distance ×
  /// the price-per-km in effect at the moment of delivery), or null if it
  /// couldn't be computed (e.g. missing coordinates).
  Future<double?> markDelivered(String orderId) async {
    final row = await supabase
        .from('orders')
        .update({'status': 'delivered'})
        .eq('id', orderId)
        .select('rider_payment')
        .maybeSingle();
    final value = row?['rider_payment'];
    return value is num ? value.toDouble() : null;
  }

  /// Upserts the rider's current position, keyed by [riderId] so a single
  /// row tracks them whether they're idle, browsing for orders, or
  /// delivering — [orderId] is null except while actively on a delivery.
  Future<void> upsertLocation({
    required String riderId,
    String? orderId,
    required double latitude,
    required double longitude,
    required String status,
  }) async {
    await supabase.from('rider_locations').upsert({
      'rider_id': riderId,
      'order_id': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'rider_id');
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return await supabase.from('profiles').select().eq('id', userId).maybeSingle();
  }

  /// The current per-km delivery rate, admin-configurable from the
  /// restaurant dashboard. Falls back to ₹10/km if the settings row or
  /// the table itself isn't reachable (e.g. migration not yet applied).
  Future<double> fetchPricePerKm() async {
    try {
      final row = await supabase
          .from('delivery_settings')
          .select('price_per_km')
          .eq('id', 1)
          .maybeSingle();
      final value = row?['price_per_km'];
      if (value is num) return value.toDouble();
      return 10.0;
    } catch (_) {
      return 10.0;
    }
  }

  /// Uploads delivery-confirmation proof to Storage and links it to the
  /// order. Bucket is public-read; the storage policy only lets the
  /// assigned rider write to "<order_id>.jpg", so the path itself is the
  /// authorization check.
  Future<String> uploadDeliveryProof(String orderId, Uint8List bytes) async {
    final path = '$orderId.jpg';
    await supabase.storage.from('delivery-proofs').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final url = supabase.storage.from('delivery-proofs').getPublicUrl(path);
    await supabase.from('orders').update({'delivery_proof_url': url}).eq('id', orderId);
    return url;
  }

  /// Uploads a new rider profile photo and updates profiles.avatar_url.
  /// Path is "<rider_id>.jpg" — the storage policy only lets a rider write
  /// to their own id, so this can never overwrite someone else's photo.
  Future<String> uploadRiderProfilePhoto(String riderId, Uint8List bytes) async {
    final path = '$riderId.jpg';
    await supabase.storage.from('rider-profiles').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final url = supabase.storage.from('rider-profiles').getPublicUrl(path);
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', riderId);
    return url;
  }

  /// Real notification history — logged automatically by a trigger on the
  /// orders table (assigned/picked-up/delivered/payment/cancelled), not
  /// mock data.
  Future<List<Map<String, dynamic>>> fetchNotifications(String riderId) async {
    final rows = await supabase
        .from('rider_notifications')
        .select()
        .eq('rider_id', riderId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> markNotificationRead(String id) async {
    await supabase.from('rider_notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String riderId) async {
    await supabase
        .from('rider_notifications')
        .update({'is_read': true})
        .eq('rider_id', riderId)
        .eq('is_read', false);
  }
}
