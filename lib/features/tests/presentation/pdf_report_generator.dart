import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:tamil_pdf_shaper/tamil_pdf_shaper.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';

class PdfReportGenerator {
  static const Map<String, Map<String, String>> _pdfI18n = {
    'en': {
      'report_title': 'TEST 11 - OFFICIAL EXAM REPORT',
      'target_exam': 'Target Exam',
      'date': 'Date',
      'sub_header': 'Official Timed Practice Test Performance',
      'candidate_name': 'Candidate Name',
      'final_score': 'Final Score',
      'accuracy': 'Accuracy',
      'correct': 'Correct',
      'wrong': 'Wrong',
      'skipped': 'Skipped',
      'time_taken': 'Time Taken',
      'min': 'min',
      'breakdown_title': 'Detailed Question, Answer & Explanation Breakdown',
      'system_tag': 'Test 11 Evaluation System',
      'question': 'Question',
      'pyq': 'PYQ',
      'correct_badge': '✓ CORRECT (+2.0)',
      'wrong_badge': '✗ WRONG (-0.66)',
      'skipped_badge': '○ SKIPPED (0.0)',
      'your_answer': 'Your Answer',
      'correct_answer': 'Correct Answer',
      'option': 'Option',
      'none': 'None',
      'explanation': 'Explanation',
    },
    'ta': {
      'report_title': 'TEST 11 - அதிகாரப்பூர்வ தேர்வு அறிக்கை',
      'target_exam': 'இலக்கு தேர்வு',
      'date': 'தேதி',
      'sub_header': 'நேரக்கட்டுப்பாடு கொண்ட பயிற்சி தேர்வு செயல்திறன்',
      'candidate_name': 'தேர்வர் பெயர்',
      'final_score': 'இறுதி மதிப்பெண்',
      'accuracy': 'துல்லியம்',
      'correct': 'சரி',
      'wrong': 'தவறு',
      'skipped': 'தவிர்க்கப்பட்டது',
      'time_taken': 'எடுத்துக்கொண்ட நேரம்',
      'min': 'நிமிடம்',
      'breakdown_title': 'விரிவான கேள்வி, விடை மற்றும் விளக்கப் பகுப்பாய்வு',
      'system_tag': 'Test 11 மதிப்பீட்டு அமைப்பு',
      'question': 'கேள்வி',
      'pyq': 'முந்தைய ஆண்டு கேள்வி',
      'correct_badge': '✓ சரி (+2.0)',
      'wrong_badge': '✗ தவறு (-0.66)',
      'skipped_badge': '○ பதிலளிக்கப்படவில்லை (0.0)',
      'your_answer': 'உங்கள் விடை',
      'correct_answer': 'சரியான விடை',
      'option': 'விருப்பம்',
      'none': 'இல்லை',
      'explanation': 'விளக்கம்',
    },
    'hi': {
      'report_title': 'TEST 11 - आधिकारिक परीक्षा रिपोर्ट',
      'target_exam': 'लक्ष्य परीक्षा',
      'date': 'दिनांक',
      'sub_header': 'आधिकारिक समयबद्ध अभ्यास परीक्षा प्रदर्शन',
      'candidate_name': 'परीक्षार्थी का नाम',
      'final_score': 'अंतिम स्कोर',
      'accuracy': 'सटीकता',
      'correct': 'सही',
      'wrong': 'गलत',
      'skipped': 'छोड़ा गया',
      'time_taken': 'लिया गया समय',
      'min': 'मिनट',
      'breakdown_title': 'विस्तृत प्रश्न, उत्तर और व्याख्या विश्लेषण',
      'system_tag': 'Test 11 मूल्यांकन प्रणाली',
      'question': 'प्रश्न',
      'pyq': 'पिछले वर्ष का प्रश्न',
      'correct_badge': '✓ सही (+2.0)',
      'wrong_badge': '✗ गलत (-0.66)',
      'skipped_badge': '○ अनुत्तरित (0.0)',
      'your_answer': 'आपका उत्तर',
      'correct_answer': 'सही उत्तर',
      'option': 'विकल्प',
      'none': 'कोई नहीं',
      'explanation': 'विस्तृत व्याख्या',
    },
  };

