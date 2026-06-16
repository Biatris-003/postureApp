import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class RulaAssessmentScreen extends StatefulWidget {
  const RulaAssessmentScreen({Key? key}) : super(key: key);

  @override
  State<RulaAssessmentScreen> createState() => _RulaAssessmentScreenState();
}

class _RulaAssessmentScreenState extends State<RulaAssessmentScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  bool _isProcessing = false;
  RulaResult? _result;

  // Rep tracking
  int _repCount = 0;
  _RepPhase _phase = _RepPhase.instruction;
  DateTime? _phaseStart;

  static const int _holdSeconds = 10;
  static const int _restSeconds = 5;

  // Animation controller for the progress bar
  late AnimationController _timerAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timerAnimController = AnimationController(vsync: this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _cameraController = controller);
    controller.startImageStream(_onCameraImage);
  }

  void _onCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final inputImage = _cameraImageToInputImage(image);
      if (inputImage == null) return;
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) {
        if (mounted) setState(() => _result = null);
        return;
      }
      final angles = RulaAngles.fromPose(poses.first);
      final result = RulaScorer.compute(angles);
      if (mounted) {
        setState(() {
          _result = result;
          _updatePhase(result.finalScore <= 2);
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  void _updatePhase(bool isExcellent) {
    final now = DateTime.now();
    switch (_phase) {
      case _RepPhase.instruction:
        // Stay in instruction until user is in excellent posture
        if (isExcellent) {
          _phase = _RepPhase.holding;
          _phaseStart = now;
          _timerAnimController.duration = Duration(seconds: _holdSeconds);
          _timerAnimController.forward(from: 0);
        }
        break;

      case _RepPhase.holding:
        if (!isExcellent) {
          // Posture broken — go back to instruction/wait
          _phase = _RepPhase.postureLost;
          _phaseStart = now;
          _timerAnimController.stop();
          _timerAnimController.reset();
        } else {
          final elapsed = now.difference(_phaseStart!).inSeconds;
          if (elapsed >= _holdSeconds) {
            _repCount++;
            _phase = _RepPhase.resting;
            _phaseStart = now;
            _timerAnimController.duration = Duration(seconds: _restSeconds);
            _timerAnimController.forward(from: 0);
          }
        }
        break;

      case _RepPhase.postureLost:
        // After 2 seconds of prompt, go back to waiting for excellent
        final elapsed = now.difference(_phaseStart!).inSeconds;
        if (elapsed >= 2) {
          _phase = _RepPhase.instruction;
          _phaseStart = null;
        }
        break;

      case _RepPhase.resting:
        final elapsed = now.difference(_phaseStart!).inSeconds;
        if (elapsed >= _restSeconds) {
          _phase = _RepPhase.instruction;
          _phaseStart = null;
          _timerAnimController.reset();
        }
        break;
    }
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseDetector.close();
    _timerAnimController.dispose();
    super.dispose();
  }

  // ── Colors & helpers ──────────────────────────────────────────────────────

  Color _scoreColor(int score) {
    if (score <= 2) return const Color(0xFF22C55E);
    if (score <= 4) return const Color(0xFF6C63FF);
    if (score <= 6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel(int score) {
    if (score <= 2) return 'Excellent';
    if (score <= 4) return 'Good';
    if (score <= 6) return 'Fair';
    return 'Poor';
  }

  Color _qualityColor(PostureQuality q) {
    switch (q) {
      case PostureQuality.excellent: return const Color(0xFF22C55E);
      case PostureQuality.good:      return const Color(0xFF6C63FF);
      case PostureQuality.fair:      return const Color(0xFFF59E0B);
      case PostureQuality.poor:      return const Color(0xFFEF4444);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    // Camera occupies top ~60% of the screen
    final cameraHeight = screenHeight * 0.60;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Column(
        children: [
          // ── TOP: Camera zone ───────────────────────────────────────────
          SizedBox(
            height: cameraHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraPreview(),
                // Gradient fade at bottom of camera zone
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    height: 60,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0A0A0F)],
                      ),
                    ),
                  ),
                ),
                // Top bar
                _buildTopBar(topPad),
                // Floating overlays on camera: score badge + rep pill
                _buildCameraOverlays(topPad),
              ],
            ),
          ),

          // ── BOTTOM: Adaptive panel ─────────────────────────────────────
          Expanded(
            child: _buildAdaptivePanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }
    return CameraPreview(controller);
  }

  Widget _buildTopBar(double topPad) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, topPad + 8, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            ),
            const SizedBox(width: 4),
            const Text(
              'Posture Assessment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOverlays(double topPad) {
    final result = _result;
    final score = result?.finalScore;
    final scoreColor = score != null ? _scoreColor(score) : Colors.white54;
    final scoreLabel = score != null ? _scoreLabel(score) : '—';

    return Positioned(
      top: topPad + 60,
      left: 16,
      right: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Posture quality badge (top-left) ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scoreColor.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: scoreColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: scoreColor.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  score != null ? '$scoreLabel  •  $score/7' : 'Detecting...',
                  style: TextStyle(
                    color: score != null ? scoreColor : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Rep pill (top-right) ────────────────────────────────────
          _buildRepPill(),
        ],
      ),
    );
  }

  Widget _buildRepPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_repCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'Reps',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Adaptive bottom panel ─────────────────────────────────────────────────

  Widget _buildAdaptivePanel() {
    switch (_phase) {
      case _RepPhase.instruction:
        return _buildInstructionPanel();
      case _RepPhase.holding:
        return _buildHoldingPanel();
      case _RepPhase.postureLost:
        return _buildPostureLostPanel();
      case _RepPhase.resting:
        return _buildRestPanel();
    }
  }

  // ── 1. Instruction panel ──────────────────────────────────────────────────
  Widget _buildInstructionPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Get Ready',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _instructionRow(
            Icons.straighten_rounded,
            'Stand or sit upright',
            'Keep your back straight against the chair / wall',
          ),
          const SizedBox(height: 10),
          _instructionRow(
            Icons.visibility_outlined,
            'Face the camera',
            'Your full upper body should be visible',
          ),
          const SizedBox(height: 10),
          _instructionRow(
            Icons.arrow_downward_rounded,
            'Relax your shoulders',
            'Arms at sides, elbows near 90° if seated at desk',
          ),
          const SizedBox(height: 10),
          _instructionRow(
            Icons.hourglass_top_rounded,
            'Hold for $_holdSeconds seconds',
            'Then rest for $_restSeconds seconds — timer starts automatically',
          ),
          const Spacer(),
          // Status bar waiting for excellent
          _buildWaitingBar(),
        ],
      ),
    );
  }

  Widget _instructionRow(IconData icon, String title, String sub) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingBar() {
    final result = _result;
    final isExcellent = result != null && result.finalScore <= 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isExcellent
            ? const Color(0xFF22C55E).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExcellent
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isExcellent
                ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF22C55E), size: 20, key: ValueKey('ok'))
                : const SizedBox(
                    width: 20,
                    height: 20,
                    key: ValueKey('wait'),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white30,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExcellent
                  ? 'Great posture! Holding for $_holdSeconds seconds…'
                  : 'Waiting for excellent posture to begin…',
              style: TextStyle(
                color: isExcellent ? const Color(0xFF22C55E) : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Holding panel ──────────────────────────────────────────────────────
  Widget _buildHoldingPanel() {
    final elapsed = _phaseStart != null
        ? DateTime.now().difference(_phaseStart!).inSeconds
        : 0;
    final remaining = (_holdSeconds - elapsed).clamp(0, _holdSeconds);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded, color: Color(0xFF22C55E), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Hold Position',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${remaining}s',
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Animated progress bar (right to left drain)
          AnimatedBuilder(
            animation: _timerAnimController,
            builder: (context, _) {
              final progress = 1.0 - _timerAnimController.value;
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(
                        _lerpColor(
                          const Color(0xFF22C55E),
                          const Color(0xFFF59E0B),
                          _timerAnimController.value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${remaining}s remaining',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Joint summary during hold
          if (_result != null) _buildMiniJointSummary(_result!),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF22C55E), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Keep this posture — assessment in progress',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildMiniJointSummary(RulaResult result) {
    final joints = [
      ('Neck',     result.angles.neck,      result.neckQuality),
      ('Trunk',    result.angles.trunk,     result.trunkQuality),
      ('Arm',      result.angles.upperArm,  result.upperArmQuality),
      ('Forearm',  result.angles.forearm,   result.forearmQuality),
      ('Wrist',    result.angles.wrist,     result.wristQuality),
      ('Shoulders',result.angles.shoulders, result.shouldersQuality),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: joints.map((j) {
        final c = _qualityColor(j.$3);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                j.$1,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
              ),
              const SizedBox(width: 4),
              Text(
                '${j.$2.toStringAsFixed(0)}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 3. Posture lost panel ─────────────────────────────────────────────────
  Widget _buildPostureLostPanel() {
    final result = _result;
    final tip = result?.topCoachingTip;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Posture Changed',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Timer paused — fix your posture to continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tip != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded,
                          color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (result != null) _buildMiniJointSummary(result),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30),
                ),
                const SizedBox(width: 10),
                Text(
                  'Return to excellent posture to restart timer',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Rest panel ─────────────────────────────────────────────────────────
  Widget _buildRestPanel() {
    final elapsed = _phaseStart != null
        ? DateTime.now().difference(_phaseStart!).inSeconds
        : 0;
    final remaining = (_restSeconds - elapsed).clamp(0, _restSeconds);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.self_improvement_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Rest',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${remaining}s',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _timerAnimController,
            builder: (context, _) {
              final progress = 1.0 - _timerAnimController.value;
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${remaining}s remaining',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rep $_repCount complete!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Relax — next round starts automatically',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildRepHistory(),
        ],
      ),
    );
  }

  Widget _buildRepHistory() {
    if (_repCount == 0) return const SizedBox.shrink();
    return Row(
      children: [
        Text(
          'Completed: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        ...List.generate(
          _repCount,
          (i) => Container(
            margin: const EdgeInsets.only(right: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  Color _lerpColor(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain models & RULA logic (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

enum PostureQuality {
  excellent,
  good,
  fair,
  poor;

  String get label => switch (this) {
        PostureQuality.excellent => 'Excellent',
        PostureQuality.good      => 'Good',
        PostureQuality.fair      => 'Fair',
        PostureQuality.poor      => 'Poor',
      };
}

enum _RepPhase { instruction, holding, postureLost, resting }

class RulaAngles {
  final double upperArm;
  final double forearm;
  final double wrist;
  final double neck;
  final double trunk;
  final double shoulders;

  const RulaAngles({
    required this.upperArm,
    required this.forearm,
    required this.wrist,
    required this.neck,
    required this.trunk,
    required this.shoulders,
  });

  factory RulaAngles.fromPose(Pose pose) {
    final lm = pose.landmarks;

    double angle3(PoseLandmarkType a, PoseLandmarkType b, PoseLandmarkType c) {
      final la = lm[a], lb = lm[b], lc = lm[c];
      if (la == null || lb == null || lc == null) return 0;
      final v1x = la.x - lb.x, v1y = la.y - lb.y;
      final v2x = lc.x - lb.x, v2y = lc.y - lb.y;
      final dot = v1x * v2x + v1y * v2y;
      final mag = math.sqrt(v1x * v1x + v1y * v1y) *
          math.sqrt(v2x * v2x + v2y * v2y);
      if (mag < 1e-9) return 0;
      return math.acos((dot / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
    }

    double fromVertical(double x1, double y1, double x2, double y2) {
      final dx = x1 - x2;
      final dy = y2 - y1;
      return math.atan2(dx.abs(), dy.abs() + 1e-9) * 180 / math.pi;
    }

    double upperArm = 30.0;
    try {
      final lsh = lm[PoseLandmarkType.leftShoulder];
      final rsh = lm[PoseLandmarkType.rightShoulder];
      final lel = lm[PoseLandmarkType.leftElbow];
      final rel = lm[PoseLandmarkType.rightElbow];
      final lhp = lm[PoseLandmarkType.leftHip];
      final rhp = lm[PoseLandmarkType.rightHip];
      if (lsh != null && rsh != null && lhp != null && rhp != null) {
        final mshx = (lsh.x + rsh.x) / 2, mshy = (lsh.y + rsh.y) / 2;
        final mhpx = (lhp.x + rhp.x) / 2, mhpy = (lhp.y + rhp.y) / 2;
        final el = (lel?.likelihood ?? 0) >= (rel?.likelihood ?? 0) ? lel : rel;
        final sh = (lel?.likelihood ?? 0) >= (rel?.likelihood ?? 0) ? lsh : rsh;
        if (el != null && sh != null) {
          final ax = el.x - sh.x, ay = el.y - sh.y;
          final tx = mhpx - mshx, ty = mhpy - mshy;
          final dot = ax * tx + ay * ty;
          final mag = math.sqrt(ax * ax + ay * ay) * math.sqrt(tx * tx + ty * ty);
          if (mag > 1e-9) {
            upperArm = math.acos((dot / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
          }
        }
      }
    } catch (_) {}

    double forearm = 90.0;
    try {
      final lConf = lm[PoseLandmarkType.leftElbow]?.likelihood ?? 0;
      final rConf = lm[PoseLandmarkType.rightElbow]?.likelihood ?? 0;
      if (lConf >= rConf) {
        forearm = angle3(PoseLandmarkType.leftShoulder,
            PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      } else {
        forearm = angle3(PoseLandmarkType.rightShoulder,
            PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      }
    } catch (_) {}

    double wrist = 10.0;
    try {
      final lConf = lm[PoseLandmarkType.leftWrist]?.likelihood ?? 0;
      final rConf = lm[PoseLandmarkType.rightWrist]?.likelihood ?? 0;
      double raw;
      if (lConf >= rConf) {
        raw = angle3(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist,
            PoseLandmarkType.leftIndex);
      } else {
        raw = angle3(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist,
            PoseLandmarkType.rightIndex);
      }
      wrist = (180 - raw).abs();
    } catch (_) {}

    double neck = 15.0;
    try {
      final lsh = lm[PoseLandmarkType.leftShoulder];
      final rsh = lm[PoseLandmarkType.rightShoulder];
      final lear = lm[PoseLandmarkType.leftEar];
      final rear = lm[PoseLandmarkType.rightEar];
      if (lsh != null && rsh != null) {
        final mshx = (lsh.x + rsh.x) / 2, mshy = (lsh.y + rsh.y) / 2;
        final ear = (lear?.likelihood ?? 0) >= (rear?.likelihood ?? 0) ? lear : rear;
        if (ear != null) {
          neck = fromVertical(ear.x, ear.y, mshx, mshy);
        }
      }
    } catch (_) {}

    double trunk = 5.0;
    try {
      final lsh = lm[PoseLandmarkType.leftShoulder];
      final rsh = lm[PoseLandmarkType.rightShoulder];
      final lhp = lm[PoseLandmarkType.leftHip];
      final rhp = lm[PoseLandmarkType.rightHip];
      if (lsh != null && rsh != null && lhp != null && rhp != null) {
        final mshx = (lsh.x + rsh.x) / 2, mshy = (lsh.y + rsh.y) / 2;
        final mhpx = (lhp.x + rhp.x) / 2, mhpy = (lhp.y + rhp.y) / 2;
        trunk = fromVertical(mshx, mshy, mhpx, mhpy);
      }
    } catch (_) {}

    double shoulders = 0.0;
    try {
      final lsh = lm[PoseLandmarkType.leftShoulder];
      final rsh = lm[PoseLandmarkType.rightShoulder];
      if (lsh != null && rsh != null) {
        final dy = (lsh.y - rsh.y).abs();
        final dx = (lsh.x - rsh.x).abs() + 1e-9;
        shoulders = math.atan(dy / dx) * 180 / math.pi;
      }
    } catch (_) {}

    return RulaAngles(
      upperArm: upperArm,
      forearm: forearm,
      wrist: wrist,
      neck: neck,
      trunk: trunk,
      shoulders: shoulders,
    );
  }
}

class RulaResult {
  final RulaAngles angles;
  final int finalScore;
  final int scoreA;
  final int scoreB;
  final PostureQuality upperArmQuality;
  final PostureQuality forearmQuality;
  final PostureQuality wristQuality;
  final PostureQuality neckQuality;
  final PostureQuality trunkQuality;
  final PostureQuality shouldersQuality;
  final String? topCoachingTip;

  const RulaResult({
    required this.angles,
    required this.finalScore,
    required this.scoreA,
    required this.scoreB,
    required this.upperArmQuality,
    required this.forearmQuality,
    required this.wristQuality,
    required this.neckQuality,
    required this.trunkQuality,
    required this.shouldersQuality,
    this.topCoachingTip,
  });
}

class RulaScorer {
  static const _tableA = <(int, int, int, int), int>{
    (1,1,1,1):1,(1,1,1,2):2,(1,1,2,1):2,(1,1,2,2):2,(1,1,3,1):2,(1,1,3,2):3,
    (1,2,1,1):2,(1,2,1,2):2,(1,2,2,1):2,(1,2,2,2):2,(1,2,3,1):3,(1,2,3,2):3,
    (1,3,1,1):2,(1,3,1,2):3,(1,3,2,1):3,(1,3,2,2):3,(1,3,3,1):3,(1,3,3,2):3,
    (2,1,1,1):2,(2,1,1,2):2,(2,1,2,1):2,(2,1,2,2):3,(2,1,3,1):3,(2,1,3,2):3,
    (2,2,1,1):2,(2,2,1,2):2,(2,2,2,1):3,(2,2,2,2):3,(2,2,3,1):3,(2,2,3,2):4,
    (2,3,1,1):2,(2,3,1,2):3,(2,3,2,1):3,(2,3,2,2):3,(2,3,3,1):4,(2,3,3,2):4,
    (3,1,1,1):2,(3,1,1,2):3,(3,1,2,1):3,(3,1,2,2):3,(3,1,3,1):3,(3,1,3,2):4,
    (3,2,1,1):2,(3,2,1,2):3,(3,2,2,1):3,(3,2,2,2):3,(3,2,3,1):4,(3,2,3,2):4,
    (3,3,1,1):2,(3,3,1,2):3,(3,3,2,1):3,(3,3,2,2):4,(3,3,3,1):4,(3,3,3,2):5,
    (4,1,1,1):3,(4,1,1,2):3,(4,1,2,1):3,(4,1,2,2):4,(4,1,3,1):4,(4,1,3,2):4,
    (4,2,1,1):3,(4,2,1,2):3,(4,2,2,1):3,(4,2,2,2):4,(4,2,3,1):4,(4,2,3,2):5,
    (4,3,1,1):3,(4,3,1,2):4,(4,3,2,1):4,(4,3,2,2):4,(4,3,3,1):4,(4,3,3,2):5,
  };

  static const _tableB = <(int, int, int), int>{
    (1,1,1):1,(1,1,2):3,(1,2,1):2,(1,2,2):3,(1,3,1):3,(1,3,2):4,
    (1,4,1):5,(1,4,2):5,(1,5,1):6,(1,5,2):6,(1,6,1):7,(1,6,2):7,
    (2,1,1):2,(2,1,2):3,(2,2,1):2,(2,2,2):3,(2,3,1):4,(2,3,2):5,
    (2,4,1):5,(2,4,2):5,(2,5,1):6,(2,5,2):7,(2,6,1):7,(2,6,2):7,
    (3,1,1):3,(3,1,2):3,(3,2,1):3,(3,2,2):4,(3,3,1):4,(3,3,2):5,
    (3,4,1):5,(3,4,2):6,(3,5,1):6,(3,5,2):7,(3,6,1):7,(3,6,2):7,
    (4,1,1):5,(4,1,2):5,(4,2,1):5,(4,2,2):6,(4,3,1):6,(4,3,2):7,
    (4,4,1):7,(4,4,2):7,(4,5,1):7,(4,5,2):7,(4,6,1):8,(4,6,2):8,
  };

  static const _tableC = <(int, int), int>{
    (1,1):1,(1,2):2,(1,3):3,(1,4):3,(1,5):4,(1,6):5,(1,7):5,
    (2,1):2,(2,2):2,(2,3):3,(2,4):4,(2,5):4,(2,6):5,(2,7):5,
    (3,1):3,(3,2):3,(3,3):3,(3,4):4,(3,5):4,(3,6):5,(3,7):6,
    (4,1):3,(4,2):3,(4,3):3,(4,4):4,(4,5):5,(4,6):6,(4,7):6,
    (5,1):4,(5,2):4,(5,3):4,(5,4):5,(5,5):6,(5,6):7,(5,7):7,
    (6,1):4,(6,2):4,(6,3):5,(6,4):6,(6,5):6,(6,6):7,(6,7):7,
    (7,1):5,(7,2):5,(7,3):6,(7,4):6,(7,5):7,(7,6):7,(7,7):7,
    (8,1):5,(8,2):5,(8,3):6,(8,4):7,(8,5):7,(8,6):7,(8,7):7,
  };

  static int _upperArmScore(double deg) {
    if (deg <= 20) return 1;
    if (deg <= 45) return 2;
    if (deg <= 90) return 3;
    return 4;
  }

  static int _forearmScore(double deg) => (60 <= deg && deg <= 100) ? 1 : 2;

  static int _wristScore(double dev) {
    if (dev <= 15) return 1;
    if (dev <= 30) return 2;
    return 3;
  }

  static int _neckScore(double deg) {
    if (deg <= 10) return 1;
    if (deg <= 20) return 2;
    if (deg <= 30) return 3;
    return 4;
  }

  static int _trunkScore(double deg) {
    if (deg <= 10) return 1;
    if (deg <= 20) return 2;
    if (deg <= 60) return 3;
    return 4;
  }

  static PostureQuality _quality(double val, double idealLo, double idealHi,
      double warnLo, double warnHi) {
    if (val >= idealLo && val <= idealHi) return PostureQuality.excellent;
    if (val >= warnLo && val <= warnHi) return PostureQuality.good;
    if ((val < warnLo - 15) || (val > warnHi + 15)) return PostureQuality.poor;
    return PostureQuality.fair;
  }

  static String? _coaching(RulaAngles a) {
    final tips = <(PostureQuality, String)>[];
    final nq = _quality(a.neck, 10, 20, 5, 30);
    if (nq != PostureQuality.excellent) {
      tips.add((nq,
          a.neck > 20
              ? 'Head too far forward — raise screen, tuck chin'
              : 'Tilt head slightly forward to 10–20°'));
    }
    final tq = _quality(a.trunk, 0, 10, 0, 20);
    if (tq != PostureQuality.excellent) {
      tips.add((tq,
          a.trunk > 20
              ? 'Leaning forward — sit upright and use lumbar support'
              : 'Engage core, sit upright against chair back'));
    }
    final uq = _quality(a.upperArm, 20, 45, 10, 60);
    if (uq != PostureQuality.excellent) {
      tips.add((uq,
          a.upperArm > 60
              ? 'Elbow too high — bring it down to desk level'
              : 'Raise elbow slightly — aim for 20–45° from body'));
    }
    final wq = _quality(a.wrist, 0, 15, 0, 25);
    if (wq != PostureQuality.excellent) {
      tips.add((wq, 'Wrist bent — keep hand straight with forearm'));
    }
    if (tips.isEmpty) return null;
    tips.sort((a, b) => a.$1.index.compareTo(b.$1.index));
    return tips.first.$2;
  }

  static RulaResult compute(RulaAngles a) {
    final ua = _upperArmScore(a.upperArm).clamp(1, 4);
    final la = _forearmScore(a.forearm).clamp(1, 3);
    final wr = _wristScore(a.wrist).clamp(1, 3);
    const wt = 2;
    final nk = _neckScore(a.neck).clamp(1, 4);
    final tr = _trunkScore(a.trunk).clamp(1, 6);
    const lg = 1;
    final scoreA = _tableA[(ua, la, wr, wt)] ?? 4;
    final scoreB = _tableB[(nk, tr, lg)] ?? 3;
    final finalScore = _tableC[((scoreA).clamp(1, 8), (scoreB).clamp(1, 7))] ?? 7;

    return RulaResult(
      angles: a,
      finalScore: finalScore,
      scoreA: scoreA,
      scoreB: scoreB,
      upperArmQuality: _quality(a.upperArm, 20, 45, 10, 60),
      forearmQuality:  _quality(a.forearm,  60, 100, 50, 110),
      wristQuality:    _quality(a.wrist,    0,  15,  0,  25),
      neckQuality:     _quality(a.neck,     10, 20,  5,  30),
      trunkQuality:    _quality(a.trunk,    0,  10,  0,  20),
      shouldersQuality:_quality(a.shoulders,0,  5,   0,  10),
      topCoachingTip:  _coaching(a),
    );
  }
}