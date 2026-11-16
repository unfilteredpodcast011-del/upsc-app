import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../domain/test_model.dart';
import '../domain/question_model.dart';

class TestRepository {
  final FirebaseFirestore _firestore;

  TestRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of available live tests for an exam (UPSC or TNPSC)
  Stream<List<TestModel>> streamLiveTests(String exam) {
    return _firestore
        .collection('tests')
        .where('exam', isEqualTo: exam)
        .where('isLive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TestModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Check if user has unlocked the test (via Rs.1 Razorpay payment)
  Future<bool> isTestUnlocked({
    required String userId,
    required String testId,
  }) async {
    final doc = await _firestore
        .collection('user_unlocked_tests')
        .doc('${userId}_$testId')
        .get();
    return doc.exists;
  }

  /// Fetch full test model
  Future<TestModel?> getTestById(String testId) async {
    final doc = await _firestore.collection('tests').doc(testId).get();
    if (!doc.exists || doc.data() == null) return null;
    return TestModel.fromMap(doc.data()!, doc.id);
  }

  /// Fetch question list for a test
  Future<List<QuestionModel>> getQuestionsForTest(List<String> questionIds) async {
    final questions = <QuestionModel>[];
    // In batches of 10 for Firestore 'whereIn' limits or direct get
    for (int i = 0; i < questionIds.length; i += 10) {
      final chunk = questionIds.sublist(
        i,
        i + 10 > questionIds.length ? questionIds.length : i + 10,
      );
      final snap = await _firestore
          .collection('questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        questions.add(QuestionModel.fromMap(doc.data(), doc.id));
      }
    }
    return questions;
  }

  /// Start or resume a test session with serverTimestamp validation
  Future<TestSessionModel> startOrResumeSession({
    required String userId,
    required String testId,
    required String exam,
    required int defaultDurationSeconds,
    required int speedOption, // 100, 75, or 50%
  }) async {
    final sessionId = 'sess_${userId}_$testId';
    final docRef = _firestore.collection('test_sessions').doc(sessionId);
    final doc = await docRef.get();

    final allowedDuration = (defaultDurationSeconds * (speedOption / 100.0)).round();

    if (doc.exists && doc.data() != null) {
      final session = TestSessionModel.fromMap(doc.data()!, sessionId);
      if (session.status == 'in_progress') {
        return session;
      }
    }

    // New Session
    final newSession = TestSessionModel(
      id: sessionId,
      userId: userId,
      testId: testId,
      exam: exam,
      startedAt: DateTime.now(),
      allowedDurationSeconds: allowedDuration,
      speedPracticePercent: speedOption,
      status: 'in_progress',
      answers: {},
    );

    await docRef.set({
      ...newSession.toMap(),
      'startedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Save locally for offline durability
    await _cacheSessionLocally(newSession);

    return newSession;
  }

  /// Incremental save to Firestore & Local Storage
  Future<void> saveAnswerProgress({
    required String sessionId,
    required String questionId,
    required AnswerEntry answer,
  }) async {
    // 1. Save to Firestore
    await _firestore.collection('test_sessions').doc(sessionId).set({
      'answers.$questionId': answer.toMap(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Cache in local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_session_$sessionId';
    final existingJson = prefs.getString(key);
    Map<String, dynamic> data = existingJson != null ? jsonDecode(existingJson) : {};
    data['answers'] = data['answers'] ?? {};
    data['answers'][questionId] = answer.toMap();
    await prefs.setString(key, jsonEncode(data));
  }

  /// Submit and evaluate test session
  Future<TestSessionModel> evaluateAndSubmitSession({
    required String sessionId,
    required String testId,
    required List<QuestionModel> questions,
    required Map<String, AnswerEntry> answers,
    required int timeTakenSeconds,
  }) async {
    int correct = 0;
    int wrong = 0;
    int unanswered = 0;
    final subjectScores = <String, Map<String, int>>{};

    for (final q in questions) {
      final ans = answers[q.id];
      final subj = q.subject;
      subjectScores[subj] = subjectScores[subj] ?? {'correct': 0, 'wrong': 0, 'total': 0};
      subjectScores[subj]!['total'] = subjectScores[subj]!['total']! + 1;

      if (ans == null || ans.selectedOption == null) {
        unanswered++;
      } else if (ans.selectedOption!.toUpperCase() == q.correctAnswer.toUpperCase()) {
        correct++;
        subjectScores[subj]!['correct'] = subjectScores[subj]!['correct']! + 1;
      } else {
        wrong++;
        subjectScores[subj]!['wrong'] = subjectScores[subj]!['wrong']! + 1;
      }
    }

    // Default +2 marks for correct, -0.66 for wrong
    final totalMarks = (correct * 2.0) - (wrong * 0.6666);
    final score = totalMarks < 0 ? 0.0 : double.parse(totalMarks.toStringAsFixed(2));
    final attempted = correct + wrong;
    final accuracy = attempted > 0
        ? double.parse(((correct / attempted) * 100).toStringAsFixed(1))
        : 0.0;

    final docRef = _firestore.collection('test_sessions').doc(sessionId);
    final snap = await docRef.get();
    final firstAttempt = snap.data()?['firstAttempt'] ?? true;

    final updated = TestSessionModel(
      id: sessionId,
      userId: snap.data()?['userId'] ?? '',
      testId: testId,
      exam: snap.data()?['exam'] ?? 'UPSC',
      startedAt: snap.data()?['startedAt'] != null
          ? DateTime.tryParse(snap.data()!['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      allowedDurationSeconds: snap.data()?['allowedDurationSeconds'] ?? 1200,
      speedPracticePercent: snap.data()?['speedPracticePercent'] ?? 100,
      status: 'completed',
      answers: answers,
      score: score,
      accuracy: accuracy,
      totalCorrect: correct,
      totalWrong: wrong,
      totalUnanswered: unanswered,
      timeTakenSeconds: timeTakenSeconds,
      submittedAt: DateTime.now(),
      firstAttempt: firstAttempt,
      subjectBreakdown: subjectScores,
    );

    await docRef.set(updated.toMap(), SetOptions(merge: true));

    // Clear local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_session_$sessionId');

    return updated;
  }

  Future<void> _cacheSessionLocally(TestSessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'local_session_${session.id}',
      jsonEncode(session.toMap()),
    );
  }
}

