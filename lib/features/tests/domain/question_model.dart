class QuestionModel {
  final String id;
  final String exam; // 'UPSC' or 'TNPSC'
  final String subject;
  final String topic;
  final String ncertChapter;
  final String difficulty; // 'easy', 'medium', 'hard'
  final String publishDate; // 'YYYY-MM-DD'
  final String status; // 'published', 'draft'
  final String uploadBatchId;
  final DateTime? uploadedAt;
  final String correctAnswer; // 'A', 'B', 'C', 'D'
  final String normalizedText;
  final String? pyqYear; // e.g. "2024", "2023", etc.
  final bool isPyq;
  final Map<String, QuestionTranslation> translations;

  QuestionModel({
    required this.id,
    required this.exam,
    required this.subject,
    required this.topic,
    required this.ncertChapter,
    required this.difficulty,
    required this.publishDate,
    this.status = 'published',
    this.uploadBatchId = '',
    this.uploadedAt,
    required this.correctAnswer,
    required this.normalizedText,
    this.pyqYear,
    this.isPyq = false,
    required this.translations,
  });

  /// Check if question is fully translated for given language
  bool isFullyTranslated(String languageCode) {
    if (languageCode == 'en') return true;
    final tr = translations[languageCode];
    if (tr == null) return false;
    if (tr.question.trim().isEmpty) return false;
    final opts = tr.options;
    if (!opts.containsKey('A') || !opts.containsKey('B') || !opts.containsKey('C') || !opts.containsKey('D')) {
      return false;
    }
    return true;
  }

  /// Convenience getter for localized question text.
  /// RULE 4: If any part of translation is missing for the language,
  /// fallback to English for the WHOLE question (never a half-translated one).
  String getLocalizedQuestion(String languageCode) {
    if (isFullyTranslated(languageCode)) {
      return translations[languageCode]!.question;
    }
    return translations['en']?.question ?? '';
  }

  Map<String, String> getLocalizedOptions(String languageCode) {
    if (isFullyTranslated(languageCode)) {
      return translations[languageCode]!.options;
    }
    return translations['en']?.options ?? {};
  }

  String getLocalizedExplanation(String languageCode) {
    if (isFullyTranslated(languageCode)) {
      return translations[languageCode]!.explanation;
    }
    return translations['en']?.explanation ?? '';
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map, String id) {
    final rawTranslations = map['translations'] as Map<String, dynamic>? ?? {};
    final parsedTranslations = <String, QuestionTranslation>{};

    rawTranslations.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedTranslations[key] = QuestionTranslation.fromMap(val);
      }
    });

    return QuestionModel(
      id: id,
      exam: map['exam'] ?? 'UPSC',
      subject: map['subject'] ?? 'General Studies',
      topic: map['topic'] ?? '',
      ncertChapter: map['ncertChapter'] ?? '',
      difficulty: map['difficulty'] ?? 'medium',
      publishDate: map['publishDate'] ?? '',
      status: map['status'] ?? 'published',
      uploadBatchId: map['uploadBatchId'] ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? DateTime.tryParse(map['uploadedAt'].toString())
          : null,
      correctAnswer: map['correctAnswer'] ?? map['correct_answer'] ?? 'A',
      normalizedText: map['normalizedText'] ?? map['question'] ?? '',
      pyqYear: map['pyqYear'] ?? map['pyq_year'] ?? (map['year'] != null ? map['year'].toString() : null),
      isPyq: map['isPyq'] == true || map['is_pyq'] == true || map['year'] != null || map['pyqYear'] != null,
      translations: parsedTranslations,
    );
  }

  Map<String, dynamic> toMap() {
    final trMap = <String, dynamic>{};
    translations.forEach((k, v) => trMap[k] = v.toMap());

    return {
      'id': id,
      'exam': exam,
      'subject': subject,
      'topic': topic,
      'ncertChapter': ncertChapter,
      'difficulty': difficulty,
      'publishDate': publishDate,
      'status': status,
      'uploadBatchId': uploadBatchId,
      'uploadedAt': uploadedAt?.toIso8601String(),
      'correctAnswer': correctAnswer,
      'normalizedText': normalizedText,
      'pyqYear': pyqYear,
      'isPyq': isPyq,
      'translations': trMap,
    };
  }
}

class QuestionTranslation {
  final String question;
  final Map<String, String> options; // {'a': '...', 'b': '...', 'c': '...', 'd': '...'}
  final String explanation;

  QuestionTranslation({
    required this.question,
    required this.options,
    required this.explanation,
  });

  factory QuestionTranslation.fromMap(Map<String, dynamic> map) {
    final opts = map['options'] as Map<String, dynamic>? ?? {};
    final stringOpts = <String, String>{};
    opts.forEach((k, v) => stringOpts[k.toString().toLowerCase()] = v.toString());

    return QuestionTranslation(
      question: map['question'] ?? '',
      options: stringOpts,
      explanation: map['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'explanation': explanation,
    };
  }
}

