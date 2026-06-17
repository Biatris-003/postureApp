import 'package:flutter/material.dart';
import 'package:smart_posture_app/presentation/member_dashboard/screens/exercise_coach_screen.dart';
import 'package:video_player/video_player.dart';
import '../../../domain/entities/exercises/exercise.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  final String? heroTag;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.heroTag,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;
  bool _isPlaying = false;

  static const Map<String, List<String>> _exerciseInstructions = {
    'Bird Dog': [
      'Start on all fours with your hands directly under your shoulders and knees under your hips.',
      'Keep your spine neutral and engage your core.',
      'Slowly extend your right arm forward and your left leg back until both are parallel to the floor.',
      'Hold the position for 3 seconds, keeping your hips level and avoiding any rotation in your torso.',
      'Return to the starting position with control.',
      'Repeat on the opposite side — left arm and right leg.',
    ],
    'Cat-Cow': [
      'Start on all fours with your hands under your shoulders and knees under your hips.',
      'For the Cat: exhale and round your spine toward the ceiling, letting your head and tailbone drop.',
      'Hold briefly for 2 seconds.',
      'For the Cow: inhale and let your belly drop toward the floor, lifting your chest and tailbone.',
      'Hold briefly for 2 seconds, then continue moving slowly between both positions.',
    ],
    'Chest Stretch': [
      'Stand facing a doorway or open wall, feet shoulder-width apart.',
      'Raise both arms out to your sides and place your palms flat against the wall at shoulder height.',
      'Gently lean your chest forward through the doorway until you feel a stretch across your chest and shoulders.',
      'Keep your back straight and your chin tucked throughout.',
      'Hold the stretch for 30 seconds, then slowly return to the starting position.',
    ],
    'Circumduction': [
      'Stand tall with your feet shoulder-width apart and arms extended straight out to your sides.',
      'Begin making slow, controlled circles with both arms simultaneously.',
      'Start with small circles and gradually increase the size.',
      'Complete the set in one direction, then reverse and circle in the opposite direction.',
      'Keep your core engaged and avoid shrugging your shoulders.',
    ],
    'Dead Bug': [
      'Lie flat on your back with your arms pointing straight up toward the ceiling.',
      'Raise your legs so your knees are bent at 90 degrees, shins parallel to the floor.',
      'Press your lower back firmly into the floor and engage your core.',
      'Slowly lower your right arm overhead and extend your left leg toward the floor simultaneously.',
      'Stop just before either limb touches the floor, keeping your lower back flat.',
      'Return to the starting position with control, then repeat on the opposite side.',
    ],
    'Glute Bridge': [
      'Lie on your back with your knees bent, feet flat on the floor hip-width apart.',
      'Place your arms flat by your sides, palms facing down.',
      'Press your feet into the floor and squeeze your glutes as you lift your hips toward the ceiling.',
      'Drive your hips up until your body forms a straight line from shoulders to knees.',
      'Hold at the top for 2 seconds, then slowly lower your hips back to the floor.',
    ],
    'Hip Flexor Stretch': [
      'Kneel on one knee with the other foot flat on the floor in front of you, forming a 90-degree angle.',
      'Keep your torso upright and place both hands gently on your front thigh for balance.',
      'Shift your weight forward slightly until you feel a stretch along the front of the hip of your kneeling leg.',
      'Hold the position for 30 seconds, keeping your core engaged and your back straight.',
      'Return to the starting position and repeat on the other side.',
    ],
    'Left Side Plank': [
      'Lie on your left side with your legs stacked straight on top of each other.',
      'Place your left forearm on the floor, elbow directly beneath your shoulder.',
      'Lift your hips off the floor until your body forms a straight diagonal line from head to feet.',
      'Keep your core braced and avoid letting your hips sag or rotate.',
      'Hold for as long as you can while maintaining correct form, then lower with control.',
    ],
    'Leg Lift': [
      'Lie flat on your back with your legs straight and arms resting by your sides.',
      'Press your lower back into the floor and engage your core.',
      'Keeping both legs straight, slowly raise them toward the ceiling until they are perpendicular to the floor.',
      'Hold briefly at the top, then slowly lower them back toward the floor.',
      'Stop just before your feet touch the floor to maintain tension, then repeat.',
    ],
    'Micro Break Walking': [
      'Stand up from your desk.',
      'Walk at a comfortable, relaxed pace with your head up and shoulders back for the full timer duration shown above.',
    ],
    'Neck Rotation': [
      'Sit or stand tall with your shoulders relaxed and your gaze forward.',
      'Slowly turn your head to the right as far as is comfortable, keeping your chin level.',
      'Hold briefly for 2 seconds, then return to the center.',
      'Slowly turn your head to the left as far as is comfortable.',
      'Hold briefly for 2 seconds, then return to center. That is one full repetition.',
    ],
    'Plank': [
      'Lie face down and place your forearms on the floor, elbows directly under your shoulders.',
      'Curl your toes under and lift your body off the floor, forming a straight line from head to heels.',
      'Engage your core, squeeze your glutes, and keep your hips level — do not let them sag or rise.',
      'Keep your neck neutral and gaze slightly ahead of your hands.',
      'Hold for as long as you can while maintaining correct form, then lower with control.',
    ],
    'Right Side Leg Raise': [
      'Lie on your right side with your legs stacked straight on top of each other.',
      'Rest your head on your right arm or prop yourself up on your right elbow.',
      'Place your left hand on the floor in front of you for stability.',
      'Keeping your top leg straight, slowly raise it toward the ceiling as high as comfortable.',
      'Hold briefly at the top for 2 seconds, then lower with control back to the starting position.',
    ],
    'Side Bending Right': [
      'Stand tall with your feet shoulder-width apart and your right arm relaxed by your side.',
      'Raise your left arm upward and slightly over your head at a comfortable angle.',
      'Slowly bend your upper body to the right, letting your right hand slide gently down your right side.',
      'Keep your chest open, your shoulders relaxed, and avoid twisting your torso.',
      'Hold the side stretch for 20 seconds, then return to the upright position with control.',
    ],
    'Sit to Stand': [
      'Sit upright near the edge of your chair with your feet flat on the floor, hip-width apart.',
      'Lean slightly forward from your hips, keeping your back straight.',
      'Press through your heels and push yourself to a fully upright standing position.',
      'Stand tall for a moment, then slowly lower yourself back onto the seat with control.',
      'Avoid using your hands to push off the chair.',
    ],
    'Squatting': [
      'Stand tall with your feet shoulder-width apart and toes pointing slightly outward.',
      'Extend your arms forward for balance as you begin to lower down.',
      'Bend at the hips and knees simultaneously, lowering your body as if sitting back into a chair.',
      'Keep your chest up, your back straight, and your knees tracking over your toes.',
      'Lower until your thighs are parallel to the floor or as far as is comfortable.',
      'Press through your heels to return to the standing position.',
    ],
    'Thoracic Back Extension': [
      'Stand tall with your feet shoulder-width apart and arms relaxed at your sides.',
      'Place your hands on your lower back or cross them over your chest for support.',
      'Gently arch your upper back backward, extending through your thoracic spine.',
      'Keep your neck neutral and avoid straining your lower back.',
      'Hold the extended position for 5 seconds, then slowly return to the upright starting position.',
    ],
    'Tummy Twist': [
      'Stand tall with your feet shoulder-width apart and arms extended straight out to your sides.',
      'Keep your hips and lower body facing forward throughout the movement.',
      'Slowly rotate your upper body and arms to the right as far as comfortable.',
      'Hold briefly for 2 seconds, then rotate back through center and continue to the left.',
      'Move smoothly and with control, breathing steadily throughout.',
    ],
  };

  static const Map<String, String> _holdDurations = {
    'Bird Dog': '3 sec',
    'Cat-Cow': '2 sec',
    'Chest Stretch': '30 sec',
    'Glute Bridge': '2 sec',
    'Hip Flexor Stretch': '30 sec',
    'Neck Rotation': '2 sec',
    'Right Side Leg Raise': '2 sec',
    'Side Bending Right': '20 sec',
    'Thoracic Back Extension': '5 sec',
    'Tummy Twist': '2 sec',
  };

  static const Map<String, int> _secPerRep = {
    'Bird Dog': 6,
    'Cat-Cow': 5,
    'Chest Stretch': 30,
    'Circumduction': 4,
    'Dead Bug': 6,
    'Glute Bridge': 4,
    'Hip Flexor Stretch': 30,
    'Left Side Plank': 20,
    'Leg Lift': 4,
    'Micro Break Walking': 60,
    'Neck Rotation': 4,
    'Plank': 20,
    'Right Side Leg Raise': 4,
    'Side Bending Right': 20,
    'Sit to Stand': 4,
    'Squatting': 4,
    'Thoracic Back Extension': 7,
    'Tummy Twist': 4,
  };

  static const Color _accentColor = Color(0xFF6C63FF);

  static String _clean(String raw) =>
      raw.replaceAll(RegExp(r'\s*(reps?|sets?)', caseSensitive: false), '').trim();

  String _calculateTotalTimer(String repsRaw, String setsRaw, String title) {
    final reps = int.tryParse(_clean(repsRaw)) ?? 10;
    final sets = int.tryParse(_clean(setsRaw)) ?? 1;
    final secPerRep = _secPerRep[title] ?? 4;

    final restSeconds = sets > 1 ? (sets - 1) * 15 : 0;
    final totalSeconds = reps * sets * secPerRep + restSeconds;

    final mins = (totalSeconds / 60).ceil();
    return '$mins min';
  }

  @override
  void initState() {
    super.initState();
    if (widget.exercise.videoAssetPath != null) {
      _initVideo(widget.exercise.videoAssetPath!);
    }
  }

  Future<void> _initVideo(String assetPath) async {
    try {
      _videoController = VideoPlayerController.asset(assetPath);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      if (mounted) setState(() => _videoInitialized = true);
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_videoInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Color _difficultyColor(String level) {
    switch (level.toLowerCase()) {
      case 'intermediate':
        return const Color(0xFFF59E0B);
      case 'advanced':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF22C55E);
    }
  }

  List<String> _getInstructions() {
    return _exerciseInstructions[widget.exercise.title] ??
        widget.exercise.description
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
  }

  String? _getHoldDuration() => _holdDurations[widget.exercise.title];

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor(widget.exercise.difficultyLevel);
    final holdDuration = _getHoldDuration();

    final repsLabel =
        '${_clean(widget.exercise.reps)}×${_clean(widget.exercise.sets)}';

    final timerLabel = _calculateTotalTimer(
      widget.exercise.reps,
      widget.exercise.sets,
      widget.exercise.title,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ExerciseCoachScreen(
                      exerciseTitle: widget.exercise.title,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                shadowColor: _accentColor.withValues(alpha: 0.4),
              ),
              child: const Text(
                'Start Exercise',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: widget.heroTag ?? 'exercise_image_${widget.exercise.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white,
                      child: Image.asset(
                        widget.exercise.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, e, st) =>
                            _buildErrorImage(context),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildImageBadge(
                            icon: Icons.timer_outlined,
                            label: timerLabel,
                            color: Colors.white,
                          ),
                          _buildImageBadge(
                            icon: Icons.bar_chart_rounded,
                            label: widget.exercise.difficultyLevel,
                            color: diffColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.exercise.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatPill(
                        icon: Icons.repeat_rounded,
                        value: repsLabel,
                        label: 'Reps',
                      ),
                      if (holdDuration != null) ...[
                        const SizedBox(width: 12),
                        _buildStatPill(
                          icon: Icons.timer_outlined,
                          value: holdDuration,
                          label: 'Hold',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildInstructionSteps(context, _getInstructions()),
                  const SizedBox(height: 40),
                  Text(
                    'Exercise Demo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildVideoPlayer(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accentColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            '$value $label',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_videoInitialized && _videoController != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                )
              else
                Image.asset(
                  widget.exercise.imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, e, st) => Container(color: Colors.white),
                ),
              if (!_isPlaying)
                Container(color: Colors.black.withValues(alpha: 0.3)),
              if (!_isPlaying)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _videoError
                          ? 'Video unavailable'
                          : _videoInitialized
                              ? 'Tap to play demo'
                              : 'Loading demo...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (_isPlaying)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInstructionSteps(BuildContext context, List<String> steps) {
    return steps.asMap().entries.map((entry) {
      final stepNum = entry.key + 1;
      final text = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: _accentColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNum',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildErrorImage(BuildContext context) {
    return Container(
      color: _accentColor.withValues(alpha: 0.1),
      child: const Icon(
        Icons.image_not_supported_rounded,
        size: 60,
        color: _accentColor,
      ),
    );
  }
}