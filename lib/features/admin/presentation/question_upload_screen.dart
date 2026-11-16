import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/utils/question_file_parser.dart';
import '../../tests/domain/question_model.dart';
import '../data/admin_repository.dart';

final adminRepoProvider = Provider<AdminRepository>((ref) => AdminRepository());

class QuestionUploadScreen extends ConsumerStatefulWidget {
  const QuestionUploadScreen({super.key});

  @override
  ConsumerState<QuestionUploadScreen> createState() => _QuestionUploadScreenState();
}

class _QuestionUploadScreenState extends ConsumerState<QuestionUploadScreen> {
  bool _isLoading = false;
  String? _selectedFileName;
  List<QuestionImportRow> _parsedRows = [];
  String _batchId = '';

  void _downloadTemplate() {
    final csvContent = QuestionFileParser.generateTemplateCsv();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV Template Structure'),
        content: SingleChildScrollView(
          child: SelectableText(
            csvContent,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndParseFile() async {
    setState(() => _isLoading = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();

        final batch = 'batch_${DateTime.now().millisecondsSinceEpoch}';
        final parsed = QuestionFileParser.parseBytes(
          bytes: bytes,
          fileName: file.name,
          batchId: batch,
        );

        setState(() {
          _selectedFileName = file.name;
          _parsedRows = parsed;
          _batchId = batch;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File parse error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _commitUpload() async {
    final validQuestions = _parsedRows
        .where((r) => r.isValid && r.question != null)
        .map((r) => r.question!)
        .toList();

    if (validQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid questions to save.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uploadedCount =
          await ref.read(adminRepoProvider).batchUploadQuestions(validQuestions);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Batch Upload Successful'),
            content: Text(
              'Successfully published $uploadedCount questions to Firestore.\nBatch ID: $_batchId',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // back to admin dashboard
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _parsedRows.where((r) => r.isValid).length;
    final errorCount = _parsedRows.where((r) => !r.isValid).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'View CSV Template',
            onPressed: _downloadTemplate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pick File Banner
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFileName ?? 'Select .xlsx or .csv Question File',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _pickAndParseFile,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Browse File'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Validation Summary Bar
                  if (_parsedRows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'Valid: $validCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Text(
                              'Errors: $errorCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Preview Table (Review before saving):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _parsedRows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final row = _parsedRows[idx];
                          return Container(
                            color: row.isValid
                                ? Colors.green.withOpacity(0.05)
                                : Colors.red.withOpacity(0.08),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    row.isValid ? Colors.green : Colors.red,
                                child: Text(
                                  '${row.rowNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(
                                row.isValid
                                    ? row.question!.getLocalizedQuestion('en')
                                    : (row.rawValues['question_en']?.toString() ??
                                        'Row parse error'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                row.isValid
                                    ? 'Ans: ${row.question!.correctAnswer} | ${row.question!.exam} | ${row.question!.subject}'
                                    : 'ERROR: ${row.errorMessage}',
                                style: TextStyle(
                                  color: row.isValid ? Colors.grey[700] : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                row.isValid ? Icons.check_circle : Icons.error,
                                color: row.isValid ? Colors.green : Colors.red,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      onPressed: validCount > 0 ? _commitUpload : null,
                      child: Text('Confirm & Save $validCount Valid Questions'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

