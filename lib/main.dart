import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/auth_service_mock.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/member_dashboard/screens/member_dashboard_screen.dart';
import 'presentation/advisor_dashboard/screens/advisor_dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'data/datasources/firebase_seeder.dart';  // Uncomment this line to seed Firebase with initial data ONLY

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // await FirebaseSeeder.seedAll(); // Uncomment this line to seed Firebase with initial data ONLY
  runApp(const ProviderScope(child: SmartPostureApp()));
}

class SmartPostureApp extends ConsumerWidget {
  const SmartPostureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    Widget homeWidget;
    if (authState == null) {
      homeWidget = const LoginScreen();
    } else if (authState.role == 'Advisor') {
      homeWidget = const AdvisorDashboardScreen();
    } else {
      homeWidget = const MemberDashboardScreen();
    }

    return MaterialApp(
      title: 'Smart Posture Monitoring System',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: homeWidget,
    );
  }
}
