import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/payment_repository.dart';
import '../../tests/domain/test_model.dart';

final paymentRepoProvider = Provider<PaymentRepository>((ref) => PaymentRepository());

class PaymentCheckoutHelper {
  late Razorpay _razorpay;
  final WidgetRef ref;
  final BuildContext context;
  final TestModel test;
  final Function() onPaymentSuccess;

  // Razorpay Test Key ID
  static const String razorpayTestKeyId = 'rzp_test_U0kJAgrYUcMteT';

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

  Future<void> startCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    final studentEmail = prefs.getString('student_email') ?? 'student@examprep.com';
    final studentPhone = prefs.getString('student_phone') ?? '9876543210';
    final studentId = prefs.getString('student_id') ?? 'student_guest';

    try {
      // Step 1: In standard Razorpay checkout without a backend order service,
      // opening with key, amount, and name allows direct payments on client side.
      final options = {
        'key': razorpayTestKeyId,
        'amount': test.priceInPaise, // 100 paise = ₹1.00
        'name': 'ExamPrep',
        'description': 'Unlock Test: ${test.title}',
        'timeout': 300, // 5 minutes
        'prefill': {
          'contact': studentPhone.length >= 10 ? studentPhone : '9876543210',
          'email': studentEmail.contains('@') ? studentEmail : 'student@examprep.com',
        },
        'theme': {
          'color': '#1E3A8A',
        },
      };

      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating payment: $e')),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id') ?? 'student_guest';

    final isVerified = await ref.read(paymentRepoProvider).verifyAndUnlockTest(
          orderId: response.orderId ?? 'direct_order',
          paymentId: response.paymentId ?? 'pay_dummy',
          signature: response.signature ?? 'direct_sig',
          testId: test.id,
          userId: studentId,
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

  void _handlePaymentError(PaymentFailureResponse response) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Notice'),
          content: Text(
            'Razorpay returned: ${response.message ?? "Payment cancelled or failed"}\n(Code: ${response.code})\n\n'
            'In Test Mode, if your Razorpay dashboard test key requires server order creation or if you want to bypass to test questions right now, tap "Unlock in Test Mode" below.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
