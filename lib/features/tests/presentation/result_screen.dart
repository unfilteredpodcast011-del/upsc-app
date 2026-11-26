import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';
import 'timed_engine_screen.dart';
import 'pdf_report_generator.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

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

            final rawTrans = m['translations'] as Map<String, dynamic>?;
            final Map<String, QuestionTranslation> transMap = {};
            if (rawTrans != null) {
              rawTrans.forEach((lang, tData) {
                if (tData is Map<String, dynamic>) {
                  final tOpts = (tData['options'] as Map<String, dynamic>?)?.map(
                        (k, v) => MapEntry(k, v.toString()),
                      ) ??
                      opts;
                  transMap[lang] = QuestionTranslation(
                    question: tData['question'] ?? qText,
                    options: tOpts,
                    explanation: tData['explanation'] ?? exp,
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
              translations: transMap,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPaddingAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Score Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                  AppSpacing.vXs,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${s.score.toStringAsFixed(2)} / ${totalMarks.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AppSpacing.vMd,
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
            AppSpacing.vLg,

            // Performance Breakdown Row
            Row(
              children: [
                _statTile('Correct', '${s.totalCorrect}', Colors.green),
                AppSpacing.hSm,
                _statTile('Wrong', '${s.totalWrong}', Colors.red),
                AppSpacing.hSm,
                _statTile('Skipped', '${s.totalUnanswered}', Colors.grey),
              ],
            ),
            AppSpacing.vXl,

            // Filter Switch: All Questions vs Only Wrong Answers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Show Only Wrong Questions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
            AppSpacing.vMd,

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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
            AppSpacing.vLg,

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
                              AppSpacing.hSm,
                              Expanded(
                                child: Text(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
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
                          AppSpacing.vSm,
                          Text(
                            q.getLocalizedQuestion(_appLanguage),
                            style: AppTypography.localizedStyle(
                              languageCode: _appLanguage,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                          AppSpacing.vMd,
                          // Display options
                          _optionBox('A', options['A'] ?? '', q.correctAnswer, userChoice),
                          _optionBox('B', options['B'] ?? '', q.correctAnswer, userChoice),
                          _optionBox('C', options['C'] ?? '', q.correctAnswer, userChoice),
                          _optionBox('D', options['D'] ?? '', q.correctAnswer, userChoice),
                          AppSpacing.vMd,
                          // Inline Detailed Explanation Box directly on card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF3B82F6).withOpacity(0.4)
                                    : const Color(0xFFBFDBFE),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 16,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF1D4ED8),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppStrings.get('solution_explanation', _appLanguage),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  q.getLocalizedExplanation(_appLanguage).isNotEmpty
                                      ? q.getLocalizedExplanation(_appLanguage)
                                      : 'Explanation available in detailed evaluation sheet.',
                                  style: AppTypography.localizedStyle(
                                    languageCode: _appLanguage,
                                    fontSize: 13,
                                    height: 1.45,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF1E293B),
                                    textLength: q.getLocalizedExplanation(_appLanguage).length,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.vMd,
                          // Full-screen review modal button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF1E3A8A),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.fullscreen_rounded, size: 18),
                              label: Text(
                                AppStrings.get('review_solution', _appLanguage),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
                              ),
                              onPressed: () => _openReviewSolutionModal(displayQuestions, index),
                            ),
                          ),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$optionLetter. ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.localizedStyle(
                languageCode: _appLanguage,
                fontSize: 13.5,
                color: textColor,
                height: 1.4,
              ),
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

  void _openReviewSolutionModal(List<QuestionModel> questionsList, int initialIndex) {
    int curIdx = initialIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final q = questionsList[curIdx];
            final ans = _session?.answers[q.id];
            final userChoice = ans?.selectedOption;
            final isCorrect = userChoice != null && userChoice.toUpperCase() == q.correctAnswer.toUpperCase();
            final isSkipped = userChoice == null;
            final opts = q.getLocalizedOptions(_appLanguage);
            final exp = q.getLocalizedExplanation(_appLanguage);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Modal Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${curIdx + 1} of ${questionsList.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.shade50
                                : (isSkipped ? Colors.grey.shade100 : Colors.red.shade50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green.shade300
                                  : (isSkipped ? Colors.grey.shade300 : Colors.red.shade300),
                            ),
                          ),
                          child: Text(
                            isCorrect ? 'Correct (+2)' : (isSkipped ? 'Skipped (0)' : 'Wrong (-0.66)'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCorrect
                                  ? Colors.green.shade800
                                  : (isSkipped ? Colors.grey.shade800 : Colors.red.shade800),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Solution Content Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            q.getLocalizedQuestion(_appLanguage),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4),
                          ),
                          const SizedBox(height: 14),

                          // 4 Options with clear highlights
                          ...['A', 'B', 'C', 'D'].map((optKey) {
                            final text = opts[optKey] ?? '';
                            final isThisOfficial = optKey == q.correctAnswer;
                            final isThisUser = optKey == userChoice;
                            final isDark = Theme.of(context).brightness == Brightness.dark;

                            Color borderCol = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
                            Color bgCol = isDark ? const Color(0xFF1E293B) : Colors.white;
                            Color optTextColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

                            if (isThisOfficial) {
                              borderCol = Colors.green;
                              bgCol = isDark ? const Color(0xFF064E3B) : Colors.green.shade50;
                              optTextColor = isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900;
                            } else if (isThisUser && !isCorrect) {
                              borderCol = Colors.red;
                              bgCol = isDark ? const Color(0xFF7F1D1D) : Colors.red.shade50;
                              optTextColor = isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgCol,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderCol, width: (isThisOfficial || isThisUser) ? 1.5 : 1),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: borderCol,
                                    foregroundColor: (isThisOfficial || (isThisUser && !isCorrect)) ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    child: Text(optKey, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      text, 
                                      style: TextStyle(
                                        fontSize: 13, 
                                        height: 1.35, 
                                        color: optTextColor,
                                      ),
                                    ),
                                  ),
                                  if (isThisOfficial)
                                    const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                  if (isThisUser && !isCorrect)
                                    const Icon(Icons.cancel, size: 18, color: Colors.red),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),

                          // User Choice vs Official Correct
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF334155)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${AppStrings.get("your_selected_option", _appLanguage)}:',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF94A3B8)
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      userChoice ?? 'Skipped',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isCorrect ? Colors.green : (isSkipped ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Colors.grey) : Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${AppStrings.get("official_correct_option", _appLanguage)}:',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF94A3B8)
                                            : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Option ${q.correctAnswer}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Detailed Explanation Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF3B82F6).withOpacity(0.4)
                                    : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.menu_book_rounded,
                                      size: 16,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF1D4ED8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppStrings.get('solution_explanation', _appLanguage),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF93C5FD)
                                            : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  exp.isNotEmpty ? exp : 'Explanation available in detailed evaluation sheet.',
                                  style: AppTypography.localizedStyle(
                                    languageCode: _appLanguage,
                                    fontSize: 13,
                                    height: 1.45,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFF1E293B),
                                    textLength: exp.length,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Modal Navigation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: curIdx > 0
                              ? () => setModalState(() => curIdx--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: Text(AppStrings.get('previous_question', _appLanguage)),
                        ),
                        Text(
                          '${curIdx + 1} / ${questionsList.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        ElevatedButton.icon(
                          onPressed: curIdx < questionsList.length - 1
                              ? () => setModalState(() => curIdx++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: Text(AppStrings.get('next_question', _appLanguage)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
