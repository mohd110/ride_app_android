import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_client.dart';
import 'data/mock_data.dart';
import 'services/background_service.dart';
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
  final String rawId;
  final String id;
  final String restaurant;
  final String restaurantAddress;
  final String dropoffAddress;
  final DateTime? deliveredAt;
  final double payout;
  final double distanceKm;
  final List<OrderLineItem> items;

  TripData({
    required this.rawId,
    required this.id,
    required this.restaurant,
    required this.restaurantAddress,
    required this.dropoffAddress,
    this.deliveredAt,
    required this.payout,
    required this.distanceKm,
    required this.items,
  });

  factory TripData.fromSupabase(Map<String, dynamic> json) {
    final restaurant = json['restaurants'] as Map<String, dynamic>?;
    final delivery = json['delivery_address'] as Map<String, dynamic>? ?? {};
    final rawId = json['id'] as String;
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

    return TripData(
      rawId: rawId,
      id: '#${rawId.substring(0, 8).toUpperCase()}',
      restaurant: restaurant?['name'] as String? ?? 'Restaurant',
      restaurantAddress: restaurant?['address'] as String? ?? '',
      dropoffAddress: delivery['address'] as String? ?? '',
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      payout: (json['rider_payment'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['delivery_distance_km'] as num?)?.toDouble() ?? 0,
      items: items,
    );
  }

  /// "Today • 14:22" / "Yesterday • 19:30" / "Jun 11 • 18:55" — matches the
  /// format the UI already expects/parses elsewhere.
  String get time {
    final d = deliveredAt?.toLocal();
    if (d == null) return '—';
    final now = DateTime.now();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(d, now)) return 'Today • $hh:$mm';
    if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday • $hh:$mm';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day} • $hh:$mm';
  }

  String get distance => distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : '—';
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState();

  static const _onlinePrefKey = 'rider_is_online';
  static const _deviceIdKey = 'device_id';

  final OrderService _orders = OrderService();
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _sessionChannel;
  List<NotificationItem> _notifications = [];

  bool _isLoggedIn = false;
  bool _isOnline = false;
  bool _isLoading = false;
  bool _isClaiming = false;
  String? _claimingOrderId;
  String? _errorMessage;
  String? _riderId;
  String? _deviceId;
  String? _forcedLogoutMessage;
  int _currentTab = 0;
  OrderState _orderState = OrderState.idle;

  EarningsSummary _earningsSummary = const EarningsSummary();
  List<DailyEarningsPoint> _dailyEarnings = [];
  List<RiderPayout> _payouts = [];
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
  List<TripData> _tripsHistory = [];

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
  String? get forcedLogoutMessage => _forcedLogoutMessage;
  int get currentTab => _currentTab;
  OrderState get orderState => _orderState;

  EarningsSummary get earningsSummary => _earningsSummary;
  double get todayEarnings => _earningsSummary.todayEarnings;
  double get weeklyEarnings => _earningsSummary.weekEarnings;
  double get monthlyEarnings => _earningsSummary.monthEarnings;
  double get lifetimeEarnings => _earningsSummary.lifetimeEarnings;
  int get todayOrders => _earningsSummary.todayOrders;
  int get deliveriesCount => _earningsSummary.totalOrders;
  double get walletBalance => _earningsSummary.walletBalance;
  List<DailyEarningsPoint> get dailyEarnings => _dailyEarnings;
  List<RiderPayout> get payouts => _payouts;
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

    await _initDeviceId();
    _isLoggedIn = true;
    _riderId = session.user.id;

    // Register the background→main message listener before anything else so
    // we don't miss a "refresh_orders" message that arrives while loading.
    FlutterForegroundTask.addTaskDataCallback(_onBackgroundMessage);

    // Register this device as the active session and subscribe to detect if
    // another device supersedes it.
    await _registerSession();
    _subscribeToSessionInvalidation();

    await _loadEarningsData();
    final profileError = await _loadProfile();
    if (profileError != null) {
      _errorMessage = profileError;
    }
    await _fetchPricePerKm();
    await _loadNotifications();
    _subscribeToNotifications();
    await _syncActiveOrder();

    if (hasActiveOrder) {
      // Mid-delivery resume — keep the background service alive regardless of
      // the rider's online preference (they may have backgrounded the app).
      _errorMessage =
          'You have an active delivery in progress. Finish it to see new orders.';
      await startRiderForegroundService();
      await _startPresenceTracking();
    } else {
      // Restore the rider's online/offline choice from before the app closed.
      // Default: true on first install so riders go online automatically.
      final prefs = await SharedPreferences.getInstance();
      final wasOnline = prefs.getBool(_onlinePrefKey) ?? true;
      if (wasOnline) {
        await goOnline();
      } else {
        _orderState = OrderState.idle;
      }
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

      await _initDeviceId();
      _isLoggedIn = true;
      _riderId = user.id;
      _currentTab = 0;
      _orderState = OrderState.idle;
      _forcedLogoutMessage = null; // clear any previous kick message

      FlutterForegroundTask.addTaskDataCallback(_onBackgroundMessage);

      // Register this login — deactivates all other devices immediately.
      await _registerSession();
      _subscribeToSessionInvalidation();

      await _loadEarningsData();
      final profileError = await _loadProfile();
      if (profileError != null) return profileError;

      await _fetchPricePerKm();
      await _loadNotifications();
      _subscribeToNotifications();
      await _syncActiveOrder();
      if (!hasActiveOrder) {
        // Fresh login: always go online (rider opened the app intending to work).
        await goOnline();
      } else {
        await startRiderForegroundService();
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
    FlutterForegroundTask.removeTaskDataCallback(_onBackgroundMessage);
    await stopRiderForegroundService();
    await _sessionChannel?.unsubscribe();
    _sessionChannel = null;
    await _teardownRealtime();
    await _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
    await _stopPresenceTracking(markOffline: true);
    // Clear the online preference so the next login starts fresh.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onlinePrefKey);
    await supabase.auth.signOut();

    _isLoggedIn = false;
    _isOnline = false;
    _riderId = null;
    _deviceId = null;
    _forcedLogoutMessage = null;
    _orderState = OrderState.idle;
    _availableOrders = [];
    _activeOrder = null;
    _rider = MockData.rider;
    _notifications = [];
    _earningsSummary = const EarningsSummary();
    _dailyEarnings = [];
    _tripsHistory = [];
    _payouts = [];
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

    // Persist the preference BEFORE starting work so that if the app is killed
    // mid-startup, the saved state is already "online."
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlinePrefKey, true);

    // Start the Android foreground service so order alerts continue arriving
    // even when the user backgrounds or swipes away the app.
    await startRiderForegroundService();

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
      // Stop the foreground service — rider explicitly chose to go offline.
      await stopRiderForegroundService();
    }
    await _teardownRealtime();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlinePrefKey, false);
    notifyListeners();
  }

  Future<String?> claimOrder(String orderId) async {
    if (_riderId == null || _isClaiming) return 'Not signed in';
    if (_deviceId == null) return 'Device not ready. Please restart the app.';

    // Stop the alert ring as soon as the rider taps Accept.
    await NotificationService.instance.stopAlert();
    _pendingAlertOrders = [];

    _isClaiming = true;
    _claimingOrderId = orderId;
    notifyListeners();

    try {
      final error = await _orders.claimOrder(orderId, _deviceId!);
      if (error != null) {
        if (error == 'session_expired') {
          // Another device logged in and this device's session is no longer
          // valid.  Force-logout immediately.
          await _forceLogout(
            'Your account was signed in on another device. '
            'Please sign in again to continue.',
          );
          return 'Signed out — another device took over this account.';
        }
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
      _batteryLevel = (_batteryLevel - 6).clamp(5, 100);
      notifyListeners();

      // Re-fetch from the database rather than incrementing in-memory —
      // the server-computed rider_payment is the source of truth, and this
      // keeps today/week/month/lifetime and the history list consistent
      // with each other instead of drifting apart.
      await _loadEarningsData();
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
    } else {
      // Delivery finished and rider is offline — no longer need the service.
      await stopRiderForegroundService();
    }
  }

  /// Called by the foreground service's background isolate when it detects a
  /// new order via Realtime or polling. Refreshes the available-orders list so
  /// the UI updates immediately if the app is in the background (but not killed).
  void _onBackgroundMessage(Object data) {
    if (data is Map && data['action'] == 'refresh_orders') {
      _refreshAvailableOrders();
    }
  }

  // ── Device identity ─────────────────────────────────────────────────────────

  /// Loads (or generates and persists) a stable device UUID. The same ID
  /// is used by the foreground service's background isolate (via shared
  /// SharedPreferences) so both isolates always agree on which device this is.
  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = _generateDeviceId();
      await prefs.setString(_deviceIdKey, id);
    }
    _deviceId = id;
  }

  String _generateDeviceId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  // ── Session management ───────────────────────────────────────────────────────

  /// Tells the backend that this device is now the active one. The
  /// SECURITY DEFINER RPC atomically deactivates all other sessions for
  /// this rider — those devices will see the change via Realtime within
  /// ~1 second and auto-logout.
  Future<void> _registerSession() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    try {
      await supabase.rpc('register_rider_session', params: {
        'p_device_id': deviceId,
      });
    } catch (_) {
      // Non-fatal. If the table/RPC doesn't exist yet (migration not run),
      // everything still works — single-session enforcement is just inactive.
    }
  }

  /// Watches the rider_sessions table for this rider. If OUR device row
  /// is flipped to is_active=false it means a different phone just logged in
  /// — force-logout this device immediately.
  void _subscribeToSessionInvalidation() {
    final riderId = _riderId;
    final deviceId = _deviceId;
    if (riderId == null || deviceId == null) return;

    _sessionChannel?.unsubscribe();
    _sessionChannel = supabase
        .channel('session-watch-$riderId-$deviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rider_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: riderId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final rowDeviceId = row['device_id'] as String?;
            final isActive = row['is_active'] as bool? ?? true;
            if (rowDeviceId == deviceId && !isActive) {
              _forceLogout(
                'Your account was signed in on another device. '
                'Please sign in again to continue.',
              );
            }
          },
        )
        .subscribe();
  }

  /// Immediately stops all activity on this device and returns the user to
  /// the login screen with [message] displayed. Called when another device
  /// takes over this rider's session.
  Future<void> _forceLogout(String message) async {
    if (!_isLoggedIn) return;

    _forcedLogoutMessage = message;

    FlutterForegroundTask.removeTaskDataCallback(_onBackgroundMessage);
    await stopRiderForegroundService();
    await _sessionChannel?.unsubscribe();
    _sessionChannel = null;
    await _teardownRealtime();
    await _notificationsChannel?.unsubscribe();
    _notificationsChannel = null;
    // Don't mark offline — the new active device is now the presence owner.
    await _stopPresenceTracking(markOffline: false);

    // Sign out locally only (scope: local) so we don't invalidate the new
    // device's JWT — Supabase JWTs are stateless; local signout just removes
    // this device's stored refresh token.
    try {
      await supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}

    _isLoggedIn = false;
    _isOnline = false;
    _riderId = null;
    _deviceId = null;
    _orderState = OrderState.idle;
    _availableOrders = [];
    _activeOrder = null;
    _rider = MockData.rider;
    _notifications = [];
    _earningsSummary = const EarningsSummary();
    _dailyEarnings = [];
    _tripsHistory = [];
    _payouts = [];
    notifyListeners();
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
      completedTasks: _earningsSummary.totalOrders,
      totalEarnings: _earningsSummary.lifetimeEarnings,
      activeHours: '—',
      deviceId: '—',
      avatarUrl: profile['avatar_url'] as String?,
    );
    return null;
  }

  /// Loads everything the earnings/history/wallet screens show, straight
  /// from the database — today/week/month/lifetime totals, the daily
  /// series for the chart, full delivered-order history, and payout
  /// records. Called on login/init and again after every completed
  /// delivery, instead of incrementing in-memory counters that used to
  /// reset to hardcoded numbers on every login.
  Future<void> _loadEarningsData() async {
    final riderId = _riderId;
    if (riderId == null) return;

    final results = await Future.wait([
      _orders.fetchEarningsSummary(),
      _orders.fetchDailyEarnings(),
      _orders.fetchOrderHistory(riderId),
      _orders.fetchPayouts(riderId),
    ]);

    _earningsSummary = results[0] as EarningsSummary;
    _dailyEarnings = results[1] as List<DailyEarningsPoint>;
    _tripsHistory = (results[2] as List<Map<String, dynamic>>)
        .map((row) => TripData.fromSupabase(row))
        .toList();
    _payouts = results[3] as List<RiderPayout>;
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
