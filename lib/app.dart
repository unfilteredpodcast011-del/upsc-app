import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/localization/locale_controller.dart';
import 'core/router/app_router.dart';

class ExamPrepApp extends ConsumerWidget {
  const ExamPrepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Test 11',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(themeState.preset),
      darkTheme: AppTheme.getDarkTheme(themeState.preset),
      themeMode: themeState.themeMode,
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ta'),
        Locale('hi'),
      ],
      routerConfig: router,
    );
  }
}
