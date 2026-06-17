import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../data/datasources/advisor_data_service_mock.dart';
import '../../../data/datasources/exercise_recommendation_service.dart';
import '../../../domain/entities/exercises/exercise.dart';
import 'exercise_detail_screen.dart';
import 'statistics_tab.dart';
import 'rula_assessment_screen.dart';
import 'weekly_assessment_screen.dart';
import '../../../utils/exercise_constants.dart'; // NEW import
import '../../../providers/exercise_progress_provider.dart'; // NEW import

class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider);
    final String userId = currentUser?.userId ?? 'unknown';

    final postureCountMap = postureCountsCache;
    final recommendationService =
        ref.watch(exerciseRecommendationServiceProvider);
    final recommendedExercises =
        recommendationService.getRecommendedExercisesFromCounts(postureCountMap);

    final mappedExercises = ref.watch(exerciseProvider);
    final defaultExercises = mappedExercises[userId] ?? [];

    // ─── NEW: read progress ──────────────────────────────────
    final progress = ref.watch(exerciseProgressNotifierProvider);

    final List<Exercise> exercises = defaultExercises;
    if (exercises.isEmpty) {
      return Center(
        child: Text(
          'No exercises assigned currently.',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row with assessment buttons ────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Your Plan',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          _AssessmentButton(
                            label: 'Weekly Assessment',
                            icon: Icons.calendar_month_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const WeeklyAssessmentScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (recommendedExercises.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Based on your posture patterns',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final exercise = exercises[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildExerciseCard(context, exercise, progress),
                  );
                },
                childCount: exercises.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildExerciseCard(
      BuildContext context, Exercise exercise, Map<String, int> progress) {
    final diffColor = _difficultyColor(exercise.difficultyLevel);
    final timerLabel = _calculateTotalTimer(
      exercise.reps,
      exercise.sets,
      exercise.title,
    );

    // ─── Determine if this exercise is tracked ──────────────────
    final isTracked = trackedExerciseTitles.contains(exercise.title);
    String repsDisplay = '${_clean(exercise.reps)}×${_clean(exercise.sets)} Reps';
    if (isTracked) {
      final coachId = exerciseTitleToCoachId[exercise.title];
      if (coachId != null) {
        final completedReps = progress[coachId];
        if (completedReps != null && completedReps > 0) {
          repsDisplay = '$completedReps reps done';
        }
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseDetailScreen(exercise: exercise),
          ),
        );
      },
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'exercise_image_${exercise.id}',
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.asset(
                    exercise.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildErrorPlaceholder(context),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: _buildTopPill(
                  icon: Icons.bar_chart_rounded,
                  label: exercise.difficultyLevel,
                  color: diffColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                exercise.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildTopPill(
                                    icon: Icons.repeat_rounded,
                                    label: repsDisplay, // ← dynamic
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTopPill(
                                    icon: Icons.timer_outlined,
                                    label: timerLabel,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPill({
    required IconData icon,
    required String label,
    Color color = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Icon(
        Icons.image_not_supported_rounded,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        size: 40,
      ),
    );
  }
}

class _AssessmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AssessmentButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}