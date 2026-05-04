import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';
import '../models/feed_post_model.dart';
import '../models/challenge_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────
  // USER
  // ─────────────────────────────────────────

  /// Stream the current user's profile document
  Stream<DocumentSnapshot> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  /// Update user profile fields
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // ─────────────────────────────────────────
  // WORKOUTS
  // ─────────────────────────────────────────

  /// Log a new workout document to Firestore
  /// Cloud Function will trigger AI overexertion check on write
  Future<String> logWorkout(WorkoutModel workout) async {
    final ref = _db.collection('workouts').doc();
    final data = workout.toMap()
      ..addAll({'workoutId': ref.id, 'createdAt': FieldValue.serverTimestamp()});

    await ref.set(data);

    // Also create a feed post for social activity
    await _createFeedPost(
      uid: workout.uid,
      workoutId: ref.id,
      caption: '${workout.exerciseType} session logged 💪',
    );

    return ref.id;
  }

  /// Stream workout documents for AI flag updates (real-time overexertion result)
  Stream<DocumentSnapshot> workoutStream(String workoutId) {
    return _db.collection('workouts').doc(workoutId).snapshots();
  }

  /// Get recent workouts for a user (for dashboard + AI rolling average)
  Future<List<WorkoutModel>> getRecentWorkouts(String uid, {int limit = 10}) async {
    final snap = await _db
        .collection('workouts')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) => WorkoutModel.fromMap(d.data())).toList();
  }

  /// Stream all workouts for a user (progress dashboard)
  Stream<QuerySnapshot> workoutsStream(String uid) {
    return _db
        .collection('workouts')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─────────────────────────────────────────
  // SOCIAL FEED
  // ─────────────────────────────────────────

  /// Stream the global activity feed (real-time onSnapshot)
  Stream<QuerySnapshot> feedStream() {
    return _db
        .collection('feed')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  Future<void> _createFeedPost({
    required String uid,
    required String workoutId,
    required String caption,
  }) async {
    await _db.collection('feed').add({
      'uid': uid,
      'workoutId': workoutId,
      'caption': caption,
      'likes': [],
      'reactions': {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle like on a feed post (atomic array union/remove)
  Future<void> toggleLike(String postId, String uid) async {
    final ref = _db.collection('feed').doc(postId);
    final snap = await ref.get();
    final likes = List<String>.from(snap.data()?['likes'] ?? []);

    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  // ─────────────────────────────────────────
  // CHALLENGES
  // ─────────────────────────────────────────

  /// Stream all open challenges
  Stream<QuerySnapshot> challengesStream() {
    return _db
        .collection('challenges')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Create a new challenge
  Future<void> createChallenge(ChallengeModel challenge) async {
    final ref = _db.collection('challenges').doc();
    await ref.set(challenge.toMap()
      ..addAll({
        'challengeId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      }));
  }

  /// Join a challenge — add uid to participants array (atomic)
  Future<void> joinChallenge(String challengeId, String uid) async {
    await _db.collection('challenges').doc(challengeId).update({
      'participants': FieldValue.arrayUnion([uid]),
    });
  }

  /// Update leaderboard entry for a challenge (atomic transaction)
  Future<void> updateLeaderboard(
      String challengeId, String uid, int newScore) async {
    final ref = _db.collection('challenges').doc(challengeId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final leaderboard =
          List<Map<String, dynamic>>.from(snap.data()?['leaderboard'] ?? []);

      final idx = leaderboard.indexWhere((e) => e['uid'] == uid);
      if (idx >= 0) {
        leaderboard[idx]['score'] = newScore;
      } else {
        leaderboard.add({'uid': uid, 'score': newScore});
      }

      leaderboard.sort((a, b) => b['score'].compareTo(a['score']));
      tx.update(ref, {'leaderboard': leaderboard});
    });
  }

  // ─────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────

  /// Stream notifications for a user
  Stream<QuerySnapshot> notificationsStream(String uid) {
    return _db
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }
}
