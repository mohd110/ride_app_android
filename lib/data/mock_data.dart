import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../app_state.dart';

class RiderProfile {
  final String id;
  final String displayName;
  final String fleetId;
  final String memberSince;
  final double rating;
  final int completedTasks;
  final double totalEarnings;
  final String activeHours;
  final String deviceId;
  final String? avatarUrl;

  const RiderProfile({
    required this.id,
    required this.displayName,
    required this.fleetId,
    required this.memberSince,
    required this.rating,
    required this.completedTasks,
    required this.totalEarnings,
    required this.activeHours,
    required this.deviceId,
    this.avatarUrl,
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String time;
  final String type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
  });

  factory NotificationItem.fromSupabase(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      time: createdAt != null ? _relativeTime(createdAt) : '',
      type: json['type'] as String? ?? 'order_assigned',
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

String _relativeTime(DateTime time) {
  // .toUtc() on each side independently before diffing — correct regardless
  // of whether `time` parsed as UTC or local, and of device timezone.
  var diff = DateTime.now().toUtc().difference(time.toUtc());
  if (diff.isNegative) diff = Duration.zero; // guard against clock skew

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${time.day}/${time.month}/${time.year}';
}

class ActiveOrderData {
  final String rawId;
  final String id;
  final String status;
  final String restaurant;
  final String restaurantAddress;
  final String restaurantPhone;
  final double? restaurantLat;
  final double? restaurantLng;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final double? customerLat;
  final double? customerLng;
  final String pickupInstruction;
  final String deliveryNote;
  final double guaranteedEarnings;
  final double peakPay;
  final String distance;
  final String eta;
  final List<OrderLineItem> items;

  const ActiveOrderData({
    required this.rawId,
    required this.id,
    this.status = 'accepted',
    required this.restaurant,
    required this.restaurantAddress,
    required this.restaurantPhone,
    this.restaurantLat,
    this.restaurantLng,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    this.customerLat,
    this.customerLng,
    required this.pickupInstruction,
    required this.deliveryNote,
    required this.guaranteedEarnings,
    required this.peakPay,
    required this.distance,
    required this.eta,
    required this.items,
  });

  factory ActiveOrderData.fromSupabase(Map<String, dynamic> json, {double pricePerKm = 10.0}) {
    final restaurant = json['restaurants'] as Map<String, dynamic>?;
    final delivery = json['delivery_address'] as Map<String, dynamic>? ?? {};
    final rawId = json['id'] as String;
    final deliveryFee = (json['delivery_fee'] as num?)?.toInt() ?? 0;
    final restaurantLat = (restaurant?['latitude'] as num?)?.toDouble();
    final restaurantLng = (restaurant?['longitude'] as num?)?.toDouble();
    final customerLat = (json['delivery_latitude'] as num?)?.toDouble();
    final customerLng = (json['delivery_longitude'] as num?)?.toDouble();

    // Rider pay is restaurant-to-customer distance × the current rate —
    // never the customer's delivery_fee, which is an unrelated number.
    // This is an estimate shown before delivery; the authoritative figure
    // is computed server-side (orders.rider_payment) once marked delivered.
    final storedPayment = (json['rider_payment'] as num?)?.toDouble();
    double estimatedEarnings;
    if (storedPayment != null) {
      estimatedEarnings = storedPayment;
    } else if (restaurantLat != null && restaurantLng != null && customerLat != null && customerLng != null) {
      final distanceKm = Geolocator.distanceBetween(restaurantLat, restaurantLng, customerLat, customerLng) / 1000.0;
      estimatedEarnings = distanceKm * pricePerKm;
    } else {
      // delivery_fee is plain rupees, not paise — no /100 conversion.
      estimatedEarnings = deliveryFee.toDouble();
    }
    final items = (json['order_items'] as List<dynamic>? ?? [])
        .map((item) {
          final row = item as Map<String, dynamic>;
          final product = row['products'] as Map<String, dynamic>?;
          return OrderLineItem(
            name: product?['name'] as String? ?? 'Item',
            subtitle: product?['description'] as String? ?? '',
            qty: '${row['quantity']}×',
          );
        })
        .toList();

    final landmark = delivery['landmark'] as String?;
    final note = landmark != null && landmark.isNotEmpty ? 'Landmark: $landmark' : '';

    return ActiveOrderData(
      rawId: rawId,
      id: '#${rawId.substring(0, 8).toUpperCase()}',
      status: json['status'] as String? ?? 'accepted',
      restaurant: restaurant?['name'] as String? ?? 'Restaurant',
      restaurantAddress: restaurant?['address'] as String? ?? '',
      restaurantPhone: restaurant?['phone'] as String? ?? '',
      restaurantLat: restaurantLat,
      restaurantLng: restaurantLng,
      customerName: delivery['name'] as String? ?? 'Customer',
      customerAddress: delivery['address'] as String? ?? '',
      customerPhone: delivery['phone'] as String? ?? '',
      customerLat: customerLat,
      customerLng: customerLng,
      pickupInstruction: 'Collect the order at the counter and verify the bag is sealed.',
      deliveryNote: note,
      guaranteedEarnings: estimatedEarnings,
      peakPay: 0,
      distance: '—',
      eta: '—',
      items: items,
    );
  }
}

class OrderLineItem {
  final String name;
  final String subtitle;
  final String qty;

  const OrderLineItem({required this.name, required this.subtitle, required this.qty});
}

class PaymentMethod {
  final String bankName;
  final String accountMasked;
  final String payoutSchedule;
  final String lastPayout;
  final double lastPayoutAmount;

  const PaymentMethod({
    required this.bankName,
    required this.accountMasked,
    required this.payoutSchedule,
    required this.lastPayout,
    required this.lastPayoutAmount,
  });
}

class SupportTopic {
  final String title;
  final String description;
  final IconData icon;

  const SupportTopic({required this.title, required this.description, required this.icon});
}

class MockData {
  MockData._();

  static const rider = RiderProfile(
    id: '#4921',
    displayName: 'Rider #4921',
    fleetId: 'A22-01',
    memberSince: 'Jan 2023',
    rating: 4.98,
    completedTasks: 1248,
    totalEarnings: 18450.00,
    activeHours: '498 hrs',
    deviceId: '88-X9-RDR',
  );

  static const vehicle = {
    'model': 'Lectric eBike Pro v2',
    'id': 'VHC-9920-B',
    'type': 'Electric Bicycle',
    'lastServiced': 'Oct 12',
    'rangeKm': 42,
    'temperature': '28°C',
    'chargeCycles': 924,
  };

  static const payment = PaymentMethod(
    bankName: 'Chase Bank',
    accountMasked: '****4921',
    payoutSchedule: 'Every Monday at 00:00 UTC',
    lastPayout: 'Jun 9, 2026',
    lastPayoutAmount: 312.40,
  );

  static const activeOrder = ActiveOrderData(
    rawId: '00000000-0000-0000-0000-000000000001',
    id: '#ORD-99201',
    restaurant: 'Artisan Pizza Co. • Downtown',
    restaurantAddress: '124 Commercial Plaza, Sector 4, High Street Avenue',
    restaurantPhone: '+1 (555) 201-4488',
    customerName: 'Alex Johnson',
    customerAddress: '742 Evergreen Terrace, Block B, West End Heights',
    customerPhone: '+1 (555) 882-3301',
    pickupInstruction: 'Ask for order at counter. Verify bag is sealed before leaving.',
    deliveryNote: 'Ring doorbell once. Leave at door if no answer.',
    guaranteedEarnings: 18.45,
    peakPay: 2.50,
    distance: '4.2 km',
    eta: '12 min',
    items: [
      OrderLineItem(name: 'Margherita Pizza (Large)', subtitle: 'Thin crust • Extra basil', qty: '1×'),
      OrderLineItem(name: 'Garlic Breadsticks', subtitle: 'With marinara dip', qty: '1×'),
      OrderLineItem(name: 'Sparkling Water', subtitle: '500ml chilled', qty: '2×'),
      OrderLineItem(name: 'Tiramisu Cup', subtitle: 'Rider note: Keep upright', qty: '1×'),
    ],
  );

  static const todayStats = {
    'earnings': 142.50,
    'onlineTime': '5h 24m',
    'orders': 12,
    'acceptanceRate': '94%',
    'avgDeliveryMin': 14,
  };

  static List<TripData> allTrips = [
    TripData(id: '#ORD-99201', restaurant: 'Artisan Pizza Co. • Downtown', time: 'Today • 14:22', payout: 18.45, tip: 4.00, distance: '4.2 km', duration: '12 min'),
    TripData(id: '#ORD-99155', restaurant: 'Spice Route Kitchen', time: 'Today • 12:45', payout: 14.50, tip: 3.00, distance: '3.8 km', duration: '11 min'),
    TripData(id: '#ORD-99102', restaurant: 'Baba Biryani - Downtown', time: 'Today • 11:20', payout: 22.80, tip: 5.00, distance: '8.1 km', duration: '18 min'),
    TripData(id: '#ORD-99088', restaurant: 'The Burger Collective', time: 'Today • 10:05', payout: 12.50, tip: 2.50, distance: '2.9 km', duration: '9 min'),
    TripData(id: '#ORD-99041', restaurant: 'Tokyo Ramen House', time: 'Yesterday • 19:30', payout: 16.20, tip: 0.00, distance: '5.1 km', duration: '15 min'),
    TripData(id: '#ORD-99012', restaurant: 'Green Bowl Salads', time: 'Yesterday • 18:15', payout: 9.80, tip: 1.50, distance: '2.2 km', duration: '8 min'),
    TripData(id: '#ORD-98977', restaurant: 'Artisan Pizza Co. • Downtown', time: 'Yesterday • 17:42', payout: 11.20, tip: 2.00, distance: '3.5 km', duration: '10 min'),
    TripData(id: '#ORD-98931', restaurant: 'Gourmet Burger Kitchen', time: 'Yesterday • 16:10', payout: 8.50, tip: 2.00, distance: '3.8 km', duration: '14 min'),
    TripData(id: '#ORD-98888', restaurant: 'Sushi Garden', time: 'Yesterday • 15:22', payout: 6.20, tip: 0.00, distance: '1.7 km', duration: '8 min'),
    TripData(id: '#ORD-98842', restaurant: 'Mediterranean Grill', time: 'Jun 11 • 20:10', payout: 13.40, tip: 3.50, distance: '4.0 km', duration: '13 min'),
    TripData(id: '#ORD-98790', restaurant: 'Curry Leaf Express', time: 'Jun 11 • 18:55', payout: 19.60, tip: 6.00, distance: '6.8 km', duration: '20 min'),
    TripData(id: '#ORD-98721', restaurant: 'Morning Brew Café', time: 'Jun 11 • 09:15', payout: 7.30, tip: 1.00, distance: '1.4 km', duration: '7 min'),
  ];

  static const supportTopics = [
    SupportTopic(
      title: 'Order issues',
      description: 'Problems with pickup, delivery, or customer contact.',
      icon: Icons.delivery_dining_rounded,
    ),
    SupportTopic(
      title: 'Payments & payouts',
      description: 'Earnings, tips, incentives, and bank deposits.',
      icon: Icons.account_balance_wallet_rounded,
    ),
    SupportTopic(
      title: 'Account & profile',
      description: 'Login, vehicle info, and fleet settings.',
      icon: Icons.person_outline_rounded,
    ),
    SupportTopic(
      title: 'Safety & emergencies',
      description: 'Report incidents or get immediate assistance.',
      icon: Icons.shield_outlined,
    ),
  ];

  static const hubManagers = [
    {'name': 'Sarah Mitchell', 'role': 'Downtown Hub Lead', 'phone': '+1 (800) 555-0199', 'hours': 'Mon–Fri 8am–8pm'},
    {'name': 'James Ortiz', 'role': 'Night Shift Coordinator', 'phone': '+1 (800) 555-0288', 'hours': 'Daily 6pm–2am'},
    {'name': 'Fleet Onboarding', 'role': 'New rider registration', 'phone': '+1 (800) 555-0100', 'hours': '24/7'},
  ];

  static const settingsOptions = [
    {'title': 'Push notifications', 'subtitle': 'Orders, payouts, and bonuses', 'enabled': true},
    {'title': 'Navigation app', 'subtitle': 'Google Maps', 'enabled': null},
    {'title': 'Dark mode', 'subtitle': 'Off', 'enabled': false},
    {'title': 'Auto-accept nearby', 'subtitle': 'Within 2 km only', 'enabled': false},
    {'title': 'Sound alerts', 'subtitle': 'New assignment chime', 'enabled': true},
  ];
}
