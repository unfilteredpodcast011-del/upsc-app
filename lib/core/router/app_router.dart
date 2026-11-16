import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/tests/presentation/test_list_screen.dart';
import '../../features/tests/presentation/timed_engine_screen.dart';
import '../../features/tests/presentation/result_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/payment/presentation/payment_history_screen.dart';

final onboardingCheckProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const TestListScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onCompleted: () {
            ref.invalidate(onboardingCheckProvider);
            context.go('/home');
          },
        ),
      ),
      GoRoute(
        path: '/test-engine/:testId',
        builder: (context, state) {
          final testId = state.pathParameters['testId']!;
          final speed = int.tryParse(state.uri.queryParameters['speed'] ?? '100') ?? 100;
          return TimedEngineScreen(testId: testId, speedOption: speed);
        },
      ),
      GoRoute(
        path: '/test-result/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return ResultScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/payment-history',
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});
