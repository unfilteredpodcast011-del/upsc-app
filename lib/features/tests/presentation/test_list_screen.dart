import '../../../core/services/quote_service.dart';
import '../../../core/services/app_update_checker.dart';
import '../../../core/services/widget_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/exam/exam_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/test_repository.dart';
import '../domain/test_model.dart';
import '../../payment/presentation/payment_checkout_helper.dart';

final testRepoProvider = Provider<TestRepository>((ref) => TestRepository());

class TestListScreen extends ConsumerStatefulWidget {
  const TestListScreen({super.key});

  @override
  ConsumerState<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends ConsumerState<TestListScreen> {
  String _candidateName = '';

  @override
  void initState() {
    super.initState();
    _loadCandidateName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateChecker.checkAppUpdate(context);
    });
  }

  Future<void> _loadCandidateName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('student_name') ?? prefs.getString('user_name') ?? '';
    final studentId = prefs.getString('student_id');

    // Real-time account validity check against database
    if (studentId != null && studentId.isNotEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('students')
            .select('id, account_status')
            .eq('id', studentId)
            .maybeSingle();

        // If admin permanently deleted the user from Admin Portal
        if (res == null) {
          await prefs.clear();
          if (mounted) {
            context.go('/onboarding');
            return;
          }
        }
      } catch (_) {}
    }

    if (mounted && name.isNotEmpty) {
      setState(() {
        _candidateName = name;
      });
    }
  }

  void _onTestCardTapped(TestModel test) async {
    // Each and every test requires Rs.1 entry fee
    _showPaymentPrompt(test);
  }

  void _showPaymentPrompt(TestModel test) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Unlock Test: ${test.title}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Includes ${test.questionCount} timed questions, server-verified evaluation, and subject-wise weak topic analysis.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Access Fee',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '₹1.00',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Prominent Mandatory Caution Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CAUTION: Do NOT press the back button or close the app during or right after payment. If you navigate back or exit before the exam launches, the test cannot be restored and we are NOT responsible for your fee.',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text('Pay ₹1 with Razorpay & Start'),
                onPressed: () {
                  Navigator.pop(ctx);
                  final checkoutHelper = PaymentCheckoutHelper(
                    ref: ref,
                    context: context,
                    test: test,
                    onPaymentSuccess: () {
                      _showSpeedOptionDialog(test);
                    },
                  );
                  checkoutHelper.startCheckout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedOptionDialog(TestModel test) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental closing by touching outside
      builder: (ctx) => PopScope(
        canPop: false, // Prevents Android back button from cancelling unlocked test
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.speed_rounded, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose Speed Practice Mode',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap one of the button options below to launch your exam immediately:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Button 1: Standard Speed
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/test-engine/${test.id}?speed=100');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.timer_outlined, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Standard Speed (100% Time)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                              ),
                              Text(
                                '${test.defaultDurationSeconds ~/ 60} minutes • Official exam pace',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill, color: Color(0xFF2563EB), size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 2: Rapid Practice
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/test-engine/${test.id}?speed=75');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.speed, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rapid Practice (75% Time)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                              ),
                              Text(
                                '${(test.defaultDurationSeconds * 0.75) ~/ 60} minutes • Fast accuracy drill',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill, color: Color(0xFFD97706), size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 3: Sprint Mode
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/test-engine/${test.id}?speed=50');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.flash_on, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sprint Mode (50% Time)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                              ),
                              Text(
                                '${(test.defaultDurationSeconds * 0.5) ~/ 60} minutes • High adrenaline challenge',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill, color: Color(0xFFDC2626), size: 28),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    void _showHelpDeskDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.headset_mic_rounded, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Support & Help Desk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encountered a payment issue, timer glitch, or bug during your mock test?',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official Support Email:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  SizedBox(height: 3),
                  SelectableText(
                    'plantgreeninertiamanagement@gmail.com',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blueAccent,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please email us with your screenshot or Razorpay Payment ID. Our team will verify and resolve your grievance immediately.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showThemeCustomizer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentTheme = ref.watch(themeProvider);
        final isDark = currentTheme.themeMode == ThemeMode.dark;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'App Appearance & Theme',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Dark Mode Toggle Switch
              SwitchListTile(
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active'),
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.amber),
                value: isDark,
                onChanged: (val) {
                  ref.read(themeProvider.notifier).setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              const Divider(height: 24),
              const Text(
                'Color Palette Presets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              // Color Presets Wrap (Blue, Green, Sky Blue, Pink, Violet, Red)
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.royalBlue,
                    color: const Color(0xFF1E3A8A),
                    name: 'Classic Blue',
                    isSelected: currentTheme.preset == AppThemePreset.royalBlue,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.forestGreen,
                    color: const Color(0xFF0F766E),
                    name: 'Green',
                    isSelected: currentTheme.preset == AppThemePreset.forestGreen,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.skyBlue,
                    color: const Color(0xFF0284C7),
                    name: 'Sky Blue',
                    isSelected: currentTheme.preset == AppThemePreset.skyBlue,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.pink,
                    color: const Color(0xFFDB2777),
                    name: 'Pink',
                    isSelected: currentTheme.preset == AppThemePreset.pink,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.violet,
                    color: const Color(0xFF7C3AED),
                    name: 'Violet',
                    isSelected: currentTheme.preset == AppThemePreset.violet,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.crimsonRed,
                    color: const Color(0xFFDC2626),
                    name: 'Red',
                    isSelected: currentTheme.preset == AppThemePreset.crimsonRed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _themeColorCircle(
    BuildContext context, {
    required AppThemePreset preset,
    required Color color,
    required String name,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(themeProvider.notifier).setPreset(preset);
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.amberAccent, width: 3.5) : null,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final selectedExam = ref.watch(selectedExamProvider);
    final testStream = ref.watch(testRepoProvider).streamLiveTests(selectedExam);
    final currentLang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('app_title', currentLang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help Desk & Support',
            onPressed: _showHelpDeskDialog,
          ),
          IconButton(
            icon: Icon(
              ref.watch(themeProvider).themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Dark / Light Theme',
            onPressed: () => _showThemeCustomizer(context),
          ),
          if (user?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Panel',
              onPressed: () => context.push('/admin'),
            ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Leaderboard',
            onPressed: () => context.push('/leaderboard'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily Streak & Hero Card
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppStrings.get('hello', currentLang)}, ${(_candidateName.isNotEmpty ? _candidateName : (user?.displayName != null && user!.displayName!.isNotEmpty ? user.displayName! : 'M. Manoj'))}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppStrings.get('target', currentLang)}: $selectedExam • ${AppStrings.get('day_streak', currentLang)}: ${user?.streakCount ?? 1} 🔥',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars, color: Colors.amberAccent),
                          Text(
                            '${user?.totalPoints ?? 50} ${AppStrings.get('points', currentLang)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Daily Motivational Inspiration Card (365 Quotes)
            FutureBuilder<DailyQuote>(
              future: QuoteService.getTodayQuote(),
              builder: (context, snapshot) {
                final quoteData = snapshot.data;
                final quoteText = quoteData?.quote ?? 'Arise, awake, and stop not until the goal is reached.';
                final authorText = quoteData?.author ?? 'Swami Vivekananda';

                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_quote_rounded, color: Color(0xFFF59E0B), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'DAILY MOTIVATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, size: 12, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(
                                  'Day ${quoteData?.day ?? (DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '\"${quoteText}\"',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '— ${authorText}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Live Practice Tests List Header (Wrapped in Expanded to gracefully wrap onto second line)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '${AppStrings.get('available_tests', currentLang)} ($selectedExam)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    AppStrings.get('per_test', currentLang),
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tests Stream Builder
            StreamBuilder<List<TestModel>>(
              stream: testStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tests = snapshot.data ?? [];
                if (tests.isNotEmpty) {
                  // Keep Android Home Screen widget continuously in sync with the top 3 live tests
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    WidgetSyncService.syncTopTestsToWidget(
                      selectedExam: selectedExam,
                      tests: tests,
                    );
                  });
                }
                if (tests.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            'No live $selectedExam tests published yet for today.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          if (user?.isAdmin == true) ...[
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.push('/admin'),
                              child: const Text('Go to Admin Panel to Publish Tests'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final test = tests[idx];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: test.type == 'daily'
                              ? Colors.amber.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            test.type == 'daily'
                                ? Icons.today
                                : Icons.assignment_outlined,
                            color: test.type == 'daily'
                                ? Colors.amber.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                        title: Text(
                          test.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${test.questionCount} Questions • ${test.defaultDurationSeconds ~/ 60} mins • Negative 1/3',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(
                                test.subject,
                                style: const TextStyle(fontSize: 10),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _onTestCardTapped(test),
                          child: Text(AppStrings.get('start', currentLang)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
