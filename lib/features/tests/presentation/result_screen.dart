import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isReviewMode = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('test_sessions')
          .doc(widget.sessionId)
          .get();

      if (snap.exists && snap.data() != null) {
        final session = TestSessionModel.fromMap(snap.data()!, snap.id);
        final testRepo = ref.read(testRepoProvider);
        final test = await testRepo.getTestById(session.testId);

        List<QuestionModel> questions = [];
        if (test != null) {
          questions = await testRepo.getQuestionsForTest(test.questionIds);
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
        body: const Center(child: Text('Test result session not found.')),
      );
    }

    final s = _session!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReviewMode ? 'Detailed Question Review' : 'Test Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            setState(() => _isReviewMode = !_isReviewMode);
          },
          child: Text(
            _isReviewMode ? 'Back to Summary' : 'Review Questions & Explanations',
          ),
        ),
      ),
      body: _isReviewMode ? _buildReviewList() : _buildSummaryView(s),
    );
  }

  Widget _buildSummaryView(TestSessionModel s) {
    final minutes = s.timeTakenSeconds ~/ 60;
    final seconds = s.timeTakenSeconds % 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Score Card
          Card(
            color: Theme.of(context).colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Column(
                children: [
                  const Text(
                    'Your Total Score',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _metricBadge('Accuracy', '${s.accuracy}%'),
                      _metricBadge('Speed', '${s.speedPracticePercent}% Mode'),
                      _metricBadge('Time Taken', '${minutes}m ${seconds}s'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown Row
          Row(
            children: [
              _statTile('Correct', '${s.totalCorrect}', Colors.green),
              const SizedBox(width: 8),
              _statTile('Incorrect', '${s.totalWrong}', Colors.red),
              const SizedBox(width: 8),
              _statTile('Unanswered', '${s.totalUnanswered}', Colors.grey),
            ],
          ),
          const SizedBox(height: 20),

          // Weak Topics & Subject Analysis
          const Text(
            'Subject-wise Analysis & Weak Topics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          if (s.subjectBreakdown != null && s.subjectBreakdown!.isNotEmpty)
            ...s.subjectBreakdown!.entries.map((entry) {
              final subjName = entry.key;
              final data = entry.value as Map<String, dynamic>;
              final correct = (data['correct'] as num?)?.toInt() ?? 0;
              final total = (data['total'] as num?)?.toInt() ?? 1;
              final percentage = ((correct / total) * 100).toStringAsFixed(0);
              final isWeak = (correct / total) < 0.5;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isWeak ? Colors.red.shade100 : Colors.green.shade100,
                    child: Icon(
                      isWeak ? Icons.warning_amber_rounded : Icons.check,
                      color: isWeak ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(subjName),
                  subtitle: Text(
                    isWeak
                        ? 'Needs Revision • $correct of $total correct ($percentage%)'
                        : 'Strong performance • $correct of $total correct ($percentage%)',
                    style: TextStyle(
                      color: isWeak ? Colors.red.shade700 : Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isWeak
                      ? Chip(
                          label: const Text('Weak Area', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.red.shade50,
                        )
                      : null,
                ),
              );
            })
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Complete more tests to generate detailed topic weak-spot alerts.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (ctx, idx) {
        final q = _questions[idx];
        final ans = _session!.answers[q.id];
        final selected = ans?.selectedOption?.toUpperCase();
        final correct = q.correctAnswer.toUpperCase();
        final isCorrect = selected == correct;
        final isUnanswered = selected == null;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Q${idx + 1} (${q.subject})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        isUnanswered
                            ? 'Unanswered'
                            : (isCorrect ? 'Correct (+2.0)' : 'Incorrect (-0.66)'),
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                      backgroundColor: isUnanswered
                          ? Colors.grey
                          : (isCorrect ? Colors.green : Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.getLocalizedQuestion('en'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                ...['a', 'b', 'c', 'd'].map((key) {
                  final text = q.getLocalizedOptions('en')[key] ?? '';
                  final isThisOptionCorrect = key.toUpperCase() == correct;
                  final isThisOptionSelected = key.toUpperCase() == selected;

                  Color? tileColor;
                  if (isThisOptionCorrect) {
                    tileColor = Colors.green.shade50;
                  } else if (isThisOptionSelected && !isCorrect) {
                    tileColor = Colors.red.shade50;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tileColor ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isThisOptionCorrect
                            ? Colors.green
                            : (isThisOptionSelected ? Colors.red : Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${key.toUpperCase()}. ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isThisOptionCorrect ? Colors.green : Colors.black87,
                          ),
                        ),
                        Expanded(child: Text(text)),
                        if (isThisOptionCorrect)
                          const Icon(Icons.check, color: Colors.green, size: 18),
                        if (isThisOptionSelected && !isCorrect)
                          const Icon(Icons.close, color: Colors.red, size: 18),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Explanation: ${q.getLocalizedExplanation('en')}',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
