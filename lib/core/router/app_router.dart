import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/tests/presentation/test_list_screen.dart';
import '../../features/tests/presentation/timed_engine_screen.dart';
import '../../features/tests/presentation/result_screen.dart';
import '../../features/tests/presentation/writing_practice_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final hasError = authState.hasError;
      final isAuthenticated = authState.value != null;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';

      if (isLoading || hasError) return null;

      // If not logged in and trying to access protected screens, redirect to /login
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // If logged in and on an auth screen, redirect to home
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const TestListScreen(),
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
        path: '/writing-practice',
        builder: (context, state) => const WritingPracticeScreen(),
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
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});

