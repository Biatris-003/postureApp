import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/auth_service_mock.dart';
import '../../../data/datasources/advisor_data_service_mock.dart';
import '../../../domain/entities/exercises/exercise.dart';
import 'exercise_detail_screen.dart';

class ExercisesTab extends ConsumerWidget {
  const ExercisesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine current user ID; if null default to string '1' for mock testing.
    final currentUser = ref.watch(authStateProvider);
    final String uid = currentUser?.uid ?? '1';
    
    // Listen directly to the global exercise state
    final mappedExercises = ref.watch(exerciseProvider);
    final List<Exercise> exercises = mappedExercises[uid] ?? [];

    if (exercises.isEmpty) {
      return Center(
        child: Text(
          "No exercises assigned currently.",
          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final exercise = exercises[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildExerciseCard(context, exercise),
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

  Widget _buildExerciseCard(BuildContext context, Exercise exercise) {
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
        height: 220,
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
              // Background Image with Hero
              Hero(
                tag: 'exercise_image_${exercise.id}',
                child: exercise.imageUrl.startsWith('http')
                    ? Image.network(
                        exercise.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(context),
                      )
                    : Image.asset(
                        exercise.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(context),
                      ),
              ),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      exercise.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exercise.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded, color: Colors.white.withValues(alpha: 0.8), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                exercise.duration,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.repeat_rounded, color: Colors.white.withValues(alpha: 0.8), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                exercise.frequency,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        )
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
      child: Icon(Icons.image_not_supported_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 40),
    );
  }
}
