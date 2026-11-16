import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';
import 'timed_engine_screen.dart';
import 'pdf_report_generator.dart';

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
  bool _isGeneratingPdf = false;
  String _studentName = 'Aspirant';
  String _appLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _studentName = prefs.getString('student_name') ?? 'Aspirant';
      _appLanguage = prefs.getString('app_language') ?? 'en';
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
            final qText = m['question'] ?? '';
            final exp = m['explanation'] ?? '';
            return QuestionModel(
              id: m['id'] ?? '',
              exam: m['exam'] ?? 'UPSC',
              subject: m['subject'] ?? 'General Studies',
              topic: m['topic'] ?? '',
              ncertChapter: '',
              difficulty: 'medium',
              publishDate: '2026-11-16',
              correctAnswer: m['correct_answer'] ?? 'A',
              normalizedText: qText,
              pyqYear: m['pyq_year'] ?? m['pyqYear'] ?? (m['year'] != null ? m['year'].toString() : null),
              isPyq: m['is_pyq'] == true || m['isPyq'] == true || m['year'] != null || m['pyqYear'] != null,
              translations: {
                'en': QuestionTranslation(question: qText, options: opts, explanation: exp),
                'ta': QuestionTranslation(question: qText, options: opts, explanation: exp),
                'hi': QuestionTranslation(question: qText, options: opts, explanation: exp),
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
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exam Result & Review'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home Dashboard',
              onPressed: () => context.go('/home'),
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
            const SizedBox(height: 12),

            // Dedicated Full PDF Download Button placed directly below Wrong Questions switch
            ElevatedButton.icon(
              onPressed: _isGeneratingPdf ? null : _downloadPdfReport,
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: Text(
                _isGeneratingPdf ? 'Generating PDF Scorecard...' : 'Download Official PDF Scorecard & Review',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 20),

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
                  final options = q.getLocalizedOptions(_appLanguage);

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
                              const Spacer(),
                              if (q.isPyq || q.pyqYear != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Text(
                                    'PYQ ${q.pyqYear ?? ''}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            q.getLocalizedQuestion(_appLanguage),
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
              icon: _isGeneratingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_for_offline),
              label: const Text('Download Detailed PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isGeneratingPdf ? null : _downloadPdfReport,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Back to Home Dashboard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/home'),
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

    Color bg = Theme.of(context).cardColor;
    Color border = Theme.of(context).dividerColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isCorrectOption) {
      bg = isDark ? const Color(0xFF064E3B) : Colors.green.shade50;
      border = Colors.green;
      textColor = isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900;
    } else if (isUserChoice) {
      bg = isDark ? const Color(0xFF7F1D1D) : Colors.red.shade50;
      border = Colors.red;
      textColor = isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900;
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

  Future<void> _downloadPdfReport() async {
    if (_session == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final path = await PdfReportGenerator.generateAndOpenTestReport(
        studentName: _studentName,
        testTitle: _test?.title ?? 'Test 11 Mock Exam',
        exam: _test?.exam ?? 'Exam',
        session: _session!,
        questions: _questions,
        language: _appLanguage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF Report generated: $path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
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
