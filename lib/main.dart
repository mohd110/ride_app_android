import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'app_state.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';
import 'widgets/overlay_bubble.dart';

/// Channel registered in MainActivity.kt — used to bring the main Activity
/// to the foreground when the rider taps the floating order bubble.
const _overlayChannel = MethodChannel('rider.overlay/control');

/// Entry point for the floating order-alert bubble.
/// Runs in its own Dart isolate inside the SYSTEM_ALERT_WINDOW overlay.
/// Keep this minimal — no Supabase, no AppState, no heavy state.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayBubble());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads GOOGLE_MAPS_API_KEY (see lib/config/maps_config.dart) from the
  // bundled .env asset. Must happen before anything touches MapsConfig.apiKey
  // — in practice that's only once the rider opens an active-delivery
  // screen, well after this resolves, but load it eagerly here regardless.
  await dotenv.load(fileName: '.env');

  // Must be called before runApp so the ReceivePort used for background→main
  // communication is registered before any isolate can send to it.
  FlutterForegroundTask.initCommunicationPort();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await NotificationService.instance.initialize();
  await AppState.instance.initialize();

  // When the overlay bubble is tapped it sends "open_app" via shareData().
  // We route to the correct tab/screen, close the bubble, then bring the
  // Activity to the foreground via the native method channel.
  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event == "open_app") {
      AppState.instance.handleBubbleTap();
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
      try {
        await _overlayChannel.invokeMethod('bringToFront');
      } catch (_) {
        // If the channel is unavailable the rider still sees the notification.
      }
    }
  });

  runApp(const RiderConnectApp());
}

class RiderConnectApp extends StatefulWidget {
  const RiderConnectApp({Key? key}) : super(key: key);

  @override
  State<RiderConnectApp> createState() => _RiderConnectAppState();
}

class _RiderConnectAppState extends State<RiderConnectApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Covers every way the app can become visible again — launcher,
      // recents, or tapping the bubble — so it never lingers on screen
      // while the app itself is already showing.
      AppState.instance.onAppForegrounded();
    } else if (state == AppLifecycleState.paused) {
      // The rider backgrounded the app (Home, task-switch, another app).
      // Show the bubble if they're online/mid-delivery — it should stay up
      // for the whole backgrounded session, not just when a new order lands.
      AppState.instance.onAppBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rider Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainNavigation(),
    );
  }
}
