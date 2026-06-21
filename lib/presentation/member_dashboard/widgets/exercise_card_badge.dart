import 'package:flutter/material.dart';

Color exerciseDifficultyColor(String level) {
  switch (level.toLowerCase()) {
    case 'intermediate':
      return const Color(0xFFF59E0B);
    case 'advanced':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF22C55E);
  }
}

/// Shared top-right label used by both exercise card screens.
class ExerciseCardBadge extends StatelessWidget {
  const ExerciseCardBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
