import 'package:equatable/equatable.dart';

import '../../../core/payment/razorpay_payment_service.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class LoadSubscription extends SubscriptionEvent {
  const LoadSubscription();
}

class SelectSubscriptionPlan extends SubscriptionEvent {
  const SelectSubscriptionPlan(this.period);

  /// 'monthly' or 'yearly'.
  final String period;

  @override
  List<Object?> get props => [period];
}

class PurchaseSubscription extends SubscriptionEvent {
  const PurchaseSubscription();
}

class VerifySubscriptionPayment extends SubscriptionEvent {
  const VerifySubscriptionPayment({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;

  @override
  List<Object?> get props => [paymentId, orderId, signature];
}

class RefreshSubscriptionStatus extends SubscriptionEvent {
  const RefreshSubscriptionStatus();
}

/// Emitted by [RazorpayPaymentService] when the user completes/cancels a
/// checkout attempt.
class SubscriptionPaymentResultReceived extends SubscriptionEvent {
  const SubscriptionPaymentResultReceived(this.result);

  final RazorpayCheckoutResult result;

  @override
  List<Object?> get props => [result];
}

class SubscriptionPaymentFailed extends SubscriptionEvent {
  const SubscriptionPaymentFailed(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;

  @override
  List<Object?> get props => [message, canRetry];
}

/// The Razorpay checkout was cancelled by the user.
class SubscriptionCheckoutCancelled extends SubscriptionEvent {
  const SubscriptionCheckoutCancelled();
}
