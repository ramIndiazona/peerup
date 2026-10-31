import '../../core/network/api_client.dart';
import '../../core/network/api_url.dart';
import '../../models/subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._api);

  final ApiClient _api;

  Future<SubscriptionStatusResult> status() async {
    final data = await _api.get(APIURL.subscriptionsMe);
    return SubscriptionStatusResult.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  Future<UsageResult> usage() async {
    final data = await _api.get(APIURL.subscriptionsUsage);
    return UsageResult.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PurchaseResult> purchase({
    String successUrl = 'peerup://premium',
    String cancelUrl = 'peerup://premium',
  }) async {
    final data = await _api.post(
      APIURL.subscriptionsPurchase,
      data: {'successUrl': successUrl, 'cancelUrl': cancelUrl},
    );
    return PurchaseResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Creates a Razorpay order for the selected billing plan.
  ///
  /// The amount is set by the backend; Flutter only chooses 'monthly' or
  /// 'yearly'.
  Future<RazorpayOrder> purchasePlan({required String plan}) async {
    final data = await _api.post(
      APIURL.subscriptionsPurchase,
      data: {'plan': plan},
    );
    return RazorpayOrder.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Sends the Razorpay payment details to the backend for verification.
  Future<PaymentVerificationResult> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final data = await _api.post(
      APIURL.subscriptionsVerifyPayment,
      data: {
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      },
    );
    return PaymentVerificationResult.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  Future<void> cancel() async {
    await _api.post(APIURL.subscriptionsCancel);
  }
}