  static String _t(String key, String lang) {
    final l = _pdfI18n.containsKey(lang) ? lang : 'en';
    final text = _pdfI18n[l]?[key] ?? _pdfI18n['en']?[key] ?? key;
    if (lang == 'ta') {
      return text.toTamilPdf;
    }
    return text;
  }

  static String _formatText(String text, String lang) {
    if (lang == 'ta') {
      return text.toTamilPdf;
    }
    return text;
  }

  static Future<String> generateAndOpenTestReport({
    required String studentName,
    required String testTitle,
    required String exam,
    required TestSessionModel session,
    required List<QuestionModel> questions,
    required String language,
  }) async {
    final pdf = pw.Document();

    final totalQ = questions.length;
    final totalMarks = (totalQ * 2.0).toStringAsFixed(0);
    final formattedDate = DateTime.now().toString().split('.')[0];

    // Load App Logo
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/app_logo.jpg');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      logoImage = null;
    }

    // Load Unicode fonts: NotoSans (base Latin) + Tamil / Hindi fallbacks
    pw.Font? baseRegular;
    pw.Font? baseBold;
    final List<pw.Font> fallbacks = [];

    try {
      final regData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      baseRegular = pw.Font.ttf(regData);
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      baseBold = pw.Font.ttf(boldData);
    } catch (e) {
      debugPrint('Base font load note: $e');
    }

    try {
      if (language == 'ta') {
        // Load the Anand MuktaMalar font provided by tamil_pdf_shaper
        try {
          final tamilMukta = await TamilPdfFont.load();
          fallbacks.add(tamilMukta);
        } catch (_) {
          final fontData = await rootBundle.load('assets/fonts/Anand_MuktaMalar.ttf');
          fallbacks.add(pw.Font.ttf(fontData));
        }
        final fontData = await rootBundle.load('assets/fonts/tamil.ttf');
        fallbacks.add(pw.Font.ttf(fontData));
        final boldFontData = await rootBundle.load('assets/fonts/NotoSansTamil-Bold.ttf');
        fallbacks.add(pw.Font.ttf(boldFontData));
      } else if (language == 'hi') {
        final fontData = await rootBundle.load('assets/fonts/hindi.ttf');
        fallbacks.add(pw.Font.ttf(fontData));
        final boldFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
        fallbacks.add(pw.Font.ttf(boldFontData));
      }
    } catch (e) {
      debugPrint('Script font load note: $e');
    }

