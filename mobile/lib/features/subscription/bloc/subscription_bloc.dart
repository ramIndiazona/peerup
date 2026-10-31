import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/payment/razorpay_payment_service.dart';
import '../../premium/subscription_repository.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

/// BLoC for the Premium Razorpay subscription purchase flow.
///
/// Keeps all purchase business logic out of the widget layer and guarantees
/// that at most one purchase is in flight at a time.
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc({required SubscriptionRepository repo})
    : _repo = repo,
      _payment = RazorpayPaymentService(),
      super(const SubscriptionInitial()) {
    _checkoutSubscription = _payment.results.listen(_onCheckoutResult);

    on<LoadSubscription>(_onLoad);
    on<SelectSubscriptionPlan>(_onSelect);
    on<PurchaseSubscription>(_onPurchase);
    on<VerifySubscriptionPayment>(_onVerify);
    on<SubscriptionPaymentFailed>(_onPaymentFailed);
    on<SubscriptionCheckoutCancelled>(_onCheckoutCancelled);
    on<RefreshSubscriptionStatus>(_onRefresh);
  }

  final SubscriptionRepository _repo;
  final RazorpayPaymentService _payment;
  late final StreamSubscription<RazorpayCheckoutResult> _checkoutSubscription;

  /// Guards against multiple simultaneous purchases.
  bool _isPurchasing = false;

  @override
  Future<void> close() {
    _isPurchasing = false;
    _checkoutSubscription.cancel();
    _payment.dispose();
    return super.close();
  }

  Future<void> _onLoad(
    LoadSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading());
    try {
      final status = await _repo.status();
      emit(
        SubscriptionLoaded(
          plans: SubscriptionOption.all(),
          selectedPeriod: null,
          status: status,
        ),
      );
    } catch (e) {
      // Keep the plans visible even if the status call fails so the user can
      // still attempt a purchase.
      emit(
        SubscriptionLoaded(
          plans: SubscriptionOption.all(),
          selectedPeriod: null,
          status: null,
        ),
      );
    }
  }

  void _onSelect(
    SelectSubscriptionPlan event,
    Emitter<SubscriptionState> emit,
  ) {
    final current = state;
    final plans =
        current is SubscriptionLoaded
            ? current.plans
            : SubscriptionOption.all();
    final status = current is SubscriptionLoaded ? current.status : null;
    emit(
      SubscriptionLoaded(
        plans: plans,
        selectedPeriod: event.period,
        status: status,
      ),
    );
  }

  Future<void> _onPurchase(
    PurchaseSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (_isPurchasing) return;

    final current = state;
    final selected =
        current is SubscriptionLoaded ? current.selectedPeriod : null;
    if (selected == null) {
      add(
        const SubscriptionPaymentFailed(
          'Please select Monthly or Yearly before subscribing.',
          canRetry: true,
        ),
      );
      return;
    }

    _isPurchasing = true;
    emit(SubscriptionPaymentProcessing(selectedPeriod: selected));

    try {
      // Step 3-5: the authenticated backend creates the Razorpay order and
      // returns the order id, public key id, amount and currency.
      final order = await _repo.purchasePlan(plan: selected);

      // Step 6: Flutter opens Razorpay Checkout.
      await _payment.openCheckout(
        keyId: order.keyId,
        orderId: order.orderId,
        amount: order.amount,
        currency: order.currency,
      );
      // The checkout outcome arrives via the Razorpay stream and is handled
      // by _onPaymentResultReceived.
    } on ApiException catch (e) {
      _isPurchasing = false;
      add(SubscriptionPaymentFailed(_message(e), canRetry: !e.isUnauthorized));
    } catch (e) {
      _isPurchasing = false;
      add(SubscriptionPaymentFailed(_message(e), canRetry: true));
    }
  }

  /// Handles the Razorpay checkout outcome delivered by [RazorpayPaymentService].
  /// Not an event handler, so it dispatches events via [add] rather than [emit].
  void _onCheckoutResult(RazorpayCheckoutResult result) {
    print('[SUBSCRIPTION BLOC] Checkout result received');
    print('[SUBSCRIPTION BLOC] Type: ${result.type}');
    print('[SUBSCRIPTION BLOC] Success: ${result.isSuccess}');
    print('[SUBSCRIPTION BLOC] Failure: ${result.isFailure}');
    print('[SUBSCRIPTION BLOC] Cancelled: ${result.isCancelled}');

    if (!_isPurchasing) {
      print('[SUBSCRIPTION BLOC] Ignored: no purchase in progress');
      return;
    }

    if (result.isSuccess) {
      final paymentId = result.paymentId;
      final orderId = result.orderId;
      final signature = result.signature;

      if (paymentId == null || orderId == null || signature == null) {
        add(
          const SubscriptionPaymentFailed(
            'Payment details are incomplete.',
            canRetry: true,
          ),
        );
        return;
      }

      add(
        VerifySubscriptionPayment(
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
        ),
      );
    } else if (result.isCancelled) {
      add(const SubscriptionCheckoutCancelled());
    } else {
      add(
        SubscriptionPaymentFailed(
          result.message ?? 'Payment failed',
          canRetry: true,
        ),
      );
    }
  }

  void _onCheckoutCancelled(
    SubscriptionCheckoutCancelled event,
    Emitter<SubscriptionState> emit,
  ) {
    _isPurchasing = false;
    emit(const SubscriptionPaymentCancelled());
  }

  Future<void> _onVerify(
    VerifySubscriptionPayment event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionPaymentVerification());

    try {
      print('[SUBSCRIPTION BLOC] Verifying payment...');

      await _repo.verifyPayment(
        paymentId: event.paymentId,
        orderId: event.orderId,
        signature: event.signature,
      );

      print('[SUBSCRIPTION BLOC] Payment verified successfully');
      print('[SUBSCRIPTION BLOC] Fetching subscription status...');

      final status = await _repo.status();

      print('[SUBSCRIPTION BLOC] Subscription status fetched');
      print('[SUBSCRIPTION BLOC] Status: ${status.status}');
      print('[SUBSCRIPTION BLOC] Plan: ${status.plan}');

      _isPurchasing = false;

      print('[SUBSCRIPTION BLOC] Emitting SubscriptionPaymentSuccess');

      emit(SubscriptionPaymentSuccess(status));
    } catch (e, stackTrace) {
      _isPurchasing = false;

      print('[SUBSCRIPTION BLOC] Verification flow failed: $e');
      print(stackTrace);

      add(SubscriptionPaymentFailed(_message(e), canRetry: true));
    }
  }

  void _onPaymentFailed(
    SubscriptionPaymentFailed event,
    Emitter<SubscriptionState> emit,
  ) {
    _isPurchasing = false;
    emit(SubscriptionPaymentFailure(event.message, canRetry: event.canRetry));
  }

  Future<void> _onRefresh(
    RefreshSubscriptionStatus event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final status = await _repo.status();
      final current = state;
      emit(
        SubscriptionLoaded(
          plans:
              current is SubscriptionLoaded
                  ? current.plans
                  : SubscriptionOption.all(),
          selectedPeriod:
              current is SubscriptionLoaded ? current.selectedPeriod : null,
          status: status,
        ),
      );
    } catch (_) {
      // Leave the current state untouched on refresh failure.
    }
  }

  String _message(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }
}
