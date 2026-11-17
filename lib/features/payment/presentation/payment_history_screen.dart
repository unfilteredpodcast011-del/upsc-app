import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/user_payment_history_tracker.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  List<PaymentRecord> _payments = [];
  String _selectedFilter = 'ALL'; // 'ALL', 'TODAY', 'YESTERDAY', 'CUSTOM'
  DateTime? _customSelectedDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await UserPaymentHistoryTracker.getHistory();
    if (mounted) {
      setState(() {
        _payments = history;
        _isLoading = false;
      });
    }
  }

  List<PaymentRecord> get _filteredPayments {
    if (_payments.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return _payments.where((item) {
      if (_selectedFilter == 'ALL') return true;

      DateTime? itemDate;
      try {
        if (item.date.isNotEmpty) {
          itemDate = DateTime.parse(item.date);
        }
      } catch (_) {}

      if (itemDate == null) return false;
      final itemDay = DateTime(itemDate.year, itemDate.month, itemDate.day);

      if (_selectedFilter == 'TODAY') {
        return itemDay.isAtSameMomentAs(today);
      } else if (_selectedFilter == 'YESTERDAY') {
        return itemDay.isAtSameMomentAs(yesterday);
      } else if (_selectedFilter == 'CUSTOM' && _customSelectedDate != null) {
        final customDay = DateTime(
          _customSelectedDate!.year,
          _customSelectedDate!.month,
          _customSelectedDate!.day,
        );
        return itemDay.isAtSameMomentAs(customDay);
      }
      return true;
    }).toList();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _selectedFilter = 'CUSTOM';
      });
    }
  }

  Widget _buildFilterChip(String label, String filterKey, {IconData? icon}) {
    final isSelected = _selectedFilter == filterKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        if (filterKey == 'CUSTOM') {
          _pickCustomDate();
        } else {
          setState(() {
            _selectedFilter = filterKey;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedList = _filteredPayments;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Payment History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
          ),
        ),
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month_outlined,
              color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            ),
            tooltip: 'Pick date from Calendar',
            onPressed: _pickCustomDate,
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            ),
            tooltip: 'Refresh',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar with Today, Yesterday, and Calendar Picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0F172A)
                : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All (${_payments.length})', 'ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Today', 'TODAY'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Yesterday', 'YESTERDAY'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    _selectedFilter == 'CUSTOM' && _customSelectedDate != null
                        ? DateFormat('dd MMM yyyy').format(_customSelectedDate!)
                        : 'Calendar Date',
                    'CUSTOM',
                    icon: Icons.calendar_today_rounded,
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),

          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : displayedList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilter == 'ALL'
                                    ? 'No payment transactions yet.'
                                    : 'No payments found for selected date filter.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedFilter == 'ALL'
                                    ? 'When you unlock ₹1 practice tests, full transaction details with payment mode (UPI, Netbanking) and test name will be displayed here.'
                                    : 'Try selecting "All" or choosing another date to see past transactions.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              if (_selectedFilter != 'ALL') ...[
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'ALL';
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all, size: 16),
                                  label: const Text('Reset Filter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A8A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: displayedList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final item = displayedList[idx];
                          final isSuccess = item.status == 'SUCCESS';
                          final isCancelled = item.status == 'CANCELLED';

                          Color badgeBg = const Color(0xFFFEE2E2);
                          Color badgeText = const Color(0xFF991B1B);
                          IconData icon = Icons.error_outline;

                          if (isSuccess) {
                            badgeBg = const Color(0xFFDCFCE7);
                            badgeText = const Color(0xFF166534);
                            icon = Icons.check_circle_rounded;
                          } else if (isCancelled) {
                            badgeBg = const Color(0xFFFEF3C7);
                            badgeText = const Color(0xFF92400E);
                            icon = Icons.cancel_outlined;
                          }

                          final isDark = Theme.of(context).brightness == Brightness.dark;

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: badgeBg,
                                      foregroundColor: badgeText,
                                      child: Icon(icon, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.testTitle,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Order: ${item.orderId}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${(item.amountPaise / 100).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: badgeBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: badgeText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Divider(
                                  height: 18,
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 14,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Mode: ${item.paymentMode}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.date.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 13,
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            item.date.replaceFirst('T', ' ').substring(0, 16),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
