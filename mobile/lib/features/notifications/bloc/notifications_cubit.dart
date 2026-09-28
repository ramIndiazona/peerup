import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/load_state.dart';
import '../../../models/app_notification.dart';
import '../notifications_repository.dart';

class NotificationsCubit extends Cubit<LoadState<List<AppNotification>>> {
  NotificationsCubit({required NotificationsRepository repo})
    : _repo = repo,
      super(const LoadState.idle());

  final NotificationsRepository _repo;

  Future<void> load() async {
    emit(const LoadState.loading());
    try {
      final result = await _repo.list();
      emit(LoadState.data(result.items));
    } catch (e) {
      emit(LoadState.error(e));
    }
  }

  Future<void> refresh() => load();

  Future<void> markRead(String id) async {
    await _repo.markRead(id);
    await load();
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;
    await Future.wait([
      for (final n in current.where((n) => !n.isRead)) _repo.markRead(n.id),
    ]);
    await load();
  }
}
