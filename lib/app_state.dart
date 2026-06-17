import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_client.dart';
import 'data/mock_data.dart';
import 'services/order_service.dart';

enum OrderState {
  idle,
  searching,
  navToRestaurant,
  verifyItems,
  navToCustomer,
  confirmDelivery,
  completed,
}

class TripData {
  final String id;
  final String restaurant;
  final String time;
  final double payout;
  final double tip;
  final String distance;
  final String duration;

  TripData({
    required this.id,
    required this.restaurant,
    required this.time,
    required this.payout,
    required this.tip,
    required this.distance,
    required this.duration,
  });
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState();

  final OrderService _orders = OrderService();
  RealtimeChannel? _ordersChannel;

  bool _isLoggedIn = false;
  bool _isOnline = false;
  bool _isLoading = false;
  bool _isClaiming = false;
  String? _claimingOrderId;
  String? _errorMessage;
  String? _riderId;
  int _currentTab = 0;
  OrderState _orderState = OrderState.idle;

  double _weeklyEarnings = 1248.50;
  double _todayEarnings = 142.50;
  double _deliveryFees = 98.00;
  double _tips = 34.50;
  double _incentives = 10.00;
  int _deliveriesCount = 18;
  double _onlineHours = 38.5;
  int _batteryLevel = 82;

  double _gpsProgress = 0.0;
  Timer? _gpsTimer;
  String _navInstruction = 'Head to pickup location';
  String _navDistanceText = '';
  String _navDurationText = '';

  List<Map<String, String>> _checklistItems = [];
  List<bool> _verifiedItems = [];
  bool _hasPhotoProof = false;
  String _recipientName = '';
  final List<TripData> _tripsHistory = List.from(MockData.allTrips);

  List<AvailableOrderSummary> _availableOrders = [];
  ActiveOrderData? _activeOrder;
  RiderProfile _rider = MockData.rider;

  bool get isLoggedIn => _isLoggedIn;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  bool get isClaiming => _isClaiming;
  String? get claimingOrderId => _claimingOrderId;
  String? get errorMessage => _errorMessage;
  String? get riderId => _riderId;
  int get currentTab => _currentTab;
  OrderState get orderState => _orderState;

  double get weeklyEarnings => _weeklyEarnings;
  double get todayEarnings => _todayEarnings;
  double get deliveryFees => _deliveryFees;
  double get tips => _tips;
  double get incentives => _incentives;
  int get deliveriesCount => _deliveriesCount;
  double get onlineHours => _onlineHours;
  int get batteryLevel => _batteryLevel;
  double get gpsProgress => _gpsProgress;
  String get navInstruction => _navInstruction;
  String get navDistanceText => _navDistanceText;
  String get navDurationText => _navDurationText;
  List<bool> get verifiedItems => _verifiedItems;
  List<Map<String, String>> get checklistItems => _checklistItems;
  bool get hasPhotoProof => _hasPhotoProof;
  String get recipientName => _recipientName;
  List<TripData> get tripsHistory => _tripsHistory;
  List<AvailableOrderSummary> get availableOrders => _availableOrders;
  bool get hasActiveOrder => _activeOrder != null;

  int get unreadNotifications => MockData.notifications.where((n) => !n.isRead).length;

  ActiveOrderData get activeOrder => _activeOrder ?? MockData.activeOrder;
  RiderProfile get rider => _rider;
  bool get isAllItemsVerified =>
      _verifiedItems.isNotEmpty && _verifiedItems.every((item) => item);

  bool isClaimingOrder(String orderId) => _isClaiming && _claimingOrderId == orderId;

  Future<void> initialize() async {
    final session = supabase.auth.currentSession;
    if (session == null) return;

    _isLoggedIn = true;
    _riderId = session.user.id;
    final profileError = await _loadProfile();
    if (profileError != null) {
      _errorMessage = profileError;
    }
    await _syncActiveOrder();
    if (!hasActiveOrder) {
      await goOnline();
    } else {
      _errorMessage =
          'You have an active delivery in progress. Finish it to see new orders.';
    }
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return 'Login failed. Please try again.';
      }

      _isLoggedIn = true;
      _riderId = user.id;
      _currentTab = 0;
      _orderState = OrderState.idle;

      final profileError = await _loadProfile();
      if (profileError != null) return profileError;

