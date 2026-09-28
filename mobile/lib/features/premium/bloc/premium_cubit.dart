import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../../../models/subscription.dart';
import '../subscription_repository.dart';

class PremiumState {
  const PremiumState({
    this.status = const LoadState.idle(),
    this.usage = const LoadState.idle(),
  });

  final LoadState<SubscriptionStatusResult> status;
  final LoadState<UsageResult> usage;
}

class PremiumCubit extends Cubit<PremiumState> {
  PremiumCubit({required SubscriptionRepository repo})
    : _repo = repo,
      super(const PremiumState());

  final SubscriptionRepository _repo;

  Future<void> load() async {
    emit(
      const PremiumState(
        status: LoadState.loading(),
        usage: LoadState.loading(),
      ),
    );
    try {
      final results = await Future.wait<Object>([
        _repo.status(),
        _repo.usage(),
      ]);
      emit(
        PremiumState(
          status: LoadState.data(results[0] as SubscriptionStatusResult),
          usage: LoadState.data(results[1] as UsageResult),
        ),
      );
    } catch (e) {
      emit(PremiumState(status: LoadState.error(e), usage: LoadState.error(e)));
    }
  }

  Future<PurchaseResult> purchase() => _repo.purchase();

  Future<void> cancel() async {
    await _repo.cancel();
    await load();
  }
}
