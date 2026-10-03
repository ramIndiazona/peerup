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
  callReconnecting,
  callReconnected,
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
