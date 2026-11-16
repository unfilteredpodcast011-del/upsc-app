import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/auth_controller.dart';

class ExamPrepApp extends ConsumerWidget {
  const ExamPrepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final userProfile = ref.watch(userProfileProvider).value;

    Locale currentLocale = const Locale('en');
    if (userProfile?.preferredLanguage == 'ta') {
      currentLocale = const Locale('ta');
    } else if (userProfile?.preferredLanguage == 'hi') {
      currentLocale = const Locale('hi');
    }

    return MaterialApp.router(
      title: 'ExamPrep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('ta'), // Tamil
        Locale('hi'), // Hindi
      ],
      routerConfig: router,
    );
  }
}
