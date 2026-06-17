import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'app_state.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

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
