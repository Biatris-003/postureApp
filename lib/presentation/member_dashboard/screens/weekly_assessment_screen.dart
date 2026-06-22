import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/exercise_data.dart';
import '../../../domain/entities/exercises/exercise.dart';
import 'exercise_detail_screen.dart';
import '../../../utils/exercise_constants.dart';
import '../../../providers/exercise_progress_provider.dart'; // new
import '../../../providers/recommended_exercises_provider.dart';
import '../widgets/exercise_card_badge.dart';

class WeeklyAssessmentScreen extends ConsumerWidget {
  const WeeklyAssessmentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // currentUser kept for future use (analytics/personalization).
    final recommendedExercisesAsync = ref.watch(recommendedExercisesProvider);

    // ─── Posture-based exercises from this week's statistics ────────────
    // weeklyPostureCountsProvider reads straight from Firestore — it does
    // NOT depend on the Statistics tab being opened. It's a FutureProvider,
    // so we must render its `loading` state explicitly instead of
    // collapsing it into an empty map (which made this screen look like
    // it had nothing to show until the data happened to arrive).

    // ─── Read progress for display ──────────────────────────────
    final progress = ref.watch(exerciseProgressNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Weekly Assessment'), centerTitle: true),
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
          // ─── Posture-recommended exercises first (already percentage-
          // ordered, qualifying postures only), then the 4 always-tracked
          // exercises appended at the bottom — unless a tracked exercise
          // is already present from the recommendation above, in which
          // case it keeps its percentage-ordered position and is not
          // duplicated at the bottom. ───────────────────────────────────
          final exercises = _buildWeeklyList(
            recommended: recommendedExercises,
            tracked: trackedExerciseTitles,
          );

          if (exercises.isEmpty) {
            return Center(
              child: Text(
                'No exercises assigned currently.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            );
          }

          return CustomScrollView(
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
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ordered by your posture patterns this week, with '
                          'your 4 core tracked exercises always included',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final exercise = exercises[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child:
                          _buildExerciseCard(context, exercise, progress),
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

  /// Builds the Weekly Assessment exercise list:
  ///   1. Posture-recommended exercises for the week's qualifying (>10%)
  ///      postures, already ordered by percentage descending.
  ///   2. The 4 always-tracked exercises (Circumduction, Squatting,
  ///      Side Bending Right, Sit-to-stand), appended at the BOTTOM —
  ///      always present no matter what postures the patient sat in this
  ///      week, regardless of whether their posture cleared the 10%
  ///      threshold — UNLESS a tracked exercise is already present from
  ///      the posture recommendation above, in which case it keeps its
  ///      percentage-ordered position and is not duplicated at the bottom.
  ///
  /// Tracked exercises not already present are pulled straight from the
  /// catalog by title (ExerciseData.findByTitle).
  List<Exercise> _buildWeeklyList({
    required List<Exercise> recommended,
    required List<String> tracked,
  }) {
    final result = <Exercise>[...recommended];
    final seen = <String>{
      for (final e in recommended) e.title.toLowerCase().trim(),
    };

    // Always-shown 4, appended at the bottom, in the fixed order given by
    // exercise_constants.dart — skipped if already present above.
    for (final title in tracked) {
      final key = title.toLowerCase().trim();
      if (seen.contains(key)) continue; // already present from recommendation
      final match = ExerciseData.findByTitle(title);
      if (match == null) continue; // not found in catalog — skip, don't fabricate
      seen.add(key);
      result.add(match);
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
                child: ExerciseCardBadge(
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
