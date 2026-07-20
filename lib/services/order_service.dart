import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_client.dart';
import '../data/mock_data.dart';

const _orderSelect =
    '*, order_items(quantity, price_at_order, products(name)), restaurants(name, address, phone, latitude, longitude)';

class AvailableOrderSummary {
  final String id;
  final String orderNumber;
  final String restaurantName;
  final String restaurantAddress;
  final String dropoffAddress;
  final String customerName;
  final double deliveryFee;
  final double estimatedEarnings;
  final String status;

  const AvailableOrderSummary({
    required this.id,
    required this.orderNumber,
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
    final rawId = json['id'] as String;

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
      id: rawId,
      // Use the admin/customer-visible order_number so riders can match what
      // the customer or restaurant says over the phone (e.g. ORD-BB-07/07/26-0042).
      // Fall back to a UUID prefix only for orders that pre-date the column.
      orderNumber: json['order_number'] as String? ?? '#${rawId.substring(0, 8).toUpperCase()}',
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

class EarningsSummary {
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final double lifetimeEarnings;
  final int todayOrders;
  final int totalOrders;
  final double walletBalance;

  const EarningsSummary({
    this.todayEarnings = 0,
    this.weekEarnings = 0,
    this.monthEarnings = 0,
    this.lifetimeEarnings = 0,
    this.todayOrders = 0,
    this.totalOrders = 0,
    this.walletBalance = 0,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      todayEarnings: (json['today_earnings'] as num?)?.toDouble() ?? 0,
      weekEarnings: (json['week_earnings'] as num?)?.toDouble() ?? 0,
      monthEarnings: (json['month_earnings'] as num?)?.toDouble() ?? 0,
      lifetimeEarnings: (json['lifetime_earnings'] as num?)?.toDouble() ?? 0,
      todayOrders: (json['today_orders'] as num?)?.toInt() ?? 0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DailyEarningsPoint {
  final DateTime day;
  final double total;

  const DailyEarningsPoint({required this.day, required this.total});

  factory DailyEarningsPoint.fromJson(Map<String, dynamic> json) {
    return DailyEarningsPoint(
      day: DateTime.parse(json['day'] as String),
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RiderPayout {
  final String id;
  final double amount;
  final String status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? paidAt;
  final DateTime createdAt;

  const RiderPayout({
    required this.id,
    required this.amount,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    this.paidAt,
    required this.createdAt,
  });

  factory RiderPayout.fromJson(Map<String, dynamic> json) {
    return RiderPayout(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OrderService {
  /// Today/week/month/lifetime earnings, order counts, and unpaid wallet
  /// balance — computed server-side straight from orders.rider_payment via
  /// the get_my_earnings_summary RPC (migration 009), always scoped to the
  /// calling rider. Replaces what used to be hardcoded numbers that only
  /// ever incremented in-memory and reset on every login.
  Future<EarningsSummary> fetchEarningsSummary() async {
    try {
      final rows = await supabase.rpc('get_my_earnings_summary') as List<dynamic>;
      if (rows.isEmpty) return const EarningsSummary();
      return EarningsSummary.fromJson(rows.first as Map<String, dynamic>);
    } catch (_) {
      return const EarningsSummary();
    }
  }

  /// Zero-filled daily earnings for the last [days] days — feeds the
  /// earnings chart's daily/weekly/monthly views from one real series
  /// instead of three separate fabricated data sets.
  Future<List<DailyEarningsPoint>> fetchDailyEarnings({int days = 180}) async {
    try {
      final rows = await supabase.rpc('get_my_daily_earnings', params: {'p_days': days}) as List<dynamic>;
      return rows.map((row) => DailyEarningsPoint.fromJson(row as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Full delivered-order history for the signed-in rider, most recent
  /// first — real rows from orders, not a mock list mixed with whatever
  /// happened to be completed in the current session.
  Future<List<Map<String, dynamic>>> fetchOrderHistory(String riderId, {int limit = 100}) async {
    final rows = await supabase
        .from('orders')
        .select(_orderSelect)
        .eq('rider_id', riderId)
        .eq('status', 'delivered')
        .order('delivered_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Payout batches for the signed-in rider (e.g. a weekly settlement) —
  /// read-only from the rider app; created/marked paid by the restaurant
  /// admin.
  Future<List<RiderPayout>> fetchPayouts(String riderId) async {
    try {
      final rows = await supabase
          .from('rider_payouts')
          .select()
          .eq('rider_id', riderId)
          .order('created_at', ascending: false);
      return (rows as List).map((row) => RiderPayout.fromJson(row as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AvailableOrderSummary>> fetchAvailableOrders({double pricePerKm = 10.0}) async {
    try {
      return _mapAvailableRows(await _queryAvailableOrders(_orderSelect), pricePerKm);
    } on PostgrestException {
      const fallbackSelect =
          'id, status, delivery_fee, delivery_address, restaurants(name, address, phone)';
      return _mapAvailableRows(await _queryAvailableOrders(fallbackSelect), pricePerKm);
    }
  }

  Future<List<dynamic>> _queryAvailableOrders(String select) async {
    final rows = await supabase
        .from('orders')
        .select(select)
        .isFilter('rider_id', null)
        .eq('payment_status', 'verified')
        .eq('order_type', 'delivery')
        .inFilter('status', ['ready'])
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
    return ActiveOrderData.fromSupabase(rows.first, pricePerKm: pricePerKm);
  }

  /// Atomically claims [orderId] for the authenticated rider on [deviceId].
  ///
  /// Returns null on success, 'session_expired' when the caller should
  /// force-logout, or a human-readable error string otherwise.
  ///
  /// Uses the claim_order_atomic SECURITY DEFINER RPC which:
  ///  1. Verifies the device still has an active session.
  ///  2. Updates orders WHERE rider_id IS NULL in a single atomic statement —
  ///     the first concurrent caller wins, all others get 'already_claimed'.
  Future<String?> claimOrder(String orderId, String deviceId) async {
    try {
      final result = await supabase.rpc('claim_order_atomic', params: {
        'p_order_id': orderId,
        'p_device_id': deviceId,
      }) as String?;

      switch (result) {
        case 'success':
          return null;
        case 'already_claimed':
          return 'This order was just claimed by another rider.';
        case 'session_expired':
          return 'session_expired'; // AppState handles this specially
        default:
          return 'Could not claim order. Please try again.';
      }
    } on PostgrestException catch (e) {
      return e.message.isNotEmpty ? e.message : 'Could not claim order.';
    } catch (_) {
      return 'Could not claim order. Please try again.';
    }
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

  /// Saves editable profile fields straight to `profiles`. Only send the
  /// fields that changed — this does a plain `.update()`, not an upsert, so
  /// it never touches columns not included in [fields].
  Future<void> updateProfile(String userId, Map<String, dynamic> fields) async {
    await supabase.from('profiles').update(fields).eq('id', userId);
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

  /// Company/app info shown on the Support and Company Info screens —
  /// singleton row (supabase/013_rider_profile_and_company_info.sql), same
  /// pattern as delivery_settings. Returns null if the migration hasn't
  /// been applied yet or the table is otherwise unreachable, so callers can
  /// fall back to sensible defaults instead of crashing.
  Future<Map<String, dynamic>?> fetchCompanyInfo() async {
    try {
      return await supabase.from('company_info').select().eq('id', 1).maybeSingle();
    } catch (_) {
      return null;
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
