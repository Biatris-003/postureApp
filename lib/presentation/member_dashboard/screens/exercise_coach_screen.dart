import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Maps exercise titles (lowercase) → coach exercise IDs in exercises.js
const Map<String, String> _exerciseCoachIds = {
  'circumduction': 'circumduction',
  'squatting': 'squat',
  'side bending (right)': 'side_bend_right',
  'sit to stand': 'sit_to_stand',
};

/// Returns the coach ID for a given exercise title, or null if not supported.
String? coachIdForTitle(String title) =>
    _exerciseCoachIds[title.toLowerCase().trim()];

class ExerciseCoachScreen extends StatefulWidget {
  final String exerciseTitle;
  const ExerciseCoachScreen({super.key, required this.exerciseTitle});

  @override
  State<ExerciseCoachScreen> createState() => _ExerciseCoachScreenState();
}

class _ExerciseCoachScreenState extends State<ExerciseCoachScreen> {
  late final WebViewController _controller;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    _requestCameraAndInit();
  }

  String? get _coachId => coachIdForTitle(widget.exerciseTitle);

  Future<void> _requestCameraAndInit() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permissionGranted = true);
      _initWebView();
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  void _initWebView() {
    _controller = WebViewController(
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _autoStartExercise(),
      ))
      ..loadFlutterAsset('assets/exercise-coach/index.html');
  }

  Future<void> _autoStartExercise() async {
    setState(() => _webViewReady = true);
    final id = _coachId;
    if (id == null) return;
    // Short delay to let JS finish initialising
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await _controller.runJavaScript(
      '''
      (function() {
        var ex = EXERCISES.find(function(e) { return e.id === "$id"; });
        if (ex) startExercise(ex);
      })();
      ''',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.exerciseTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ── Permission Denied ──────────────────────────────────────────────────
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 56, color: Colors.white54),
              ),
              const SizedBox(height: 28),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please grant camera access so the AI coach\ncan analyse your exercise form in real-time.',
                style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open App Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10b981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Requesting Permission ──────────────────────────────────────────────
    if (!_permissionGranted) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF10b981)),
            SizedBox(height: 20),
            Text(
              'Requesting camera permission…',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // ── WebView (with loading overlay) ─────────────────────────────────────
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_webViewReady)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10b981)),
                  SizedBox(height: 20),
                  Text(
                    'Loading AI exercise coach…',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Make sure you are connected to the internet.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
