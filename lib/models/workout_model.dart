// ─────────────────────────────────────────
// WorkoutModel
// Firestore collection: /workouts/{workoutId}
// ─────────────────────────────────────────
class WorkoutModel {
  final String uid;
  final String workoutId;
  final String exerciseType; // 'strength' | 'cardio' | 'flexibility'
  final List<ExerciseSet> exercises;
  final double intensityScore; // 1–10 self-rated
  final double restGapHours;   // hours since last workout
  final DateTime? createdAt;
  final List<Map<String, dynamic>> photoUrls;
  final AIFlag? aiFlag;

  WorkoutModel({
    required this.uid,
    this.workoutId = '',
    required this.exerciseType,
    required this.exercises,
    required this.intensityScore,
    required this.restGapHours,
    this.createdAt,
    this.photoUrls = const [],
    this.aiFlag,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'workoutId': workoutId,
        'exerciseType': exerciseType,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'intensityScore': intensityScore,
        'restGapHours': restGapHours,
        'photoUrls': photoUrls,
        'aiFlag': null, // populated by Cloud Function
      };

  factory WorkoutModel.fromMap(Map<String, dynamic> map) => WorkoutModel(
        uid: map['uid'] ?? '',
        workoutId: map['workoutId'] ?? '',
        exerciseType: map['exerciseType'] ?? 'strength',
        exercises: (map['exercises'] as List<dynamic>? ?? [])
            .map((e) => ExerciseSet.fromMap(e))
            .toList(),
        intensityScore: (map['intensityScore'] ?? 5).toDouble(),
        restGapHours: (map['restGapHours'] ?? 24).toDouble(),
        photoUrls: List<Map<String, dynamic>>.from(map['photoUrls'] ?? []),
        aiFlag: map['aiFlag'] != null ? AIFlag.fromMap(map['aiFlag']) : null,
      );
}

class ExerciseSet {
  final String name;
  final int sets;
  final int reps;
  final double weight; // kg

  ExerciseSet({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
      };

  factory ExerciseSet.fromMap(Map<String, dynamic> map) => ExerciseSet(
        name: map['name'] ?? '',
        sets: map['sets'] ?? 0,
        reps: map['reps'] ?? 0,
        weight: (map['weight'] ?? 0).toDouble(),
      );
}

// AI overexertion flag — populated by Cloud Function
class AIFlag {
  final bool triggered;
  final List<String> reasons;
  final String severity; // 'caution' | 'warning'

  AIFlag({
    required this.triggered,
    required this.reasons,
    required this.severity,
  });

  factory AIFlag.fromMap(Map<String, dynamic> map) => AIFlag(
        triggered: map['triggered'] ?? false,
        reasons: List<String>.from(map['reasons'] ?? []),
        severity: map['severity'] ?? 'caution',
      );
}
