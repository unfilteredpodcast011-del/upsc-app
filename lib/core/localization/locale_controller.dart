import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language') ?? 'en';
    state = Locale(lang);
  }

  Future<void> setLocale(String langCode) async {
    state = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);

    // Also persist to Supabase student profile if online
    try {
      final studentId = prefs.getString('student_id');
      if (studentId != null && studentId.contains('-')) {
        await Supabase.instance.client
            .from('students')
            .update({'preferred_language': langCode})
            .eq('id', studentId);
      }
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

