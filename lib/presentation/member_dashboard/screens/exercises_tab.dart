import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/exercise_data.dart';
import '../../../domain/entities/exercises/exercise.dart';
import 'exercise_detail_screen.dart';
import 'weekly_assessment_screen.dart';
import '../../../utils/exercise_constants.dart';
import '../../../utils/exercise_timer.dart';
import '../../../providers/exercise_progress_provider.dart';
import '../../../providers/recommended_exercises_provider.dart';
import '../widgets/exercise_card_badge.dart';
import 'exercise_coach_screen.dart';
import '../../../providers/exercise_done_provider.dart';
import '../../../core/theme/app_theme.dart';

class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedExercisesAsync = ref.watch(recommendedExercisesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: recommendedExercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'Could not load your posture data. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        data: (recommendedExercises) {
          final rawExercises = _appendTrackedExercises(
            recommended: recommendedExercises,
            tracked: trackedExerciseTitles,
          );
          final doneSet = ref.watch(exerciseDoneProvider).value ?? {};
          final exercises = [
            ...rawExercises.where((e) => !doneSet.contains(e.title)),
            ...rawExercises.where((e) => doneSet.contains(e.title)),
          ];
          
          if (exercises.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No exercises needed right now — your posture this week '
                  'looks good!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text(
                                //   'Exercises',
                                //   style: TextStyle(
                                //     fontSize: 24,
                                //     fontWeight: FontWeight.w700,
                                //     color: Theme.of(context).colorScheme.onSurface,
                                //   ),
                                // ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recommended exercises based on your posture patterns',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _AssessmentButton(
                            label: 'Weekly Assessment',
                            icon: Icons.calendar_month_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WeeklyAssessmentScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final exercise = exercises[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildExerciseCard(context, exercise, ref),
                    );
                  }, childCount: exercises.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Exercise> _appendTrackedExercises({
    required List<Exercise> recommended,
    required List<String> tracked,
  }) {
    final result = <Exercise>[...recommended];
    final seen = <String>{
      for (final e in recommended) e.title.toLowerCase().trim(),
    };

    for (final title in tracked) {
      final key = title.toLowerCase().trim();
      if (seen.contains(key)) continue;
      final match = ExerciseData.findByTitle(title);
      if (match == null) continue;
      seen.add(key);
      result.add(match);
    }

    return result;
  }

  Widget _buildExerciseCard(
    BuildContext context,
    Exercise exercise,
    WidgetRef ref,
  ) {
    final diffColor = exerciseDifficultyColor(exercise.difficultyLevel);
    final isTracked = trackedExerciseTitles.contains(exercise.title);
    final progress = ref.watch(exerciseProgressNotifierProvider);
    
    var repsPerSet = 5;
    String repsDisplay = exercise.reps.isNotEmpty
        ? '${exercise.reps} × ${exercise.sets}'
        : '5 reps × 3 sets';
    if (isTracked) {
      final coachId = exerciseTitleToCoachId[exercise.title];
      if (coachId != null && progress.containsKey(coachId)) {
        final completed = progress[coachId]!;
        if (completed > 0) {
          repsPerSet = (completed / 3).ceil();
          repsDisplay = '$repsPerSet Reps × 3 Sets';
        }
      }
    }

    final coachId = isTracked ? exerciseTitleToCoachId[exercise.title] : null;
    final completedReps = (coachId != null && progress.containsKey(coachId))
        ? progress[coachId]
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseDetailScreen(
              exercise: exercise,
              heroTag: 'exercise_image_${exercise.id}',
              isTracked: false,
              completedReps: completedReps,
              fromWeeklyAssessment: false,
            ),
          ),
        );
      },
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
                      Colors.transparent,
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
                child: Consumer(
                  builder: (context, ref, _) {
                    final isDone =
                        ref
                            .watch(exerciseDoneProvider)
                            .value
                            ?.contains(exercise.title) ??
                        false;
                    if (isDone) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10b981),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ExerciseCardBadge(
                      label: exercise.difficultyLevel,
                      color: diffColor,
                    );
                  },
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildTopPill(
                                    icon: Icons.repeat_rounded,
                                    label: repsDisplay,
                                  ),
                                  _buildTopPill(
                                    icon: Icons.timer_outlined,
                                    label: calculateExerciseTotalTime(
                                      repsPerSet,
                                      exercise.title,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
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
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(16),
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
