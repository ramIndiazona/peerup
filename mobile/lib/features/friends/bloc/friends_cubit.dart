import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/realtime/realtime_connection_state.dart';
import '../../../core/realtime/realtime_event.dart';
import '../../../core/realtime/realtime_event_bus.dart';
import '../../../core/utils/load_state.dart';
import '../../../models/friend.dart';
import '../friends_repository.dart';

/// Loads and keeps the accepted-friends list up to date.
///
/// Uses the project-wide [LoadState] convention for loading/loaded/empty/error
/// and listens on the shared socket for friendship changes.
class FriendsCubit extends Cubit<LoadState<List<Friend>>> {
  FriendsCubit({
    required FriendsRepository repo,
    RealtimeEventBus? socket,
    String? Function()? currentUserId,
  }) : _repo = repo,
       _socket = socket,
       _currentUserId = currentUserId,
       super(const LoadState.idle()) 
       {
    final bus = _socket;
    if (bus != null) {
      for (final event in _friendshipEvents) {
        bus.subscribe(event);
      }
      _eventsSub = bus.serverEvents.listen(_onServerEvent);
      _connectionSub = bus.connectionStateStream.listen(_onConnection);
    }
  }

  /// Events that can change friendship membership.
  static const List<String> _friendshipEvents = [
    'FRIENDSHIP_CREATED',
    'FRIEND_REQUEST_ACCEPTED',
  ];

  final FriendsRepository _repo;
  final RealtimeEventBus? _socket;
  final String? Function()? _currentUserId;

  StreamSubscription<RealtimeRawEvent>? _eventsSub;
  StreamSubscription<RealtimeConnectionState>? _connectionSub;

  Future<void> load() async
   {
    emit(const LoadState.loading());
    try {
      final page = await _repo.list(
        page: 1,
        limit: 100,
        currentUserId: _currentUserId?.call(),
      );
      final items = _dedupe(page.items);
      emit(LoadState.data(items));
    } catch (e) 
    {
      if (isClosed) return;
      emit(LoadState.error(e));
    }
  }

  Future<void> refresh() => load();


  // Future<void> sendFriendRequest() async
  //  {
  //   emit(const LoadState.loading());
  //   try {
  //     var data={};
  //     final page = await _repo.sendFriendRequest(
  //     data
  //     );
  //     final items = _dedupe(page.items);
  //     emit(LoadState.data(items));
  //   } catch (e) 
  //   {
  //     if (isClosed) return;
  //     emit(LoadState.error(e));
  //   }
  // }

Future<dynamic> submitCallFeedback({
  required String receiverId,
 required String? reaction,
  required List<String> feedback,
  required bool addToFriends,
  required bool connectAgain,
}) async {
  final response = await _repo.sendFriendRequest(
    receiverId: receiverId,
    reaction: reaction,
    feedback: feedback,
    addToFriends: addToFriends,
    connectAgain: connectAgain,
  );

  // Refresh accepted friends after submitting the request.
  // Pending requests will not appear in the accepted-friends list.
  if (addToFriends && !isClosed) {
    await load();
  }

  return response;
}
  
  
  
  /// Refresh when a friendship is created or accepted.
  ///
  /// We deliberately re-fetch from the backend (source of truth) instead of
  /// fabricating a friend row from the event payload.
  void _onServerEvent(RealtimeRawEvent event) {
    if (!_friendshipEvents.contains(event.name)) return;
    unawaited(load());
  }

  void _onConnection(RealtimeConnectionState connection) {
    if (connection == RealtimeConnectionState.connected) {
      unawaited(load());
    }
  }

  List<Friend> _dedupe(List<Friend> friends) {
    final seen = <String>{};
    final result = <Friend>[];
    for (final friend in friends) {
      if (friend.id.isEmpty) continue;
      if (seen.add(friend.id)) result.add(friend);
    }
    return result;
  }

  @override
  Future<void> close() async {
    for (final event in _friendshipEvents) {
      _socket?.unsubscribe(event);
    }
    await _eventsSub?.cancel();
    await _connectionSub?.cancel();
    return super.close();
  }

  @override
  void onChange(Change<LoadState<List<Friend>>> change) {
    super.onChange(change);
    debugPrint('[FRIENDS] ${change.nextState.status}');
  }
}
