/// Timing used consistently by exercise cards and the exercise detail page.
const Map<String, int> exerciseSecondsPerRep = {
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
  'Sit-to-stand': 4,
  'Squatting': 4,
  'Thoracic Back Extension': 7,
  'Tummy Twist': 4,
};

String calculateExerciseTotalTime(int repsPerSet, String title) {
  const sets = 3;
  const restBetweenSetsSeconds = 15;
  final secondsPerRep = exerciseSecondsPerRep[title] ?? 4;
  final totalSeconds =
      repsPerSet * sets * secondsPerRep + (sets - 1) * restBetweenSetsSeconds;
  return '${(totalSeconds / 60).ceil()} min';
}
