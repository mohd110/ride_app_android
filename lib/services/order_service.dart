import 'package:postgrest/postgrest.dart';
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
  final String status;

  const AvailableOrderSummary({
    required this.id,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.dropoffAddress,
    required this.customerName,
    required this.deliveryFee,
    required this.status,
  });

  factory AvailableOrderSummary.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurants'] as Map<String, dynamic>?;
    final delivery = json['delivery_address'] as Map<String, dynamic>? ?? {};
    final fee = (json['delivery_fee'] as num?)?.toInt() ?? 0;

    return AvailableOrderSummary(
      id: json['id'] as String,
      restaurantName: restaurant?['name'] as String? ?? 'Restaurant',
      restaurantAddress: restaurant?['address'] as String? ?? '',
      dropoffAddress: delivery['address'] as String? ?? '',
      customerName: delivery['name'] as String? ?? 'Customer',
      deliveryFee: fee / 100.0,
      status: json['status'] as String? ?? '',
    );
  }
}

class OrderService {
  Future<List<AvailableOrderSummary>> fetchAvailableOrders() async {
    try {
      return await _mapAvailableRows(await _queryAvailableOrders(_orderSelect));
    } on PostgrestException {
      const fallbackSelect =
          'id, status, delivery_fee, delivery_address, restaurants(name, address, phone)';
      return await _mapAvailableRows(await _queryAvailableOrders(fallbackSelect));
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

  List<AvailableOrderSummary> _mapAvailableRows(List<dynamic> rows) {
    return rows
        .map((row) => AvailableOrderSummary.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<ActiveOrderData?> fetchActiveOrder(String riderId) async {
    final row = await supabase
        .from('orders')
        .select(_orderSelect)
        .eq('rider_id', riderId)
        .not('status', 'in', ['delivered', 'cancelled'])
        .maybeSingle();

    if (row == null) return null;
    return ActiveOrderData.fromSupabase(row);
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

  Future<void> markDelivered(String orderId) async {
    await supabase.from('orders').update({'status': 'delivered'}).eq('id', orderId);
  }

  Future<void> upsertLocation({
    required String orderId,
    required String riderId,
    required double latitude,
    required double longitude,
  }) async {
    await supabase.from('rider_locations').upsert({
      'order_id': orderId,
      'rider_id': riderId,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'order_id');
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    return await supabase.from('profiles').select().eq('id', userId).maybeSingle();
  }
}
