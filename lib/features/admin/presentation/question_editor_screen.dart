import 'package:flutter/material.dart';
import '../../tests/domain/question_model.dart';

class QuestionEditorScreen extends StatefulWidget {
  final QuestionModel? existingQuestion;
  final Function(QuestionModel) onSave;

  const QuestionEditorScreen({
    super.key,
    this.existingQuestion,
    required this.onSave,
  });

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _qEnController;
  late TextEditingController _optAController;
  late TextEditingController _optBController;
  late TextEditingController _optCController;
  late TextEditingController _optDController;
  late TextEditingController _explanationController;
  late TextEditingController _subjectController;
  late TextEditingController _topicController;
  late TextEditingController _ncertController;

  // Translations
  late TextEditingController _qTaController;
  late TextEditingController _qHiController;

  String _exam = 'UPSC';
  String _difficulty = 'medium';
  String _correctAnswer = 'A';

  @override
  void initState() {
    super.initState();
    final q = widget.existingQuestion;
    _qEnController = TextEditingController(text: q?.getLocalizedQuestion('en') ?? '');
    _optAController = TextEditingController(text: q?.getLocalizedOptions('en')['a'] ?? '');
    _optBController = TextEditingController(text: q?.getLocalizedOptions('en')['b'] ?? '');
    _optCController = TextEditingController(text: q?.getLocalizedOptions('en')['c'] ?? '');
    _optDController = TextEditingController(text: q?.getLocalizedOptions('en')['d'] ?? '');
    _explanationController = TextEditingController(text: q?.getLocalizedExplanation('en') ?? '');
    _subjectController = TextEditingController(text: q?.subject ?? 'History');
    _topicController = TextEditingController(text: q?.topic ?? '');
    _ncertController = TextEditingController(text: q?.ncertChapter ?? '');

    _qTaController = TextEditingController(text: q?.getLocalizedQuestion('ta') ?? '');
    _qHiController = TextEditingController(text: q?.getLocalizedQuestion('hi') ?? '');

    if (q != null) {
      _exam = q.exam;
      _difficulty = q.difficulty;
      _correctAnswer = q.correctAnswer;
    }
  }

  @override
  void dispose() {
    _qEnController.dispose();
    _optAController.dispose();
    _optBController.dispose();
    _optCController.dispose();
    _optDController.dispose();
    _explanationController.dispose();
    _subjectController.dispose();
    _topicController.dispose();
    _ncertController.dispose();
    _qTaController.dispose();
    _qHiController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final translations = <String, QuestionTranslation>{
        'en': QuestionTranslation(
          question: _qEnController.text.trim(),
          options: {
            'a': _optAController.text.trim(),
            'b': _optBController.text.trim(),
            'c': _optCController.text.trim(),
            'd': _optDController.text.trim(),
          },
          explanation: _explanationController.text.trim(),
        ),
      };

      if (_qTaController.text.trim().isNotEmpty) {
        translations['ta'] = QuestionTranslation(
          question: _qTaController.text.trim(),
          options: {
            'a': _optAController.text.trim(),
            'b': _optBController.text.trim(),
            'c': _optCController.text.trim(),
            'd': _optDController.text.trim(),
          },
          explanation: _explanationController.text.trim(),
        );
      }

      if (_qHiController.text.trim().isNotEmpty) {
        translations['hi'] = QuestionTranslation(
          question: _qHiController.text.trim(),
          options: {
            'a': _optAController.text.trim(),
            'b': _optBController.text.trim(),
            'c': _optCController.text.trim(),
            'd': _optDController.text.trim(),
          },
          explanation: _explanationController.text.trim(),
        );
      }

      final normalized = _qEnController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final question = QuestionModel(
        id: widget.existingQuestion?.id ??
            'q_${DateTime.now().microsecondsSinceEpoch}',
        exam: _exam,
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        ncertChapter: _ncertController.text.trim(),
        difficulty: _difficulty,
        publishDate: widget.existingQuestion?.publishDate ?? todayStr,
        status: 'published',
        correctAnswer: _correctAnswer,
        normalizedText: normalized,
        translations: translations,
        uploadedAt: widget.existingQuestion?.uploadedAt ?? DateTime.now(),
      );

      widget.onSave(question);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingQuestion == null
            ? 'Add Question'
            : 'Edit Question'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exam & Difficulty Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _exam,
                      decoration: const InputDecoration(labelText: 'Exam'),
                      items: const [
                        DropdownMenuItem(value: 'UPSC', child: Text('UPSC')),
                        DropdownMenuItem(value: 'TNPSC', child: Text('TNPSC')),
                      ],
                      onChanged: (v) => setState(() => _exam = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(labelText: 'Difficulty'),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subject & Topic
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => v!.isEmpty ? 'Subject required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ncertController,
                decoration: const InputDecoration(labelText: 'NCERT Reference'),
              ),
              const SizedBox(height: 16),

              // English Question Text
              TextFormField(
                controller: _qEnController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Question (English) *'),
                validator: (v) => v!.isEmpty ? 'Question text required' : null,
              ),
              const SizedBox(height: 16),

              // Options
              TextFormField(
                controller: _optAController,
                decoration: const InputDecoration(labelText: 'Option A *'),
                validator: (v) => v!.isEmpty ? 'Option A required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _optBController,
                decoration: const InputDecoration(labelText: 'Option B *'),
                validator: (v) => v!.isEmpty ? 'Option B required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _optCController,
                decoration: const InputDecoration(labelText: 'Option C *'),
                validator: (v) => v!.isEmpty ? 'Option C required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _optDController,
                decoration: const InputDecoration(labelText: 'Option D *'),
                validator: (v) => v!.isEmpty ? 'Option D required' : null,
              ),
              const SizedBox(height: 16),

              // Correct Answer Dropdown
              DropdownButtonFormField<String>(
                value: _correctAnswer,
                decoration: const InputDecoration(labelText: 'Correct Option *'),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Option A')),
                  DropdownMenuItem(value: 'B', child: Text('Option B')),
                  DropdownMenuItem(value: 'C', child: Text('Option C')),
                  DropdownMenuItem(value: 'D', child: Text('Option D')),
                ],
                onChanged: (v) => setState(() => _correctAnswer = v!),
              ),
              const SizedBox(height: 16),

              // Explanation
              TextFormField(
                controller: _explanationController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Explanation'),
              ),
              const SizedBox(height: 24),

              // Optional Translations Accordion
              ExpansionTile(
                title: const Text('Optional Translations (Tamil & Hindi)'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _qTaController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question in Tamil (தமிழ்)',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: _qHiController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question in Hindi (हिन्दी)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Question'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

