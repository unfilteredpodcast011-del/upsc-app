import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/exam/exam_controller.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/streak_service.dart';
import '../../../core/theme/app_typography.dart';

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
  String _appVersionDisplay = 'v1.1.0 (Build 8)';
  String _dailyReminderTime = '09:00';
  bool _dailyReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadAppVersion();
    _loadReminderPreferences();
  }

  Future<void> _loadReminderPreferences() async {
    final prefs = await NotificationService().getReminderPreferences();
    if (mounted) {
      setState(() {
        _dailyReminderTime = prefs['reminder_time'] as String;
        _dailyReminderEnabled = prefs['is_enabled'] as bool;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersionDisplay = 'v${info.version} (Build ${info.buildNumber})';
        });
      }
    } catch (_) {}
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

    final streakData = await StreakService.getCurrentStreakAndPoints(studentId);
    final calculatedPoints = streakData['points'] ?? (50 + (parsedAttempts.length * 20));
    final calculatedStreak = streakData['streak'] ?? 1;

    setState(() {
      _displayName = prefs.getString('student_name') ?? 'Aspirant';
      _email = prefs.getString('student_email') ?? '';
      _targetExam = prefs.getString('target_exam') ?? 'UPSC';
      _district = prefs.getString('student_district') ?? '';
      _streakCount = calculatedStreak;
      _totalPoints = calculatedPoints;
      _attemptsHistory = parsedAttempts;
    });
  }

  void _switchExamWithTransition(String newExam) async {
    final currentExam = ref.read(selectedExamProvider);
    if (currentExam == newExam) return;

    final currentLocale = ref.read(localeProvider);
    final langCode = currentLocale.languageCode;

    // Show professional loading dialog with smooth animation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: newExam == 'TNPSC' ? Colors.teal.shade50 : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        newExam == 'TNPSC' ? const Color(0xFF0F766E) : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppStrings.get('switching_to', langCode, params: {'exam': newExam}),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.get('configuring_for', langCode, params: {'exam': newExam}),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Simulate clean transition loading (1.2 seconds)
    await Future.delayed(const Duration(milliseconds: 1200));
    await ref.read(selectedExamProvider.notifier).setExam(newExam);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_exam', newExam);
    final studentId = prefs.getString('student_id') ?? 'student_guest';

    // Log exact exam switch audit trail to Supabase in real-time
    try {
      if (studentId.contains('-')) {
        // 1. Update candidate profile in students table
        await Supabase.instance.client
            .from('students')
            .update({'target_exam': newExam})
            .eq('id', studentId);

        // 2. Insert audit event record into payments table
        await Supabase.instance.client.from('payments').insert({
          'student_id': studentId,
          'razorpay_order_id': 'AUDIT: Switched Exam Stream from $currentExam to $newExam',
          'razorpay_payment_id': 'exam_switch_$newExam',
          'amount_paise': 0,
          'status': 'audit_event',
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _targetExam = newExam);
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Switched successfully to $newExam!'),
            ],
          ),
          backgroundColor: newExam == 'TNPSC' ? const Color(0xFF0F766E) : const Color(0xFF1E3A8A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    final currentExam = ref.watch(selectedExamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                                  '${AppStrings.get('target', langCode)}: $currentExam',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                  AppStrings.get('days_label', langCode, params: {'n': '$_streakCount'}),
                  Icons.local_fire_department,
                  Colors.orange,
                  onTap: () => _showStreakRulesDialog(context, langCode),
                ),
                const SizedBox(width: 8),
                _badgeCard(
                  AppStrings.get('points', langCode),
                  AppStrings.get('points_label', langCode, params: {'n': '$_totalPoints'}),
                  Icons.stars,
                  Colors.amber.shade800,
                  onTap: () => _showStreakRulesDialog(context, langCode),
                ),
                const SizedBox(width: 8),
                _badgeCard(
                  AppStrings.get('role_label', langCode),
                  AppStrings.get('role_student', langCode),
                  Icons.verified_user,
                  Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Streak & Points Rules Banner Link
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showStreakRulesDialog(context, langCode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.get('streak_rules_title', langCode),
                        style: AppTypography.localizedStyle(
                          languageCode: langCode,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFFBBF24) : Colors.orange.shade900,
                          textLength: AppStrings.get('streak_rules_title', langCode).length,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFFFBBF24) : Colors.orange.shade900,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Target Exam Settings Selector Card
            Text(
              AppStrings.get('target_exam', langCode),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      activeColor: const Color(0xFF1E3A8A),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school, color: Color(0xFF1E3A8A), size: 22),
                      ),
                      title: Text(AppStrings.get('upsc_title', langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(AppStrings.get('upsc_subtitle', langCode), style: const TextStyle(fontSize: 12)),
                      value: 'UPSC',
                      groupValue: currentExam,
                      onChanged: (val) {
                        if (val != null) _switchExamWithTransition(val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      activeColor: const Color(0xFF0F766E),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance, color: Color(0xFF0F766E), size: 22),
                      ),
                      title: Text(AppStrings.get('tnpsc_title', langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(AppStrings.get('tnpsc_subtitle', langCode), style: const TextStyle(fontSize: 12)),
                      value: 'TNPSC',
                      groupValue: currentExam,
                      onChanged: (val) {
                        if (val != null) _switchExamWithTransition(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment History Navigation Button
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.receipt_long, color: Color(0xFFD97706)),
                ),
                title: Text(AppStrings.get('payment_history_title', langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(AppStrings.get('payment_history_subtitle', langCode), style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/payment-history'),
              ),
            ),
            const SizedBox(height: 12),

            // Official Support & Feedback Desk Card
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB)),
                ),
                title: Text(AppStrings.get('support_desk_title', langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(AppStrings.get('support_desk_subtitle', langCode), style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.send_rounded, color: Color(0xFF2563EB), size: 20),
                onTap: () => _showSupportDialog(context),
              ),
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
                    title: Text(AppStrings.get('lang_en', langCode)),
                    value: 'en',
                    groupValue: currentLocale.languageCode,
                    onChanged: (val) {
                      if (val != null) _switchLanguage(val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text(AppStrings.get('lang_ta', langCode)),
                    value: 'ta',
                    groupValue: currentLocale.languageCode,
                    onChanged: (val) {
                      if (val != null) _switchLanguage(val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text(AppStrings.get('lang_hi', langCode)),
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
                        AppStrings.get('mock_test_label', langCode, params: {'exam': '$exam'}),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${AppStrings.get("accuracy_label", langCode)}: $accuracy% • ${AppStrings.get("time_label", langCode)}: ${timeSec ~/ 60}m ${timeSec % 60}s\n${AppStrings.get("correct_label", langCode)}: ${att['totalCorrect']} | ${AppStrings.get("wrong_label", langCode)}: ${att['totalWrong']} | ${AppStrings.get("skipped_label", langCode)}: ${att['totalUnanswered']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: AppStrings.get('review_test', langCode),
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
            const SizedBox(height: 28),

            // Daily Test Reminder Notification Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark 
                      ? const Color(0xFF60A5FA).withOpacity(0.5) 
                      : const Color(0xFF2563EB).withOpacity(0.3),
                  width: 1.2,
                ),
              ),
              color: isDark 
                  ? const Color(0xFF1E293B) 
                  : const Color(0xFFF0F7FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isDark 
                              ? const Color(0xFF1E3A8A) 
                              : const Color(0xFFDBEAFE),
                          radius: 18,
                          child: Icon(
                            Icons.notifications_active_rounded, 
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8), 
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.get('daily_test_reminder_title', langCode),
                                style: AppTypography.localizedStyle(
                                  languageCode: langCode,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  textLength: AppStrings.get('daily_test_reminder_title', langCode).length,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                AppStrings.get('daily_test_reminder_sub', langCode),
                                style: AppTypography.localizedStyle(
                                  languageCode: langCode,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                  textLength: AppStrings.get('daily_test_reminder_sub', langCode).length,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _dailyReminderEnabled,
                          activeColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          onChanged: (val) async {
                            setState(() => _dailyReminderEnabled = val);
                            await NotificationService().updateReminderPreferences(
                              reminderTime: '$_dailyReminderTime:00',
                              isEnabled: val,
                            );
                          },
                        ),
                      ],
                    ),
                    if (_dailyReminderEnabled) ...[
                      Divider(
                        height: 24, 
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.get('reminder_time_label', langCode),
                            style: AppTypography.localizedStyle(
                              languageCode: langCode,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                              textLength: AppStrings.get('reminder_time_label', langCode).length,
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                width: 1.2,
                              ),
                              backgroundColor: isDark 
                                  ? const Color(0xFF0F172A).withOpacity(0.5) 
                                  : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () async {
                              final parts = _dailyReminderTime.split(':');
                              final initial = TimeOfDay(
                                hour: int.tryParse(parts[0]) ?? 9,
                                minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                              );
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initial,
                              );
                              if (picked != null) {
                                final hStr = picked.hour.toString().padLeft(2, '0');
                                final mStr = picked.minute.toString().padLeft(2, '0');
                                final timeStr = '$hStr:$mStr';
                                setState(() => _dailyReminderTime = timeStr);
                                await NotificationService().updateReminderPreferences(
                                  reminderTime: '$timeStr:00',
                                  isEnabled: _dailyReminderEnabled,
                                );
                              }
                            },
                            icon: Icon(
                              Icons.access_time_rounded, 
                              size: 16, 
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                            ),
                            label: Text(
                              _dailyReminderTime,
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Reset Points & Accuracy Button
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? Colors.amber.withOpacity(0.4) : Colors.amber.shade300),
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.amber.shade50.withOpacity(0.5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.amber.withOpacity(0.2) : Colors.amber.shade100,
                  child: const Icon(Icons.restart_alt_rounded, color: Colors.orange),
                ),
                title: Text(
                  AppStrings.get('reset_leaderboard_title', langCode),
                  style: AppTypography.localizedStyle(
                    languageCode: langCode,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    textLength: AppStrings.get('reset_leaderboard_title', langCode).length,
                  ),
                ),
                subtitle: Text(
                  AppStrings.get('reset_leaderboard_subtitle', langCode),
                  style: AppTypography.localizedStyle(
                    languageCode: langCode,
                    fontSize: 12.0,
                    height: 1.35,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    textLength: AppStrings.get('reset_leaderboard_subtitle', langCode).length,
                  ),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showResetPointsDialog(context),
                  child: Text(AppStrings.get('reset_btn', langCode), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Colors.red,
                ),
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  AppStrings.get('sign_out', langCode),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Version & Play Store Sync Info Footer
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(
                          'Test 11 App • $_appVersionDisplay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Synced with Google Play Store Releases',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final currentLocale = ref.read(localeProvider);
    final langCode = currentLocale.languageCode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            Text(AppStrings.get('sign_out_confirm_title', langCode)),
          ],
        ),
        content: Text(
          AppStrings.get('sign_out_confirm_msg', langCode),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.get('cancel', langCode)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.get('sign_out', langCode)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showResetPointsDialog(BuildContext context) {
    final currentLocale = ref.read(localeProvider);
    final langCode = currentLocale.languageCode;
    final textController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(AppStrings.get('reset_dialog_title', langCode)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('reset_dialog_desc', langCode),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.get('reset_type_prompt', langCode),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'reset point',
                  isDense: true,
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.get('cancel', langCode)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final typed = textController.text.trim().toLowerCase();
                if (typed != 'reset point') {
                  setDialogState(() {
                    errorText = AppStrings.get('reset_error_mismatch', langCode);
                  });
                  return;
                }

                // Execute Reset
                final prefs = await SharedPreferences.getInstance();
                final studentId = prefs.getString('student_id') ?? 'student_guest';

                await prefs.setInt('total_points', 0);
                await prefs.setInt('streak_count', 0);
                await prefs.remove('test_attempts_history_$studentId');
                await prefs.remove('overall_accuracy');

                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _totalPoints = 0;
                    _streakCount = 0;
                    _attemptsHistory = [];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.get('reset_success', langCode)),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(AppStrings.get('confirm_reset_btn', langCode)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    final currentLocale = ref.read(localeProvider);
    final langCode = currentLocale.languageCode;
    final nameCtrl = TextEditingController(text: _displayName != 'Aspirant' ? _displayName : '');
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController();
    final orderCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Text(AppStrings.get('feedback_dialog_title', langCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('feedback_prompt', langCode),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('feedback_name', langCode),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('feedback_phone', langCode),
                    hintText: 'e.g. 9876543210',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('feedback_email', langCode),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orderCtrl,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('feedback_order', langCode),
                    hintText: 'pay_... or order_...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: messageCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('feedback_msg', langCode),
                    hintText: 'Explain the error or suggestion in detail...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.get('feedback_direct_email', langCode),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(AppStrings.get('cancel', langCode)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final message = messageCtrl.text.trim();
                      final orderId = orderCtrl.text.trim();

                      if (message.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.get('feedback_empty_err', langCode))),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        final phoneTag = phone.isNotEmpty ? ' [Phone: ' + phone + ']' : '';
                        final orderTag = orderId.isNotEmpty ? ' [Order: ' + orderId + ']' : '';
                        final summary = 'INQUIRY: ${name.isEmpty ? _displayName : name}${phoneTag} (${email.isEmpty ? _email : email})${orderTag} - $message';

                        final prefs = await SharedPreferences.getInstance();
                        final studentId = prefs.getString('student_id') ?? '8294c73f-be46-4f65-939c-9eaebe11273f';

                        await Supabase.instance.client.from('payments').insert({
                          'student_id': studentId.contains('-') ? studentId : '8294c73f-be46-4f65-939c-9eaebe11273f',
                          'razorpay_order_id': summary,
                          'razorpay_payment_id': 'app_feedback_inquiry',
                          'amount_paise': 0,
                          'status': 'support_inquiry',
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppStrings.get('feedback_submitted', langCode)),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (err) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${AppStrings.get("feedback_failed", langCode)}$err'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(AppStrings.get('submit_feedback', langCode)),
            ),
          ],
        ),
      ),
    );
  }

  void _showStreakRulesDialog(BuildContext context, String langCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.get('streak_rules_title', langCode),
                style: AppTypography.localizedStyle(
                  languageCode: langCode,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  textLength: AppStrings.get('streak_rules_title', langCode).length,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.get('streak_rules_desc', langCode),
                style: AppTypography.localizedStyle(
                  languageCode: langCode,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.get('leaderboard_rules_title', langCode),
                      style: AppTypography.localizedStyle(
                        languageCode: langCode,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        textLength: AppStrings.get('leaderboard_rules_title', langCode).length,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.get('leaderboard_rules_desc', langCode),
                style: AppTypography.localizedStyle(
                  languageCode: langCode,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
