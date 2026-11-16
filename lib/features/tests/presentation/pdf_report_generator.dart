import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../domain/test_model.dart';
import '../domain/question_model.dart';

class PdfReportGenerator {
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E3A8A'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TEST 11 - EXAM REPORT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Target Exam: $exam | Date: $formattedDate',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Candidate Name:',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                      ),
                      pw.Text(
                        studentName,
                        style: pw.TextStyle(
                          color: PdfColors.amberAccent,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Scorecard Summary Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColor.fromHex('#F8FAFC'),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _summaryCol('Final Score', '${session.score.toStringAsFixed(2)} / $totalMarks', PdfColor.fromHex('#1E3A8A')),
                  _summaryCol('Accuracy', '${session.accuracy.toStringAsFixed(1)}%', PdfColor.fromHex('#0F766E')),
                  _summaryCol('Correct', '${session.totalCorrect}', PdfColor.fromHex('#16A34A')),
                  _summaryCol('Wrong', '${session.totalWrong}', PdfColor.fromHex('#DC2626')),
                  _summaryCol('Skipped', '${session.totalUnanswered}', PdfColor.fromHex('#64748B')),
                  _summaryCol('Time Taken', '${(session.timeTakenSeconds / 60).toStringAsFixed(1)} min', PdfColor.fromHex('#475569')),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text(
              'Detailed Question & Answer Analysis',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            // Questions List
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
                  ? 'CORRECT (+2.0)'
                  : (isSkipped ? 'SKIPPED (0.0)' : 'WRONG (-0.66)');

              final opts = q.getLocalizedOptions('en');
              final qText = q.getLocalizedQuestion('en');

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
                        pw.Text(
                          'Question $idx [${q.subject}]',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                        pw.Text(
                          statusText,
                          style: pw.TextStyle(
                            color: statusColor,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      qText,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            'Your Answer: ${userOption ?? "None"}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            'Correct Answer: ${q.correctAnswer}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#16A34A'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (opts.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'A) ${opts["A"] ?? ""}   B) ${opts["B"] ?? ""}   C) ${opts["C"] ?? ""}   D) ${opts["D"] ?? ""}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
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

  static pw.Widget _summaryCol(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
