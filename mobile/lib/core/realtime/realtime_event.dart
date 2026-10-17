/// Server-originated WebSocket events mapped to typed values.
///
/// One shared [RealtimeSocketService] emits these; feature services
/// (LivePresenceService, MatchmakingService, CallService) subscribe and filter
/// by their own concern.
enum RealtimeEventType {
  connected,
  liveCount,
  liveUsers,
  liveStarted,
  liveStopped,
  matchFound,
  matchSearching,
  matchCancelled,
  matchTimeout,
  callOffer,
  callAnswer,
  iceCandidate,
  callConnected,
  callEnded,
  heartbeatAck,
  error,
  disconnected,
}

class RealtimeEvent {
  const RealtimeEvent(this.type, this.data, {this.callId});

  final RealtimeEventType type;
  final Map<String, dynamic> data;
  final String? callId;

  String? get rawErrorCode => data['code'] as String?;
}

/// A server-originated event whose name is not part of the statically typed
/// [RealtimeEventType] set.
///
/// The shared socket already exposes a small typed vocabulary for live,
/// matchmaking and call signalling. Cross-cutting features (notifications,
/// friendships, chat) do not need their own socket connections; instead they
/// subscribe to the extra event names they care about on the shared socket
/// and receive them here.
///
/// Examples of names delivered through this channel:
///   * `NOTIFICATION_CREATED` (persisted in the NestJS backend today)
///   * `FRIENDSHIP_CREATED`, `FRIEND_REQUEST_RECEIVED`,
///     `FRIEND_REQUEST_ACCEPTED` (persisted in the NestJS backend today)
///   * `CHAT_MESSAGE` (emitted by the NestJS `ConversationsService` after a
///     message is persisted; fanned out to both participants)
class RealtimeRawEvent {
  const RealtimeRawEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;

  @override
  String toString() => 'RealtimeRawEvent($name, $data)';
}
