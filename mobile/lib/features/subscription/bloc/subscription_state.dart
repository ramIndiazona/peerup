import 'package:equatable/equatable.dart';

import '../../../models/subscription.dart';

/// The billing period the user can subscribe to.
enum SubscriptionBillingPeriod { monthly, yearly }

/// A purchasable Premium plan.
///
/// The [displayPrice] is only for UI display. The amount actually charged is
/// set by the backend and must never be trusted from the client.
class SubscriptionOption {
  const SubscriptionOption({
    required this.period,
    required this.name,
    required this.displayPrice,
    required this.duration,
    required this.features,
  });

  final SubscriptionBillingPeriod period;
  final String name;

  /// Display price in rupees (indicative only).
  final int displayPrice;
  final String duration;
  final List<String> features;

  String get apiValue =>
      period == SubscriptionBillingPeriod.monthly ? 'monthly' : 'yearly';

  static const kMonthly = SubscriptionOption(
    period: SubscriptionBillingPeriod.monthly,
    name: 'Monthly Premium',
    displayPrice: 199,
    duration: '1 month',
    features: [
      'Up to 50 AI conversations / day',
      '120 minutes of AI practice / day',
      'Advanced grammar & pronunciation feedback',
      'All premium AI characters',
    ],
  );

  static const kYearly = SubscriptionOption(
    period: SubscriptionBillingPeriod.yearly,
    name: 'Yearly Premium',
    displayPrice: 999,
    duration: '1 year',
    features: [
      'Up to 50 AI conversations / day',
      '120 minutes of AI practice / day',
      'Advanced grammar & pronunciation feedback',
      'All premium AI characters',
    ],
  );

  static List<SubscriptionOption> all() => [kMonthly, kYearly];
}

sealed class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

class SubscriptionLoading extends SubscriptionState {
  const SubscriptionLoading();
}

class SubscriptionLoaded extends SubscriptionState {
  const SubscriptionLoaded({
    this.plans = const [],
    this.selectedPeriod,
    this.status,
  });

  final List<SubscriptionOption> plans;

  /// 'monthly' | 'yearly' or null when nothing is selected.
  final String? selectedPeriod;
  final SubscriptionStatusResult? status;

  @override
  List<Object?> get props => [plans, selectedPeriod, status];
}

class SubscriptionPaymentProcessing extends SubscriptionState {
  const SubscriptionPaymentProcessing({this.selectedPeriod});

  final String? selectedPeriod;

  @override
  List<Object?> get props => [selectedPeriod];
}

class SubscriptionPaymentVerification extends SubscriptionState {
  const SubscriptionPaymentVerification();
}

class SubscriptionPaymentSuccess extends SubscriptionState {
  const SubscriptionPaymentSuccess(this.status);

  final SubscriptionStatusResult status;

  @override
  List<Object?> get props => [status];
}

class SubscriptionPaymentFailure extends SubscriptionState {
  const SubscriptionPaymentFailure(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;

  @override
  List<Object?> get props => [message, canRetry];
}

class SubscriptionPaymentCancelled extends SubscriptionState {
  const SubscriptionPaymentCancelled();
}
