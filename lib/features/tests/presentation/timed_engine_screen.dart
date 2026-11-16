import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/test_repository.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';

final testRepoProvider = Provider<TestRepository>((ref) => TestRepository());

class TimedEngineScreen extends ConsumerStatefulWidget {
  final String testId;
  final int speedOption;

  const TimedEngineScreen({
    super.key,
    required this.testId,
    this.speedOption = 100,
  });

  @override
  ConsumerState<TimedEngineScreen> createState() => _TimedEngineScreenState();
}

class _TimedEngineScreenState extends ConsumerState<TimedEngineScreen> {
  bool _isLoading = true;
  String? _error;
  TestModel? _test;
  List<QuestionModel> _questions = [];
  TestSessionModel? _session;
  String _studentId = 'student_guest';

  int _currentIndex = 0;
  String _currentLanguage = 'en';
  final Map<String, AnswerEntry> _answers = {};
  final Set<String> _importantQuestionIds = {};

  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  int _totalDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _studentId = prefs.getString('student_id') ?? 'student_guest';
      _currentLanguage = prefs.getString('app_language') ?? 'en';
      final testRepo = ref.read(testRepoProvider);

      final test = await testRepo.getTestById(widget.testId);
      if (test == null) throw 'Test not found.';

      // Load questions for this test session without repeating previously attended ones
      final questions = await testRepo.getQuestionsForTestSession(
        testId: test.id,
        exam: test.exam,
        count: test.questionCount,
        userId: _studentId,
      );

      if (questions.isEmpty) throw 'No questions loaded for this test.';

      // Load important questions saved for this user
      final savedImportant = prefs.getStringList('important_questions_$_studentId')?.toSet() ?? <String>{};
      _importantQuestionIds.addAll(savedImportant);

      final session = await testRepo.startOrResumeSession(
        userId: _studentId,
        testId: test.id,
        exam: test.exam,
        defaultDurationSeconds: test.defaultDurationSeconds,
        speedOption: widget.speedOption,
        questions: questions,
      );

      _test = test;
      _questions = questions;
      _session = session;
      _answers.addAll(session.answers);

      final now = DateTime.now();
      final elapsed = now.difference(session.startedAt).inSeconds;
      _totalDurationSeconds = session.allowedDurationSeconds;
      _secondsRemaining = _totalDurationSeconds - (elapsed > 0 ? elapsed : 0);

      if (_secondsRemaining <= 0) {
        _autoSubmit();
        return;
      }

      _startTimer();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _autoSubmit();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _selectOption(String option) {
    final currentQ = _questions[_currentIndex];
    final existing = _answers[currentQ.id] ?? AnswerEntry();
    final updated = existing.copyWith(selectedOption: option);

    setState(() {
      _answers[currentQ.id] = updated;
    });

    if (_session != null) {
      ref.read(testRepoProvider).saveAnswerProgress(
            sessionId: _session!.id,
            questionId: currentQ.id,
            answer: updated,
          );
    }
  }

  void _toggleMarkForReview() {
    final currentQ = _questions[_currentIndex];
    final existing = _answers[currentQ.id] ?? AnswerEntry();
    final updated = existing.copyWith(markedForReview: !existing.markedForReview);

    setState(() {
      _answers[currentQ.id] = updated;
    });

    if (_session != null) {
      ref.read(testRepoProvider).saveAnswerProgress(
            sessionId: _session!.id,
            questionId: currentQ.id,
            answer: updated,
          );
    }
  }

