import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamCategory {
  final String code;
  final String title;
  final String subtitle;
  final bool isDefault;

  const ExamCategory({
    required this.code,
    required this.title,
    required this.subtitle,
    this.isDefault = false,
  });
}

final availableExamsProvider = FutureProvider<List<ExamCategory>>((ref) async {
  final defaults = <ExamCategory>[
    const ExamCategory(
      code: 'UPSC',
      title: 'UPSC Civil Services',
      subtitle: 'IAS, IPS, IFS & Central Services Prelims',
      isDefault: true,
    ),
    const ExamCategory(
      code: 'TNPSC',
      title: 'TNPSC Group Services',
      subtitle: 'Group I, II, IIA, III & IV / VAO',
      isDefault: true,
    ),
  ];

  try {
    if (Supabase.instance.isInitialized) {
      final res = await Supabase.instance.client
          .from('payments')
          .select('razorpay_order_id')
          .eq('status', 'exam_category')
          .order('created_at', ascending: true);

      final seen = {'UPSC', 'TNPSC'};
      for (final row in res) {
        try {
          final raw = row['razorpay_order_id']?.toString();
          if (raw == null) continue;
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final code = (data['code'] ?? '').toString().trim().toUpperCase();
          if (code.isEmpty || seen.contains(code)) continue;
          seen.add(code);
          defaults.add(ExamCategory(
            code: code,
            title: (data['title'] ?? code).toString(),
            subtitle: (data['subtitle'] ?? 'Government Exam Mock Tests').toString(),
          ));
        } catch (_) {}
      }
    }
  } catch (_) {}

  return defaults;
});

final selectedExamProvider = StateNotifierProvider<SelectedExamNotifier, String>((ref) {
  return SelectedExamNotifier();
});

class SelectedExamNotifier extends StateNotifier<String> {
  SelectedExamNotifier() : super('UPSC') {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('target_exam');
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setExam(String exam) async {
    if (state == exam) return;
    state = exam;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_exam', exam);
  }
}
