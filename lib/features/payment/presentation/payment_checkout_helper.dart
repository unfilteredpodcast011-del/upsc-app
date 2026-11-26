import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/payment_repository.dart';
import '../data/user_payment_history_tracker.dart';
import '../../tests/domain/test_model.dart';

final paymentRepoProvider = Provider<PaymentRepository>((ref) => PaymentRepository());

class PaymentCheckoutHelper {
  late Razorpay _razorpay;
  final WidgetRef ref;
  final BuildContext context;
  final TestModel test;
  final Function() onPaymentSuccess;

  // Razorpay Live Key ID
  static const String razorpayTestKeyId = 'rzp_live_TvILTj34p5TVTl';

  PaymentCheckoutHelper({
    required this.ref,
    required this.context,
    required this.test,
    required this.onPaymentSuccess,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<void> startCheckout({String paymentMode = 'UPI / Netbanking'}) async {
    final prefs = await SharedPreferences.getInstance();
    final studentEmail = prefs.getString('student_email') ?? '';
    final studentPhone = prefs.getString('student_phone') ?? '';
    final studentName = prefs.getString('student_name') ?? 'Aspirant';
    final studentDistrict = prefs.getString('student_district') ?? '';
    final studentId = prefs.getString('student_id') ?? 'student_guest';

    try {
      final orderId = await ref.read(paymentRepoProvider).createRazorpayOrder(
            testId: test.id,
            userId: studentId,
            amountPaise: test.priceInPaise,
            testTitle: test.title,
          );

      final options = {
        'key': razorpayTestKeyId,
        'amount': test.priceInPaise,
        if (orderId.startsWith('order_') && !orderId.startsWith('order_17')) 'order_id': orderId,
        'name': 'Test 11',
        'description': '${test.exam}: ${test.title}',
        'timeout': 300,
        'prefill': {
          'name': studentName,
          if (studentPhone.isNotEmpty) 'contact': studentPhone,
          if (studentEmail.isNotEmpty) 'email': studentEmail,
        },
        'notes': {
          'student_name': studentName,
          'student_district': studentDistrict,
          'target_exam': test.exam,
          'test_title': test.title,
          'question_count': '${test.questionCount}',
          'payment_mode': paymentMode,
        },
        'theme': {
          'color': '#0F172A',
        },
        'retry': {
          'enabled': true,
          'max_count': 3,
        },
        'send_sms_hash': true,
      };

      _razorpay.open(options);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initiating payment: $e')),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_guest';

    await UserPaymentHistoryTracker.logPayment(
      testTitle: '${test.exam}: ${test.title} (${test.questionCount} Questions)',
      testId: test.id,
      orderId: response.orderId ?? 'order_${DateTime.now().millisecondsSinceEpoch}',
      paymentId: response.paymentId ?? 'pay_success',
      status: 'SUCCESS',
      paymentMode: 'UPI / Netbanking',
      amountPaise: test.priceInPaise,
    );

    final isVerified = await ref.read(paymentRepoProvider).verifyAndUnlockTest(
          orderId: response.orderId ?? 'direct_order',
          paymentId: response.paymentId ?? 'pay_dummy',
          signature: response.signature ?? 'direct_sig',
          testId: test.id,
          userId: studentId,
          amountPaise: test.priceInPaise,
        );

    if (isVerified) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified! Test unlocked successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      onPaymentSuccess();
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    final status = (response.code == Razorpay.PAYMENT_CANCELLED) ? 'CANCELLED' : 'FAILED';
    await UserPaymentHistoryTracker.logPayment(
      testTitle: '${test.exam}: ${test.title} (${test.questionCount} Questions)',
      testId: test.id,
      orderId: 'order_${DateTime.now().millisecondsSinceEpoch}',
      paymentId: 'fail_code_${response.code}',
      status: status,
      paymentMode: 'UPI / Netbanking',
      amountPaise: test.priceInPaise,
    );

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Notice'),
          content: Text(
            'Razorpay status: ${response.message ?? "Payment cancelled or failed"}\n\n'
            'In Test Mode, if you wish to bypass to test questions right now, tap "Unlock in Test Mode" below.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                final studentId = prefs.getString('student_id') ?? 'student_guest';
                await prefs.setBool('unlocked_${studentId}_${test.id}', true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test unlocked in Test Mode!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                onPaymentSuccess();
              },
              child: const Text('Unlock in Test Mode', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External wallet chosen: ${response.walletName}')),
      );
    }
  }
}
