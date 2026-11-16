import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final double score;
  final int timeTakenSeconds;
  final double accuracy;
  final int rank;
  final int streakDays;

  LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.timeTakenSeconds,
    required this.accuracy,
    required this.rank,
    this.streakDays = 1,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, String userId, int rank) {
    return LeaderboardEntry(
      userId: userId,
      displayName: map['displayName'] ?? 'Aspirant',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      timeTakenSeconds: (map['timeTakenSeconds'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      rank: rank,
      streakDays: (map['streakDays'] as num?)?.toInt() ?? 1,
    );
  }
}

class LeaderboardRepository {
  final FirebaseFirestore _firestore;

  LeaderboardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream top 50 leaderboard entries sorted by score desc, then timeTaken asc
  Stream<List<LeaderboardEntry>> streamLeaderboard({
    required String exam, // 'UPSC' or 'TNPSC'
    required String period, // 'daily', 'weekly', 'all_time'
  }) {
    // Read from test_sessions directly for high real-time responsiveness
    Query query = _firestore
        .collection('test_sessions')
        .where('exam', isEqualTo: exam)
        .where('status', isEqualTo: 'completed')
        .where('firstAttempt', isEqualTo: true)
        .orderBy('score', descending: true)
        .orderBy('timeTakenSeconds', descending: false)
        .limit(50);

    return query.snapshots().map((snapshot) {
      int rank = 1;
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final entry = LeaderboardEntry(
          userId: data['userId'] ?? doc.id,
          displayName: data['displayName'] ?? 'Aspirant ${doc.id.substring(0, 5)}',
          score: (data['score'] as num?)?.toDouble() ?? 0.0,
          timeTakenSeconds: (data['timeTakenSeconds'] as num?)?.toInt() ?? 0,
          accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0.0,
          rank: rank++,
          streakDays: (data['speedPracticePercent'] as num?)?.toInt() ?? 1,
        );
        return entry;
      }).toList();
    });
  }
}

