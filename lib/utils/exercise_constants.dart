// This file centralises the four exercises that can save reps.
// The titles must match exactly the `Exercise.title` strings.
const List<String> trackedExerciseTitles = [
  'Circumduction',
  'Squatting',
  'Side Bending (Right)',
  'Sit-to-stand',
];

// Map from exercise title (as shown in the app) to the coach ID used in exercises.js.
const Map<String, String> exerciseTitleToCoachId = {
  'Circumduction': 'circumduction',
  'Squatting': 'squat',
  'Side Bending (Right)': 'side_bend_right',
  'Sit-to-stand': 'sit_to_stand',
};

// Helper to get coach ID for a title.
String? coachIdForTitle(String title) => exerciseTitleToCoachId[title];