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

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor(widget.exercise.difficultyLevel);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero static image at top ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.exercise.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                        blurRadius: 15,
                        color: Colors.black87,
                        offset: Offset(0, 4))
                  ],
                ),
              ),
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
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.9)
                          ],
                          stops: const [0.5, 1.0],
                        ),
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
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Chips row: Reps / Sets / Duration / Difficulty ───
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildInfoChip(
                        context,
                        Icons.repeat_rounded,
                        widget.exercise.reps,
                        Theme.of(context).primaryColor,
                      ),
                      _buildInfoChip(
                        context,
                        Icons.layers_rounded,
                        widget.exercise.sets,
                        const Color(0xFF8B5CF6),
                      ),
                      _buildInfoChip(
                        context,
                        Icons.timer_outlined,
                        widget.exercise.duration,
                        const Color(0xFF06B6D4),
                      ),
                      _buildInfoChip(
                        context,
                        Icons.bar_chart_rounded,
                        widget.exercise.difficultyLevel,
                        diffColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ── Instructions ─────────────────────────────────────
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
                  ..._buildInstructionSteps(
                      context, widget.exercise.description),

                  const SizedBox(height: 40),

                  // ── Demo Video ────────────────────────────────────────
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

                  const SizedBox(height: 48),

                  // ── Start Exercise button ─────────────────────────────
                  SizedBox(
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
                      style:
                          Theme.of(context).elevatedButtonTheme.style?.copyWith(
                                padding: WidgetStateProperty.all(
                                    const EdgeInsets.symmetric(vertical: 20)),
                              ),
                      child: const Text('Start Exercise',
                          style:
                              TextStyle(fontSize: 18, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Video player ───────────────────────────────────────────────────────
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
              // Video frame or thumbnail
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
                  errorBuilder: (ctx, e, st) =>
                      Container(color: Colors.white),
                ),

              // Overlay when paused
              if (!_isPlaying)
                Container(color: Colors.black.withValues(alpha: 0.4)),

              // Play button / status text
              if (!_isPlaying)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 40),
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
                        shadows: [
                          Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),

              // Pause icon shown bottom-right while playing
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
                    child: const Icon(Icons.pause_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Numbered instruction steps ─────────────────────────────────────────
  List<Widget> _buildInstructionSteps(
      BuildContext context, String description) {
    final lines = description
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return lines.asMap().entries.map((entry) {
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
              decoration: BoxDecoration(
                color:
                    Theme.of(context).primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNum',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w800,
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

  Widget _buildInfoChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorImage(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Icon(Icons.image_not_supported_rounded,
          size: 60, color: Theme.of(context).primaryColor),
    );
  }
}