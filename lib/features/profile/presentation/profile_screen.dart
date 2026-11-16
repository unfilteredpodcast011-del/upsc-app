import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/app_strings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _displayName = 'Aspirant';
  String _email = '';
  String _targetExam = 'UPSC';
  String _district = '';
  int _streakCount = 1;
  int _totalPoints = 50;
  List<Map<String, dynamic>> _attemptsHistory = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_guest';
    final historyList = prefs.getStringList('test_attempts_history_$studentId') ?? [];

    final parsedAttempts = <Map<String, dynamic>>[];
    for (final str in historyList) {
      try {
        parsedAttempts.add(jsonDecode(str) as Map<String, dynamic>);
      } catch (_) {}
    }

    setState(() {
      _displayName = prefs.getString('student_name') ?? 'Aspirant';
      _email = prefs.getString('student_email') ?? '';
      _targetExam = prefs.getString('target_exam') ?? 'UPSC';
      _district = prefs.getString('student_district') ?? '';
      _streakCount = prefs.getInt('streak_count') ?? 1;
      _totalPoints = prefs.getInt('total_points') ?? (50 + (parsedAttempts.length * 20));
      _attemptsHistory = parsedAttempts;
    });
  }

  void _switchLanguage(String langCode) async {
    await ref.read(localeProvider.notifier).setLocale(langCode);
    if (mounted) {
      final name = langCode == 'ta' ? 'தமிழ்' : (langCode == 'hi' ? 'हिन्दी' : 'English');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('App language changed to $name!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);
    final langCode = currentLocale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('my_profile', langCode)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_email.isNotEmpty)
                            Text(
                              _email,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              Chip(
                                label: Text(
                                  '${AppStrings.get('target', langCode)}: $_targetExam',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (_district.isNotEmpty)
                                Chip(
                                  label: Text(
                                    _district,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Streaks & Achievements
            Row(
              children: [
                _badgeCard(
                  AppStrings.get('day_streak', langCode),
                  '$_streakCount Days',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _badgeCard(
                  AppStrings.get('points', langCode),
                  '$_totalPoints pts',
                  Icons.stars,
                  Colors.amber.shade800,
                ),
                const SizedBox(width: 8),
                _badgeCard(
                  'ROLE',
                  AppStrings.get('role_student', langCode),
                  Icons.verified_user,
                  Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Language Selector
            Text(
              AppStrings.get('preferred_language', langCode),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('English (Default)'),
                    value: 'en',
                    groupValue: currentLocale.languageCode,
                    onChanged: (val) {
                      if (val != null) _switchLanguage(val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('தமிழ் (Tamil - TNPSC Specialized)'),
                    value: 'ta',
                    groupValue: currentLocale.languageCode,
                    onChanged: (val) {
                      if (val != null) _switchLanguage(val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('हिन्दी (Hindi)'),
                    value: 'hi',
                    groupValue: currentLocale.languageCode,
                    onChanged: (val) {
                      if (val != null) _switchLanguage(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Test Attempts History
            Text(
              AppStrings.get('recent_attempts', langCode),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_attemptsHistory.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.assignment_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.get('no_attempts', langCode),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attemptsHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final att = _attemptsHistory[idx];
                  final score = att['score'] ?? 0.0;
                  final accuracy = att['accuracy'] ?? 0.0;
                  final timeSec = att['timeTakenSeconds'] ?? 0;
                  final exam = att['exam'] ?? 'UPSC';
                  final sessionId = att['sessionId'] ?? '';

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: score >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                        child: Text(
                          '$score',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: score >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                      title: Text(
                        'Mock Test ($exam)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Accuracy: $accuracy% • Time: ${timeSec ~/ 60}m ${timeSec % 60}s\nCorrect: ${att['totalCorrect']} | Wrong: ${att['totalWrong']} | Skipped: ${att['totalUnanswered']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Review Test',
                        onPressed: () {
                          if (sessionId.isNotEmpty) {
                            context.push('/test-result/$sessionId');
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _badgeCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
