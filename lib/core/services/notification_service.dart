import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _prefReminderTimeKey = 'daily_test_reminder_time';
  static const String _prefReminderEnabledKey = 'daily_test_reminder_enabled';

  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Request permission on iOS and Android 13+
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('Notification authorization status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        debugPrint('FCM Registration Token: $token');
        if (token != null) {
          await syncTokenToBackend(token);
        }

        // Listen for token refreshes
        messaging.onTokenRefresh.listen((newToken) {
          syncTokenToBackend(newToken);
        });
      }
    } catch (e) {
      debugPrint('NotificationService init error (graceful): $e');
    }
  }

  Future<void> syncTokenToBackend(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('student_id');
      final reminderTime = prefs.getString(_prefReminderTimeKey) ?? '09:00:00';
      final isEnabled = prefs.getBool(_prefReminderEnabledKey) ?? true;

      if (studentId != null && studentId.isNotEmpty) {
        await supabase.from('notification_preferences').upsert({
          'user_id': studentId,
          'fcm_token': token,
          'reminder_time': reminderTime,
          'is_enabled': isEnabled,
          'timezone': DateTime.now().timeZoneName,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      }
    } catch (e) {
      debugPrint('Error syncing FCM token to Supabase: $e');
    }
  }

  Future<void> updateReminderPreferences({
    required String reminderTime,
    required bool isEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefReminderTimeKey, reminderTime);
      await prefs.setBool(_prefReminderEnabledKey, isEnabled);

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await syncTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Error updating reminder preferences: $e');
    }
  }

  Future<Map<String, dynamic>> getReminderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'reminder_time': prefs.getString(_prefReminderTimeKey) ?? '09:00',
      'is_enabled': prefs.getBool(_prefReminderEnabledKey) ?? true,
    };
  }
}

