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

class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // currentUser kept for future use (e.g. analytics, personalization),
    // but the plan itself no longer merges with a separate assigned plan.
    final recommendedExercisesAsync = ref.watch(recommendedExercisesProvider);

    // ─── Posture-based exercises from this week's statistics ────────────
    // weeklyPostureCountsProvider reads straight from Firestore — it does
    // NOT depend on the Statistics tab being opened. It's a FutureProvider,
    // so on first load it's genuinely in a `loading` state for as long as
    // the Firestore round-trip takes. We must render that loading state
    // explicitly — treating "still loading" the same as "no postures
    // qualified" (returning an empty map) is what made this screen look
    // empty until the data happened to arrive.

    // ─── Read progress for display (tracked exercises only) ─────────────
    final progress = ref.watch(exerciseProgressNotifierProvider);

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
          // ─── Force-include the 4 tracked exercises at the bottom of the
          // list, unless they're already present from the posture
          // recommendation above (in which case they keep their
          // percentage-ordered position and are not duplicated). ─────────
          final exercises = _appendTrackedExercises(
            recommended: recommendedExercises,
            tracked: trackedExerciseTitles,
          );

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
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                color:
                                    Theme.of(context).colorScheme.onSurface,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ordered by your most frequent posture patterns '
                          'this week',
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

  /// Appends the 4 always-tracked exercises (Circumduction, Squatting,
  /// Side Bending Right, Sit-to-stand) to the bottom of [recommended],
  /// skipping any tracked title that's already present (case-insensitive,
  /// trimmed) so nothing is duplicated. Tracked exercises that aren't in
  /// [recommended] are pulled straight from the catalog by title.
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

    // Determine if this exercise is one of the 4 tracked
    final isTracked = trackedExerciseTitles.contains(exercise.title);

    // Get completed reps from weekly assessment (Firestore). If the user
    // hasn't completed a Weekly Assessment for this exercise yet, fall
    // back to the catalog's fixed default reps/sets.
    var repsPerSet = 5;
    String repsDisplay = exercise.reps.isNotEmpty
        ? '${exercise.reps} × ${exercise.sets}'
        : '5 reps × 3 sets';
    if (isTracked) {
      final coachId = exerciseTitleToCoachId[exercise.title];
      if (coachId != null && progress.containsKey(coachId)) {
        final completed = progress[coachId]!;
        if (completed > 0) {
          // Calculate: Ceiling(completedReps / 3) Reps × 3 Sets
          repsPerSet = (completed / 3).ceil();
          repsDisplay = '$repsPerSet Reps × 3 Sets';
        }
      }
    }

    // Get completed reps for the detail screen (if any)
    final coachId = isTracked ? exerciseTitleToCoachId[exercise.title] : null;
    final completedReps = (coachId != null && progress.containsKey(coachId))
        ? progress[coachId]
        : null;

    return GestureDetector(
      onTap: () {
  final coachId = exerciseTitleToCoachId[exercise.title];
  final hasCoaching = coachId != null;

  if (hasCoaching) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseCoachScreen(
          exerciseTitle: exercise.title,
          trackReps: false, // main tab never saves
        ),
      ),
    );
  } else {
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
  }
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
