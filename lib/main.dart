import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // We close the bubble, set the dashboard tab, then bring the Activity
  // to the foreground via the native method channel.
  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event == "open_app") {
      AppState.instance.setTab(0);
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

class RiderConnectApp extends StatelessWidget {
  const RiderConnectApp({Key? key}) : super(key: key);

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
