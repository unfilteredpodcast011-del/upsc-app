import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle streak tracking and points calculation reliably.
/// Rules:
/// 1. Streak increases by +1 when user completes at least 1 mock test in a calendar day.
/// 2. If user practiced yesterday and practices today, streak increases: streak = streak + 1.
/// 3. If user practiced already today, streak stays maintained (doesn't double increment on same day).
/// 4. If user missed yesterday (gap >= 2 days), streak resets to 1 on today's practice.
/// 5. Points calculation:
///    - Base registration bonus: 50 pts
///    - Each test completed: +20 pts
///    - Accuracy bonus: If accuracy >= 80%, +15 bonus pts; if >= 60%, +10 bonus pts
///    - Positive score points: Adds Math.max(0, score)
class StreakService {
  StreakService._();

  /// Check and update streak when a test is completed.
  /// Returns a map with {'streak': int, 'points': int, 'streakIncreased': bool}
  static Future<Map<String, dynamic>> recordTestCompletion({
    required String userId,
    required double score,
    required double accuracy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final lastPracticeDateKey = 'last_practice_date_$userId';
    final streakKey = 'streak_count_$userId';
    final pointsKey = 'total_points_$userId';

    final lastDateStr = prefs.getString(lastPracticeDateKey) ?? prefs.getString('last_practice_date');
    int currentStreak = prefs.getInt(streakKey) ?? prefs.getInt('streak_count') ?? 1;
    int currentPoints = prefs.getInt(pointsKey) ?? prefs.getInt('total_points') ?? 50;

    bool streakIncreased = false;

    if (lastDateStr == null || lastDateStr.isEmpty) {
      // First recorded test
      currentStreak = 1;
      streakIncreased = true;
    } else if (lastDateStr == todayStr) {
      // Already practiced today, keep current streak (does not decrease or double increment)
      streakIncreased = false;
    } else {
      try {
        final lastDate = DateTime.parse(lastDateStr);
        final differenceInDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;

        if (differenceInDays == 1) {
          // Practiced yesterday! Streak increases by +1
          currentStreak += 1;
          streakIncreased = true;
        } else if (differenceInDays > 1) {
          // Missed 1 or more full days! Streak resets to 1
          currentStreak = 1;
          streakIncreased = true;
        }
      } catch (_) {
        currentStreak = 1;
      }
    }

    // Calculate points earned for this test
    int pointsEarned = 20; // 20 pts per test completed
    if (accuracy >= 80.0) {
      pointsEarned += 15; // High accuracy bonus
    } else if (accuracy >= 60.0) {
      pointsEarned += 10;
    }
    if (score > 0) {
      pointsEarned += score.toInt();
    }

    currentPoints += pointsEarned;

    // Save locally for this user and globally
    await prefs.setString(lastPracticeDateKey, todayStr);
    await prefs.setString('last_practice_date', todayStr);
    await prefs.setInt(streakKey, currentStreak);
    await prefs.setInt('streak_count', currentStreak);
    await prefs.setInt(pointsKey, currentPoints);
    await prefs.setInt('total_points', currentPoints);

    return {
      'streak': currentStreak,
      'points': currentPoints,
      'streakIncreased': streakIncreased,
      'pointsEarned': pointsEarned,
    };
  }

  /// Get current streak for display, evaluating if a day was missed
  static Future<Map<String, int>> getCurrentStreakAndPoints(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastDateStr = prefs.getString('last_practice_date_$userId') ?? prefs.getString('last_practice_date');
    int streak = prefs.getInt('streak_count_$userId') ?? prefs.getInt('streak_count') ?? 1;
    int points = prefs.getInt('total_points_$userId') ?? prefs.getInt('total_points') ?? 50;

    if (lastDateStr != null && lastDateStr.isNotEmpty) {
      try {
        final lastDate = DateTime.parse(lastDateStr);
        final daysDiff = today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;
        // If more than 1 day has passed without practice, active streak drops to 0 until practice resumes
        if (daysDiff > 1) {
          streak = 0;
          await prefs.setInt('streak_count_$userId', 0);
          await prefs.setInt('streak_count', 0);
        }
      } catch (_) {}
    }

    return {
      'streak': streak,
      'points': points,
    };
  }
}
