/// High-level lifecycle of the shared WebSocket connection.
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,

  /// The backend rejected the token used for the handshake; the service is
  /// forcing a refresh before retrying with a fresh one.
  unauthorized,
}
