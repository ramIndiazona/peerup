import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/realtime/realtime_connection_state.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_event_bus.dart';
import '../../../models/app_notification.dart';
import '../notifications_repository.dart';
import 'notifications_state.dart';

export 'notifications_state.dart';

/// Owns the in-app notification list, its unread badge and the real-time
/// updates delivered over the shared socket.
///
/// Uses the project-wide Cubit convention (the notifications feature already
/// shipped as a Cubit). State carries initial/loading/loaded/empty/error,
/// pagination and the derived unread count.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationsRepository repo,
    RealtimeEventBus? socket,
  }) : _repo = repo,
       _socket = socket,
       super(const NotificationsState()) {
    final bus = _socket;
    if (bus != null) {
      // Backend emits NOTIFICATION_CREATED to the target user's socket when a
      // notification row is persisted (see FriendRequestsService).
      bus.subscribe(_notificationEvent);
      _eventsSub = bus.serverEvents.listen(_onServerEvent);
      _connectionSub = bus.connectionStateStream.listen(_onConnection);
    }
  }

  static const String _notificationEvent = 'NOTIFICATION_CREATED';
  static const int _pageSize = 20;

  final NotificationsRepository _repo;
  final RealtimeEventBus? _socket;

  StreamSubscription<RealtimeRawEvent>? _eventsSub;
  StreamSubscription<RealtimeConnectionState>? _connectionSub;

  /// Load page 1, replacing the current list.
  Future<void> load() async {
    emit(state.copyWith(status: NotificationsStatus.loading, clearError: true));
    try {
      final result = await _repo.list(page: 1, limit: _pageSize);
    
      if (isClosed) return;
      emit(
        NotificationsState(
          status: NotificationsStatus.loaded,
          items: result.items,
          total: result.total,
          page: 1,
          hasMore: result.items.length < result.total,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: NotificationsStatus.error, error: e));
    }
  }

  Future<void> refresh() => load();

  /// Load the next page and append (de-duplicated) results.
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.isLoading) return;
    emit(state.copyWith(loadingMore: true));
    try {
      final next = state.page + 1;
      final result = await _repo.list(page: next, limit: _pageSize);
      if (isClosed) return;

      final seen = state.items.map((n) => n.id).toSet();
      final merged = [
        ...state.items,
        ...result.items.where((n) => seen.add(n.id)),
      ];
      emit(
        state.copyWith(
          items: merged,
          total: result.total,
          page: next,
          loadingMore: false,
          hasMore: merged.length < result.total,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loadingMore: false, error: e));
    }
  }

  /// Mark a single notification read on the backend, then reflect it locally.
  Future<void> markRead(String id) async {
    final current = state.items;
    final index = current.indexWhere((n) => n.id == id);
    if (index < 0 || current[index].isRead) return;

    try {
      await _repo.markRead(id);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e));
      return;
    }
    if (isClosed) return;

    final updated = [...current];
    updated[index] = AppNotification(
      id: current[index].id,
      type: current[index].type,
      title: current[index].title,
      body: current[index].body,
      data: current[index].data,
      readAt: DateTime.now(),
      createdAt: current[index].createdAt,
    );
    emit(state.copyWith(items: updated));
  }

  /// Mark every unread notification read.
  ///
  /// The backend exposes no bulk endpoint, so this issues idempotent PATCH
  /// calls (safe to retry) and then updates the local state.
  Future<void> markAllRead() async {
    final unread = state.items.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    try {
      await Future.wait([for (final n in unread) _repo.markRead(n.id)]);
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e));
      return;
    }
    if (isClosed) return;

    final now = DateTime.now();
    emit(
      state.copyWith(
        items: [
          for (final n in state.items)
            n.isRead
                ? n
                : AppNotification(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  readAt: now,
                  createdAt: n.createdAt,
                ),
        ],
      ),
    );
  }

  /// Accept a pending friend request referenced by a notification.
  ///
  /// The backend resolves the stored notification metadata, so the action
  /// disappears after a refresh. We also update the local copy immediately.
  Future<bool> acceptFriendRequest(AppNotification notification) async {
    final requestId = notification.data?['requestId'];
    if (requestId is! String || requestId.isEmpty) return false;

    try {
      await _repo.acceptFriendRequest(requestId);
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(error: e));
      return false;
    }
    if (isClosed) return false;

    final now = DateTime.now();
    final updated = [
      for (final item in state.items)
        if (item.id == notification.id)
          AppNotification(
            id: item.id,
            type: item.type,
            title: item.title,
            body: item.body,
            data: {...?item.data, 'kind': 'FRIEND_REQUEST_ACCEPTED'},
            readAt: item.readAt ?? now,
            createdAt: item.createdAt,
          )
        else
          item,
    ];

    emit(state.copyWith(items: updated));
    return true;
  }

  void _onServerEvent(RealtimeRawEvent event) {
    if (event.name != _notificationEvent) return;

    final raw = event.data['notification'] ?? event.data;
    if (raw is! Map) {
      debugPrint('[NOTIF] ignoring malformed payload');
      return;
    }

    final AppNotification notification;
    try {
      notification = AppNotification.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('[NOTIF] parse error: $e');
      return;
    }

    if (notification.id.isEmpty) return;

    // The same event may be delivered more than once (reconnect, duplicate
    // server fan-out). Never create duplicate rows.
    if (state.items.any((n) => n.id == notification.id)) return;

    emit(
      state.copyWith(
        status: NotificationsStatus.loaded,
        items: [notification, ...state.items],
        total: state.total + 1,
      ),
    );
  }

  void _onConnection(RealtimeConnectionState connection) {
    // Pull anything missed while the socket was down.
    if (connection == RealtimeConnectionState.connected && !state.isLoading) {
      unawaited(load());
    }
  }

  @override
  Future<void> close() async {
    _socket?.unsubscribe(_notificationEvent);
    await _eventsSub?.cancel();
    await _connectionSub?.cancel();
    return super.close();
  }
}
