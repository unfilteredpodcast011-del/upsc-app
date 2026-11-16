import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/theme_controller.dart';
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
  String _selectedExam = 'UPSC';

  @override
  void initState() {
    super.initState();
    _loadStoredExam();
  }

  Future<void> _loadStoredExam() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('target_exam');
    if (saved != null && (saved == 'UPSC' || saved == 'TNPSC')) {
      setState(() => _selectedExam = saved);
    }
  }

  void _onTestCardTapped(TestModel test) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'local_student';

    final testRepo = ref.read(testRepoProvider);
    final isUnlocked = await testRepo.isTestUnlocked(
      userId: studentId,
      testId: test.id,
    );

    if (isUnlocked) {
      _showSpeedOptionDialog(test);
    } else {
      _showPaymentPrompt(test);
    }
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
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Speed Practice Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer_outlined, color: Colors.blue),
              title: const Text('Standard Speed (100% Time)'),
              subtitle: Text('${test.defaultDurationSeconds ~/ 60} minutes'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/test-engine/${test.id}?speed=100');
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.orange),
              title: const Text('Rapid Practice (75% Time)'),
              subtitle: Text(
                '${(test.defaultDurationSeconds * 0.75) ~/ 60} minutes',
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/test-engine/${test.id}?speed=75');
              },
            ),
            ListTile(
              leading: const Icon(Icons.flash_on, color: Colors.red),
              title: const Text('Sprint Mode (50% Time)'),
              subtitle: Text(
                '${(test.defaultDurationSeconds * 0.5) ~/ 60} minutes',
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/test-engine/${test.id}?speed=50');
              },
            ),
          ],
        ),
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
              // Color Presets Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.royalBlue,
                    color: const Color(0xFF1E3A8A),
                    name: 'Royal Blue',
                    isSelected: currentTheme.preset == AppThemePreset.royalBlue,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.forestGreen,
                    color: const Color(0xFF0F766E),
                    name: 'Teal Forest',
                    isSelected: currentTheme.preset == AppThemePreset.forestGreen,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.imperialPurple,
                    color: const Color(0xFF581C87),
                    name: 'Imperial',
                    isSelected: currentTheme.preset == AppThemePreset.imperialPurple,
                  ),
                  _themeColorCircle(
                    ctx,
                    preset: AppThemePreset.crimsonRed,
                    color: const Color(0xFF991B1B),
                    name: 'Crimson',
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
    final testStream = ref.watch(testRepoProvider).streamLiveTests(_selectedExam);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ExamPrep'),
        actions: [
            DropdownButton<String>(
              dropdownColor: Theme.of(context).colorScheme.primary,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              underline: const SizedBox.shrink(),
              value: _selectedExam,
              items: const [
                DropdownMenuItem(value: 'UPSC', child: Text('UPSC')),
                DropdownMenuItem(value: 'TNPSC', child: Text('TNPSC')),
              ],
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _selectedExam = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('target_exam', val);
                }
              },
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
            icon: const Icon(Icons.border_color_outlined),
            tooltip: 'Writing Practice',
            onPressed: () => context.push('/writing-practice'),
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
                            'Hello, ${user?.displayName ?? 'Aspirant'}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: $_selectedExam CSE • Day streak: ${user?.streakCount ?? 1} 🔥',
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
                            '${user?.totalPoints ?? 50} pts',
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
            const SizedBox(height: 20),

            // Live Practice Tests List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available $_selectedExam Tests',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹1 per test',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
                if (tests.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            'No live $_selectedExam tests published yet for today.',
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
                          child: const Text('Start'),
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
