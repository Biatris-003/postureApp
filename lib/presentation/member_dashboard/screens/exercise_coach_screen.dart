import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/exercise_constants.dart';
import '../../../providers/exercise_progress_provider.dart';

/// Maps exercise titles (lowercase) → coach exercise IDs in exercises.js
/// Now uses the global map from exercise_constants.dart

class ExerciseCoachScreen extends ConsumerStatefulWidget {
  final String exerciseTitle;
  final bool trackReps; // NEW: whether to save reps

  const ExerciseCoachScreen({
    super.key,
    required this.exerciseTitle,
    this.trackReps = false,
  });

  @override
  ConsumerState<ExerciseCoachScreen> createState() =>
      _ExerciseCoachScreenState();
}

class _ExerciseCoachScreenState extends ConsumerState<ExerciseCoachScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  bool _webViewReady = false;
  int _completedReps = 0; // NEW: holds the latest rep count from JS

  String? get _coachId => exerciseTitleToCoachId[widget.exerciseTitle];

  @override
  void initState() {
    super.initState();
    _requestCameraAndInit();
  }

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
    var controller = WebViewController(
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _autoStartExercise(),
      ))
      ..loadFlutterAsset('assets/exercise-coach/index.html');

    // ─── Add JavaScript channel only if tracking reps ───
    if (widget.trackReps) {
      controller.addJavaScriptChannel(
        'RepCounter',
        onMessageReceived: (JavaScriptMessage message) {
          final int reps = int.tryParse(message.message) ?? 0;
          if (mounted) {
            setState(() => _completedReps = reps);
          }
        },
      );
    }

    _controller = controller;
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

  // ─── Save reps and pop ──────────────────────────────────────────
  Future<void> _saveAndPop() async {
    if (widget.trackReps && _completedReps > 0 && _coachId != null) {
      final notifier = ref.read(exerciseProgressNotifierProvider.notifier);
      await notifier.saveProgress(_coachId!, _completedReps);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveAndPop();
        return false; // we already popped
      },
      child: Scaffold(
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
          actions: [
            // ─── Finish button only when tracking ───
            if (widget.trackReps)
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded),
                onPressed: _saveAndPop,
                tooltip: 'Finish & save reps',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // ── Permission Denied ──────────────────────────────────────────
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

    // ── Requesting Permission ──────────────────────────────────────
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

    // ── WebView (with loading overlay) ─────────────────────────────
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