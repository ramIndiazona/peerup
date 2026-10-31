import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Outcome of a Razorpay Checkout attempt.
///
/// Flutter never decides whether a payment succeeded; it only forwards the
/// result returned by the Razorpay SDK so the backend can verify it.
class RazorpayCheckoutResult {
  const RazorpayCheckoutResult._({
    required this.type,
    this.paymentId,
    this.orderId,
    this.signature,
    this.code,
    this.message,
  });

  factory RazorpayCheckoutResult.success({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    return RazorpayCheckoutResult._(
      type: RazorpayResultType.success,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  factory RazorpayCheckoutResult.failure({
    required String code,
    required String message,
  }) {
    return RazorpayCheckoutResult._(
      type: RazorpayResultType.failure,
      code: code,
      message: message,
    );
  }

  factory RazorpayCheckoutResult.cancelled() {
    return const RazorpayCheckoutResult._(type: RazorpayResultType.cancelled);
  }

  factory RazorpayCheckoutResult.externalWallet(String walletName) {
    return RazorpayCheckoutResult._(
      type: RazorpayResultType.externalWallet,
      message: walletName,
    );
  }

  final RazorpayResultType type;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? code;
  final String? message;

  bool get isSuccess => type == RazorpayResultType.success;
  bool get isFailure => type == RazorpayResultType.failure;
  bool get isCancelled => type == RazorpayResultType.cancelled;
}

enum RazorpayResultType { success, failure, cancelled, externalWallet }

/// Thin wrapper around the official Razorpay Flutter SDK.
///
/// Use [openCheckout] to present Razorpay Checkout and listen to [results]
/// for the outcome. The [Razorpay secret key] is never embedded here; only
/// the public key id returned by the backend is used to open checkout.
class RazorpayPaymentService {
  Razorpay? _razorpay;
  final StreamController<RazorpayCheckoutResult> _controller =
      StreamController<RazorpayCheckoutResult>.broadcast();

  /// Emits one result per checkout attempt.
  Stream<RazorpayCheckoutResult> get results => _controller.stream;

  /// Lazily creates the Razorpay instance and registers its event handlers.
  /// This avoids touching the platform channel until checkout is actually opened.
  Razorpay _getRazorpay() {
    if (_razorpay == null) {
      final instance = Razorpay();
      instance.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      instance.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      instance.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      _razorpay = instance;
    }
    return _razorpay!;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
  final paymentId = response.paymentId;
  final orderId = response.orderId;
  final signature = response.signature;

  print('[RAZORPAY] Payment success callback received');
  print('[RAZORPAY] Payment ID present: ${paymentId != null}');
  print('[RAZORPAY] Order ID present: ${orderId != null}');
  print('[RAZORPAY] Signature present: ${signature != null}');

  if (paymentId == null ||
      orderId == null ||
      signature == null ||
      paymentId.isEmpty ||
      orderId.isEmpty ||
      signature.isEmpty) {
    _controller.add(
      RazorpayCheckoutResult.failure(
        code: 'INVALID_PAYMENT_RESPONSE',
        message: 'Payment details are incomplete. Please contact support.',
      ),
    );
    return;
  }

  _controller.add(
    RazorpayCheckoutResult.success(
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    ),
  );
}
void _handlePaymentError(PaymentFailureResponse response) {
  final code = (response.code ?? '').toString();
  final message = response.message ?? 'Payment failed';

  print('[RAZORPAY] Payment error callback received');
  print('[RAZORPAY] Error code: $code');
  print('[RAZORPAY] Error message: $message');

  _controller.add(
    RazorpayCheckoutResult.failure(
      code: code,
      message: message,
    ),
  );
}
  void _handleExternalWallet(ExternalWalletResponse response) {
    _controller.add(
      RazorpayCheckoutResult.externalWallet(response.walletName!),
    );
  }

  /// Opens Razorpay Checkout for [orderId].
  ///
  /// [amount] must be in paise (the smallest currency unit) and is the value
  /// returned by the backend.
  Future<void> openCheckout({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    String? email,
    String? contact,
  }) async {
    final options = <String, dynamic>{
      'key': keyId,
      'amount': amount,
      'currency': currency,
      'order_id': orderId,
      'name': 'PeerUp',
      'description': 'Premium subscription',
      'prefill': <String, dynamic>{
        if (email != null && email.isNotEmpty) 'email': email,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
      },
      'theme': <String, dynamic>{'color': '#5B5FF7'},
    };
    _getRazorpay().open(options);
  }

  void dispose() {
    _controller.close();
    _razorpay?.clear();
    _razorpay = null;
  }
}
