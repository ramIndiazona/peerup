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

  Future<void> cancel() async {
    await _api.post(APIURL.subscriptionsCancel);
  }
}
