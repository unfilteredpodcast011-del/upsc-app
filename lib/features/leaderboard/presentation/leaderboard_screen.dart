import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/app_strings.dart';

class LeaderboardEntry {
  final String name;
  final String exam;
  final double score;
  final double accuracy;
  final int timeTakenSeconds;
  final int rank;

  LeaderboardEntry({
    required this.name,
    required this.exam,
    required this.score,
    required this.accuracy,
    required this.timeTakenSeconds,
    required this.rank,
  });
}

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedExam = 'UPSC';
  bool _isLoading = true;
  List<LeaderboardEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_guest';
    final studentName = prefs.getString('student_name') ?? 'Aspirant';

    // 1. Gather all student history attempts and aggregate per user (1 single combined entry per student)
    final history = prefs.getStringList('test_attempts_history_$studentId') ?? [];
    
    // Aggregate this user's attempts specifically for the selected exam
    double userExamScoreSum = 0;
    int userExamAttemptCount = 0;
    double userAccuracySum = 0;
    int userTotalTime = 0;

    for (final str in history) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final examType = (map['exam'] ?? 'UPSC').toString().toUpperCase();
        if (examType == _selectedExam.toUpperCase()) {
          userExamScoreSum += (map['score'] as num?)?.toDouble() ?? 0.0;
          userAccuracySum += (map['accuracy'] as num?)?.toDouble() ?? 0.0;
          userTotalTime += (map['timeTakenSeconds'] as num?)?.toInt() ?? 0;
          userExamAttemptCount++;
        }
      } catch (_) {}
    }

    final list = <LeaderboardEntry>[];
    final Map<String, LeaderboardEntry> studentEntries = {};

    // 1. Fetch all registered students from Supabase
    try {
      final studentsRes = await Supabase.instance.client
          .from('students')
          .select('id, full_name, target_exam');

      final Map<String, Map<String, dynamic>> allStudents = {};
      for (final s in studentsRes) {
        final sid = s['id']?.toString() ?? '';
        allStudents[sid] = s;
      }

      // 2. Fetch all real exam submissions from Supabase payments table
      final examSubmissions = await Supabase.instance.client
          .from('payments')
          .select('student_id, razorpay_order_id, created_at')
          .eq('status', 'exam_submitted')
          .order('created_at', ascending: false);

      // Track aggregated scores and attempts per student
      final Map<String, double> studentScores = {};
      final Map<String, double> studentAccuracies = {};
      final Map<String, int> studentTimes = {};
      final Map<String, int> studentCounts = {};

      for (final row in examSubmissions) {
        try {
          final sid = row['student_id']?.toString() ?? '';
          final rawOrder = row['razorpay_order_id'];
          if (rawOrder == null) continue;
          final Map<String, dynamic> data = jsonDecode(rawOrder);
          final examType = (data['exam'] ?? 'UPSC').toString().toUpperCase();
          if (examType != _selectedExam.toUpperCase()) continue;

          final sc = (data['score'] as num?)?.toDouble() ?? 0.0;
          final acc = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
          final tm = (data['time_taken_seconds'] as num?)?.toInt() ?? 0;

          studentScores[sid] = (studentScores[sid] ?? 0.0) + sc;
          studentAccuracies[sid] = (studentAccuracies[sid] ?? 0.0) + acc;
          studentTimes[sid] = (studentTimes[sid] ?? 0) + tm;
          studentCounts[sid] = (studentCounts[sid] ?? 0) + 1;
        } catch (_) {}
      }

      // 3. Populate all registered students for the selected exam
      allStudents.forEach((sid, sInfo) {
        final sExam = (sInfo['target_exam'] ?? 'UPSC').toString().toUpperCase();
        if (sExam != _selectedExam.toUpperCase() && _selectedExam.isNotEmpty) {
          // Keep students if their target exam matches or if they took tests in this exam
          if (!studentCounts.containsKey(sid)) return;
        }

        final rawName = sInfo['full_name']?.toString() ?? 'Aspirant';
        final isCurrent = sid == studentId || rawName.toLowerCase() == studentName.toLowerCase();
        final displayName = isCurrent ? '$rawName (You)' : rawName;

        final attempts = studentCounts[sid] ?? 0;
        double totalScore = studentScores[sid] ?? 0.0;
        double avgAccuracy = attempts > 0 ? (studentAccuracies[sid]! / attempts) : 0.0;
        int totalTime = studentTimes[sid] ?? 0;

        // If it's the current user, combine with local session storage if higher
        if (isCurrent && userExamAttemptCount > 0) {
          if (userExamScoreSum > totalScore) totalScore = userExamScoreSum;
          if (userAccuracySum / userExamAttemptCount > avgAccuracy) {
            avgAccuracy = userAccuracySum / userExamAttemptCount;
          }
          if (userTotalTime > totalTime) totalTime = userTotalTime;
        }

        studentEntries[sid] = LeaderboardEntry(
          name: displayName,
          exam: _selectedExam,
          score: double.parse(totalScore.toStringAsFixed(1)),
          accuracy: double.parse(avgAccuracy.toStringAsFixed(1)),
          timeTakenSeconds: totalTime,
          rank: 1,
        );
      });
    } catch (_) {
      // Fallback: If offline, show current user entry
      if (userExamAttemptCount > 0) {
        studentEntries[studentId] = LeaderboardEntry(
          name: '$studentName (You)',
          exam: _selectedExam,
          score: double.parse(userExamScoreSum.toStringAsFixed(1)),
          accuracy: double.parse((userAccuracySum / userExamAttemptCount).toStringAsFixed(1)),
          timeTakenSeconds: userTotalTime,
          rank: 1,
        );
      }
    }

    list.addAll(studentEntries.values);

    // Sort by score desc, time asc
    list.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return a.timeTakenSeconds.compareTo(b.timeTakenSeconds);
    });

    final ranked = <LeaderboardEntry>[];
    for (int i = 0; i < list.length; i++) {
      final e = list[i];
      ranked.add(LeaderboardEntry(
        name: e.name,
        exam: e.exam,
        score: e.score,
        accuracy: e.accuracy,
        timeTakenSeconds: e.timeTakenSeconds,
        rank: i + 1,
      ));
    }

    if (mounted) {
      setState(() {
        _entries = ranked;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('leaderboard', langCode)),
        actions: [
          DropdownButton<String>(
            dropdownColor: Theme.of(context).colorScheme.primary,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            underline: const SizedBox.shrink(),
            value: _selectedExam,
            items: const [
              DropdownMenuItem(value: 'UPSC', child: Text('UPSC')),
              DropdownMenuItem(value: 'TNPSC', child: Text('TNPSC')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedExam = val);
                _loadLeaderboard();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: [
            Tab(text: AppStrings.get('all_time', langCode)),
            Tab(text: AppStrings.get('weekly', langCode)),
            Tab(text: AppStrings.get('today', langCode)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardList(langCode),
                _buildLeaderboardList(langCode),
                _buildLeaderboardList(langCode),
              ],
            ),
    );
  }

  Widget _buildLeaderboardList(String langCode) {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No test attempts recorded yet for $_selectedExam.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _entries.length,
      itemBuilder: (ctx, idx) {
        final entry = _entries[idx];
        final isTop3 = entry.rank <= 3;

        Color medalColor = Colors.grey.shade400;
        if (entry.rank == 1) medalColor = Colors.amber;
        if (entry.rank == 2) medalColor = Colors.blueGrey.shade300;
        if (entry.rank == 3) medalColor = Colors.brown.shade300;

        return Card(
          elevation: isTop3 ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isTop3 ? BorderSide(color: medalColor.withOpacity(0.6), width: 1.5) : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isTop3 ? medalColor : Colors.grey.shade200,
              foregroundColor: isTop3 ? Colors.white : Colors.black87,
              child: isTop3
                  ? const Icon(Icons.emoji_events, size: 20)
                  : Text('${entry.rank}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(
              entry.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${AppStrings.get('accuracy', langCode)}: ${entry.accuracy}% • ${entry.timeTakenSeconds ~/ 60}m ${entry.timeTakenSeconds % 60}s',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${entry.score} pts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
