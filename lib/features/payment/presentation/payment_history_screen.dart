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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Payment History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _payments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          'No payment transactions yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'When you unlock ₹1 practice tests, full transaction details with payment mode (UPI, Netbanking) and test name will be displayed here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: _payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = _payments[idx];
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

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Order: ${item.orderId}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF64748B),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
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
                          const Divider(height: 18, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF475569)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Mode: ${item.paymentMode}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.date.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 13, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.date.replaceFirst('T', ' ').substring(0, 16),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
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
    );
  }
}
