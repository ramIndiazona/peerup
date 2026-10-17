import 'realtime_connection_state.dart';
import 'realtime_event.dart';

/// Read/subscribe surface of the single shared realtime connection.
///
/// Feature BLoCs depend on this abstraction (not on `io.Socket`) so they can
/// be unit tested without a live backend, while production always uses the
/// one shared [RealtimeSocketService] instance.
abstract class RealtimeEventBus {
  /// Broadcast stream of named server events (see [RealtimeRawEvent]).
  Stream<RealtimeRawEvent> get serverEvents;

  /// Broadcast stream of the connection lifecycle.
  Stream<RealtimeConnectionState> get connectionStateStream;

  /// Current connection lifecycle value.
  RealtimeConnectionState get connectionState;

  /// Register interest in a server event name. Idempotent per caller and
  /// reference counted, so several features can subscribe to the same event.
  ///
  /// The listener is (re)attached to the live socket, including after a
  /// reconnect.
  void subscribe(String event);

  /// Release interest in a server event name.
  void unsubscribe(String event);
}
