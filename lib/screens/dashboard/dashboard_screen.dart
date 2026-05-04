import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/workout_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.workoutsStream(auth.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final workouts = snapshot.hasData
              ? snapshot.data!.docs
                  .map((d) => WorkoutModel.fromMap(d.data() as Map<String, dynamic>))
                  .toList()
              : <WorkoutModel>[];

          final totalWorkouts = workouts.length;
          final avgIntensity = workouts.isEmpty
              ? 0.0
              : workouts.map((w) => w.intensityScore).reduce((a, b) => a + b) / workouts.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Stats row
              Row(children: [
                _StatCard(label: 'Total Workouts', value: '$totalWorkouts'),
                const SizedBox(width: 12),
                _StatCard(label: 'Avg Intensity', value: avgIntensity.toStringAsFixed(1)),
                const SizedBox(width: 12),
                _StatCard(label: 'This Week', value: '${_thisWeekCount(workouts)}'),
              ]),

              const SizedBox(height: 24),

              // Intensity chart
              const Text('Intensity Over Time',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: workouts.length < 2
                    ? const Center(child: Text('Log at least 2 workouts to see chart',
                        style: TextStyle(color: Colors.grey)))
                    : LineChart(_intensityChartData(workouts)),
              ),

              const SizedBox(height: 24),

              // Exercise type breakdown
              const Text('Exercise Types',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: workouts.isEmpty
                    ? const Center(child: Text('No data yet', style: TextStyle(color: Colors.grey)))
                    : PieChart(_exerciseTypeChartData(workouts)),
              ),

              const SizedBox(height: 24),

              // Recent workouts list
              const Text('Recent Workouts',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...workouts.take(5).map((w) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(_typeIcon(w.exerciseType), color: const Color(0xFF0057FF)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.exerciseType[0].toUpperCase() + w.exerciseType.substring(1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${w.exercises.length} exercises',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0057FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${w.intensityScore.toInt()}/10',
                      style: const TextStyle(color: Color(0xFF0057FF), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ]),
              )),
            ]),
          );
        },
      ),
    );
  }

  int _thisWeekCount(List<WorkoutModel> workouts) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return workouts.where((w) => w.createdAt != null && w.createdAt!.isAfter(weekAgo)).length;
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'cardio': return Icons.directions_run;
      case 'flexibility': return Icons.self_improvement;
      default: return Icons.fitness_center;
    }
  }

  LineChartData _intensityChartData(List<WorkoutModel> workouts) {
    final spots = workouts.reversed.toList().asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), e.value.intensityScore)).toList();

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFF0057FF),
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF0057FF).withOpacity(0.1),
          ),
          dotData: FlDotData(show: false),
        ),
      ],
    );
  }

  PieChartData _exerciseTypeChartData(List<WorkoutModel> workouts) {
    final counts = <String, int>{};
    for (final w in workouts) {
      counts[w.exerciseType] = (counts[w.exerciseType] ?? 0) + 1;
    }
    final colors = [const Color(0xFF0057FF), const Color(0xFFFF3B30), Colors.amber];
    final entries = counts.entries.toList();

    return PieChartData(
      sections: entries.asMap().entries.map((e) => PieChartSectionData(
        value: e.value.value.toDouble(),
        title: e.value.key,
        color: colors[e.key % colors.length],
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      )).toList(),
      sectionsSpace: 3,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141824),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
