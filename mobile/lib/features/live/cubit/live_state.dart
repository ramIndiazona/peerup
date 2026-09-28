import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../models/live_user.dart';

/// Reactive real-time live-presence UI state.
///
/// `totalCount`/`users` mirror the server's LIVE_USERS snapshot. The current
/// user is counted by the server too, so `otherCount` subtracts one when the
/// user is live. Matching/eligibility stays on the backend — this is display
/// state only.
class LiveState extends Equatable {
  const LiveState({
    this.connected = false,
    this.totalCount = 0,
    this.users = const [],
    this.selfLive = false,
    this.selfId,
  });

  final bool connected;
  final int totalCount;
  final List<LiveUser> users;
  final bool selfLive;
  final String? selfId;

  bool get selfInList => selfId != null && users.any((u) => u.id == selfId);

  /// Other live users visible in the UI (current user excluded).
  List<LiveUser> get others =>
      selfId == null ? users : users.where((u) => u.id != selfId).toList();

  /// TOTAL live users minus the current user when they are live.
  int get otherCount => max(0, totalCount - (selfLive ? 1 : 0));

  LiveState copyWith({
    bool? connected,
    int? totalCount,
    List<LiveUser>? users,
    bool? selfLive,
    String? selfId,
  }) => LiveState(
    connected: connected ?? this.connected,
    totalCount: totalCount ?? this.totalCount,
    users: users ?? this.users,
    selfLive: selfLive ?? this.selfLive,
    selfId: selfId ?? this.selfId,
  );

  @override
  List<Object?> get props => [connected, totalCount, users, selfLive, selfId];
}
