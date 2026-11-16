import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRecord {
  final String orderId;
  final String paymentId;
  final String testTitle;
  final int amountPaise;
  final String status; // 'SUCCESS', 'FAILED', 'CANCELLED'
  final String date;

  PaymentRecord({
    required this.orderId,
    required this.paymentId,
    required this.testTitle,
    required this.amountPaise,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'paymentId': paymentId,
    'testTitle': testTitle,
    'amountPaise': amountPaise,
    'status': status,
    'date': date,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    orderId: map['orderId'] ?? '',
    paymentId: map['paymentId'] ?? '',
    testTitle: map['testTitle'] ?? '',
    amountPaise: (map['amountPaise'] as num?)?.toInt() ?? 100,
    status: map['status'] ?? 'PENDING',
    date: map['date'] ?? '',
  );
}

class UserPaymentHistoryTracker {
  static Future<void> logPayment({
    required String testTitle,
    required String testId,
    required String orderId,
    required String paymentId,
    required String status, // 'SUCCESS', 'FAILED', 'CANCELLED'
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_guest';

    final rec = PaymentRecord(
      orderId: orderId,
      paymentId: paymentId,
      testTitle: testTitle,
      amountPaise: 100,
      status: status,
      date: DateTime.now().toIso8601String(),
    );

    // Save locally
    final key = 'user_payment_history_$studentId';
    final existing = prefs.getStringList(key) ?? [];
    existing.insert(0, jsonEncode(rec.toMap()));
    await prefs.setStringList(key, existing);

    // Sync to Supabase
    try {
      await Supabase.instance.client.from('payments').insert({
        'student_id': studentId,
        'test_id': testId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'amount_paise': 100,
        'status': status.toLowerCase(),
      });
    } catch (_) {}
  }

  static Future<List<PaymentRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_guest';
    final key = 'user_payment_history_$studentId';
    final existing = prefs.getStringList(key) ?? [];

    final list = <PaymentRecord>[];
    for (final str in existing) {
      try {
        list.add(PaymentRecord.fromMap(jsonDecode(str)));
      } catch (_) {}
    }
    return list;
  }
}

