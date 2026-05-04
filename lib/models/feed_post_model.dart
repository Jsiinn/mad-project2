// ─────────────────────────────────────────
// FeedPostModel
// Firestore collection: /feed/{postId}
// ─────────────────────────────────────────
class FeedPostModel {
  final String postId;
  final String uid;
  final String workoutId;
  final String caption;
  final List<String> likes;
  final Map<String, dynamic> reactions;
  final DateTime? createdAt;

  FeedPostModel({
    required this.postId,
    required this.uid,
    required this.workoutId,
    required this.caption,
    this.likes = const [],
    this.reactions = const {},
    this.createdAt,
  });

  factory FeedPostModel.fromMap(String id, Map<String, dynamic> map) =>
      FeedPostModel(
        postId: id,
        uid: map['uid'] ?? '',
        workoutId: map['workoutId'] ?? '',
        caption: map['caption'] ?? '',
        likes: List<String>.from(map['likes'] ?? []),
        reactions: Map<String, dynamic>.from(map['reactions'] ?? {}),
        createdAt: (map['createdAt'] as dynamic)?.toDate(),
      );
}

// ─────────────────────────────────────────
// ChallengeModel
// Firestore collection: /challenges/{challengeId}
// ─────────────────────────────────────────
class ChallengeModel {
  final String challengeId;
  final String title;
  final String creatorUid;
  final List<String> participants;
  final String metric; // 'totalVolume' | 'workoutCount' | 'streak'
  final List<Map<String, dynamic>> leaderboard;
  final String status; // 'open' | 'closed'
  final DateTime? endsAt;

  ChallengeModel({
    this.challengeId = '',
    required this.title,
    required this.creatorUid,
    this.participants = const [],
    required this.metric,
    this.leaderboard = const [],
    this.status = 'open',
    this.endsAt,
  });

  Map<String, dynamic> toMap() => {
        'challengeId': challengeId,
        'title': title,
        'creatorUid': creatorUid,
        'participants': participants,
        'metric': metric,
        'leaderboard': leaderboard,
        'status': status,
        'endsAt': endsAt?.toIso8601String(),
      };

  factory ChallengeModel.fromMap(String id, Map<String, dynamic> map) =>
      ChallengeModel(
        challengeId: id,
        title: map['title'] ?? '',
        creatorUid: map['creatorUid'] ?? '',
        participants: List<String>.from(map['participants'] ?? []),
        metric: map['metric'] ?? 'workoutCount',
        leaderboard:
            List<Map<String, dynamic>>.from(map['leaderboard'] ?? []),
        status: map['status'] ?? 'open',
      );
}
