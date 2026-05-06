import 'package:flutter/material.dart';
import '../../../domain/entities/exercises/exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({Key? key, required this.exercise}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                exercise.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(blurRadius: 15.0, color: Colors.black87, offset: Offset(0, 4))],
                ),
              ),
              background: Hero(
                tag: 'exercise_image_${exercise.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    exercise.imageUrl.startsWith('http')
                        ? Image.network(
                            exercise.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildErrorImage(context),
                          )
                        : Image.asset(
                            exercise.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildErrorImage(context),
                          ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
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
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
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
                  Row(
                    children: [
                      _buildInfoChip(context, Icons.timer_outlined, exercise.duration, Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      _buildInfoChip(context, Icons.repeat_rounded, exercise.frequency, const Color(0xFFF59E0B)),
                    ],
                  ),
                  const SizedBox(height: 40),
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
                  Text(
                    exercise.description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '3D Demonstration',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 320,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: exercise.modelUrl != null
                          ? Image.asset(
                              exercise.modelUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildVideoFallback(context),
                            )
                          : _buildVideoFallback(context),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Exercise tracking started!'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                      },
                      style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 20)),
                      ),
                      child: const Text('Start Exercise', style: TextStyle(fontSize: 18, letterSpacing: 0.5)),
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

  Widget _buildVideoFallback(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        exercise.imageUrl.startsWith('http')
            ? Image.network(
                exercise.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(context),
              )
            : Image.asset(
                exercise.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(context),
              ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Watch Demonstration Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Standard player fallback enabled',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorImage(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Icon(Icons.image_not_supported_rounded, size: 60, color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
    );
  }
}
