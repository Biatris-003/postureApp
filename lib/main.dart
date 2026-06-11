import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/auth_service_mock.dart';
import 'presentation/auth/screens/welcome_screen.dart';
import 'presentation/member_dashboard/screens/member_dashboard_screen.dart';
import 'presentation/advisor_dashboard/screens/advisor_dashboard_screen.dart';
import 'presentation/debug/screens/prediction_debug_screen.dart';
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
      routes: {
        PredictionDebugScreen.routeName: (_) => const PredictionDebugScreen(),
      },
      // home: initializationError != null && !isBypassed
      //     ? Scaffold(
      //         body: Center(
      //           child: Padding(
      //             padding: const EdgeInsets.all(24.0),
      //             child: Column(
      //               mainAxisAlignment: MainAxisAlignment.center,
      //               children: [
      //                 const Icon(Icons.error_outline, color: Colors.red, size: 64),
      //                 const SizedBox(height: 16),
      //                 const Text('Startup Error', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      //                 const SizedBox(height: 8),
      //                 Text(initializationError!),
      //                 const SizedBox(height: 24),
      //                 const Text('The app will continue with mock data if you proceed.', textAlign: TextAlign.center),
      //                 const SizedBox(height: 32),
      //                 ElevatedButton(
      //                   onPressed: () {
      //                     ref.read(bypassErrorProvider.notifier).bypass();
      //                   },
      //                   style: ElevatedButton.styleFrom(
      //                     backgroundColor: const Color(0xFF1565C0),
      //                     foregroundColor: Colors.white,
      //                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      //                   ),
      //                   child: const Text('Continue to App (Mock Mode)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      //                 ),
      //               ],
      //             ),
      //           ),
      //         ),
      //       )
      //     : (authState == null
      //         ? const WelcomeScreen()
      //         : (authState.role == 'Advisor'
      //             ? const AdvisorDashboardScreen()
      //             : const MemberDashboardScreen())),
      home: const PredictionDebugScreen(),
    );
  }
}
