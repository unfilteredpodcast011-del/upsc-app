import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/exam/exam_controller.dart';

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

  void _switchExamWithTransition(String newExam) async {
    final currentExam = ref.read(selectedExamProvider);
    if (currentExam == newExam) return;

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
                  'Switching to $newExam',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configuring question banks, syllabus & mock tests for $newExam...',
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
                      title: const Text('UPSC Civil Services (CSE)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('IAS, IPS, IFS • General Studies Paper 1 • Prelims Simulation', style: TextStyle(fontSize: 12)),
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
                      title: const Text('TNPSC Combined Services', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Group 1, 2, 2A & 4 • General Studies & Mental Ability (1000 Bank)', style: TextStyle(fontSize: 12)),
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
                title: const Text('My Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('View transactions, ₹1 test orders & status', style: TextStyle(fontSize: 12)),
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
                title: const Text('Help, Grievance & Feedback Form', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Submit queries, payment issues or feedback directly to admin', style: TextStyle(fontSize: 12)),
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

  void _showSupportDialog(BuildContext context) {
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
          title: const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('Feedback & Support Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Facing an issue, payment glitch, or question suggestion? Submit your feedback directly to the administrator team:',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Your Name *',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
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
                    labelText: 'Email Address',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orderCtrl,
                  decoration: InputDecoration(
                    labelText: 'Razorpay Payment / Order ID (Optional)',
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
                    labelText: 'Feedback / Issue Message *',
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
                  child: const Row(
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Direct Email: plantgreeninertiamanagement@gmail.com',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
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
              child: const Text('Cancel'),
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
                          const SnackBar(content: Text('Please enter your feedback or grievance details.')),
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
                            const SnackBar(
                              content: Text('Thank you! Your feedback has been sent directly to the Admin Portal.'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (err) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Submission failed: $err'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Feedback'),
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
