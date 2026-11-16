import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import '../../features/tests/domain/question_model.dart';

class QuestionImportRow {
  final int rowNumber;
  final bool isValid;
  final String? errorMessage;
  final QuestionModel? question;
  final Map<String, dynamic> rawValues;

  QuestionImportRow({
    required this.rowNumber,
    required this.isValid,
    this.errorMessage,
    this.question,
    required this.rawValues,
  });
}

class QuestionFileParser {
  /// Generate the standard CSV template for Admins to download
  static String generateTemplateCsv() {
    final headers = [
      'question_en',
      'option_a',
      'option_b',
      'option_c',
      'option_d',
      'correct_answer',
      'explanation',
      'exam',
      'subject',
      'topic',
      'ncert_class_chapter',
      'difficulty',
      'publish_date',
      'question_ta',
      'option_a_ta',
      'option_b_ta',
      'option_c_ta',
      'option_d_ta',
      'explanation_ta',
      'question_hi',
      'option_a_hi',
      'option_b_hi',
      'option_c_hi',
      'option_d_hi',
      'explanation_hi',
    ];

    final sampleRow = [
      'Who among the following was the founder of the Maurya Empire?',
      'Chandragupta Maurya',
      'Ashoka',
      'Bindusara',
      'Brihadratha',
      'A',
      'Chandragupta Maurya founded the Maurya Empire in 322 BCE with the help of Chanakya.',
      'UPSC',
      'History',
      'Mauryan Empire',
      'Class 6 Chapter 7',
      'easy',
      '2026-11-14',
      'மௌரியப் பேரரசை நிறுவியவர் யார்?',
      'சந்திரகுப்த மௌரியர்',
      'அசோகர்',
      'பிந்துசாரர்',
      'பிருகத்ரதன்',
      'சாணக்கியரின் உதவியுடன் கி.மு 322 இல் சந்திரகுப்த மௌரியர் ஆட்சியை நிறுவினார்.',
      'मौर्य साम्राज्य के संस्थापक निम्नलिखित में से कौन थे?',
      'चन्द्रगुप्त मौर्य',
      'अशोक',
      'बिन्दुसार',
      'बृहद्रथ',
      'चाणक्य की सहायता से 322 ईसा पूर्व में चंद्रगुप्त मौर्य ने मौर्य साम्राज्य की स्थापना की थी।',
    ];

    return const ListToCsvConverter().convert([headers, sampleRow]);
  }

  /// Parse either CSV or XLSX bytes into validated QuestionImportRow list
  static List<QuestionImportRow> parseBytes({
    required Uint8List bytes,
    required String fileName,
    required String batchId,
  }) {
    if (fileName.toLowerCase().endsWith('.xlsx')) {
      return _parseExcel(bytes, batchId);
    } else {
      return _parseCsv(bytes, batchId);
    }
  }

  static List<QuestionImportRow> _parseExcel(Uint8List bytes, String batchId) {
    final excel = Excel.decodeBytes(bytes);
    final results = <QuestionImportRow>[];
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName];

    if (table == null || table.rows.isEmpty) {
      return results;
    }

    final headerRow = table.rows.first
        .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    final seenNormalizedQuestions = <String>{};

    for (int i = 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      if (row.isEmpty || row.every((c) => c?.value == null || c!.value.toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      final map = <String, dynamic>{};
      for (int j = 0; j < headerRow.length; j++) {
        if (j < row.length) {
          map[headerRow[j]] = row[j]?.value?.toString().trim() ?? '';
        }
      }

      results.add(_validateAndBuildQuestion(
        rowNumber: i + 1,
        map: map,
        batchId: batchId,
        seenQuestions: seenNormalizedQuestions,
      ));
    }

    return results;
  }

  static List<QuestionImportRow> _parseCsv(Uint8List bytes, String batchId) {
    final content = String.fromCharCodes(bytes);
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    final results = <QuestionImportRow>[];

    if (rows.isEmpty) return results;

    final headerRow = rows.first
        .map((cell) => cell?.toString().trim().toLowerCase() ?? '')
        .toList();

    final seenNormalizedQuestions = <String>{};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
        continue;
      }

      final map = <String, dynamic>{};
      for (int j = 0; j < headerRow.length; j++) {
        if (j < row.length) {
          map[headerRow[j]] = row[j]?.toString().trim() ?? '';
        }
      }

      results.add(_validateAndBuildQuestion(
        rowNumber: i + 1,
        map: map,
        batchId: batchId,
        seenQuestions: seenNormalizedQuestions,
      ));
    }

