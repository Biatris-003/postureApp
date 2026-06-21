import '../../domain/entities/exercises/exercise.dart';
import '../../domain/entities/exercises/exercise_model.dart';

/// Single source of truth for every exercise in the app: the full catalog
/// (id, title, description, reps/sets/duration, difficulty, asset paths)
/// AND the posture → exercise recommendation mapping.
///
/// Nothing else should hardcode exercise metadata. Screens, providers, and
/// the recommendation service all read from here so there's exactly one
/// place to fix a typo, swap an asset, or add an exercise.
///
/// IMPORTANT (reps/sets/difficulty model):
/// - `difficultyLevel` is now a fixed property of the exercise itself
///   (e.g. Circumduction is always Beginner, Plank is always Intermediate),
///   same as `description` or `imageUrl`. It is NEVER derived from posture
///   statistics.
/// - `reps`/`sets` in the catalog below are just the small starting
///   defaults (used until the user has logged real reps via the Weekly
///   Assessment). They are NOT scaled by posture percentage anymore.
/// - The *actual* reps/sets shown in the UI for the 4 tracked exercises
///   come from Firestore (`exerciseProgress`, via
///   `exerciseProgressNotifierProvider`) once the user has completed a
///   Weekly Assessment. Until then, the catalog defaults below are shown.
///   Non-tracked exercises have no rep-tracking mechanism, so they always
///   show their catalog defaults.
class ExerciseData {
  // ───────────────────────────────────────────────────────────────────
  // Recommendation threshold
  // ───────────────────────────────────────────────────────────────────

  /// Percentage-of-readings threshold a bad posture must exceed (within the
  /// selected statistics period — day/week/month) before its exercises are
  /// recommended/shown. e.g. 10 means "more than 10% of readings this
  /// period". Postures at or below this are excluded entirely from
  /// ExercisesTab (see [qualifyingPostures]).
  static const double recommendationThresholdPercent = 10;

  // ───────────────────────────────────────────────────────────────────
  // Master catalog — every exercise in the app, by canonical title.
  // Canonical titles MUST match exercise_constants.dart and the
  // instruction/hold-duration/sec-per-rep maps in exercise_detail_screen.dart.
  //
  // `reps`/`sets`/`difficultyLevel` here are fixed, permanent properties —
  // difficultyLevel reflects how hard the exercise inherently is;
  // reps/sets are just the small starting defaults.
  // ───────────────────────────────────────────────────────────────────

