import os

# 1. Fix test_list_screen.dart
path_tests = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\tests\presentation\test_list_screen.dart"
with open(path_tests, "r", encoding="utf-8") as f:
    text_tests = f.read()

help_desk_code = """  void _showHelpDeskDialog() {
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

  void _showThemeCustomizer(BuildContext context) {"""

text_tests = text_tests.replace("void _showThemeCustomizer(BuildContext context) {", help_desk_code)
with open(path_tests, "w", encoding="utf-8") as f:
    f.write(text_tests)
print("SUCCESS: test_list_screen.dart defined _showHelpDeskDialog!")

# 2. Fix profile_screen.dart
path_profile = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\profile\presentation\profile_screen.dart"
with open(path_profile, "r", encoding="utf-8") as f:
    text_profile = f.read()

support_dialog_code = """  void _showSupportDialog(BuildContext context) {
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
              'Encountered a payment deduction error, timer issue, or technical glitch?',
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
              'Feel free to email us with screenshots or your Razorpay Payment ID. Our technical support team is dedicated to resolving all aspirant queries promptly.',
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

  Widget _badgeCard(String label, String value, IconData icon, Color color) {"""

text_profile = text_profile.replace("Widget _badgeCard(String label, String value, IconData icon, Color color) {", support_dialog_code)
with open(path_profile, "w", encoding="utf-8") as f:
    f.write(text_profile)
print("SUCCESS: profile_screen.dart defined _showSupportDialog!")

