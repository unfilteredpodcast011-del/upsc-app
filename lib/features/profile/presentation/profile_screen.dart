import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _switchLanguage(BuildContext context, WidgetRef ref, String langCode) async {
    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'preferredLanguage': langCode});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language updated to $langCode')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        (user?.displayName.isNotEmpty == true)
                            ? user!.displayName[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Aspirant',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              'Target: ${user?.targetExam ?? 'UPSC'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Streaks & Achievements
            Row(
              children: [
                _badgeCard('Streak', '${user?.streakCount ?? 1} Days', Icons.local_fire_department, Colors.orange),
                const SizedBox(width: 8),
                _badgeCard('Points', '${user?.totalPoints ?? 50} pts', Icons.stars, Colors.amber.shade800),
                const SizedBox(width: 8),
                _badgeCard('Role', user?.role.toUpperCase() ?? 'STUDENT', Icons.verified_user, Colors.indigo),
              ],
            ),
            const SizedBox(height: 20),

            // Language Selector
            const Text(
              'Preferred In-App Language',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('English (Default)'),
                    value: 'en',
                    groupValue: user?.preferredLanguage ?? 'en',
                    onChanged: (val) {
                      if (val != null) _switchLanguage(context, ref, val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('தமிழ் (Tamil - TNPSC Specialized)'),
                    value: 'ta',
                    groupValue: user?.preferredLanguage ?? 'en',
                    onChanged: (val) {
                      if (val != null) _switchLanguage(context, ref, val);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('हिन्दी (Hindi)'),
                    value: 'hi',
                    groupValue: user?.preferredLanguage ?? 'en',
                    onChanged: (val) {
                      if (val != null) _switchLanguage(context, ref, val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Past Test Attempts History
            const Text(
              'Recent Test Attempts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('test_sessions')
                  .where('userId', isEqualTo: user?.uid ?? '')
                  .where('status', isEqualTo: 'completed')
                  .orderBy('submittedAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'No tests completed yet. Start your first timed test to view history!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (ctx, idx) {
                    final data = docs[idx].data() as Map<String, dynamic>;
                    final score = (data['score'] as num?)?.toDouble() ?? 0.0;
                    final acc = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
                    final testId = data['testId'] ?? '';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.history, color: Colors.blue),
                        ),
                        title: Text('Test: $testId'),
                        subtitle: Text('Accuracy: ${acc.toStringAsFixed(0)}%'),
                        trailing: Text(
                          '${score.toStringAsFixed(1)} marks',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.green,
                          ),
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

  Widget _badgeCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
