import os

file_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\profile\presentation\profile_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

old_tile = """            // Payment History Navigation Button
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.receipt_long, color: Color(0xFFD97706)),
                ),
                title: const Text('My Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('View transactions, ₹1 test orders & status', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/payment-history'),
              ),
            ),
            const SizedBox(height: 20),"""

new_tile = """            // Payment History Navigation Button
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.receipt_long, color: Color(0xFFD97706)),
                ),
                title: const Text('My Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('View transactions, ₹1 test orders & status', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/payment-history'),
              ),
            ),
            const SizedBox(height: 12),

            // Official Support & Help Desk Card
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.headset_mic_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Support & Help Desk', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('plantgreeninertiamanagement@gmail.com', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                trailing: const Icon(Icons.mail_outline),
                onTap: () => _showSupportDialog(context),
              ),
            ),
            const SizedBox(height: 20),"""

text = text.replace(old_tile, new_tile)

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
              'Feel free to email us with screenshots or your Razorpay Payment ID. Our technical support team is dedicated to resolving all aspirant queries promptly.',
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

if "_showSupportDialog" not in text:
    text = text.replace("Widget _badgeCard(", support_dialog_code + "\n  Widget _badgeCard(")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print("SUCCESS: profile_screen.dart patched with Support Desk card and dialog!")

