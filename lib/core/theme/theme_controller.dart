import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreset {
  royalBlue,
  forestGreen,
  imperialPurple,
  crimsonRed,
}

class ThemeState {
  final ThemeMode themeMode;
  final AppThemePreset preset;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.preset = AppThemePreset.royalBlue,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    AppThemePreset? preset,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      preset: preset ?? this.preset,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('app_theme_mode') ?? 'system';
    final presetStr = prefs.getString('app_theme_preset') ?? 'royalBlue';

    ThemeMode mode = ThemeMode.system;
    if (modeStr == 'light') mode = ThemeMode.light;
    if (modeStr == 'dark') mode = ThemeMode.dark;

    AppThemePreset preset = AppThemePreset.royalBlue;
    for (final p in AppThemePreset.values) {
      if (p.name == presetStr) {
        preset = p;
        break;
      }
    }

    state = ThemeState(themeMode: mode, preset: preset);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('app_theme_mode', modeStr);
  }

  Future<void> setPreset(AppThemePreset preset) async {
    state = state.copyWith(preset: preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_preset', preset.name);
  }

  Future<void> toggleDarkMode() async {
    final newMode = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
