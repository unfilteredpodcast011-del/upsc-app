class TestModel {
  final String id;
  final String title;
  final String type; // 'daily', 'subject', 'full_mock', 'writing'
  final String exam; // 'UPSC' or 'TNPSC'
  final String subject;
  final int questionCount;
  final List<String> questionIds;
  final int defaultDurationSeconds;
  final double negativeMarkingFactor; // default 0.3333
  final double marksPerQuestion; // default 2.0
  final int priceInPaise; // effective payable amount in paise
  final int originalPriceInPaise; // original MRP in paise (e.g. 4900 for ₹49, 11100 for ₹111)
  final String publishDate;
  final bool isLive;

  /// Helper to get official tiered pricing based on question count:
  /// 25q: Original ₹49 -> Discounted ₹1
  /// 50q: Original ₹49 -> Discounted ₹11
  /// 100q: Original ₹111 -> Discounted ₹11
  /// 200q: Original ₹111 -> Discounted ₹11
  static ({int originalRs, int discountedRs, int effectivePaise}) getTierPricing(int questionCount) {
    if (questionCount <= 25) {
      return (originalRs: 49, discountedRs: 1, effectivePaise: 100);
    } else if (questionCount <= 50) {
      return (originalRs: 49, discountedRs: 11, effectivePaise: 1100);
    } else if (questionCount <= 100) {
      return (originalRs: 111, discountedRs: 11, effectivePaise: 1100);
    } else {
      // 200q or higher
      return (originalRs: 111, discountedRs: 11, effectivePaise: 1100);
    }
  }

  TestModel({
    required this.id,
    required this.title,
    required this.type,
    required this.exam,
    required this.subject,
    required this.questionCount,
    required this.questionIds,
    this.defaultDurationSeconds = 1200, // 20 mins default
    this.negativeMarkingFactor = 0.3333,
    this.marksPerQuestion = 2.0,
    int? priceInPaise,
    int? originalPriceInPaise,
    required this.publishDate,
    this.isLive = true,
  })  : priceInPaise = priceInPaise ?? getTierPricing(questionCount).effectivePaise,
        originalPriceInPaise = originalPriceInPaise ?? (getTierPricing(questionCount).originalRs * 100);

  factory TestModel.fromMap(Map<String, dynamic> map, String id) {
    final qCount = (map['questionCount'] as num?)?.toInt() ?? 0;
    final tier = getTierPricing(qCount);
    return TestModel(
      id: id,
      title: map['title'] ?? '',
      type: map['type'] ?? 'daily',
      exam: map['exam'] ?? 'UPSC',
      subject: map['subject'] ?? 'General Studies',
      questionCount: qCount,
      questionIds: List<String>.from(map['questionIds'] ?? []),
      defaultDurationSeconds:
          (map['defaultDurationSeconds'] as num?)?.toInt() ?? 1200,
      negativeMarkingFactor:
          (map['negativeMarkingFactor'] as num?)?.toDouble() ?? 0.3333,
      marksPerQuestion:
          (map['marksPerQuestion'] as num?)?.toDouble() ?? 2.0,
      priceInPaise: (map['priceInPaise'] as num?)?.toInt() ?? tier.effectivePaise,
      originalPriceInPaise: (map['originalPriceInPaise'] as num?)?.toInt() ?? (tier.originalRs * 100),
      publishDate: map['publishDate'] ?? '',
      isLive: map['isLive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'exam': exam,
      'subject': subject,
      'questionCount': questionCount,
      'questionIds': questionIds,
      'defaultDurationSeconds': defaultDurationSeconds,
      'negativeMarkingFactor': negativeMarkingFactor,
      'marksPerQuestion': marksPerQuestion,
      'priceInPaise': priceInPaise,
      'publishDate': publishDate,
      'isLive': isLive,
    };
  }
}

class TestSessionModel {
  final String id;
  final String userId;
  final String testId;
  final String exam;
  final DateTime startedAt;
  final int allowedDurationSeconds;
  final int speedPracticePercent; // 100, 75, 50
  final String status; // 'in_progress', 'completed', 'expired'
  final Map<String, AnswerEntry> answers; // questionId -> AnswerEntry
  final double score;
  final double accuracy;
  final int totalCorrect;
  final int totalWrong;
  final int totalUnanswered;
  final int timeTakenSeconds;
  final DateTime? submittedAt;
  final bool firstAttempt;
  final Map<String, dynamic>? subjectBreakdown;

  TestSessionModel({
    required this.id,
    required this.userId,
    required this.testId,
    required this.exam,
    required this.startedAt,
    required this.allowedDurationSeconds,
    this.speedPracticePercent = 100,
    this.status = 'in_progress',
    required this.answers,
    this.score = 0.0,
    this.accuracy = 0.0,
    this.totalCorrect = 0,
    this.totalWrong = 0,
    this.totalUnanswered = 0,
    this.timeTakenSeconds = 0,
    this.submittedAt,
    this.firstAttempt = true,
    this.subjectBreakdown,
  });

  factory TestSessionModel.fromMap(Map<String, dynamic> map, String id) {
    final rawAnswers = map['answers'] as Map<String, dynamic>? ?? {};
    final parsedAnswers = <String, AnswerEntry>{};
    rawAnswers.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        parsedAnswers[k] = AnswerEntry.fromMap(v);
      }
    });

    return TestSessionModel(
      id: id,
      userId: map['userId'] ?? '',
      testId: map['testId'] ?? '',
      exam: map['exam'] ?? 'UPSC',
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      allowedDurationSeconds:
          (map['allowedDurationSeconds'] as num?)?.toInt() ?? 1200,
      speedPracticePercent:
          (map['speedPracticePercent'] as num?)?.toInt() ?? 100,
      status: map['status'] ?? 'in_progress',
      answers: parsedAnswers,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      totalCorrect: (map['totalCorrect'] as num?)?.toInt() ?? 0,
      totalWrong: (map['totalWrong'] as num?)?.toInt() ?? 0,
      totalUnanswered: (map['totalUnanswered'] as num?)?.toInt() ?? 0,
      timeTakenSeconds: (map['timeTakenSeconds'] as num?)?.toInt() ?? 0,
      submittedAt: map['submittedAt'] != null
          ? DateTime.tryParse(map['submittedAt'].toString())
          : null,
      firstAttempt: map['firstAttempt'] ?? true,
      subjectBreakdown: map['subjectBreakdown'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    final ansMap = <String, dynamic>{};
    answers.forEach((k, v) => ansMap[k] = v.toMap());

    return {
      'id': id,
      'userId': userId,
      'testId': testId,
      'exam': exam,
      'startedAt': startedAt.toIso8601String(),
      'allowedDurationSeconds': allowedDurationSeconds,
      'speedPracticePercent': speedPracticePercent,
      'status': status,
      'answers': ansMap,
      'score': score,
      'accuracy': accuracy,
      'totalCorrect': totalCorrect,
      'totalWrong': totalWrong,
      'totalUnanswered': totalUnanswered,
      'timeTakenSeconds': timeTakenSeconds,
      'submittedAt': submittedAt?.toIso8601String(),
      'firstAttempt': firstAttempt,
      'subjectBreakdown': subjectBreakdown,
    };
  }
}

class AnswerEntry {
  final String? selectedOption; // 'A', 'B', 'C', 'D' or null
  final bool markedForReview;
  final int timeSpentSec;

  AnswerEntry({
    this.selectedOption,
    this.markedForReview = false,
    this.timeSpentSec = 0,
  });

  factory AnswerEntry.fromMap(Map<String, dynamic> map) {
    return AnswerEntry(
      selectedOption: map['selectedOption'],
      markedForReview: map['markedForReview'] ?? false,
      timeSpentSec: (map['timeSpentSec'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedOption': selectedOption,
      'markedForReview': markedForReview,
      'timeSpentSec': timeSpentSec,
    };
  }

  AnswerEntry copyWith({
    String? selectedOption,
    bool? markedForReview,
    int? timeSpentSec,
    bool clearOption = false,
  }) {
    return AnswerEntry(
      selectedOption: clearOption ? null : (selectedOption ?? this.selectedOption),
      markedForReview: markedForReview ?? this.markedForReview,
      timeSpentSec: timeSpentSec ?? this.timeSpentSec,
    );
  }
}

