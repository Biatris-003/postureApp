import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/screens/welcome_screen.dart';
import 'providers/user_settings_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final firebaseInitializedProvider = Provider<bool>((ref) => throw UnimplementedError());

class BypassNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void bypass() => state = true;
}
final bypassErrorProvider = NotifierProvider<BypassNotifier, bool>(BypassNotifier.new);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    print('✅ .env loaded successfully');
    print('🔑 Pinecone key exists: ${dotenv.env['PINECONE_API_KEY'] != null}');
    print('🔑 Groq key exists: ${dotenv.env['GROQ_API_KEY'] != null}');
    print('🔑 Host exists: ${dotenv.env['PINECONE_INDEX_HOST'] != null}');
  } catch (e) {
    print('❌ .env load error: $e');
  }

  bool firebaseInitialized = false;
  String? errorMessage;

  try {
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
    final settingsAsync = ref.watch(userSettingsProvider);
    final darkMode = settingsAsync.when(
      data: (s) => s.darkModeOverride,
      loading: () => false,
      error: (err, st) => false,
    );

    return MaterialApp(
      title: 'Smart Posture Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.system,
      // ✅ Always start with WelcomeScreen
      home: const WelcomeScreen(),
    );
  }
}