    // Global document typography theme with registered fallbacks
    final themeData = pw.ThemeData.withFont(
      base: baseRegular,
      bold: baseBold,
      italic: baseRegular,
      boldItalic: baseBold,
      fontFallback: fallbacks,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: themeData,
        build: (pw.Context context) {
          return [
            // Header Banner with App Logo
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E3A8A'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(logoImage, width: 44, height: 44, fit: pw.BoxFit.cover),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _t('report_title', language),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              fontFallback: fallbacks,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '${_t("target_exam", language)}: $exam | ${_t("date", language)}: $formattedDate',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontFallback: fallbacks),
                          ),
                          pw.Text(
                            _t('sub_header', language),
                            style: pw.TextStyle(color: PdfColors.amberAccent, fontSize: 8, fontFallback: fallbacks),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${_t("candidate_name", language)}:',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontFallback: fallbacks),
                      ),
                      pw.Text(
                        studentName,
                        style: pw.TextStyle(
                          color: PdfColors.amberAccent,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          fontFallback: fallbacks,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Scorecard Summary Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                color: PdfColor.fromHex('#F8FAFC'),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _summaryCol(_t('final_score', language), '${session.score.toStringAsFixed(2)} / $totalMarks', PdfColor.fromHex('#1E3A8A'), fallbacks),
                  _summaryCol(_t('accuracy', language), '${session.accuracy.toStringAsFixed(1)}%', PdfColor.fromHex('#0F766E'), fallbacks),
                  _summaryCol(_t('correct', language), '${session.totalCorrect}', PdfColor.fromHex('#16A34A'), fallbacks),
                  _summaryCol(_t('wrong', language), '${session.totalWrong}', PdfColor.fromHex('#DC2626'), fallbacks),
                  _summaryCol(_t('skipped', language), '${session.totalUnanswered}', PdfColor.fromHex('#64748B'), fallbacks),
                  _summaryCol(_t('time_taken', language), '${(session.timeTakenSeconds / 60).toStringAsFixed(1)} ${_t("min", language)}', PdfColor.fromHex('#475569'), fallbacks),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _t('breakdown_title', language),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'), fontFallback: fallbacks),
                ),
                pw.Text(
                  _t('system_tag', language),
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontFallback: fallbacks),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // Questions List (Wrapped in pw.Wrap or atomic containers to prevent blank trailing boxes)
            ...questions.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final q = entry.value;
              final ans = session.answers[q.id];
              final userOption = ans?.selectedOption;
              final isCorrect = userOption != null && userOption.toUpperCase() == q.correctAnswer.toUpperCase();
              final isSkipped = userOption == null;

              final statusColor = isCorrect
                  ? PdfColor.fromHex('#16A34A')
                  : (isSkipped ? PdfColor.fromHex('#64748B') : PdfColor.fromHex('#DC2626'));
              final statusText = isCorrect
                  ? _t('correct_badge', language)
                  : (isSkipped ? _t('skipped_badge', language) : _t('wrong_badge', language));

              final opts = q.getLocalizedOptions(language);
              final qText = _formatText(q.getLocalizedQuestion(language), language);
              final explanation = _formatText(q.getLocalizedExplanation(language), language);
              final subjectText = _formatText(q.subject, language);

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: statusColor, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${_t("question", language)} $idx [$subjectText] ${q.isPyq ? "• ${_t('pyq', language)} ${q.pyqYear ?? ''}" : ""}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColor.fromHex('#1E293B'), fontFallback: fallbacks),
                          ),
                        ),
                        pw.Text(
                          statusText,
                          style: pw.TextStyle(
                            color: statusColor,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8.5,
                            fontFallback: fallbacks,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      qText,
                      style: pw.TextStyle(fontSize: 9, fontFallback: fallbacks),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${_t("your_answer", language)}: ${userOption != null ? "${_t("option", language)} $userOption" : _t("none", language)}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: statusColor,
                              fontFallback: fallbacks,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            '${_t("correct_answer", language)}: ${_t("option", language)} ${q.correctAnswer}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#16A34A'),
                              fontFallback: fallbacks,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (opts.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'A) ${_formatText(opts["A"] ?? opts["a"] ?? "", language)}   B) ${_formatText(opts["B"] ?? opts["b"] ?? "", language)}   C) ${_formatText(opts["C"] ?? opts["c"] ?? "", language)}   D) ${_formatText(opts["D"] ?? opts["d"] ?? "", language)}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontFallback: fallbacks),
                      ),
                    ],
                    // Detailed Explanation Section
                    if (explanation.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F1F5F9'),
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.6),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              '${_t("explanation", language)}:',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1E3A8A'),
                                fontFallback: fallbacks,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              explanation,
                              style: pw.TextStyle(fontSize: 7.8, color: PdfColors.black, fontFallback: fallbacks),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // Save and open
    final outputDir = await getApplicationDocumentsDirectory();
    final filePath = '${outputDir.path}/Test11_${session.id}_Report.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(filePath);
    return filePath;
  }

  static pw.Widget _summaryCol(String label, String value, PdfColor color, List<pw.Font> fallbacks) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, fontFallback: fallbacks)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color, fontFallback: fallbacks),
        ),
      ],
    );
  }
}
