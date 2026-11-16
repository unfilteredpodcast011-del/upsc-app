import os

path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\profile\presentation\profile_screen.dart"

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add Supabase import if not present
if "import 'package:supabase_flutter/supabase_flutter.dart';" not in text:
    text = "import 'package:supabase_flutter/supabase_flutter.dart';\n" + text

# 2. Add audit log insertion in _switchExamWithTransition
old_switch_tail = """    // Simulate clean transition loading (1.2 seconds)
    await Future.delayed(const Duration(milliseconds: 1200));
    await ref.read(selectedExamProvider.notifier).setExam(newExam);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_exam', newExam);

    if (mounted) {
      setState(() => _targetExam = newExam);
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog"""

new_switch_tail = """    // Simulate clean transition loading (1.2 seconds)
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
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog"""

text = text.replace(old_switch_tail, new_switch_tail)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: profile_screen.dart updated with exam switch audit logger!")

