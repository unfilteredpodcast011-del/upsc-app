import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';

class TestRepository {
  List<QuestionModel>? _cachedTnpscQuestions;
  List<QuestionModel>? _cachedUpscQuestions;

  /// Load questions from assets/data/
  Future<List<QuestionModel>> _loadQuestionsForExam(String exam) async {
    if (exam == 'TNPSC') {
      if (_cachedTnpscQuestions != null) return _cachedTnpscQuestions!;
      final jsonStr = await rootBundle.loadString('assets/data/tnpsc_questions.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      _cachedTnpscQuestions = list.map((item) {
        final Map<String, dynamic> m = item;
        final opts = (m['options'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {};
        return QuestionModel(
          id: m['id'] ?? '',
          exam: 'TNPSC',
          subject: m['subject'] ?? 'General Studies',
          topic: m['topic'] ?? '',
          ncertChapter: '',
          difficulty: 'medium',
          publishDate: '2026-11-16',
          correctAnswer: m['correct_answer'] ?? 'A',
          normalizedText: m['question'] ?? '',
          translations: {
            'en': QuestionTranslation(
              question: m['question'] ?? '',
              options: opts,
              explanation: 'Correct Answer: ${m['correct_answer']}',
            ),
          },
        );
      }).toList();
      return _cachedTnpscQuestions!;
    } else {
      if (_cachedUpscQuestions != null) return _cachedUpscQuestions!;
      final jsonStr = await rootBundle.loadString('assets/data/upsc_questions.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      _cachedUpscQuestions = list.map((item) {
        final Map<String, dynamic> m = item;
        final opts = (m['options'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {};
        return QuestionModel(
          id: m['id'] ?? '',
          exam: 'UPSC',
          subject: m['subject'] ?? 'General Studies',
          topic: m['topic'] ?? '',
          ncertChapter: '',
          difficulty: 'medium',
          publishDate: '2026-11-16',
          correctAnswer: m['correct_answer'] ?? 'A',
          normalizedText: m['question'] ?? '',
          translations: {
            'en': QuestionTranslation(
              question: m['question'] ?? '',
              options: opts,
              explanation: m['explanation'] ?? 'Correct Answer: ${m['correct_answer']}',
            ),
          },
        );
      }).toList();
      return _cachedUpscQuestions!;
    }
  }

  /// Stream of available live tests for an exam (UPSC or TNPSC)
  Stream<List<TestModel>> streamLiveTests(String exam) async* {
    yield await getLiveTests(exam);
  }

  /// Get defined tests for an exam
  Future<List<TestModel>> getLiveTests(String exam) async {
    if (exam == 'TNPSC') {
      return [
        TestModel(
          id: 'tnpsc_mock_daily_1',
          title: 'TNPSC Group 1/2 Daily Prelims Mock (Random 25)',
          type: 'daily',
          exam: 'TNPSC',
          subject: 'General Studies & Mental Ability',
          questionCount: 25,
          questionIds: [],
          defaultDurationSeconds: 1500, // 25 mins
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'tnpsc_mock_full_1',
          title: 'TNPSC Full Model Mock Test (50 Questions)',
          type: 'full_mock',
          exam: 'TNPSC',
          subject: 'Comprehensive Syllabus (From 1000 Bank)',
          questionCount: 50,
          questionIds: [],
          defaultDurationSeconds: 3000, // 50 mins
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'tnpsc_aptitude_special',
          title: 'TNPSC Aptitude & Mental Ability Special (20 Qs)',
          type: 'subject',
          exam: 'TNPSC',
          subject: 'General Aptitude',
          questionCount: 20,
          questionIds: [],
          defaultDurationSeconds: 1200,
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
      ];
    } else {
      return [
        TestModel(
          id: 'upsc_mock_prelims_1',
          title: 'UPSC CSE Prelims Daily Mock (Random 25)',
          type: 'daily',
          exam: 'UPSC',
          subject: 'General Studies Paper 1',
          questionCount: 25,
          questionIds: [],
          defaultDurationSeconds: 1800, // 30 mins
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'upsc_ancient_history_full',
          title: 'UPSC Ancient Indian History Deep Mock (50 Qs)',
          type: 'subject',
          exam: 'UPSC',
          subject: 'Ancient Indian History',
          questionCount: 50,
          questionIds: [],
          defaultDurationSeconds: 3000,
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'upsc_comprehensive_mock',
          title: 'UPSC CSE Full Prelims Simulation (100 Qs)',
          type: 'full_mock',
          exam: 'UPSC',
          subject: 'General Studies Comprehensive',
          questionCount: 100,
          questionIds: [],
          defaultDurationSeconds: 7200, // 2 hours
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
      ];
    }
  }

  /// Check if user has unlocked the test (via Rs.1 Razorpay payment)
  Future<bool> isTestUnlocked({
    required String userId,
    required String testId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'unlocked_${userId}_$testId';
    if (prefs.getBool(localKey) == true) return true;

    // Check Supabase if available
    try {
      final res = await Supabase.instance.client
          .from('payments')
          .select('id')
          .eq('student_id', userId)
          .eq('test_id', testId)
          .eq('status', 'captured')
          .maybeSingle();
      if (res != null) {
        await prefs.setBool(localKey, true);
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Fetch full test model
  Future<TestModel?> getTestById(String testId) async {
    final upscTests = await getLiveTests('UPSC');
    final tnpscTests = await getLiveTests('TNPSC');
    for (final t in [...upscTests, ...tnpscTests]) {
      if (t.id == testId) return t;
    }
    return null;
  }

  /// Generate or fetch questions for a test without repeating previously attended questions
  Future<List<QuestionModel>> getQuestionsForTestSession({
    required String testId,
    required String exam,
    required int count,
    required String userId,
  }) async {
    final allQuestions = await _loadQuestionsForExam(exam);
    final prefs = await SharedPreferences.getInstance();

    // Load attended questions IDs for this user
    final attendedKey = 'attended_questions_${userId}_$exam';
    final attendedIds = prefs.getStringList(attendedKey)?.toSet() ?? <String>{};

    // Filter unvisited questions first to prevent repetition
    List<QuestionModel> available = allQuestions.where((q) => !attendedIds.contains(q.id)).toList();

    // If available is smaller than needed, reset visited pool so student can re-cycle through whole 1000 bank
    if (available.length < count) {
      attendedIds.clear();
      available = List<QuestionModel>.from(allQuestions);
      await prefs.setStringList(attendedKey, []);
    }

    // Shuffle randomly to give a realistic fresh mock test every time
    available.shuffle();
    final selected = available.take(count).toList();

    // Mark these as attended for future sessions
    for (final q in selected) {
      attendedIds.add(q.id);
    }
    await prefs.setStringList(attendedKey, attendedIds.toList());

    return selected;
  }

  /// Mark question as Important (Starred)
  Future<bool> toggleImportantQuestion({
    required String userId,
    required String questionId,
    required bool isImportant,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'important_questions_$userId';
    final set = prefs.getStringList(key)?.toSet() ?? <String>{};

    if (isImportant) {
      set.add(questionId);
    } else {
      set.remove(questionId);
    }

    await prefs.setStringList(key, set.toList());
    return isImportant;
  }

  /// Check if question is marked important
  Future<bool> isQuestionImportant({
    required String userId,
    required String questionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'important_questions_$userId';
    final set = prefs.getStringList(key)?.toSet() ?? <String>{};
    return set.contains(questionId);
  }

  /// Start or resume a test session
  Future<TestSessionModel> startOrResumeSession({
    required String userId,
    required String testId,
    required String exam,
    required int defaultDurationSeconds,
    required int speedOption,
    required List<QuestionModel> questions,
  }) async {
    final sessionId = 'sess_${userId}_$testId';
    final allowedDuration = (defaultDurationSeconds * (speedOption / 100.0)).round();

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('local_session_$sessionId');
    if (cached != null) {
      try {
        final session = TestSessionModel.fromMap(jsonDecode(cached), sessionId);
        if (session.status == 'in_progress') {
          return session;
        }
      } catch (_) {}
    }

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

    await _cacheSessionLocally(newSession);
    return newSession;
  }

  /// Save answer progress locally
  Future<void> saveAnswerProgress({
    required String sessionId,
    required String questionId,
    required AnswerEntry answer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_session_$sessionId';
    final existingJson = prefs.getString(key);
    Map<String, dynamic> data = existingJson != null ? jsonDecode(existingJson) : {};
    data['answers'] = data['answers'] ?? {};
    data['answers'][questionId] = answer.toMap();
    await prefs.setString(key, jsonEncode(data));
  }

  /// Submit and evaluate test session (+2 for correct, -0.66 for wrong)
  Future<TestSessionModel> evaluateAndSubmitSession({
    required String sessionId,
    required String testId,
    required String exam,
    required List<QuestionModel> questions,
    required Map<String, AnswerEntry> answers,
    required int timeTakenSeconds,
    required String userId,
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

    final totalMarks = (correct * 2.0) - (wrong * 0.6666);
    final score = totalMarks < 0 ? 0.0 : double.parse(totalMarks.toStringAsFixed(2));
    final attempted = correct + wrong;
    final accuracy = attempted > 0
        ? double.parse(((correct / attempted) * 100).toStringAsFixed(1))
        : 0.0;

    final session = TestSessionModel(
      id: sessionId,
      userId: userId,
      testId: testId,
      exam: exam,
      startedAt: DateTime.now().subtract(Duration(seconds: timeTakenSeconds)),
      allowedDurationSeconds: timeTakenSeconds,
      speedPracticePercent: 100,
      status: 'completed',
      answers: answers,
      score: score,
      accuracy: accuracy,
      totalCorrect: correct,
      totalWrong: wrong,
      totalUnanswered: unanswered,
      timeTakenSeconds: timeTakenSeconds,
      submittedAt: DateTime.now(),
      firstAttempt: true,
      subjectBreakdown: subjectScores,
    );

    // Save evaluated session to local storage for result display
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('result_session_$sessionId', jsonEncode(session.toMap()));
    await prefs.setString(
      'result_questions_$sessionId',
      jsonEncode(questions.map((q) => {
        'id': q.id,
        'exam': q.exam,
        'subject': q.subject,
        'topic': q.topic,
        'question': q.normalizedText,
        'options': q.getLocalizedOptions('en'),
        'correct_answer': q.correctAnswer,
        'explanation': q.getLocalizedExplanation('en'),
      }).toList()),
    );

    // Save to local test attempts history list so Profile & Leaderboard display immediately
    final historyKey = 'test_attempts_history_$userId';
    final existingHistory = prefs.getStringList(historyKey) ?? [];
    final attemptJson = jsonEncode({
      'sessionId': sessionId,
      'testId': testId,
      'exam': exam,
      'score': score,
      'accuracy': accuracy,
      'totalCorrect': correct,
      'totalWrong': wrong,
      'totalUnanswered': unanswered,
      'timeTakenSeconds': timeTakenSeconds,
      'submittedAt': DateTime.now().toIso8601String(),
    });
    existingHistory.insert(0, attemptJson);
    await prefs.setStringList(historyKey, existingHistory);

    // Also record test attempt in Supabase if online
    try {
      await Supabase.instance.client.from('test_attempts').insert({
        'student_id': userId,
        'test_id': testId,
        'score': score,
        'accuracy': accuracy,
        'total_correct': correct,
        'total_wrong': wrong,
        'total_unanswered': unanswered,
        'time_taken_seconds': timeTakenSeconds,
      });
    } catch (_) {}

    return session;
  }

  Future<void> _cacheSessionLocally(TestSessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'local_session_${session.id}',
      jsonEncode(session.toMap()),
    );
  }
}
