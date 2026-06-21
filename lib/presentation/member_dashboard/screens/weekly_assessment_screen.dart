import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../data/datasources/advisor_data_service_mock.dart';
import '../../../data/datasources/exercise_recommendation_service.dart';
import '../../../data/datasources/exercise_data.dart';
import '../../../domain/entities/exercises/exercise.dart';
import 'exercise_detail_screen.dart';
import '../../../utils/exercise_constants.dart';
import '../../../providers/exercise_progress_provider.dart'; // new
import '../../../providers/weekly_posture_counts_provider.dart';
import '../widgets/exercise_card_badge.dart';

class WeeklyAssessmentScreen extends ConsumerWidget {
  const WeeklyAssessmentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider);
    final String userId = currentUser?.userId ?? 'unknown';

    // ─── Posture-based recommendations from this week's statistics ──────
    final postureCountMap = ref
        .watch(weeklyPostureCountsProvider)
        .when(
          data: (counts) => counts,
          loading: () => const <String, int>{},
          error: (error, stackTrace) => const <String, int>{},
        );
    final recommendationService = ref.watch(
      exerciseRecommendationServiceProvider,
    );
    final recommendedExercises = recommendationService
        .getRecommendedExercisesFromCounts(postureCountMap);

    // ─── Assigned plan (the user's default exercise list). Falls back to
    // the full ExerciseData.catalog if this user has no custom override. ──
    final mappedExercises = ref.watch(exerciseProvider);
    final defaultExercises = effectivePlanFor(mappedExercises, userId);

    // ─── Read progress for display ──────────────────────────────
    final progress = ref.watch(exerciseProgressNotifierProvider);

    // ─── Always include the 4 tracked exercises, regardless of posture,
    // then layer posture-recommended exercises on top, deduplicated. ─────
    final List<Exercise> exercises = _buildWeeklyList(
      tracked: trackedExerciseTitles,
      assigned: defaultExercises,
      recommended: recommendedExercises,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Weekly Assessment'), centerTitle: true),
      body: exercises.isEmpty
          ? Center(
              child: Text(
                'No exercises assigned currently.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Plan',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (recommendedExercises.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Includes extra exercises based on your posture patterns this week',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final exercise = exercises[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildExerciseCard(context, exercise, progress),
                      );
                    }, childCount: exercises.length),
                  ),
                ),
              ],
            ),
    );
  }

  /// Builds the Weekly Assessment exercise list:
  ///   1. The 4 always-tracked exercises (Circumduction, Squatting,
  ///      Side Bending Right, Sit-to-stand) — always present, no matter
  ///      what postures the patient sat in this week.
  ///   2. Posture-recommended exercises for the week's worst postures,
  ///      appended after, skipping anything already in the tracked set.
  ///
  /// Tracked exercises are pulled from [assigned] by exact title match
  /// (so they keep their real id/progress link). If a tracked title is
  /// somehow missing from the assigned plan, it's skipped rather than
  /// fabricated, since we don't have a safe id/image/video for it here.
  List<Exercise> _buildWeeklyList({
    required List<String> tracked,
    required List<Exercise> assigned,
    required List<Exercise> recommended,
  }) {
    final assignedByTitle = <String, Exercise>{
      for (final e in assigned) e.title.toLowerCase().trim(): e,
    };

    final result = <Exercise>[];
    final seen = <String>{};

    // 1) Always-shown 4, in the fixed order given by exercise_constants.dart.
    for (final title in tracked) {
      final key = title.toLowerCase().trim();
      final match = assignedByTitle[key] ?? ExerciseData.findByTitle(title);
      if (match == null) continue; // not found in plan — skip, don't fabricate
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(match);
    }

    // 2) Posture-recommended exercises on top, deduped against the 4 above
    // and against each other. Prefer the assigned-plan version if it
    // exists (keeps stable id/progress), else use the recommended model.
    for (final rec in recommended) {
      final key = rec.title.toLowerCase().trim();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(rec);
    }

    return result;
  }

  Widget _buildExerciseCard(
    BuildContext context,
    Exercise exercise,
    Map<String, int> progress,
  ) {
    final diffColor = exerciseDifficultyColor(exercise.difficultyLevel);

    // Determine if this exercise is tracked
    final isTracked = trackedExerciseTitles.contains(exercise.title);

    // Get completed reps if any (for display)
    final coachId = isTracked ? exerciseTitleToCoachId[exercise.title] : null;
    final completedReps = (coachId != null && progress.containsKey(coachId))
        ? progress[coachId]
        : null;

    return GestureDetector(
      onTap: () {
        // ─── Open the detail screen ────────────────────────────────────
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseDetailScreen(
              exercise: exercise,
              heroTag: 'weekly_exercise_image_${exercise.id}',
              isTracked: isTracked, // true for the 4, false for others
              completedReps: completedReps,
              fromWeeklyAssessment: true, // <-- weekly assessment mode
            ),
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
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'weekly_exercise_image_${exercise.id}',
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
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.25, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: [
                    if (!isTracked)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'For You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ExerciseCardBadge(
                      label: exercise.difficultyLevel,
                      color: diffColor,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
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
                    Text(
                      exercise.description.split('\n').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