    return results;
  }

  static QuestionImportRow _validateAndBuildQuestion({
    required int rowNumber,
    required Map<String, dynamic> map,
    required String batchId,
    required Set<String> seenQuestions,
  }) {
    final questionEn = (map['question_en'] ?? map['question'] ?? '').toString().trim();
    final optA = (map['option_a'] ?? '').toString().trim();
    final optB = (map['option_b'] ?? '').toString().trim();
    final optC = (map['option_c'] ?? '').toString().trim();
    final optD = (map['option_d'] ?? '').toString().trim();
    final correctAnswer = (map['correct_answer'] ?? '').toString().trim().toUpperCase();
    final explanation = (map['explanation'] ?? '').toString().trim();
    final exam = (map['exam'] ?? 'UPSC').toString().trim().toUpperCase();
    final subject = (map['subject'] ?? 'General Studies').toString().trim();
    final topic = (map['topic'] ?? '').toString().trim();
    final ncert = (map['ncert_class_chapter'] ?? map['ncert'] ?? '').toString().trim();
    final difficulty = (map['difficulty'] ?? 'medium').toString().trim().toLowerCase();
    var publishDate = (map['publish_date'] ?? '').toString().trim();

    // Validation checks
    if (questionEn.isEmpty) {
      return QuestionImportRow(
        rowNumber: rowNumber,
        isValid: false,
        errorMessage: 'Missing question_en text',
        rawValues: map,
      );
    }

    if (optA.isEmpty || optB.isEmpty || optC.isEmpty || optD.isEmpty) {
      return QuestionImportRow(
        rowNumber: rowNumber,
        isValid: false,
        errorMessage: 'All 4 options (A, B, C, D) are required',
        rawValues: map,
      );
    }

    if (!['A', 'B', 'C', 'D'].contains(correctAnswer)) {
      return QuestionImportRow(
        rowNumber: rowNumber,
        isValid: false,
        errorMessage: 'Invalid correct_answer: "$correctAnswer" (Must be A, B, C, or D)',
        rawValues: map,
      );
    }

    final normalized = questionEn
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();

    if (seenQuestions.contains(normalized)) {
      return QuestionImportRow(
        rowNumber: rowNumber,
        isValid: false,
        errorMessage: 'Duplicate question text in this file',
        rawValues: map,
      );
    }
    seenQuestions.add(normalized);

    if (publishDate.isEmpty) {
      // Default to today
      final now = DateTime.now();
      publishDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    // Translations map
    final translations = <String, QuestionTranslation>{
      'en': QuestionTranslation(
        question: questionEn,
        options: {'a': optA, 'b': optB, 'c': optC, 'd': optD},
        explanation: explanation,
      ),
    };

    // Check optional Tamil
    final qTa = (map['question_ta'] ?? '').toString().trim();
    if (qTa.isNotEmpty) {
      translations['ta'] = QuestionTranslation(
        question: qTa,
        options: {
          'a': (map['option_a_ta'] ?? optA).toString().trim(),
          'b': (map['option_b_ta'] ?? optB).toString().trim(),
          'c': (map['option_c_ta'] ?? optC).toString().trim(),
          'd': (map['option_d_ta'] ?? optD).toString().trim(),
        },
        explanation: (map['explanation_ta'] ?? explanation).toString().trim(),
      );
    }

    // Check optional Hindi
    final qHi = (map['question_hi'] ?? '').toString().trim();
    if (qHi.isNotEmpty) {
      translations['hi'] = QuestionTranslation(
        question: qHi,
        options: {
          'a': (map['option_a_hi'] ?? optA).toString().trim(),
          'b': (map['option_b_hi'] ?? optB).toString().trim(),
          'c': (map['option_c_hi'] ?? optC).toString().trim(),
          'd': (map['option_d_hi'] ?? optD).toString().trim(),
        },
        explanation: (map['explanation_hi'] ?? explanation).toString().trim(),
      );
    }

    final id = 'q_${DateTime.now().microsecondsSinceEpoch}_$rowNumber';

    final question = QuestionModel(
      id: id,
      exam: exam.contains('TNPSC') ? 'TNPSC' : 'UPSC',
      subject: subject,
      topic: topic,
      ncertChapter: ncert,
      difficulty: ['easy', 'medium', 'hard'].contains(difficulty) ? difficulty : 'medium',
      publishDate: publishDate,
      status: 'published',
      uploadBatchId: batchId,
      uploadedAt: DateTime.now(),
      correctAnswer: correctAnswer,
      normalizedText: normalized,
      translations: translations,
    );

    return QuestionImportRow(
      rowNumber: rowNumber,
      isValid: true,
      question: question,
      rawValues: map,
    );
  }
}
