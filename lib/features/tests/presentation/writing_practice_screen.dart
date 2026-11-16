import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

class WritingPracticeScreen extends ConsumerStatefulWidget {
  const WritingPracticeScreen({super.key});

  @override
  ConsumerState<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends ConsumerState<WritingPracticeScreen> {
  final _answerController = TextEditingController();
  final int _wordLimit = 250;
  int _currentWordCount = 0;
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isSaving = false;

  final String _question =
      'Discuss the significance of the Bhakti and Sufi movements in shaping the composite culture and social harmony of medieval India. (150-250 words)';

  @override
  void initState() {
    super.initState();
    _startTimer();
    _answerController.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  void _updateWordCount() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      setState(() => _currentWordCount = 0);
    } else {
      final words = text.split(RegExp(r'\s+'));
      setState(() => _currentWordCount = words.length);
    }
  }

  Future<void> _saveAnswer() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    if (_answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write an answer before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('writing_practice_submissions')
          .add({
        'userId': user.uid,
        'question': _question,
        'exam': 'UPSC',
        'wordLimit': _wordLimit,
        'wordCount': _currentWordCount,
        'content': _answerController.text.trim(),
        'timeTakenSeconds': _secondsElapsed,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer saved successfully to your portfolio!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving answer: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    final isOverLimit = _currentWordCount > _wordLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mains Writing Practice'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Question Prompt Box
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UPSC GS Paper 1 • Culture & History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Word Count Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Answer:'),
                Text(
                  '$_currentWordCount / $_wordLimit words',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOverLimit ? Colors.red : Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Text Area
            TextField(
              controller: _answerController,
              maxLines: 14,
              decoration: InputDecoration(
                hintText:
                  'Structure your answer with: Introduction (Context/Definition), Body paragraphs (Key contributions, saints, social impacts), and Conclusion...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAnswer,
              icon: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Save & Submit Answer'),
            ),
          ],
        ),
      ),
    );
  }
}
