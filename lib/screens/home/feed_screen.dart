import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/feed_post_model.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BEAST MODE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.feedStream(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state with recovery guidance
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Connection issue', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Check your connection and pull to refresh',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              ]),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.fitness_center, size: 64, color: Color(0xFF0057FF)),
                const SizedBox(height: 16),
                const Text('No workouts yet!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Log your first workout to get started',
                  style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ]),
            );
          }

          final posts = snapshot.data!.docs
              .map((d) => FeedPostModel.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {}, // Firestore stream auto-updates
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              itemBuilder: (context, i) => _FeedCard(
                post: posts[i],
                currentUid: auth.uid ?? '',
                firestore: firestore,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedPostModel post;
  final String currentUid;
  final FirestoreService firestore;

  const _FeedCard({required this.post, required this.currentUid, required this.firestore});

  @override
  Widget build(BuildContext context) {
    final liked = post.likes.contains(currentUid);
    final timeStr = post.createdAt != null
        ? DateFormat('MMM d, h:mm a').format(post.createdAt!)
        : 'Just now';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141824),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF0057FF),
              child: Text(post.uid.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.uid.substring(0, 8),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ])),
          ]),

          const SizedBox(height: 12),
          Text(post.caption, style: const TextStyle(color: Colors.white, fontSize: 15)),

          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(
              onTap: () => firestore.toggleLike(post.postId, currentUid),
              child: Row(children: [
                Icon(liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? const Color(0xFFFF3B30) : Colors.grey, size: 20),
                const SizedBox(width: 4),
                Text('${post.likes.length}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}
