import 'package:flutter/material.dart';
import '../data/user_payment_history_tracker.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  List<PaymentRecord> _payments = [];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payment History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No payment transactions yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'When you unlock ₹1 practice tests, transaction statuses (Success, Failed, or Cancelled) will be shown here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = _payments[idx];
                    final isSuccess = item.status == 'SUCCESS';
                    final isCancelled = item.status == 'CANCELLED';

                    Color badgeBg = Colors.red.shade100;
                    Color badgeText = Colors.red.shade800;
                    IconData icon = Icons.error_outline;

                    if (isSuccess) {
                      badgeBg = Colors.green.shade100;
                      badgeText = Colors.green.shade800;
                      icon = Icons.check_circle_outline;
                    } else if (isCancelled) {
                      badgeBg = Colors.amber.shade100;
                      badgeText = Colors.amber.shade900;
                      icon = Icons.cancel_outlined;
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: badgeBg,
                              foregroundColor: badgeText,
                              child: Icon(icon),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.testTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Order: ${item.orderId}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                  if (item.date.isNotEmpty)
                                    Text(
                                      item.date.replaceFirst('T', ' ').substring(0, 16),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${item.amountPaise / 100}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: badgeText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

