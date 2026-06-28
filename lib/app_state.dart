import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_client.dart';
import 'data/mock_data.dart';
import 'services/notification_service.dart';
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
  RealtimeChannel? _notificationsChannel;
  List<NotificationItem> _notifications = [];

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
  Timer? _presenceTimer;
  String _navInstruction = 'Head to pickup location';
  String _navDistanceText = '';
  String _navDurationText = '';
  double? _riderLat;
  double? _riderLng;
  double? _distanceToRestaurantKm;
  double? _distanceToCustomerKm;
  String? _locationError;
  double _pricePerKm = 10.0;
  double _lastPayout = 0.0;

  List<Map<String, String>> _checklistItems = [];
  List<bool> _verifiedItems = [];
  bool _hasPhotoProof = false;
  String? _deliveryProofUrl;
  bool _isUploadingPhoto = false;
  String _recipientName = '';
  final List<TripData> _tripsHistory = List.from(MockData.allTrips);

  List<AvailableOrderSummary> _availableOrders = [];
  Set<String> _knownOrderIds = {};
  bool _hasInitialOrdersSnapshot = false;
  int _newOrderPulse = 0;
  List<AvailableOrderSummary> _pendingAlertOrders = [];
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
  double? get riderLat => _riderLat;
  double? get riderLng => _riderLng;
  double? get distanceToRestaurantKm => _distanceToRestaurantKm;
  double? get distanceToCustomerKm => _distanceToCustomerKm;
  String? get locationError => _locationError;
  double get pricePerKm => _pricePerKm;
  double get lastPayout => _lastPayout;
  List<bool> get verifiedItems => _verifiedItems;
  List<Map<String, String>> get checklistItems => _checklistItems;
  bool get hasPhotoProof => _hasPhotoProof;
  String? get deliveryProofUrl => _deliveryProofUrl;
  bool get isUploadingPhoto => _isUploadingPhoto;
  String get recipientName => _recipientName;
  List<TripData> get tripsHistory => _tripsHistory;
  List<AvailableOrderSummary> get availableOrders => _availableOrders;
  int get newOrderPulse => _newOrderPulse;
  List<AvailableOrderSummary> get pendingAlertOrders => _pendingAlertOrders;
  bool get hasActiveOrder => _activeOrder != null;

  List<NotificationItem> get notifications => _notifications;
  int get unreadNotifications => _notifications.where((n) => !n.isRead).length;

  ActiveOrderData get activeOrder => _activeOrder ?? MockData.activeOrder;
  RiderProfile get rider => _rider;
  // An order with zero items (e.g. missing order_items rows) has nothing to
  // check off — every([]) is vacuously true, which is correct here. The old
  // isNotEmpty guard meant a zero-item order could never pass verification,
  // permanently blocking "Start Delivery".
  bool get isAllItemsVerified => _verifiedItems.every((item) => item);

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
    await _fetchPricePerKm();
    await _loadNotifications();
    _subscribeToNotifications();
    await _syncActiveOrder();
    if (!hasActiveOrder) {
      await goOnline();
    } else {
      _errorMessage =
          'You have an active delivery in progress. Finish it to see new orders.';
      await _startPresenceTracking();
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

      await _fetchPricePerKm();
      await _loadNotifications();
      _subscribeToNotifications();
      await _syncActiveOrder();
      if (!hasActiveOrder) {
        await goOnline();
      } else {
        await _startPresenceTracking();
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
    await _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
    await _stopPresenceTracking(markOffline: true);
    await supabase.auth.signOut();

    _isLoggedIn = false;
    _isOnline = false;
    _riderId = null;
    _orderState = OrderState.idle;
    _availableOrders = [];
    _activeOrder = null;
    _rider = MockData.rider;
    _notifications = [];
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

    await _fetchPricePerKm();
    await _refreshAvailableOrders();
    _subscribeToOrders();
    await _startPresenceTracking();
  }

  Future<void> goOffline() async {
    _isOnline = false;
    if (!hasActiveOrder) {
      _orderState = OrderState.idle;
      await _stopPresenceTracking(markOffline: true);
    }
    await _teardownRealtime();
    notifyListeners();
  }

  Future<String?> claimOrder(String orderId) async {
    if (_riderId == null || _isClaiming) return 'Not signed in';

    // Stop the alert ring as soon as the rider taps Accept.
    await NotificationService.instance.stopAlert();
    _pendingAlertOrders = [];

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
        restaurantLat: order.restaurantLat,
        restaurantLng: order.restaurantLng,
        customerName: order.customerName,
        customerAddress: order.customerAddress,
        customerPhone: order.customerPhone,
        customerLat: order.customerLat,
        customerLng: order.customerLng,
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
      return null;
    } catch (e) {
      return 'Could not start delivery. Please try again.';
    }
  }

  void arrivedAtCustomer() {
    _orderState = OrderState.confirmDelivery;
    _hasPhotoProof = false;
    _deliveryProofUrl = null;
    _recipientName = _activeOrder?.customerName ?? '';
    notifyListeners();
  }

  /// Opens the camera or gallery, uploads the photo to Supabase Storage,
  /// and links it to the active order. Returns an error message on
  /// failure, or null on success.
  Future<String?> uploadPhotoProof(ImageSource source) async {
    final order = _activeOrder;
    if (order == null) return 'No active order';

    _isUploadingPhoto = true;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1280);
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      final url = await _orders.uploadDeliveryProof(order.rawId, bytes);

      _deliveryProofUrl = url;
      _hasPhotoProof = true;
      return null;
    } catch (e) {
      return 'Could not upload photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
  }

  void setRecipientName(String name) {
    _recipientName = name;
    notifyListeners();
  }

  Future<String?> completeDelivery() async {
    final order = _activeOrder;
    if (order == null) return 'No active order';

    try {
      final actualPayment = await _orders.markDelivered(order.rawId);
      _distanceToRestaurantKm = null;
      _distanceToCustomerKm = null;
      _orderState = OrderState.completed;

      // Prefer the authoritative server-computed figure; the order's own
      // estimate is only a fallback if it genuinely couldn't be computed
      // (e.g. missing coordinates).
      final payout = actualPayment ?? order.guaranteedEarnings;
      _lastPayout = payout;
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
      avatarUrl: profile['avatar_url'] as String?,
    );
    return null;
  }

  /// Opens the camera or gallery, uploads the photo to Supabase Storage,
  /// and updates the rider's profile immediately (and persists past
  /// refresh, since it's read back from profiles.avatar_url on next load).
  Future<String?> uploadProfilePhoto(ImageSource source) async {
    final riderId = _riderId;
    if (riderId == null) return 'Not signed in';

    _isUploadingPhoto = true;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      final url = await _orders.uploadRiderProfilePhoto(riderId, bytes);

      _rider = RiderProfile(
        id: _rider.id,
        displayName: _rider.displayName,
        fleetId: _rider.fleetId,
        memberSince: _rider.memberSince,
        rating: _rider.rating,
        completedTasks: _rider.completedTasks,
        totalEarnings: _rider.totalEarnings,
        activeHours: _rider.activeHours,
        deviceId: _rider.deviceId,
        avatarUrl: url,
      );
      return null;
    } catch (e) {
      return 'Could not upload photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
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
    _activeOrder = await _orders.fetchActiveOrder(_riderId!, pricePerKm: _pricePerKm);
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
      _knownOrderIds = {};
      _hasInitialOrdersSnapshot = false;
      notifyListeners();
      return;
    }

    try {
      final fetched = await _orders.fetchAvailableOrders(pricePerKm: _pricePerKm);

      if (_hasInitialOrdersSnapshot) {
        final newOnes = fetched.where((o) => !_knownOrderIds.contains(o.id)).toList();
        if (newOnes.isNotEmpty) {
          _newOrderPulse++;
          _pendingAlertOrders = newOnes;
          NotificationService.instance.showNewOrders(newOnes);
        }
      } else {
        _hasInitialOrdersSnapshot = true;
      }

      _availableOrders = fetched;
      _knownOrderIds = fetched.map((o) => o.id).toSet();
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

  /// Called by the alert overlay when the rider taps Dismiss.
  Future<void> dismissAlert() async {
    await NotificationService.instance.stopAlert();
    _pendingAlertOrders = [];
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

  Future<void> _loadNotifications() async {
    final riderId = _riderId;
    if (riderId == null) return;
    try {
      final rows = await _orders.fetchNotifications(riderId);
      _notifications = rows.map((row) => NotificationItem.fromSupabase(row)).toList();
    } catch (_) {
      // Leave whatever was already loaded rather than wiping it on a
      // transient fetch failure.
    }
  }

  /// Live updates the badge/list the instant a new notification is
  /// inserted (e.g. a new order is assigned), independent of whichever
  /// screen is currently open.
  void _subscribeToNotifications() {
    final riderId = _riderId;
    if (riderId == null) return;

    _notificationsChannel?.unsubscribe();
    _notificationsChannel = supabase
        .channel('rider-notifications-$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rider_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: riderId,
          ),
          callback: (_) async {
            await _loadNotifications();
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> markNotificationRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;

    _notifications[index].isRead = true;
    notifyListeners();
    try {
      await _orders.markNotificationRead(id);
    } catch (_) {
      // The badge will self-correct on the next load/realtime event.
    }
  }

  Future<void> markAllNotificationsRead() async {
    final riderId = _riderId;
    if (riderId == null) return;

    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    try {
      await _orders.markAllNotificationsRead(riderId);
    } catch (_) {
      // Self-corrects on next load/realtime event.
    }
  }

  Future<void> _fetchPricePerKm() async {
    _pricePerKm = await _orders.fetchPricePerKm();
  }

  /// Runs continuously for as long as the rider is online OR mid-delivery —
  /// not just during the "navigate to customer" leg. This is what lets the
  /// rider show up as a live dot for the admin dashboard while idle/browsing,
  /// and what lets a restaurant see the rider approaching for pickup, not
  /// just after pickup.
  Future<void> _startPresenceTracking() async {
    final riderId = _riderId;
    if (riderId == null) return;

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) {
      _locationError =
          'Location permission denied. Your live location and distance-based '
          'earnings won\'t update until location access is allowed.';
      notifyListeners();
      return;
    }

    _presenceTimer?.cancel();
    await _pushPresence(riderId);

    _presenceTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isOnline && !hasActiveOrder) {
        _stopPresenceTracking(markOffline: false);
        return;
      }
      await _pushPresence(riderId);
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _pushPresence(String riderId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final order = _activeOrder;
      final status = order != null ? 'delivering' : (_isOnline ? 'online' : 'idle');

      await _orders.upsertLocation(
        riderId: riderId,
        orderId: order?.rawId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        status: status,
      );

      _riderLat = pos.latitude;
      _riderLng = pos.longitude;
      _locationError = null;
      _updateLiveDistances(pos.latitude, pos.longitude);

      if (_orderState == OrderState.navToRestaurant || _orderState == OrderState.navToCustomer) {
        _gpsProgress = (_gpsProgress + 0.05).clamp(0.0, 1.0);
        _navDistanceText = 'GPS active';
        _navDurationText = 'Live tracking';
      }
    } catch (e) {
      // Surfaced to the UI rather than swallowed — a silent failure here
      // looks identical to "rider's GPS isn't working" from the outside,
      // which was the actual root cause of the original bug report.
      _locationError = 'Could not read GPS position. Check that location '
          'services are turned on and permission is granted.';
    }
    notifyListeners();
  }

  void _updateLiveDistances(double lat, double lng) {
    final order = _activeOrder;
    if (order == null) {
      _distanceToRestaurantKm = null;
      _distanceToCustomerKm = null;
      return;
    }

    _distanceToRestaurantKm = (order.restaurantLat != null && order.restaurantLng != null)
        ? Geolocator.distanceBetween(lat, lng, order.restaurantLat!, order.restaurantLng!) / 1000.0
        : null;

    _distanceToCustomerKm = (order.customerLat != null && order.customerLng != null)
        ? Geolocator.distanceBetween(lat, lng, order.customerLat!, order.customerLng!) / 1000.0
        : null;
  }

  Future<void> _stopPresenceTracking({required bool markOffline}) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;

    final riderId = _riderId;
    if (markOffline && riderId != null && _riderLat != null && _riderLng != null) {
      try {
        await _orders.upsertLocation(
          riderId: riderId,
          orderId: null,
          latitude: _riderLat!,
          longitude: _riderLng!,
          status: 'offline',
        );
      } catch (_) {
        // Best-effort — nothing actionable if this fails on the way out.
      }
    }
  }
}
