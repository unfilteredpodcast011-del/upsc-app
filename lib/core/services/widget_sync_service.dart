import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/tests/domain/test_model.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('com.examprep.app/widget');

  static Future<void> syncTopTestsToWidget({
    required String selectedExam,
    required List<TestModel> tests,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('target_exam', selectedExam);

      final top3 = tests.take(3).map((t) => {
        'id': t.id,
        'title': t.title,
        'questions': t.questionCount,
        'duration': t.durationMinutes,
        'exam': t.exam,
      }).toList();

      await prefs.setString('cached_widget_tests_$selectedExam', jsonEncode(top3));

      // Trigger native widget refresh
      await _channel.invokeMethod('refreshWidget');
    } catch (e) {
      // Non-blocking background sync note
    }
  }
}

