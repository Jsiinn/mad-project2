import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/workout_model.dart';

class LogWorkoutScreen extends StatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  String _exerciseType = 'strength';
  double _intensityScore = 5;
  double _restGapHours = 24;
  bool _saving = false;
  String? _savedWorkoutId;

  final List<Map<String, dynamic>> _exercises = [];

  Future<void> _saveWorkout() async {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();

    setState(() => _saving = true);

    try {
      final workout = WorkoutModel(
        uid: auth.uid!,
        exerciseType: _exerciseType,
        exercises: _exercises
            .map((e) => ExerciseSet(
                  name: e['name'] ?? 'Exercise',
                  sets: e['sets'] ?? 3,
                  reps: e['reps'] ?? 10,
                  weight: (e['weight'] ?? 0).toDouble(),
                ))
            .toList(),
        intensityScore: _intensityScore,
        restGapHours: _restGapHours,
      );

      final workoutId = await firestore.logWorkout(workout);

      setState(() {
        _saving = false;
        _savedWorkoutId = workoutId;
      });

      // Listen for AI flag in real time
      _listenForAIFlag(workoutId);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _listenForAIFlag(String workoutId) {
    final firestore = context.read<FirestoreService>();

    firestore.workoutStream(workoutId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data() as Map<String, dynamic>;
      final flagData = data['aiFlag'];
      if (flagData != null && flagData['triggered'] == true) {
        final flag = AIFlag.fromMap(flagData);
        _showAIOverlay(flag, workoutId);
      }
    });
  }

  void _showAIOverlay(AIFlag flag, String workoutId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            flag.severity == 'warning' ? Icons.warning_amber : Icons.info_outline,
            color: flag.severity == 'warning' ? Colors.orange : Colors.yellow,
          ),
          const SizedBox(width: 8),
          Text(
            flag.severity == 'warning' ? 'Overexertion Warning' : 'Recovery Caution',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Our AI detected the following:',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            ...flag.reasons.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• ', style: TextStyle(color: Color(0xFFFF3B30))),
                Expanded(child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 13))),
              ]),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Good call! Rest up 💪"),
                    backgroundColor: Color(0xFF0057FF)),
              );
            },
            child: const Text("Got it — I'll rest soon",
              style: TextStyle(color: Color(0xFF0057FF))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30)),
            onPressed: () {
              // Confirm flag in Firestore for tracking
              FirebaseFirestore.instance
                  .collection('workouts')
                  .doc(workoutId)
                  .update({'aiFlag.userConfirmed': true});
              Navigator.pop(context);
            },
            child: const Text('Log anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Workout',
        style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Exercise type selector
          const Text('Exercise Type', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: ['strength', 'cardio', 'flexibility'].map((type) {
            final selected = _exerciseType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _exerciseType = type),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0057FF) : const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(type[0].toUpperCase() + type.substring(1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    )),
                ),
              ),
            );
          }).toList()),

          const SizedBox(height: 24),

          // Intensity slider
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Intensity', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text('${_intensityScore.toInt()}/10',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: _intensityScore,
            min: 1, max: 10, divisions: 9,
            activeColor: const Color(0xFF0057FF),
            onChanged: (v) => setState(() => _intensityScore = v),
          ),

          const SizedBox(height: 16),

          // Rest gap
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Hours since last workout', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text('${_restGapHours.toInt()}h',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: _restGapHours,
            min: 1, max: 72, divisions: 71,
            activeColor: const Color(0xFF0057FF),
            onChanged: (v) => setState(() => _restGapHours = v),
          ),

          const SizedBox(height: 24),

          // Exercise list
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Exercises', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ]),

          ..._exercises.asMap().entries.map((e) => _ExerciseRow(
            data: e.value,
            onRemove: () => setState(() => _exercises.removeAt(e.key)),
          )),

          if (_exercises.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141824),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Tap + Add to log exercises',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saving ? null : _saveWorkout,
            child: _saving
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Workout 💪',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  void _addExercise() {
    setState(() => _exercises.add({'name': 'Exercise', 'sets': 3, 'reps': 10, 'weight': 0.0}));
  }
}

class _ExerciseRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRemove;

  const _ExerciseRow({required this.data, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.drag_handle, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(data['name'], style: const TextStyle(color: Colors.white))),
        Text('${data['sets']}x${data['reps']} @ ${data['weight']}kg',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onRemove),
      ]),
    );
  }
}
