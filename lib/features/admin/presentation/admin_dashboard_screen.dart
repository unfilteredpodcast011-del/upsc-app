import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/admin_repository.dart';
import '../domain/admin_stats_model.dart';
import '../../tests/domain/question_model.dart';
import 'question_upload_screen.dart';
import 'question_editor_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _examFilter = 'ALL';
  AdminStatsModel? _stats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final stats = await ref.read(adminRepoProvider).getAdminStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    }
  }

  void _exportQuestionsToCsv(List<QuestionModel> questions) {
    final rows = <List<dynamic>>[
      ['ID', 'Exam', 'Subject', 'Topic', 'Difficulty', 'Question', 'Answer'],
    ];

    for (final q in questions) {
      rows.add([
        q.id,
        q.exam,
        q.subject,
        q.topic,
        q.difficulty,
        q.getLocalizedQuestion('en'),
        q.correctAnswer,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exported Questions (CSV)'),
        content: SingleChildScrollView(
          child: SelectableText(
            csvData,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishDailyTest(String exam) async {
    try {
      final test = await ref.read(adminRepoProvider).buildDailyTestForToday(exam);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully published ${test.title} with ${test.questionCount} questions!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish daily test: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final questionsStream =
        ref.watch(adminRepoProvider).streamAllQuestions(examFilter: _examFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Question Bank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionEditorScreen(
              onSave: (q) async {
                await ref.read(adminRepoProvider).saveSingleQuestion(q);
                _loadStats();
              },
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI Summary Grid
            if (_loadingStats)
              const Center(child: LinearProgressIndicator())
            else if (_stats != null) ...[
              Row(
                children: [
                  _buildStatCard(
                    'Questions',
                    '${_stats!.totalQuestions}',
                    Icons.quiz,
                    Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'Students',
                    '${_stats!.totalUsers}',
                    Icons.people,
                    Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'Revenue',
                    '₹${_stats!.totalRevenueRs.toStringAsFixed(0)}',
                    Icons.currency_rupee,
                    Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    'Attempts',
                    '${_stats!.totalAttempts}',
                    Icons.trending_up,
                    Colors.deepOrange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Quick Actions: Upload & Daily Test Generation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Batch Ingestion & Automation',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Excel/CSV'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QuestionUploadScreen(),
                              ),
                            ).then((_) => _loadStats()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _publishDailyTest('UPSC'),
                            child: const Text('Publish Today\'s UPSC Test'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _publishDailyTest('TNPSC'),
                            child: const Text('Publish Today\'s TNPSC Test'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Question List Header & Exam Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Question Bank',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: _examFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Exams')),
                    DropdownMenuItem(value: 'UPSC', child: Text('UPSC')),
                    DropdownMenuItem(value: 'TNPSC', child: Text('TNPSC')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _examFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live Questions Stream List
            StreamBuilder<List<QuestionModel>>(
              stream: questionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No questions found. Click "Upload Excel/CSV" or "Add Question" to begin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export to CSV'),
                        onPressed: () => _exportQuestionsToCsv(list),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (ctx, idx) {
                        final q = list[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: q.exam == 'UPSC'
                                  ? Colors.blue.shade100
                                  : Colors.orange.shade100,
                              child: Text(
                                q.correctAnswer,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              q.getLocalizedQuestion('en'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${q.exam} • ${q.subject} • ${q.topic.isEmpty ? q.difficulty : q.topic}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuestionEditorScreen(
                                        existingQuestion: q,
                                        onSave: (up) async {
                                          await ref
                                              .read(adminRepoProvider)
                                              .saveSingleQuestion(up);
                                        },
                                      ),
                                    ),
                                  );
                                } else if (val == 'delete') {
                                  await ref
                                      .read(adminRepoProvider)
                                      .deleteQuestion(q.id);
                                  _loadStats();
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
