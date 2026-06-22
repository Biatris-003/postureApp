import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/exercise_constants.dart';
import '../../../providers/exercise_progress_provider.dart';
import '../../../providers/exercise_done_provider.dart';

class ExerciseCoachScreen extends ConsumerStatefulWidget {
  final String exerciseTitle;
  final bool trackReps;
  final bool markDoneOnFinish; // true = mark done in exerciseDoneProvider
  final bool isWeeklyAssessment; // true = mark done in weekly done provider

  const ExerciseCoachScreen({
    super.key,
    required this.exerciseTitle,
    this.trackReps = false,
    this.markDoneOnFinish = false,
    this.isWeeklyAssessment = false,
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
  int _completedReps = 0;

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

    controller.addJavaScriptChannel(
      'RepCounter',
      onMessageReceived: (JavaScriptMessage message) {
        final int reps = int.tryParse(message.message) ?? 0;
        if (mounted) {
          setState(() => _completedReps = reps);
        }
      },
    );

    _controller = controller;
  }

  Future<void> _autoStartExercise() async {
    setState(() => _webViewReady = true);
    final id = _coachId;
    if (id == null) return;
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

  Future<void> _stopCamera() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          if (typeof camera !== 'undefined' && camera) {
            try { camera.stop(); } catch(e) {}
            camera = null;
          }
          if (window._activeStream) {
            window._activeStream.getTracks().forEach(function(track) {
              track.stop();
            });
            window._activeStream = null;
          }
          var video = document.getElementById('video');
          if (video && video.srcObject) {
            video.srcObject.getTracks().forEach(function(track) {
              track.stop();
            });
            video.srcObject = null;
          }
        })();
      ''');
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
  }

Future<void> _backWithoutSaving() async {
  await _stopCamera();
  if (mounted) {
    Navigator.of(context).pop(); // close coach only, no marking done
  }
}

  Future<void> _saveAndPop() async {
    await _stopCamera();

    // Save rep progress (weekly assessment only)
    if (widget.trackReps && _completedReps > 0 && _coachId != null) {
      final notifier = ref.read(exerciseProgressNotifierProvider.notifier);
      await notifier.saveProgress(_coachId!, _completedReps);
    }

    // Mark exercise as done in the correct provider
    if (widget.markDoneOnFinish) {
      if (widget.isWeeklyAssessment) {
        await ref
            .read(weeklyExerciseDoneProvider.notifier)
            .markDone(widget.exerciseTitle);
      } else {
        await ref
            .read(exerciseDoneProvider.notifier)
            .markDone(widget.exerciseTitle);
      }
    }

    // Pop twice: close coach, then close exercise detail
    if (mounted) {
      Navigator.of(context)
        ..pop() // close coach screen
        ..pop(); // close exercise detail screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
  onWillPop: () async {
    await _backWithoutSaving();
    return false;
  },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
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
                        style: TextStyle(
                            color: Colors.white54, fontSize: 15, height: 1.6),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_permissionGranted) {
      return SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Expanded(
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Stack(
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
                            style:
                                TextStyle(color: Colors.white60, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Make sure you are connected to the internet.',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
  return Container(
    height: 56,
    color: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _backWithoutSaving,
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Colors.white70),
          label: const Text('Back',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        TextButton(
          onPressed: _saveAndPop,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF10b981),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}