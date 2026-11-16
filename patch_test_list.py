import os

file_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\tests\presentation\test_list_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Update AppBar actions: Remove the redundant exam badge button with settings icon
old_appbar = """      appBar: AppBar(
        title: Text(AppStrings.get('app_title', currentLang)),
        actions: [
          // Target Exam Badge Button (Tapping opens Profile/Settings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/profile'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedExam == 'TNPSC' ? Icons.account_balance : Icons.school,
                      size: 15,
                      color: Colors.amberAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      selectedExam,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.settings, size: 12, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              ref.watch(themeProvider).themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode_outlined,
            ),
            tooltip: 'Toggle Dark / Light Theme',
            onPressed: () => _showThemeCustomizer(context),
          ),"""

new_appbar = """      appBar: AppBar(
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
          ),"""

text = text.replace(old_appbar, new_appbar)

# 2. Fix the overflow on "கிடைக்கக்கூடிய தேர்வுகள் (TNPSC)" by wrapping in Expanded and allow soft wrap / multi-line
old_header = """            // Live Practice Tests List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppStrings.get('available_tests', currentLang)} ($selectedExam)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppStrings.get('per_test', currentLang),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),"""

new_header = """            // Live Practice Tests List Header (Wrapped in Expanded to gracefully wrap onto second line)
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
            ),"""

text = text.replace(old_header, new_header)

# 3. Add _showHelpDeskDialog method
help_desk_method = """  void _showHelpDeskDialog() {
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black800),
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
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
"""

# Insert _showHelpDeskDialog before _showThemeCustomizer
if "_showHelpDeskDialog" not in text:
    text = text.replace("void _showThemeCustomizer(", help_desk_method + "\n  void _showThemeCustomizer(")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: test_list_screen.dart patched (overflow fixed, redundant profile button removed, Help Desk added)!")

