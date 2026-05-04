import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF141824),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to sign out?',
                    style: TextStyle(color: Colors.grey)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthService>().signOut();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(auth.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final displayName = data['displayName'] ?? 'Athlete';
          final email = data['email'] ?? '';
          final avatarUrl = data['avatarUrl'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF0057FF),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(email, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),

              const SizedBox(height: 24),

              // Stats row
              Row(children: [
                _ProfileStat(label: 'Workouts', value: '${stats['totalWorkouts'] ?? 0}'),
                _ProfileStat(label: 'Streak', value: '${stats['currentStreak'] ?? 0}d'),
                _ProfileStat(label: 'Volume', value: '${stats['totalVolume'] ?? 0}kg'),
              ]),

              const SizedBox(height: 24),

              // Weekly goal
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Weekly Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _GoalRow(label: 'Strength sessions', current: 0,
                    goal: (data['weeklyGoal']?['strengthDays'] ?? 3)),
                  const SizedBox(height: 8),
                  _GoalRow(label: 'Cardio sessions', current: 0,
                    goal: (data['weeklyGoal']?['cardioDays'] ?? 2)),
                ]),
              ),

              const SizedBox(height: 16),

              // Notification preferences
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _NotifTile(label: 'Challenge Alerts',
                    value: data['notificationPreferences']?['challengeAlerts'] ?? true,
                    uid: auth.uid!, field: 'challengeAlerts'),
                  _NotifTile(label: 'Milestone Alerts',
                    value: data['notificationPreferences']?['milestoneAlerts'] ?? true,
                    uid: auth.uid!, field: 'milestoneAlerts'),
                  _NotifTile(label: 'Workout Reminders',
                    value: data['notificationPreferences']?['reminderAlerts'] ?? false,
                    uid: auth.uid!, field: 'reminderAlerts'),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF141824), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _GoalRow extends StatelessWidget {
  final String label;
  final int current;
  final int goal;
  const _GoalRow({required this.label, required this.current, required this.goal});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
      Text('$current/$goal', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    ]),
    const SizedBox(height: 4),
    LinearProgressIndicator(
      value: goal > 0 ? current / goal : 0,
      backgroundColor: Colors.white12,
      color: const Color(0xFF0057FF),
      borderRadius: BorderRadius.circular(4),
    ),
  ]);
}

class _NotifTile extends StatelessWidget {
  final String label;
  final bool value;
  final String uid;
  final String field;
  const _NotifTile({required this.label, required this.value, required this.uid, required this.field});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
    Switch(
      value: value,
      activeColor: const Color(0xFF0057FF),
      onChanged: (v) {
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'notificationPreferences.$field': v,
        });
      },
    ),
  ]);
}