      await _syncActiveOrder();
      if (!hasActiveOrder) {
        await goOnline();
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not sign in. Check your connection.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _teardownRealtime();
    _gpsTimer?.cancel();
    await supabase.auth.signOut();

    _isLoggedIn = false;
    _isOnline = false;
    _riderId = null;
    _orderState = OrderState.idle;
    _availableOrders = [];
    _activeOrder = null;
    _rider = MockData.rider;
    notifyListeners();
  }

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  Future<void> goOnline() async {
    if (_riderId == null) return;

    _isOnline = true;
    if (!hasActiveOrder) {
      _orderState = OrderState.searching;
      _errorMessage = null;
    }
    notifyListeners();

    await _refreshAvailableOrders();
    _subscribeToOrders();
  }

  Future<void> goOffline() async {
    _isOnline = false;
    if (!hasActiveOrder) {
      _orderState = OrderState.idle;
    }
    await _teardownRealtime();
    notifyListeners();
  }

  Future<String?> claimOrder(String orderId) async {
    if (_riderId == null || _isClaiming) return 'Not signed in';

    _isClaiming = true;
    _claimingOrderId = orderId;
    notifyListeners();

    try {
      final error = await _orders.claimOrder(orderId, _riderId!);
      if (error != null) {
        await _refreshAvailableOrders();
        return error;
      }

      await _loadActiveOrder();
      if (_activeOrder == null) {
        return 'Order claimed but could not load details';
      }

      _orderState = OrderState.navToRestaurant;
      _gpsProgress = 0.0;
      _navInstruction = 'Head to ${_activeOrder!.restaurant}';
      _setupChecklistFromActiveOrder();
      await _refreshAvailableOrders();
      return null;
    } catch (e) {
      return 'Could not claim order. Please try again.';
    } finally {
      _isClaiming = false;
      _claimingOrderId = null;
      notifyListeners();
    }
  }

  void arrivedAtRestaurant() {
    _gpsTimer?.cancel();
    _orderState = OrderState.verifyItems;
    for (int i = 0; i < _verifiedItems.length; i++) {
      _verifiedItems[i] = false;
    }
    notifyListeners();
  }

  void toggleItemVerification(int index) {
    if (index >= 0 && index < _verifiedItems.length) {
      _verifiedItems[index] = !_verifiedItems[index];
      notifyListeners();
    }
  }

  Future<String?> startDelivery() async {
    final order = _activeOrder;
    if (order == null) return 'No active order';

    try {
      await _orders.markOutForDelivery(order.rawId);
      _activeOrder = ActiveOrderData(
        rawId: order.rawId,
        id: order.id,
        status: 'out_for_delivery',
        restaurant: order.restaurant,
        restaurantAddress: order.restaurantAddress,
        restaurantPhone: order.restaurantPhone,
        customerName: order.customerName,
        customerAddress: order.customerAddress,
        customerPhone: order.customerPhone,
        pickupInstruction: order.pickupInstruction,
        deliveryNote: order.deliveryNote,
        guaranteedEarnings: order.guaranteedEarnings,
        peakPay: order.peakPay,
        distance: order.distance,
        eta: order.eta,
        items: order.items,
      );

      _orderState = OrderState.navToCustomer;
      _gpsProgress = 0.0;
      _navInstruction = 'Deliver to ${order.customerName}';
      notifyListeners();
      await _startLocationTracking();
      return null;
    } catch (e) {
      return 'Could not start delivery. Please try again.';
    }
  }

  void arrivedAtCustomer() {
    _stopLocationTracking();
    _orderState = OrderState.confirmDelivery;
    _hasPhotoProof = false;
    _recipientName = _activeOrder?.customerName ?? '';
    notifyListeners();
  }

  void uploadPhotoProof() {
    _hasPhotoProof = true;
    notifyListeners();
  }

  void setRecipientName(String name) {
    _recipientName = name;
    notifyListeners();
  }

  Future<String?> completeDelivery() async {
    final order = _activeOrder;
    if (order == null) return 'No active order';

    try {
      await _orders.markDelivered(order.rawId);
      _stopLocationTracking();
      _orderState = OrderState.completed;

      final payout = order.guaranteedEarnings;
      _weeklyEarnings += payout;
      _todayEarnings += payout;
      _deliveriesCount += 1;
      _deliveryFees += payout;
      _batteryLevel = (_batteryLevel - 6).clamp(5, 100);

      _tripsHistory.insert(
        0,
        TripData(
          id: order.id,
          restaurant: order.restaurant,
          time: 'Just now',
          payout: payout,
          tip: 0,
          distance: order.distance,
          duration: '—',
        ),
      );

      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not mark delivery complete.';
    }
  }

