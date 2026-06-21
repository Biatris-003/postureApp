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
import '../../../utils/exercise_constants.dart';
import '../../../providers/exercise_progress_provider.dart';

class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider);
    final String userId = currentUser?.userId ?? 'unknown';

    // ─── Posture-based recommendations from this week's statistics ──────
    final postureCountMap = postureCountsCache;
    final recommendationService =
        ref.watch(exerciseRecommendationServiceProvider);
    final recommendedExercises =
        recommendationService.getRecommendedExercisesFromCounts(postureCountMap);

    // ─── Assigned plan (the user's default exercise list). Falls back to
    // the full ExerciseData.catalog if this user has no custom override. ──
    final mappedExercises = ref.watch(exerciseProvider);
    final defaultExercises = effectivePlanFor(mappedExercises, userId);

    // ─── Read progress for display ──────────────────────────────
    final progress = ref.watch(exerciseProgressNotifierProvider);

    // ─── Merge: recommended exercises first, then the assigned plan,
    // deduplicated by title (case-insensitive) so nothing shows twice. ───
    final List<Exercise> exercises = _mergeExercises(
      recommended: recommendedExercises,
      assigned: defaultExercises,
    );

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

    // Titles that came from posture recommendations, so we can badge them
    // in the list (and so the caption only refers to those cards).
    final recommendedTitles = recommendedExercises
        .map((e) => e.title.toLowerCase().trim())
        .toSet();

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
                  if (recommendedTitles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Highlighted exercises are based on your posture patterns this week',
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
                  final isRecommended = recommendedTitles
                      .contains(exercise.title.toLowerCase().trim());
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildExerciseCard(
                      context,
                      exercise,
                      progress,
                      isRecommended: isRecommended,
                    ),
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

  /// Combines posture-recommended exercises with the user's assigned plan.
  /// Recommended exercises are listed first (most relevant to this week),
  /// followed by the rest of the assigned plan. Duplicate titles (case
  /// insensitive, trimmed) are kept only once — the assigned-plan version
  /// wins if both exist, since it carries the user's real progress/id.
  List<Exercise> _mergeExercises({
    required List<Exercise> recommended,
    required List<Exercise> assigned,
  }) {
    final assignedByTitle = <String, Exercise>{
      for (final e in assigned) e.title.toLowerCase().trim(): e,
    };

    final merged = <Exercise>[];
    final seen = <String>{};

    // Recommended first — prefer the assigned-plan version if the same
    // exercise already exists there (keeps a stable id/progress link).
    for (final rec in recommended) {
      final key = rec.title.toLowerCase().trim();
      if (seen.contains(key)) continue;
      seen.add(key);
      merged.add(assignedByTitle[key] ?? rec);
    }

    // Then the rest of the assigned plan.
    for (final entry in assignedByTitle.entries) {
      if (seen.contains(entry.key)) continue;
      seen.add(entry.key);
      merged.add(entry.value);
    }

    return merged;
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
    BuildContext context,
    Exercise exercise,
    Map<String, int> progress, {
    bool isRecommended = false,
  }) {
    final diffColor = _difficultyColor(exercise.difficultyLevel);

    // Determine if this exercise is one of the 4 tracked
    final isTracked = trackedExerciseTitles.contains(exercise.title);

    // Get completed reps from weekly assessment
    String repsDisplay = '10 Reps × 3 Sets';
    if (isTracked) {
      final coachId = exerciseTitleToCoachId[exercise.title];
      if (coachId != null && progress.containsKey(coachId)) {
        final completed = progress[coachId]!;
        if (completed > 0) {
          // Calculate: Ceiling(completedReps / 3) Reps × 3 Sets
          final repsPerSet = (completed / 3).ceil();
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
        // Always open the detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseDetailScreen(
              exercise: exercise,
              heroTag: 'exercise_image_${exercise.id}',
              isTracked: false, // <-- no saving from main tab
              completedReps: completedReps,
              fromWeeklyAssessment: false, // <-- main tab mode
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
                child: Row(
                  children: [
                    if (isRecommended)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildTopPill(
                          icon: Icons.auto_graph_rounded,
                          label: 'For You',
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                    _buildTopPill(
                      icon: Icons.bar_chart_rounded,
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
                              _buildTopPill(
                                icon: Icons.repeat_rounded,
                                label: repsDisplay,
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