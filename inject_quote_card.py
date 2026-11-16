import os

file_path = r"c:\Users\manoj\OneDrive\Documents\pgi\upsc\examprep\lib\features\tests\presentation\test_list_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

import_stmt = "import '../../../core/services/quote_service.dart';\n"
if import_stmt not in text:
    text = import_stmt + text

old_body_target = """            // Daily Streak & Hero Card
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
                            '${AppStrings.get('hello', currentLang)}, ${user?.displayName ?? 'Aspirant'}!',
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
            const SizedBox(height: 20),"""

new_body_quote = """            // Daily Streak & Hero Card
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
                            '${AppStrings.get('hello', currentLang)}, ${user?.displayName ?? 'Aspirant'}!',
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
                        '\\"${quoteText}\\"',
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
            const SizedBox(height: 18),"""

if old_body_target in text:
    text = text.replace(old_body_target, new_body_quote)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("SUCCESS: Injected Daily Quote card into test_list_screen.dart")
else:
    print("WARNING: old_body_target not found verbatim")