  static final List<Exercise> catalog = [
    Exercise(
      id: 'ex1',
      title: 'Chest Stretch',
      description:
          'Stand in a doorway, press your palms against the frame, and lean '
          'gently forward to open up tight chest and shoulder muscles.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'accessibility_new',
      imageUrl: 'assets/images/exercises/chest_stretch.png',
      videoAssetPath: 'assets/videos/chest_stretch.mp4',
    ),
    Exercise(
      id: 'ex2',
      title: 'Thoracic Back Extension',
      description:
          'Gently arch your upper back backward while standing tall, '
          'opening up the thoracic spine after long periods of forward bending.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/thoracic_back_extension.png',
      videoAssetPath: 'assets/videos/thoracic_back_extension.mp4',
    ),
    Exercise(
      id: 'ex3',
      title: 'Circumduction',
      description:
          'Slow, controlled arm circles that loosen the shoulders and '
          'upper back after sitting in a forward-leaning position.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/circumduction.png',
      videoAssetPath: 'assets/videos/circumduction.mp4',
    ),
    Exercise(
      id: 'ex4',
      title: 'Cat-Cow',
      description:
          'On all fours, alternate between rounding and arching your spine '
          'to mobilize the back and relieve slouched-posture tension.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/cat_cow.png',
      videoAssetPath: 'assets/videos/cat_cow.mp4',
    ),
    Exercise(
      id: 'ex5',
      title: 'Dead Bug',
      description:
          'Lying on your back, slowly extend opposite arm and leg while '
          'keeping your core engaged and lower back flat on the floor.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Intermediate',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/dead_bug.png',
      videoAssetPath: 'assets/videos/dead_bug.mp4',
    ),
    Exercise(
      id: 'ex6',
      title: 'Bird Dog',
      description:
          'On all fours, extend opposite arm and leg while keeping your '
          'spine neutral, building core stability that supports good sitting posture.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/bird_dog.png',
      videoAssetPath: 'assets/videos/bird_dog.mp4',
    ),
    Exercise(
      id: 'ex7',
      title: 'Hip Flexor Stretch',
      description:
          'A kneeling lunge stretch that releases tight hip flexors caused '
          'by long periods of sitting.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/hip_flexor_stretch.png',
      videoAssetPath: 'assets/videos/hip_flexor_stretch.mp4',
    ),
    Exercise(
      id: 'ex8',
      title: 'Tummy Twist',
      description:
          'Standing rotations through the torso that mobilize the spine '
          'and ease stiffness from slouching.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/tummy_twist.png',
      videoAssetPath: 'assets/videos/tummy_twist.mp4',
    ),
    Exercise(
      id: 'ex9',
      title: 'Squatting',
      description:
          'A controlled sit-back squat that strengthens the legs and core, '
          'counteracting the effects of prolonged slouched sitting.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Intermediate',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/squatting.png',
      videoAssetPath: 'assets/videos/squatting.mp4',
    ),
    Exercise(
      id: 'ex10',
      title: 'Plank',
      description:
          'A core-stabilizing hold on forearms and toes that builds the '
          'strength needed to resist arching the lower back.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Intermediate',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/plank.png',
      videoAssetPath: 'assets/videos/plank.mp4',
    ),
    Exercise(
      id: 'ex11',
      title: 'Glute Bridge',
      description:
          'Lying on your back, lift your hips toward the ceiling to '
          'strengthen the glutes and stabilize the pelvis against excess arching.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/glute_bridge.png',
      videoAssetPath: 'assets/videos/glute_bridge.mp4',
    ),
    Exercise(
      id: 'ex12',
      title: 'Leg Lift',
      description:
          'Lying flat, raise both legs together with control to build '
          'lower-abdominal strength that supports the lower back.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/leg_lift.png',
      videoAssetPath: 'assets/videos/leg_lift.mp4',
    ),
    Exercise(
      id: 'ex13',
      title: 'Right Side Leg Raise',
      description:
          'Lying on your right side, raise the top leg with control to '
          'strengthen the right hip — used to counterbalance a left-leaning posture.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/right_side_leg_raise.png',
      videoAssetPath: 'assets/videos/right_side_leg_raise.mp4',
    ),
    Exercise(
      id: 'ex14',
      title: 'Side Bending Right',
      description:
          'A standing side stretch toward the right that lengthens the '
          'left side of the torso — used to counterbalance a left-leaning posture.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/side_bending_right.png',
      videoAssetPath: 'assets/videos/side_bending_right.mp4',
    ),
    Exercise(
      id: 'ex15',
      title: 'Left Side Plank',
      description:
          'A side plank held on the left forearm that strengthens the '
          'left side of the core — used to counterbalance a right-leaning posture.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Intermediate',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/left_side_plank.png',
      videoAssetPath: 'assets/videos/left_side_plank.mp4',
    ),
    Exercise(
      id: 'ex16',
      title: 'Micro Break Walking',
      description:
          'A short, relaxed walk away from the desk to break up long '
          'periods of static sitting.',
      reps: '1 rep',
      sets: '1 set',
      duration: '3 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'directions_walk',
      imageUrl: 'assets/images/exercises/micro_break_walking.png',
      videoAssetPath: 'assets/videos/micro_break_walking.mp4',
    ),
    Exercise(
      id: 'ex17',
      title: 'Neck Rotation',
      description:
          'Slow head turns from side to side that relieve neck tension '
          'built up from long sitting sessions.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'accessibility_new',
      imageUrl: 'assets/images/exercises/neck_rotation.png',
      videoAssetPath: 'assets/videos/neck_rotation.mp4',
    ),
    Exercise(
      id: 'ex18',
      title: 'Sit-to-stand',
      description:
          'Standing up from a seated position and sitting back down with '
          'control, getting the legs and core moving after sitting still.',
      reps: '5 reps',
      sets: '3 sets',
      duration: '5 mins',
      difficultyLevel: 'Beginner',
      iconCode: 'fitness_center',
      imageUrl: 'assets/images/exercises/sit_to_stand.png',
      videoAssetPath: 'assets/videos/sit_to_stand.mp4',
    ),
  ];

  /// Fast lookup: canonical title (case-insensitive, trimmed) → Exercise.
  static final Map<String, Exercise> _byTitle = {
    for (final e in catalog) e.title.toLowerCase().trim(): e,
  };

  /// Look up a catalog exercise by title. Matching is case-insensitive and
  /// trims whitespace, so callers don't need to worry about exact casing.
  static Exercise? findByTitle(String title) => _byTitle[title.toLowerCase().trim()];

  /// The 3 "good posture" exercises — general mobility/movement breaks,
  /// not tied to any bad posture. Useful for default/fallback plans.
  static const List<String> uprightExerciseTitles = [
    'Sit-to-stand',
    'Neck Rotation',
    'Micro Break Walking',
  ];

  // ───────────────────────────────────────────────────────────────────
  // Posture → exercise recommendation mapping
  // ───────────────────────────────────────────────────────────────────

