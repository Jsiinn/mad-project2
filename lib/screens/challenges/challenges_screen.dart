import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/feed_post_model.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateChallenge(context, auth, firestore),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: firestore.challengesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load challenges',
              style: TextStyle(color: Colors.grey)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.emoji_events, size: 64, color: Color(0xFF0057FF)),
              SizedBox(height: 16),
              Text('No challenges yet!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Tap + to create one', style: TextStyle(color: Colors.grey)),
            ]));
          }

          final challenges = snapshot.data!.docs
              .map((d) => ChallengeModel.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: challenges.length,
            itemBuilder: (context, i) => _ChallengeCard(
              challenge: challenges[i],
              currentUid: auth.uid ?? '',
              firestore: firestore,
            ),
          );
        },
      ),
    );
  }

  void _showCreateChallenge(BuildContext context, AuthService auth, FirestoreService firestore) {
    final titleController = TextEditingController();
    String metric = 'workoutCount';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141824),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('New Challenge', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Challenge Title', filled: true, fillColor: Color(0xFF0A0E1A)),
            ),
            const SizedBox(height: 16),
            const Text('Metric', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            ...['workoutCount', 'totalVolume', 'streak'].map((m) =>
              RadioListTile<String>(
                title: Text(m, style: const TextStyle(color: Colors.white)),
                value: m, groupValue: metric,
                activeColor: const Color(0xFF0057FF),
                onChanged: (v) => setModalState(() => metric = v!),
              )
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;
                await firestore.createChallenge(ChallengeModel(
                  title: titleController.text,
                  creatorUid: auth.uid!,
                  metric: metric,
                  participants: [auth.uid!],
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Challenge'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final String currentUid;
  final FirestoreService firestore;

  const _ChallengeCard({required this.challenge, required this.currentUid, required this.firestore});

  @override
  Widget build(BuildContext context) {
    final joined = challenge.participants.contains(currentUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0057FF).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(challenge.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          if (!joined)
            ElevatedButton(
              onPressed: () => firestore.joinChallenge(challenge.challengeId, currentUid),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('Join', style: TextStyle(fontSize: 13)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0057FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Joined', style: TextStyle(color: Color(0xFF0057FF), fontSize: 13)),
            ),
        ]),
        const SizedBox(height: 8),
        Text('${challenge.participants.length} participants • ${challenge.metric}',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),

        if (challenge.leaderboard.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Leaderboard', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          ...challenge.leaderboard.take(3).toList().asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Text('#${e.key + 1}', style: TextStyle(
                  color: e.key == 0 ? Colors.amber : Colors.grey, fontSize: 13)),
                const SizedBox(width: 8),
                Text(e.value['uid'].toString().substring(0, 8),
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                const Spacer(),
                Text('${e.value['score']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            )
          ),
        ],
      ]),
    );
  }
}
