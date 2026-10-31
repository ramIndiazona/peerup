import 'package:flutter_test/flutter_test.dart';

import 'package:peerup/core/network/api_url.dart';
import 'package:peerup/features/premium/subscription_repository.dart';
import 'package:peerup/models/enums.dart';
import 'package:peerup/models/subscription.dart';

import '../../support/fakes.dart';

void main() {
  late StubApiClient api;
  late SubscriptionRepository repo;

  setUp(() {
    api = StubApiClient();
    repo = SubscriptionRepository(api);
  });

  test(
    'purchasePlan posts the selected plan and parses the Razorpay order',
    () async {
      api.onPost = (path, data) async {
        expect(path, APIURL.subscriptionsPurchase);
        expect(data, {'plan': 'yearly'});
        return {
          'success': true,
          'mode': 'checkout',
          'orderId': 'order_123',
          'keyId': 'rzp_test_123',
          'amount': 99900,
          'currency': 'INR',
        };
      };

      final order = await repo.purchasePlan(plan: 'yearly');

      expect(order.orderId, 'order_123');
      expect(order.keyId, 'rzp_test_123');
      expect(order.amount, 99900);
      expect(order.currency, 'INR');
      expect(api.calls.single.method, 'POST');
    },
  );

  test('verifyPayment posts payment details and parses the result', () async {
    api.onPost = (path, data) async {
      expect(path, APIURL.subscriptionsVerifyPayment);
      expect(data['razorpay_payment_id'], 'pay_123');
      expect(data['razorpay_order_id'], 'order_123');
      expect(data['razorpay_signature'], 'signature');
      return {
        'success': true,
        'status': 'PAID',
        'plan': 'PREMIUM',
        'renewsAt': '2026-12-31T00:00:00Z',
      };
    };

    final result = await repo.verifyPayment(
      paymentId: 'pay_123',
      orderId: 'order_123',
      signature: 'signature',
    );

    expect(result.success, isTrue);
    expect(result.status, 'PAID');
    expect(result.plan, SubscriptionPlan.premium);
    expect(result.renewsAt, isNotNull);
  });

  test('purchasePlan propagates backend errors', () async {
    api.onPost = (path, data) async {
      throw Exception('network down');
    };

    expect(() => repo.purchasePlan(plan: 'monthly'), throwsA(isA<Exception>()));
  });
}
