class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'student' or 'admin'
  final String targetExam; // 'UPSC' or 'TNPSC' or 'BOTH'
  final String preferredLanguage; // 'en', 'ta', 'hi'
  final int streakCount;
  final int totalPoints;
  final List<String> badges;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'student',
    this.targetExam = 'UPSC',
    this.preferredLanguage = 'en',
    this.streakCount = 0,
    this.totalPoints = 0,
    this.badges = const [],
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'student',
      targetExam: map['targetExam'] ?? 'UPSC',
      preferredLanguage: map['preferredLanguage'] ?? 'en',
      streakCount: (map['streakCount'] as num?)?.toInt() ?? 0,
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'targetExam': targetExam,
      'preferredLanguage': preferredLanguage,
      'streakCount': streakCount,
      'totalPoints': totalPoints,
      'badges': badges,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? role,
    String? targetExam,
    String? preferredLanguage,
    int? streakCount,
    int? totalPoints,
    List<String>? badges,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      targetExam: targetExam ?? this.targetExam,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      streakCount: streakCount ?? this.streakCount,
      totalPoints: totalPoints ?? this.totalPoints,
      badges: badges ?? this.badges,
      createdAt: createdAt,
    );
  }
}