  Future<void> _toggleImportantQuestion() async {
    final currentQ = _questions[_currentIndex];
    final isImp = _importantQuestionIds.contains(currentQ.id);
    final newImp = !isImp;

    setState(() {
      if (newImp) {
        _importantQuestionIds.add(currentQ.id);
      } else {
        _importantQuestionIds.remove(currentQ.id);
      }
    });

    await ref.read(testRepoProvider).toggleImportantQuestion(
          userId: _studentId,
          questionId: currentQ.id,
          isImportant: newImp,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newImp ? 'Marked as Important Question ⭐' : 'Removed from Important'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _clearResponse() {
    final currentQ = _questions[_currentIndex];
    final existing = _answers[currentQ.id] ?? AnswerEntry();
    final updated = existing.copyWith(clearOption: true);

    setState(() {
      _answers[currentQ.id] = updated;
    });

    if (_session != null) {
      ref.read(testRepoProvider).saveAnswerProgress(
            sessionId: _session!.id,
            questionId: currentQ.id,
            answer: updated,
          );
    }
  }

  Future<void> _submitTest() async {
    final answeredCount = _answers.values.where((a) => a.selectedOption != null).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Practice Test?'),
        content: Text(
          'You have answered $answeredCount of ${_questions.length} questions.\n\n'
          'Are you sure you want to finish and calculate your score?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeSubmission();
    }
  }

  void _autoSubmit() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time is up! Evaluating your test...'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    _executeSubmission();
  }

  Future<void> _executeSubmission() async {
    _countdownTimer?.cancel();
    setState(() => _isLoading = true);

    final timeTaken = _totalDurationSeconds - _secondsRemaining;

    final completedSession =
        await ref.read(testRepoProvider).evaluateAndSubmitSession(
              sessionId: _session?.id ?? 'sess_${DateTime.now().millisecondsSinceEpoch}',
              testId: _test?.id ?? widget.testId,
              exam: _test?.exam ?? 'UPSC',
              questions: _questions,
              answers: _answers,
              timeTakenSeconds: timeTaken > 0 ? timeTaken : 1,
              userId: _studentId,
            );

    if (mounted) {
      context.go('/test-result/${completedSession.id}');
    }
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Securing timed practice session...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Return to Tests'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQ = _questions[_currentIndex];
    final currentAns = _answers[currentQ.id];
    final options = currentQ.getLocalizedOptions(_currentLanguage);
    final questionText = currentQ.getLocalizedQuestion(_currentLanguage);
    final isImportant = _importantQuestionIds.contains(currentQ.id);

    final progressRatio = _totalDurationSeconds > 0
        ? _secondsRemaining / _totalDurationSeconds
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.grid_view_rounded),
          tooltip: 'Question Palette',
          onPressed: _showQuestionPalette,
        ),
        title: Column(
          children: [
            Text(
              _formatTimer(_secondsRemaining),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: _secondsRemaining < 120 ? Colors.redAccent : Colors.white,
              ),
            ),
            Text(
              'Q ${_currentIndex + 1} of ${_questions.length}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Important Question Star Toggle
          IconButton(
            icon: Icon(
              isImportant ? Icons.star : Icons.star_border,
              color: isImportant ? Colors.amberAccent : Colors.white70,
            ),
            tooltip: isImportant ? 'Marked as Important' : 'Mark as Important',
            onPressed: _toggleImportantQuestion,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Submit Test',
            onPressed: _submitTest,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: progressRatio,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              _secondsRemaining < 120 ? Colors.red : Theme.of(context).colorScheme.primary,
            ),
          ),

          // Question Card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tags & Badges Row (Wrap to avoid Right OverFlow on small screens)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text(
                          currentQ.subject,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.blue.shade50,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (currentQ.topic.isNotEmpty)
                        Chip(
                          label: Text(
                            currentQ.topic,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.amber.shade50,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (isImportant)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                'Important',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          currentAns?.markedForReview == true
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: currentAns?.markedForReview == true
                              ? Colors.purple
                              : Colors.grey,
                        ),
                        tooltip: 'Mark for Review',
                        onPressed: _toggleMarkForReview,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Question Text
                  Text(
                    'Q${_currentIndex + 1}. $questionText',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options List
                  ...['A', 'B', 'C', 'D'].map((optKey) {
                    final optText = options[optKey] ?? options[optKey.toLowerCase()] ?? '';
                    if (optText.isEmpty) return const SizedBox.shrink();

                    final isSelected = currentAns?.selectedOption?.toUpperCase() == optKey;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => _selectOption(optKey),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade200,
                                child: Text(
                                  optKey,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  optText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Bottom Navigation Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: _currentIndex > 0
                      ? () => setState(() => _currentIndex--)
                      : null,
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: currentAns?.selectedOption != null ? _clearResponse : null,
                  child: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: _currentIndex < _questions.length - 1
                      ? () => setState(() => _currentIndex++)
                      : _submitTest,
                  child: Text(
                    _currentIndex < _questions.length - 1 ? 'Next' : 'Submit Test',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuestionPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Question Palette',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _legendItem(Colors.green, 'Answered'),
                  _legendItem(Colors.purple, 'Review'),
                  _legendItem(Colors.amber, 'Important ⭐'),
                  _legendItem(Colors.grey.shade400, 'Unvisited'),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _questions.length,
                  itemBuilder: (ctx, idx) {
                    final q = _questions[idx];
                    final ans = _answers[q.id];
                    final isAns = ans?.selectedOption != null;
                    final isRev = ans?.markedForReview == true;
                    final isImp = _importantQuestionIds.contains(q.id);

                    Color bg = Colors.grey.shade200;
                    Color textCol = Colors.black87;

                    if (isRev) {
                      bg = Colors.purple;
                      textCol = Colors.white;
                    } else if (isAns) {
                      bg = Colors.green;
                      textCol = Colors.white;
                    }

                    return Stack(
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _currentIndex = idx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _currentIndex == idx
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textCol,
                              ),
                            ),
                          ),
                        ),
                        if (isImp)
                          const Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(Icons.star, size: 12, color: Colors.amber),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