  Future<void> finishSuccessScreen() async {
    _activeOrder = null;
    _orderState = _isOnline ? OrderState.searching : OrderState.idle;
    notifyListeners();

    if (_isOnline) {
      await _refreshAvailableOrders();
    }
  }

  Future<String?> _loadProfile() async {
    if (_riderId == null) return null;

    final profile = await _orders.fetchProfile(_riderId!);
    if (profile == null) {
      return 'Rider profile not found. Ask your manager to set up your account.';
    }
    if (profile['role'] != 'rider') {
      return 'This account is not a rider. Sign in with a rider account.';
    }

    _rider = RiderProfile(
      id: _riderId!.substring(0, 8),
      displayName: profile['full_name'] as String? ?? 'Rider',
      fleetId: 'RDR',
      memberSince: '—',
      rating: 5.0,
      completedTasks: _deliveriesCount,
      totalEarnings: _weeklyEarnings,
      activeHours: '—',
      deviceId: '—',
    );
    return null;
  }

  Future<void> _syncActiveOrder() async {
    if (_riderId == null) return;

    await _loadActiveOrder();
    if (_activeOrder == null) {
      if (_isOnline) {
        _orderState = OrderState.searching;
      } else {
        _orderState = OrderState.idle;
      }
      return;
    }

    _setupChecklistFromActiveOrder();
    _orderState = _orderStateFromStatus(_activeOrder!.status);

    if (_orderState == OrderState.navToCustomer) {
      await _startLocationTracking();
    }
  }

  OrderState _orderStateFromStatus(String status) {
    switch (status) {
      case 'out_for_delivery':
        return OrderState.navToCustomer;
      case 'delivered':
        return OrderState.completed;
      default:
        return OrderState.navToRestaurant;
    }
  }

  Future<void> _loadActiveOrder() async {
    if (_riderId == null) {
      _activeOrder = null;
      return;
    }
    _activeOrder = await _orders.fetchActiveOrder(_riderId!);
  }

  void _setupChecklistFromActiveOrder() {
    final order = _activeOrder;
    if (order == null) {
      _checklistItems = [];
      _verifiedItems = [];
      return;
    }

    _checklistItems = order.items
        .map((i) => {'name': i.name, 'sub': i.subtitle, 'qty': i.qty})
        .toList();
    _verifiedItems = List.filled(order.items.length, false);
  }

  Future<void> _refreshAvailableOrders() async {
    if (_riderId == null || !_isOnline || hasActiveOrder) {
      _availableOrders = [];
      notifyListeners();
      return;
    }

    try {
      _availableOrders = await _orders.fetchAvailableOrders();
      if (_availableOrders.isNotEmpty) {
        _errorMessage = null;
      }
    } on PostgrestException catch (e) {
      _errorMessage = e.message.isNotEmpty
          ? e.message
          : 'Could not load available orders. Check your rider account permissions.';
      _availableOrders = [];
    } catch (e) {
      _errorMessage = 'Could not load available orders';
      _availableOrders = [];
    }
    notifyListeners();
  }

  void _subscribeToOrders() {
    _ordersChannel?.unsubscribe();
    _ordersChannel = supabase
        .channel('available-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _refreshAvailableOrders(),
        )
        .subscribe();
  }

  Future<void> _teardownRealtime() async {
    await _ordersChannel?.unsubscribe();
    _ordersChannel = null;
  }

  Future<void> _startLocationTracking() async {
    final order = _activeOrder;
    final riderId = _riderId;
    if (order == null || riderId == null) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return;
      }
    }

    _gpsTimer?.cancel();
    await _pushLocation(order.rawId, riderId);

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_orderState != OrderState.navToCustomer) {
        _stopLocationTracking();
        return;
      }
      await _pushLocation(order.rawId, riderId);
    });
  }

  Future<void> _pushLocation(String orderId, String riderId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _orders.upsertLocation(
        orderId: orderId,
        riderId: riderId,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      _gpsProgress = (_gpsProgress + 0.05).clamp(0.0, 1.0);
      _navDistanceText = 'GPS active';
      _navDurationText = 'Live tracking';
      notifyListeners();
    } catch (_) {
      // Location may be unavailable on simulator — delivery flow still works.
    }
  }

  void _stopLocationTracking() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }
}
