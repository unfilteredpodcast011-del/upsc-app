import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/payment_repository.dart';
import '../../tests/domain/test_model.dart';

final paymentRepoProvider = Provider<PaymentRepository>((ref) => PaymentRepository());

class PaymentCheckoutHelper {
  late Razorpay _razorpay;
  final WidgetRef ref;
  final BuildContext context;
  final TestModel test;
  final Function() onPaymentSuccess;

  // Razorpay Test Key ID (switchable in config)
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
      // Step 1: Create Order
      final orderId = await ref.read(paymentRepoProvider).createRazorpayOrder(
            testId: test.id,
            userId: studentId,
          );

      // Step 2: Open Razorpay checkout modal
      final options = {
        'key': razorpayTestKeyId,
        'amount': test.priceInPaise, // 100 paise = ₹1.00
        'name': 'ExamPrep',
        'order_id': orderId,
        'description': 'Unlock Practice Test: ${test.title}',
        'timeout': 300, // 5 minutes
        'prefill': {
          'contact': studentPhone,
          'email': studentEmail,
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
          orderId: response.orderId ?? '',
          paymentId: response.paymentId ?? '',
          signature: response.signature ?? '',
          testId: test.id,
          userId: studentId,
        );

    if (isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verified! Test unlocked successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      onPaymentSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment verification failed. Please contact support.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment cancelled or failed (${response.code}): ${response.message}'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: startCheckout,
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet chosen: ${response.walletName}')),
    );
  }
}

