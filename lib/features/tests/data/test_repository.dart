import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';

class TestRepository {
  List<QuestionModel>? _cachedTnpscQuestions;
  List<QuestionModel>? _cachedUpscQuestions;

  /// Load questions from assets/data/ merged with dynamic PYQ questions from Supabase
  Future<List<QuestionModel>> _loadQuestionsForExam(String exam) async {
    List<QuestionModel> staticQuestions = [];
    if (exam == 'TNPSC') {
      if (_cachedTnpscQuestions != null) return _cachedTnpscQuestions!;
      final jsonStr = await rootBundle.loadString('assets/data/tnpsc_questions.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      staticQuestions = list.map((item) {
        final Map<String, dynamic> m = item;
        final opts = (m['options'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {};

        final rawTranslations = m['translations'] as Map<String, dynamic>?;
        final Map<String, QuestionTranslation> translationsMap = {};

        if (rawTranslations != null) {
          rawTranslations.forEach((lang, trans) {
            if (trans is Map<String, dynamic>) {
              final tOpts = (trans['options'] as Map<String, dynamic>?)?.map(
                    (k, v) => MapEntry(k, v.toString()),
                  ) ??
                  opts;
              translationsMap[lang] = QuestionTranslation(
                question: trans['question'] ?? m['question'] ?? '',
                options: tOpts,
                explanation: trans['explanation'] ?? 'Correct Answer: ${m['correct_answer']}',
              );
            }
          });
        }

        if (!translationsMap.containsKey('en')) {
          translationsMap['en'] = QuestionTranslation(
            question: m['question'] ?? '',
            options: opts,
            explanation: 'Correct Answer: ${m['correct_answer']}',
          );
        }

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
          pyqYear: m['year']?.toString() ?? m['pyq_year']?.toString(),
          isPyq: m['is_pyq'] == true || m['year'] != null,
          translations: translationsMap,
        );
      }).toList();
    } else {
      if (_cachedUpscQuestions != null) return _cachedUpscQuestions!;
      final jsonStr = await rootBundle.loadString('assets/data/upsc_questions.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      staticQuestions = list.map((item) {
        final Map<String, dynamic> m = item;
        final opts = (m['options'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {};

        final rawTranslations = m['translations'] as Map<String, dynamic>?;
        final Map<String, QuestionTranslation> translationsMap = {};

        if (rawTranslations != null) {
          rawTranslations.forEach((lang, trans) {
            if (trans is Map<String, dynamic>) {
              final tOpts = (trans['options'] as Map<String, dynamic>?)?.map(
                    (k, v) => MapEntry(k, v.toString()),
                  ) ??
                  opts;
              translationsMap[lang] = QuestionTranslation(
                question: trans['question'] ?? m['question'] ?? '',
                options: tOpts,
                explanation: trans['explanation'] ?? m['explanation'] ?? 'Correct Answer: ${m['correct_answer']}',
              );
            }
          });
        }

        if (!translationsMap.containsKey('en')) {
          translationsMap['en'] = QuestionTranslation(
            question: m['question'] ?? '',
            options: opts,
            explanation: m['explanation'] ?? 'Correct Answer: ${m['correct_answer']}',
          );
        }

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
          pyqYear: m['year']?.toString() ?? m['pyq_year']?.toString(),
          isPyq: m['is_pyq'] == true || m['year'] != null,
          translations: translationsMap,
        );
      }).toList();
    }

    // Now dynamically fetch and append any admin uploaded PYQ questions from Supabase in permanent creation order
    try {
      final res = await Supabase.instance.client
          .from('payments')
          .select('id, razorpay_order_id, amount_paise, created_at')
          .eq('status', 'pyq_question')
          .order('created_at', ascending: true);

      if (res.isNotEmpty) {
        final List<QuestionModel> dynamicPyqs = [];
        for (final row in res) {
          try {
            final raw = row['razorpay_order_id'];
            if (raw == null) continue;
            final Map<String, dynamic> data = jsonDecode(raw);
            final rowExam = (data['exam'] ?? 'UPSC').toString().toUpperCase();
            if (rowExam != exam) continue;

            final qText = data['question'] ?? '';
            final exp = data['explanation'] ?? 'Correct Answer: ${data['correct_answer']}';
            final year = data['year']?.toString() ?? (row['amount_paise'] != 0 ? row['amount_paise'].toString() : '2024');
            final Map<String, dynamic> rawOpts = data['options'] ?? {};
            final Map<String, String> opts = {};
            rawOpts.forEach((k, v) => opts[k.toString().toUpperCase()] = v.toString());

            // Check if full multilingual translations were stored
            final Map<String, QuestionTranslation> transMap = {};
            if (data['translations'] is Map) {
              final Map<String, dynamic> rawTrans = data['translations'];
              rawTrans.forEach((lang, tData) {
                if (tData is Map) {
                  final tQuestion = tData['question']?.toString() ?? qText;
                  final tExp = tData['explanation']?.toString() ?? exp;
                  final Map<String, String> tOpts = {};
                  if (tData['options'] is List) {
                    final list = tData['options'] as List;
                    const keys = ['A', 'B', 'C', 'D'];
                    for (int i = 0; i < list.length && i < 4; i++) {
                      tOpts[keys[i]] = list[i].toString();
                    }
                  } else if (tData['options'] is Map) {
                    (tData['options'] as Map).forEach((k, v) => tOpts[k.toString().toUpperCase()] = v.toString());
                  }
                  transMap[lang] = QuestionTranslation(
                    question: tQuestion,
                    options: tOpts.isNotEmpty ? tOpts : opts,
                    explanation: tExp,
                  );
                }
              });
            }

            if (!transMap.containsKey('en')) {
              transMap['en'] = QuestionTranslation(question: qText, options: opts, explanation: exp);
            }
            if (!transMap.containsKey('ta')) {
              transMap['ta'] = transMap['en']!;
            }
            if (!transMap.containsKey('hi')) {
              transMap['hi'] = transMap['en']!;
            }

            dynamicPyqs.add(
              QuestionModel(
                id: row['id'],
                exam: exam,
                subject: data['subject'] ?? (exam == 'TNPSC' ? 'TNPSC Previous Year Paper' : 'UPSC Previous Year Paper'),
                topic: data['topic'] ?? 'Previous Year Question ($year)',
                ncertChapter: '',
                difficulty: 'medium',
                publishDate: '2026-11-16',
                correctAnswer: (data['correct_answer'] ?? 'A').toString().toUpperCase(),
                normalizedText: qText,
                pyqYear: year,
                isPyq: true,
                translations: transMap,
              ),
            );
          } catch (_) {}
        }

        if (dynamicPyqs.isNotEmpty) {
          // Appended at the end (after 1200) to maintain permanent sequence numbers
          staticQuestions = [...staticQuestions, ...dynamicPyqs];
        }
      }
    } catch (_) {}

    if (exam == 'TNPSC') {
      _cachedTnpscQuestions = staticQuestions;
    } else {
      _cachedUpscQuestions = staticQuestions;
    }

    return staticQuestions;
  }

