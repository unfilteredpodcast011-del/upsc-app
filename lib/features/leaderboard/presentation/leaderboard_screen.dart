import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/leaderboard_repository.dart';

final leaderboardRepoProvider =
    Provider<LeaderboardRepository>((ref) => LeaderboardRepository());

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedExam = 'UPSC';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Leaderboard'),
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
            onChanged: (val) {
              if (val != null) setState(() => _selectedExam = val);
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amberAccent,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'This Week'),
            Tab(text: 'All-Time'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardList('daily', currentUser?.uid),
          _buildLeaderboardList('weekly', currentUser?.uid),
          _buildLeaderboardList('all_time', currentUser?.uid),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(String period, String? currentUserId) {
    final stream = ref.watch(leaderboardRepoProvider).streamLeaderboard(
          exam: _selectedExam,
          period: period,
        );

    return StreamBuilder<List<LeaderboardEntry>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'No $_selectedExam test attempts yet for this period.\nBe the first to rank on the leaderboard!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isCurrentUser = entry.userId == currentUserId;

            Color rankBadgeColor = Colors.grey.shade400;
            if (entry.rank == 1) rankBadgeColor = Colors.amber.shade700;
            if (entry.rank == 2) rankBadgeColor = Colors.blueGrey.shade400;
            if (entry.rank == 3) rankBadgeColor = Colors.brown.shade400;

            final minutes = entry.timeTakenSeconds ~/ 60;
            final seconds = entry.timeTakenSeconds % 60;

            return Container(
              color: isCurrentUser
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                  : Colors.transparent,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rankBadgeColor,
                  child: Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      entry.displayName,
                      style: TextStyle(
                        fontWeight:
                            isCurrentUser ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  'Time: ${minutes}m ${seconds}s • Acc: ${entry.accuracy.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Text(
                  '${entry.score.toStringAsFixed(1)} pts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
