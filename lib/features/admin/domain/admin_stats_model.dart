class AdminStatsModel {
  final int totalQuestions;
  final int totalUsers;
  final int totalPayments;
  final double totalRevenueRs;
  final int totalAttempts;
  final double todayRevenueRs;
  final int todayNewUsers;
  final Map<String, int> subjectCounts;

  AdminStatsModel({
    required this.totalQuestions,
    required this.totalUsers,
    required this.totalPayments,
    required this.totalRevenueRs,
    required this.totalAttempts,
    this.todayRevenueRs = 0.0,
    this.todayNewUsers = 0,
    required this.subjectCounts,
  });

  factory AdminStatsModel.empty() {
    return AdminStatsModel(
      totalQuestions: 0,
      totalUsers: 0,
      totalPayments: 0,
      totalRevenueRs: 0.0,
      totalAttempts: 0,
      todayRevenueRs: 0.0,
      todayNewUsers: 0,
      subjectCounts: {},
    );
  }
}

