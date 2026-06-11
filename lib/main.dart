import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/auth_service_mock.dart';
import 'presentation/auth/screens/welcome_screen.dart';
import 'presentation/member_dashboard/screens/member_dashboard_screen.dart';
import 'presentation/advisor_dashboard/screens/advisor_dashboard_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// import 'data/datasources/firebase_seeder.dart';  // Uncomment this line to seed Firebase with initial data ONLY

final firebaseInitializedProvider = Provider<bool>((ref) => throw UnimplementedError());

class BypassNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void bypass() => state = true;
}
final bypassErrorProvider = NotifierProvider<BypassNotifier, bool>(BypassNotifier.new);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  String? errorMessage;

  try {
    // Attempting to initialize Firebase with the provided options.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    errorMessage = e.toString();
  }

  runApp(ProviderScope(
    overrides: [
      firebaseInitializedProvider.overrideWithValue(firebaseInitialized),
    ],
    child: SmartPostureApp(
      initializationError: errorMessage,
    ),
  ));
}

class SmartPostureApp extends ConsumerWidget {
  final String? initializationError;
  const SmartPostureApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBypassed = ref.watch(bypassErrorProvider);
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Smart Posture Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: authState == null
          ? const WelcomeScreen()
          : (authState.role == 'Advisor'
              ? const AdvisorDashboardScreen()
              : const MemberDashboardScreen()),
    );
  }
}
