import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'app_state.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';

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