  /// Maps each BAD posture label (as produced by AnalyticsService /
  /// PostureClassification.postureLabel, and used in statistics_tab.dart's
  /// postureCountsCache) to the list of exercise titles that target it.
  ///
  /// NOTE: keys here MUST exactly match the postureLabel strings coming
  /// out of Firestore / AnalyticsService.calculatePostureCounts():
  ///   upright, forward_bending, backward_bending, slouching,
  ///   left_bending, right_bending
  /// 'upright' is intentionally absent — it's a good posture, never
  /// recommended against.
  static const Map<String, List<String>> postureExercisesMap = {

    'forward_bending': [
      'Chest Stretch',
      'Thoracic Back Extension',
      'Circumduction',
    ],

    'slouching': [
      'Cat-Cow',
      'Dead Bug',
      'Bird Dog',
      'Hip Flexor Stretch',
      'Tummy Twist',
      'Squatting',
    ],

    // Backward bending / arching → hyperlordosis-targeting exercises.
    'backward_bending': [
      'Plank',
      'Glute Bridge',
      'Leg Lift',
      'Hip Flexor Stretch',
    ],

    // Leaning left → strengthen/stretch the opposite (right) side.
    'left_bending': [
      'Right Side Leg Raise',
      'Side Bending Right',
    ],

    // Leaning right → strengthen/stretch the opposite (left) side.
    'right_bending': [
      'Left Side Plank',
    ],
  };

  // ───────────────────────────────────────────────────────────────────
  // Posture percentage helpers
  // ───────────────────────────────────────────────────────────────────

  /// Computes the percentage of [totalReadings] each bad posture
  /// represents, keeping only postures that exceed
  /// [recommendationThresholdPercent]. 'upright' is always excluded since
  /// it has no entry in [postureExercisesMap].
  ///
  /// Returned map is NOT ordered — callers that need postures sorted by
  /// percentage (e.g. ExercisesTab) should sort the entries themselves,
  /// or use [qualifyingPosturesSortedByPercentage].
  static Map<String, double> qualifyingPostures(
    Map<String, int> postureCountMap,
    int totalReadings,
  ) {
    final qualifying = <String, double>{};
    for (final entry in postureCountMap.entries) {
      if (entry.key == 'upright') continue;
      final percentage = totalReadings > 0
          ? ((entry.value / totalReadings) * 100).toDouble()
          : 0.0;
      if (percentage > recommendationThresholdPercent) {
        qualifying[entry.key] = percentage;
      }
    }
    return qualifying;
  }

  /// Same as [qualifyingPostures] but returned as a list of
  /// `MapEntry<postureKey, percentage>` sorted by percentage descending
  /// (highest/most-problematic posture first). This is the order
  /// ExercisesTab should walk when building its exercise list.
  static List<MapEntry<String, double>> qualifyingPosturesSortedByPercentage(
    Map<String, int> postureCountMap,
    int totalReadings,
  ) {
    final qualifying = qualifyingPostures(postureCountMap, totalReadings);
    final entries = qualifying.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Builds exercise models for the given posture counts, ordered by
  /// posture percentage (highest first), pulling full Exercise data (with
  /// real descriptions, fixed difficulty, and fixed default reps/sets)
  /// from [catalog] rather than constructing blank-description placeholders.
  ///
  /// Postures at or below [recommendationThresholdPercent] are excluded
  /// entirely — their exercises do not appear in the result at all.
  ///
  /// Reps/sets/difficulty are NOT scaled by percentage anymore — they come
  /// straight from the catalog. The percentage is used purely to decide
  /// (a) which postures qualify and (b) the order exercises appear in.
  static List<ExerciseModel> buildExerciseModels({
    required Map<String, int> postureCountMap,
    required int totalReadings,
  }) {
    final exercises = <ExerciseModel>[];
    final seenTitles = <String>{};

    final sortedPostures = qualifyingPosturesSortedByPercentage(
      postureCountMap,
      totalReadings,
    );

    if (sortedPostures.isEmpty) return [];

    for (final entry in sortedPostures) {
      final posture = entry.key;

      final titles = postureExercisesMap[posture] ?? [];
      for (final title in titles) {
        final key = title.toLowerCase().trim();
        if (seenTitles.contains(key)) continue;
        seenTitles.add(key);

        final base = findByTitle(title);
        if (base == null) {
          // Should never happen if postureExercisesMap titles are kept in
          // sync with the catalog above — skip rather than fabricate.
          continue;
        }

        exercises.add(ExerciseModel(
          id: base.id,
          title: base.title,
          description: base.description,
          reps: base.reps,
          sets: base.sets,
          duration: base.duration,
          difficultyLevel: base.difficultyLevel,
          iconCode: base.iconCode,
          imageUrl: base.imageUrl,
          videoAssetPath: base.videoAssetPath,
          postureKey: posture,
        ));
      }
    }

    return exercises;
  }
}