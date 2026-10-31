import 'package:flutter_test/flutter_test.dart';

import 'package:peerup/core/network/api_url.dart';
import 'package:peerup/features/premium/subscription_repository.dart';
import 'package:peerup/features/subscription/bloc/subscription_bloc.dart';
import 'package:peerup/features/subscription/bloc/subscription_event.dart';
import 'package:peerup/features/subscription/bloc/subscription_state.dart';
import 'package:peerup/models/enums.dart';
import 'package:peerup/models/subscription.dart';

import '../../support/fakes.dart';

void main() {
  late StubApiClient api;
  late SubscriptionRepository repo;
  late SubscriptionBloc bloc;

  setUp(() {
    api = StubApiClient();
    repo = SubscriptionRepository(api);
    bloc = SubscriptionBloc(repo: repo);
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<SubscriptionLoaded> _loadedState() async {
    bloc.add(const LoadSubscription());
    return (await bloc.stream.firstWhere((s) => s is SubscriptionLoaded))
        as SubscriptionLoaded;
  }

  test('load emits both plans and the current subscription status', () async {
    api.onGet = (path, _) async {
      if (path == APIURL.subscriptionsMe) {
        return {'plan': 'FREE', 'status': 'INACTIVE', 'features': {}};
      }
      throw StateError('unexpected path $path');
    };

    final state = await _loadedState();

    expect(state.plans, hasLength(2));
    expect(state.plans.map((p) => p.apiValue).toList(), ['monthly', 'yearly']);
    expect(state.selectedPeriod, isNull);
    expect(state.status?.plan, SubscriptionPlan.free);
    expect(state.status?.isPremiumActive, isFalse);
  });

  test('select updates the chosen billing period', () async {
    bloc.add(const SelectSubscriptionPlan('yearly'));
    final state =
        (await bloc.stream.firstWhere((s) => s is SubscriptionLoaded))
            as SubscriptionLoaded;
    expect(state.selectedPeriod, 'yearly');

    bloc.add(const SelectSubscriptionPlan('monthly'));
    final second =
        (await bloc.stream.firstWhere((s) => s is SubscriptionLoaded))
            as SubscriptionLoaded;
    expect(second.selectedPeriod, 'monthly');
  });

  test('purchase without a selected plan emits a retryable failure', () async {
    await _loadedState();
    bloc.add(const PurchaseSubscription());
    final state =
        await bloc.stream.firstWhere((s) => s is SubscriptionPaymentFailure)
            as SubscriptionPaymentFailure;
    expect(state.message, contains('Monthly or Yearly'));
    expect(state.canRetry, isTrue);
  });
}