  /// Stream of available live tests for an exam (UPSC or TNPSC)
  Stream<List<TestModel>> streamLiveTests(String exam) async* {
    yield await getLiveTests(exam);
  }

  /// Get defined tests for an exam (Built-in + Admin Uploaded Custom Packages)
  Future<List<TestModel>> getLiveTests(String exam) async {
    List<TestModel> baseTests = [];
    if (exam == 'TNPSC') {
      baseTests = [
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
          title: 'TNPSC Full Model Mock Test (100 Questions)',
          type: 'full_mock',
          exam: 'TNPSC',
          subject: 'Complete TNPSC Syllabus (From 1000 Question Bank)',
          questionCount: 100,
          questionIds: [],
          defaultDurationSeconds: 7200, // 2 hours
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'tnpsc_mock_mega_200',
          title: 'TNPSC Group 1 Grand Full Length Mock (200 Questions)',
          type: 'full_mock',
          exam: 'TNPSC',
          subject: 'General Studies + Aptitude (Full 3-Hour Exam)',
          questionCount: 200,
          questionIds: [],
          defaultDurationSeconds: 10800, // 3 hours
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'tnpsc_aptitude_special',
          title: 'TNPSC Aptitude & Mental Ability Special (50 Qs)',
          type: 'subject',
          exam: 'TNPSC',
          subject: 'General Aptitude & Reasoning',
          questionCount: 50,
          questionIds: [],
          defaultDurationSeconds: 3000, // 50 mins
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
      ];
    } else {
      baseTests = [
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
          defaultDurationSeconds: 3000, // 50 mins
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
        TestModel(
          id: 'upsc_comprehensive_mock',
          title: 'UPSC CSE Full Prelims Simulation (100 Qs)',
          type: 'full_mock',
          exam: 'UPSC',
          subject: 'General Studies Comprehensive (Full Prelims Paper 1)',
          questionCount: 100,
          questionIds: [],
          defaultDurationSeconds: 7200, // 2 hours
          priceInPaise: 100,
          publishDate: '2026-11-16',
          isLive: true,
        ),
      ];
    }

    // Now dynamically load any custom test packages published by admin AND filter out any disabled tests
    try {
      // 1. Fetch disabled tests
      final disabledRes = await Supabase.instance.client
          .from('payments')
          .select('razorpay_order_id')
          .eq('status', 'disabled_test');
      
      final Set<String> disabledIds = {};
      if (disabledRes.isNotEmpty) {
        for (final row in disabledRes) {
          final testId = row['razorpay_order_id']?.toString();
          if (testId != null && testId.isNotEmpty) disabledIds.add(testId);
        }
      }

      // Filter base tests by disabledIds
      if (disabledIds.isNotEmpty) {
        baseTests = baseTests.where((t) => !disabledIds.contains(t.id)).toList();
      }

      // 2. Fetch custom test packages
      final res = await Supabase.instance.client
          .from('payments')
          .select('id, razorpay_order_id, amount_paise, created_at')
          .eq('status', 'test_package')
          .order('created_at', ascending: false);

      if (res.isNotEmpty) {
        final List<TestModel> customPackages = [];
        for (final row in res) {
          try {
            if (disabledIds.contains(row['id'])) continue;
            final raw = row['razorpay_order_id'];
            if (raw == null) continue;
            final Map<String, dynamic> data = jsonDecode(raw);
            final rowExam = (data['exam'] ?? 'UPSC').toString().toUpperCase();
            if (rowExam != exam) continue;

            final int qCount = (data['questionCount'] as num?)?.toInt() ?? 25;
            final int durationMins = (data['durationMinutes'] as num?)?.toInt() ?? (qCount * 60 ~/ 50);

            customPackages.add(
              TestModel(
                id: row['id'],
                title: data['title'] ?? 'Custom Practice Set ($qCount Qs)',
                type: qCount >= 100 ? 'full_mock' : (qCount == 25 ? 'daily' : 'subject'),
                exam: exam,
                subject: data['subject'] ?? 'General Studies Paper',
                questionCount: qCount,
                questionIds: [],
                defaultDurationSeconds: durationMins * 60,
                priceInPaise: 100,
                publishDate: row['created_at']?.toString() ?? '2026-11-17',
                isLive: true,
              ),
            );
          } catch (_) {}
        }
        if (customPackages.isNotEmpty) {
          baseTests = [...customPackages, ...baseTests];
        }
      }
    } catch (_) {}

    return baseTests;
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

  /// Generate or fetch questions sequentially from permanent question bank with cycle-aware no-repeat allocation.
  /// RULE 3:
  /// - Queries user_question_history for this user, exam and current cycle.
  /// - Gives unseen questions in order.
  /// - If unseen < requested, advances to cycle_no + 1 and fills the rest without duplicating within the same test.
  /// - Newly uploaded questions automatically join the unseen pool.
  /// - Seamlessly migrates legacy pointers so no candidate loses progress.
  Future<List<QuestionModel>> getQuestionsForTestSession({
    required String testId,
    required String exam,
    required int count,
    required String userId,
  }) async {
    // 0. CHECK FOR FIXED MOCK TEST OR SPECIFIC BUNDLE FIRST
    // If the test has specific attached questions in payments or tests table, fetch those exact questions
    try {
      final specificRows = await Supabase.instance.client
          .from('payments')
          .select('id, razorpay_order_id, amount_paise, created_at')
          .eq('status', 'pyq_question')
          .order('created_at', ascending: true);

      if (specificRows.isNotEmpty) {
        final List<QuestionModel> bundleQuestions = [];
        for (final row in specificRows) {
          try {
            final raw = row['razorpay_order_id'];
            if (raw == null) continue;
            final Map<String, dynamic> data = jsonDecode(raw);
            if (data['topic'] == testId || data['test_id'] == testId) {
              final qText = data['question'] ?? '';
              final exp = data['explanation'] ?? 'Correct Answer: ${data['correct_answer']}';
              final year = data['year']?.toString() ?? '2026';
              final Map<String, dynamic> rawOpts = data['options'] ?? {};
              final Map<String, String> opts = {};
              rawOpts.forEach((k, v) => opts[k.toString().toUpperCase()] = v.toString());

              // Build translations
              final Map<String, QuestionTranslation> transMap = {};
              if (data['translations'] is Map) {
                final Map<String, dynamic> rawTrans = data['translations'];
                rawTrans.forEach((lang, tData) {
                  if (tData is Map) {
                    final tQuestion = tData['question']?.toString() ?? qText;
                    final tExp = tData['explanation']?.toString() ?? exp;
                    final Map<String, String> tOpts = {};
                    if (tData['options'] is List) {
                      final list = tData['options'] as List;
                      const keys = ['A', 'B', 'C', 'D'];
                      for (int i = 0; i < list.length && i < 4; i++) {
                        tOpts[keys[i]] = list[i].toString();
                      }
                    } else if (tData['options'] is Map) {
                      (tData['options'] as Map).forEach((k, v) => tOpts[k.toString().toUpperCase()] = v.toString());
                    }
                    transMap[lang] = QuestionTranslation(
                      question: tQuestion,
                      options: tOpts.isNotEmpty ? tOpts : opts,
                      explanation: tExp,
                    );
                  }
                });
              }

              if (!transMap.containsKey('en')) {
                transMap['en'] = QuestionTranslation(question: qText, options: opts, explanation: exp);
              }
              if (!transMap.containsKey('ta')) {
                transMap['ta'] = transMap['en']!;
              }
              if (!transMap.containsKey('hi')) {
                transMap['hi'] = transMap['en']!;
              }

              bundleQuestions.add(
                QuestionModel(
                  id: row['id'],
                  exam: exam,
                  subject: data['subject'] ?? 'Previous Year Question Paper',
                  topic: data['topic'] ?? 'PYQ Fixed Bundle',
                  ncertChapter: '',
                  difficulty: 'medium',
                  publishDate: '2026-11-16',
                  correctAnswer: (data['correct_answer'] ?? 'A').toString().toUpperCase(),
                  normalizedText: qText,
                  pyqYear: year,
                  isPyq: true,
                  translations: transMap,
                ),
              );
            }
          } catch (_) {}
        }

        if (bundleQuestions.isNotEmpty) {
          // If this is a specific test paper bundle, return its fixed questions without mixing with random practice pool
          return bundleQuestions;
        }
      }
    } catch (_) {}

    final allQuestions = await _loadQuestionsForExam(exam);
    if (allQuestions.isEmpty) return [];

    final totalCount = allQuestions.length;
    final int requested = count > totalCount ? totalCount : count;
    final prefs = await SharedPreferences.getInstance();

    // 1. Try atomic Postgres RPC allocation if RPC is active on Supabase
    if (userId.contains('-')) {
      try {
        final rpcRes = await Supabase.instance.client.rpc('allocate_test_questions', params: {
          'p_user_id': userId,
          'p_exam': exam,
          'p_count': requested,
        });

        if (rpcRes != null && rpcRes is List && rpcRes.isNotEmpty) {
          final List<QuestionModel> rpcAllocated = [];
          for (final row in rpcRes) {
            final qId = row['id']?.toString() ?? '';
            final match = allQuestions.firstWhere(
              (q) => q.id == qId,
              orElse: () => QuestionModel.fromMap(row, qId),
            );
            rpcAllocated.add(match);
          }
          if (rpcAllocated.length == requested) {
            return rpcAllocated;
          }
        }
      } catch (_) {}
    }

    // 2. Client-side cycle-aware no-repeat allocation engine (Syncs with user_question_history & local cache)
    final cycleKey = 'exam_cycle_${userId}_$exam';
    final seenKey = 'seen_qids_${userId}_$exam';

    int currentCycle = prefs.getInt(cycleKey) ?? 1;
    List<String> seenIds = prefs.getStringList(seenKey) ?? [];

    // Migrate existing legacy pointer if seenIds is empty
    final pointerKey = 'question_pointer_${userId}_$exam';
    final legacyPointer = prefs.getInt(pointerKey);
    if (seenIds.isEmpty && legacyPointer != null && legacyPointer > 0 && legacyPointer <= totalCount) {
      for (int i = 0; i < legacyPointer; i++) {
        seenIds.add(allQuestions[i].id);
      }
      await prefs.setStringList(seenKey, seenIds);
    }

    // Try fetching remote history from user_question_history or pointer row
    try {
      if (userId.contains('-')) {
        final histRes = await Supabase.instance.client
            .from('user_question_history')
            .select('question_id, cycle_no')
            .eq('user_id', userId)
            .eq('exam', exam)
            .order('seen_at', ascending: true);

        if (histRes.isNotEmpty) {
          final Set<String> remoteSeen = {};
          int maxCycle = 1;
          for (final row in histRes) {
            final c = (row['cycle_no'] as num?)?.toInt() ?? 1;
            if (c > maxCycle) maxCycle = c;
            final qId = row['question_id']?.toString();
            if (qId != null) remoteSeen.add(qId);
          }
          currentCycle = maxCycle;
          seenIds = remoteSeen.toList();
          await prefs.setInt(cycleKey, currentCycle);
          await prefs.setStringList(seenKey, seenIds);
        }
      }
    } catch (_) {}

    final seenSet = seenIds.toSet();
    final List<QuestionModel> unseenPool = allQuestions.where((q) => !seenSet.contains(q.id)).toList();

    final List<QuestionModel> allocated = [];

    if (unseenPool.length >= requested) {
      // Plenty of unseen questions in current cycle
      allocated.addAll(unseenPool.take(requested));
    } else {
      // Take all remaining unseen
      allocated.addAll(unseenPool);
      final int neededFromNextCycle = requested - allocated.length;

      // Start new cycle (cycle_no + 1)
      currentCycle += 1;
      await prefs.setInt(cycleKey, currentCycle);
      seenIds.clear();

      // Allocate remainder from new cycle without repeating questions already chosen in this test
      final currentChosenIds = allocated.map((q) => q.id).toSet();
      final freshPool = allQuestions.where((q) => !currentChosenIds.contains(q.id)).toList();
      allocated.addAll(freshPool.take(neededFromNextCycle));
    }

    // Mark newly allocated questions as seen
    final newlySeenIds = allocated.map((q) => q.id).toList();
    seenIds.addAll(newlySeenIds);
    await prefs.setStringList(seenKey, seenIds);
    await prefs.setInt(cycleKey, currentCycle);

    // Sync newly seen questions to user_question_history in Supabase
    if (userId.contains('-')) {
      try {
        final inserts = newlySeenIds.map((qId) => {
          'user_id': userId,
          'question_id': qId.contains('-') ? qId : null,
          'exam': exam,
          'cycle_no': currentCycle,
          'seen_at': DateTime.now().toIso8601String(),
        }).where((m) => m['question_id'] != null).toList();

        if (inserts.isNotEmpty) {
          await Supabase.instance.client
              .from('user_question_history')
              .upsert(inserts, onConflict: 'user_id,question_id,cycle_no');
        }
      } catch (_) {}
    }

    return allocated;
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

  /// Start or resume a test session with initial in_progress attempt record in Supabase
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
          final elapsed = DateTime.now().difference(session.startedAt).inSeconds;
          if (elapsed < session.allowedDurationSeconds && elapsed >= 0) {
            return session;
          } else {
            // Test time already expired, discard stale session
            await prefs.remove('local_session_$sessionId');
          }
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

    // Save attempt record to Supabase as source of truth
    try {
      final attemptPayload = {
        'sessionId': sessionId,
        'userId': userId,
        'testId': testId,
        'exam': exam,
        'status': 'in_progress',
        'test_size': questions.length,
        'question_ids': questions.map((q) => q.id).toList(),
        'started_at': newSession.startedAt.toIso8601String(),
        'allowed_duration_seconds': allowedDuration,
        'last_heartbeat': DateTime.now().toIso8601String(),
        'answers': {},
      };

      await Supabase.instance.client.from('payments').insert({
        'student_id': userId,
        'test_id': null,
        'amount_paise': questions.length,
        'status': 'exam_attempt_in_progress',
        'razorpay_payment_id': sessionId,
        'razorpay_order_id': jsonEncode(attemptPayload),
      });
    } catch (_) {}

    return newSession;
  }

  /// Send heartbeat and sync selected answer to server immediately
  Future<void> sendHeartbeatAndSyncAnswer({
    required String sessionId,
    required String userId,
    required Map<String, AnswerEntry> answers,
  }) async {
    try {
      final ansMap = <String, dynamic>{};
      answers.forEach((k, v) => ansMap[k] = v.toMap());

      final existingRow = await Supabase.instance.client
          .from('payments')
          .select('id, razorpay_order_id')
          .eq('student_id', userId)
          .eq('razorpay_payment_id', sessionId)
          .eq('status', 'exam_attempt_in_progress')
          .maybeSingle();

      if (existingRow != null) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(existingRow['razorpay_order_id'].toString());
        } catch (_) {}
        data['last_heartbeat'] = DateTime.now().toIso8601String();
        data['answers'] = ansMap;

        await Supabase.instance.client
            .from('payments')
            .update({'razorpay_order_id': jsonEncode(data)})
            .eq('id', existingRow['id']);
      }
    } catch (_) {}
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
  /// Marks unattended questions as skipped. Supports auto-submitted flag.
  Future<TestSessionModel> evaluateAndSubmitSession({
    required String sessionId,
    required String testId,
    required String exam,
    required List<QuestionModel> questions,
    required Map<String, AnswerEntry> answers,
    required int timeTakenSeconds,
    required String userId,
    bool isAutoSubmitted = false,
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
      status: isAutoSubmitted ? 'auto_submitted' : 'completed',
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
    await prefs.remove('local_session_$sessionId');
    await prefs.setString('result_session_$sessionId', jsonEncode(session.toMap()));
    final appLang = prefs.getString('app_language') ?? 'en';
    await prefs.setString(
      'result_questions_$sessionId',
      jsonEncode(questions.map((q) => {
        'id': q.id,
        'exam': q.exam,
        'subject': q.subject,
        'topic': q.topic,
        'question': q.getLocalizedQuestion(appLang),
        'options': q.getLocalizedOptions(appLang),
        'correct_answer': q.correctAnswer,
        'explanation': q.getLocalizedExplanation(appLang),
      }).toList()),
    );

    // Save to local test attempts history list so Profile & Test History display immediately
    final historyKey = 'test_attempts_history_$userId';
    final existingHistory = prefs.getStringList(historyKey) ?? [];
    final attemptJson = jsonEncode({
      'sessionId': sessionId,
      'testId': testId,
      'exam': exam,
      'testTitle': testId.contains('tnpsc') ? 'TNPSC Combined Services Mock' : 'UPSC Civil Services Prelims Mock',
      'test_size': questions.length,
      'status': isAutoSubmitted ? 'Auto-submitted' : 'Submitted',
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

    // Finalize attempt in Supabase (idempotent update or insert)
    try {
      final ansMap = <String, dynamic>{};
      answers.forEach((k, v) => ansMap[k] = v.toMap());

      final finishedPayload = {
        'sessionId': sessionId,
        'userId': userId,
        'testId': testId,
        'exam': exam,
        'status': isAutoSubmitted ? 'auto_submitted' : 'submitted',
        'score': score,
        'accuracy': accuracy,
        'total_correct': correct,
        'total_wrong': wrong,
        'total_skipped': unanswered,
        'total_questions': questions.length,
        'time_taken_seconds': timeTakenSeconds,
        'submitted_at': DateTime.now().toIso8601String(),
        'question_ids': questions.map((q) => q.id).toList(),
        'answers': ansMap,
      };

      // Check if an in_progress attempt exists
      final inProg = await Supabase.instance.client
          .from('payments')
          .select('id')
          .eq('student_id', userId)
          .eq('razorpay_payment_id', sessionId)
          .eq('status', 'exam_attempt_in_progress')
          .maybeSingle();

      if (inProg != null) {
        await Supabase.instance.client
            .from('payments')
            .update({
              'status': isAutoSubmitted ? 'exam_auto_submitted' : 'exam_submitted',
              'amount_paise': (score * 100).toInt(),
              'razorpay_order_id': jsonEncode(finishedPayload),
            })
            .eq('id', inProg['id']);
      } else {
        await Supabase.instance.client.from('payments').insert({
          'student_id': userId,
          'test_id': null,
          'amount_paise': (score * 100).toInt(),
          'status': isAutoSubmitted ? 'exam_auto_submitted' : 'exam_submitted',
          'razorpay_payment_id': sessionId,
          'razorpay_order_id': jsonEncode(finishedPayload),
        });
      }
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
