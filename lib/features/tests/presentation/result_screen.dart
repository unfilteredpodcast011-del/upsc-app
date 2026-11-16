import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';
import 'timed_engine_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ResultScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isLoading = true;
  TestSessionModel? _session;
  TestModel? _test;
  List<QuestionModel> _questions = [];
  bool _onlyShowMistakes = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSession = prefs.getString('result_session_${widget.sessionId}');
      final cachedQuestions = prefs.getString('result_questions_${widget.sessionId}');

      if (cachedSession != null) {
        final sessionMap = jsonDecode(cachedSession) as Map<String, dynamic>;
        final session = TestSessionModel.fromMap(sessionMap, widget.sessionId);
        final testRepo = ref.read(testRepoProvider);
        final test = await testRepo.getTestById(session.testId);

        List<QuestionModel> questions = [];
        if (cachedQuestions != null) {
          final List<dynamic> qList = jsonDecode(cachedQuestions);
          questions = qList.map((m) {
            final opts = (m['options'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, v.toString()),
                ) ??
                {};
            return QuestionModel(
              id: m['id'] ?? '',
              exam: m['exam'] ?? 'UPSC',
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
                  explanation: m['explanation'] ?? '',
                ),
              },
            );
          }).toList();
        }

        setState(() {
          _session = session;
          _test = test;
          _questions = questions;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading results: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('Session data not found.')),
      );
    }

    final s = _session!;
    final totalMarks = (_test?.questionCount ?? _questions.length) * (_test?.marksPerQuestion ?? 2.0);

    // Filter questions if "Show Only Wrong Questions" is active
    final displayQuestions = _onlyShowMistakes
        ? _questions.where((q) {
            final entry = s.answers[q.id];
            return entry != null && entry.selectedOption != q.correctAnswer;
          }).toList()
        : _questions;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exam Result & Review'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home Dashboard',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Exam Score',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.score.toStringAsFixed(2)} / ${totalMarks.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricBadge('Accuracy', '${s.accuracy.toStringAsFixed(1)}%'),
                      _metricBadge('Time Taken', '${(s.timeTakenSeconds / 60).toStringAsFixed(1)}m'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance Breakdown Row
            Row(
              children: [
                _statTile('Correct', '${s.totalCorrect}', Colors.green),
                const SizedBox(width: 8),
                _statTile('Wrong', '${s.totalWrong}', Colors.red),
                const SizedBox(width: 8),
                _statTile('Skipped', '${s.totalUnanswered}', Colors.grey),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Switch: All Questions vs Only Wrong Answers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Show Only Wrong Questions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _onlyShowMistakes,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setState(() => _onlyShowMistakes = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Question & Answer List (No explanations shown)
            Text(
              _onlyShowMistakes
                  ? 'Your Mistakes (${displayQuestions.length} Questions):'
                  : 'All Questions & Answers:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (displayQuestions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    _onlyShowMistakes
                        ? 'Awesome! You made 0 mistakes in this exam.'
                        : 'No questions to display.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayQuestions.length,
                itemBuilder: (ctx, index) {
                  final q = displayQuestions[index];
                  final entry = s.answers[q.id];
                  final userChoice = entry?.selectedOption;
                  final isCorrect = userChoice == q.correctAnswer;
                  final isSkipped = userChoice == null;
                  final options = q.getLocalizedOptions('en');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCorrect
                            ? Colors.green.shade300
                            : (isSkipped ? Colors.grey.shade300 : Colors.red.shade300),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isCorrect
                                    ? Colors.green
                                    : (isSkipped ? Colors.grey : Colors.red),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isCorrect
                                    ? 'Correct (+2)'
                                    : (isSkipped ? 'Skipped (0)' : 'Wrong (-0.66)'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect
                                      ? Colors.green
                                      : (isSkipped ? Colors.grey : Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            q.getLocalizedQuestion('en'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Display options
                          _optionBox('A', options['A'] ?? '', q.correctAnswer, userChoice),
                          _optionBox('B', options['B'] ?? '', q.correctAnswer, userChoice),
                          _optionBox('C', options['C'] ?? '', q.correctAnswer, userChoice),
                          _optionBox('D', options['D'] ?? '', q.correctAnswer, userChoice),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Back to Home Dashboard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }

  Widget _optionBox(String optionLetter, String text, String correctLetter, String? userAns) {
    final isCorrectOption = optionLetter == correctLetter;
    final isUserChoice = optionLetter == userAns;

    Color bg = Colors.white;
    Color border = Colors.grey.shade300;
    Color textColor = Colors.black87;

    if (isCorrectOption) {
      bg = Colors.green.shade50;
      border = Colors.green;
      textColor = Colors.green.shade900;
    } else if (isUserChoice) {
      bg = Colors.red.shade50;
      border = Colors.red;
      textColor = Colors.red.shade900;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            '$optionLetter. ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
          if (isCorrectOption)
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
          if (isUserChoice && !isCorrectOption)
            const Icon(Icons.cancel, color: Colors.red, size: 16),
        ],
      ),
    );
  }

  Widget _metricBadge(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _statTile(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
