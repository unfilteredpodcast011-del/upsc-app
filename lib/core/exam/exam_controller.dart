import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (saved != null && (saved == 'UPSC' || saved == 'TNPSC')) {
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

