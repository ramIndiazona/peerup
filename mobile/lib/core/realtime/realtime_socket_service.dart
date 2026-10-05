import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../auth/token_manager.dart';
import '../config/app_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_event.dart';

/// Single shared realtime connection to the NestJS `/realtime` gateway.
///
/// Connection lifecycle:
///
/// Flutter
///   ↓
/// create socket with fresh JWT
///   ↓
/// Socket.IO transport connected
///   ↓
/// NestJS validates JWT
///   ↓
/// NestJS emits CONNECTED
///   ↓
/// Flutter becomes authenticated
///   ↓
/// heartbeat starts
///   ↓
/// LIVE_START / START_MATCH / CALL signaling
///
/// IMPORTANT:
/// Socket.IO `connect` does NOT mean the application is authenticated.
/// Authentication is considered complete only after the backend sends
/// `CONNECTED`.
class RealtimeSocketService {
  RealtimeSocketService({required TokenManager tokens}) : _tokens = tokens;

  final TokenManager _tokens;

  io.Socket? _socket;

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  final StreamController<RealtimeConnectionState> _connectionController =
      StreamController<RealtimeConnectionState>.broadcast();

  Timer? _heartbeat;
  Timer? _reconnectTimer;

  Future<void>? _connecting;

  int _reconnectAttempt = 0;

  bool _manualDisconnect = false;

  /// Completer for the CURRENT socket authentication attempt.
  ///
  /// This is intentionally stored at service level so authentication
  /// rejection can immediately release `_doConnect()` instead of making
  /// it wait for the complete authentication timeout.
  Completer<void>? _authenticationCompleter;

  static const Duration _heartbeatInterval = Duration(seconds: 15);

  static const Duration _authenticationTimeout = Duration(seconds: 10);

  static const List<Duration> _backoffDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  // ============================================================
  // PUBLIC STREAMS
  // ============================================================

  Stream<RealtimeEvent> get events => _events.stream;

  Stream<RealtimeConnectionState> get connectionStateStream =>
      _connectionController.stream;

  // ============================================================
  // CONNECTION STATE
  // ============================================================

  RealtimeConnectionState _connection = RealtimeConnectionState.disconnected;

  RealtimeConnectionState get connectionState => _connection;

  /// True ONLY after:
  ///
  /// 1. Socket.IO transport is connected.
  /// 2. NestJS has validated the JWT.
  /// 3. NestJS has emitted CONNECTED.
  bool get isAuthenticated =>
      _socket?.connected == true &&
      _connection == RealtimeConnectionState.connected;

  /// Existing services use this name.
  bool get isConnected => isAuthenticated;

  // ============================================================
  // CONNECT
  // ============================================================

  Future<void> connect() async {
    _manualDisconnect = false;

    // Already fully authenticated.
    if (isAuthenticated) {
      return;
    }

    // Cancel any pending reconnect because the caller explicitly
    // requested a connection.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Reuse an existing connection attempt.
    final existingConnect = _connecting;

    if (existingConnect != null) {
      await existingConnect;
      return;
    }

    final future = _doConnect();

    _connecting = future;

    try {
      await future;
    } finally {
      if (identical(_connecting, future)) {
        _connecting = null;
      }
    }
  }

  Future<void> _doConnect() async {
    // ----------------------------------------------------------
    // CLEAN UP OLD SOCKET
    // ----------------------------------------------------------

    final existing = _socket;

    if (existing != null) {
      if (existing.connected && isAuthenticated) {
        return;
      }

      _teardownSocket();
    }

    _setConnection(RealtimeConnectionState.connecting);

    // ----------------------------------------------------------
    // GET FRESH TOKEN
    // ----------------------------------------------------------

    final token = await _tokens.getValidAccessToken();

    if (token == null || token.isEmpty) {
      debugPrint('[WS] no valid token available');

      _setConnection(RealtimeConnectionState.disconnected);

      return;
    }

    // ----------------------------------------------------------
    // AUTHENTICATION COMPLETER
    // ----------------------------------------------------------

    final authenticated = Completer<void>();

    _authenticationCompleter = authenticated;

    // ----------------------------------------------------------
    // CREATE SOCKET
    // ----------------------------------------------------------

    debugPrint('[WS] creating authenticated socket');

    final socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setPath(AppConfig.wsPath)
          .setAuth({'token': token})
          .disableReconnection()
          .build(),
    );

    _socket = socket;

    // ----------------------------------------------------------
    // CURRENT SOCKET CHECK
    // ----------------------------------------------------------

    bool isCurrentSocket() {
      return identical(_socket, socket);
    }

    // ==========================================================
    // SOCKET.IO TRANSPORT CONNECTED
    // ==========================================================

    socket.onConnect((_) {
      if (!isCurrentSocket()) {
        debugPrint('[WS] ignoring stale transport connect');

        return;
      }

      debugPrint(
        '[WS] transport connected '
        '- waiting for server CONNECTED',
      );

      // IMPORTANT:
      //
      // Do NOT mark the connection authenticated here.
      //
      // NestJS still has to validate the JWT and emit CONNECTED.
    });

    // ==========================================================
    // SERVER AUTHENTICATED
    // ==========================================================

    socket.on('CONNECTED', (data) {
      if (!isCurrentSocket()) {
        debugPrint('[WS] ignoring stale CONNECTED event');

        return;
      }

      debugPrint('[WS] server authenticated');

      _reconnectAttempt = 0;

      _setConnection(RealtimeConnectionState.connected);

      _startHeartbeat();

      _push(_typed(RealtimeEventType.connected, data));

      _completeAuthentication();
    });

    // ==========================================================
    // DISCONNECTED
    // ==========================================================

    socket.onDisconnect((reason) {
      if (!isCurrentSocket()) {
        debugPrint('[WS] ignoring stale socket disconnect');

        return;
      }

      debugPrint('[WS] disconnected reason=$reason');

      _heartbeat?.cancel();
      _heartbeat = null;

      // Release anyone waiting for authentication.
      _completeAuthentication();

      // Manual disconnect owns its state transition.
      if (_manualDisconnect) {
        return;
      }

      // This socket is no longer usable.
      if (identical(_socket, socket)) {
        _socket = null;
      }

      _setConnection(RealtimeConnectionState.disconnected);

      _push(RealtimeEvent(RealtimeEventType.disconnected, {'reason': reason}));

      _scheduleReconnect();
    });

    // ==========================================================
    // CONNECT ERROR
    // ==========================================================

    socket.onConnectError((data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] connect error: $data');

      final text = '$data'.toLowerCase();

      final authRejected =
          text.contains('unauthorized') ||
          text.contains('invalid token') ||
          text.contains('authentication') ||
          text.contains('token');

      if (authRejected) {
        unawaited(_onAuthRejected(socket));

        return;
      }

      _completeAuthentication();

      _heartbeat?.cancel();
      _heartbeat = null;

      _setConnection(RealtimeConnectionState.disconnected);

      if (!_manualDisconnect) {
        _teardownSpecificSocket(socket);

        _scheduleReconnect();
      }
    });

    // ==========================================================
    // GENERIC SOCKET ERROR
    // ==========================================================

    socket.onError((data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] socket error: $data');

      _push(RealtimeEvent(RealtimeEventType.error, {'message': '$data'}));
    });

    // ==========================================================
    // HEARTBEAT ACK
    // ==========================================================

    socket.on('HEARTBEAT_ACK', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.heartbeatAck, data));
    });

    // ==========================================================
    // LIVE COUNT
    // ==========================================================

    socket.on('LIVE_COUNT_UPDATED', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.liveCount, data));
    });

    // ==========================================================
    // LIVE USERS
    // ==========================================================

    socket.on('LIVE_USERS', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.liveUsers, data));
    });

    // ==========================================================
    // LIVE STARTED
    // ==========================================================

    socket.on('LIVE_STARTED', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.liveStarted, data));
    });

    // ==========================================================
    // LIVE STOPPED
    // ==========================================================

    socket.on('LIVE_STOPPED', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.liveStopped, data));
    });

    // ==========================================================
    // MATCH FOUND
    // ==========================================================

    socket.on('MATCH_FOUND', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] MATCH_FOUND');

      _push(_typed(RealtimeEventType.matchFound, data));
    });

    // ==========================================================
    // MATCH SEARCHING
    // ==========================================================

    socket.on('MATCH_SEARCHING', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.matchSearching, data));
    });

    // ==========================================================
    // MATCH CANCELLED
    // ==========================================================

    socket.on('MATCH_CANCELLED', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.matchCancelled, data));
    });

    // ==========================================================
    // MATCH TIMEOUT
    // ==========================================================

    socket.on('MATCH_TIMEOUT', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.matchTimeout, data));
    });

    // ==========================================================
    // CALL OFFER
    // ==========================================================

    socket.on('CALL_OFFER', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] CALL_OFFER received');

      _push(_typed(RealtimeEventType.callOffer, data));
    });

    // ==========================================================
    // CALL ANSWER
    // ==========================================================

    socket.on('CALL_ANSWER', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] CALL_ANSWER received');

      _push(_typed(RealtimeEventType.callAnswer, data));
    });

    // ==========================================================
    // ICE CANDIDATE
    // ==========================================================

    socket.on('ICE_CANDIDATE', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] ICE_CANDIDATE received');

      _push(_typed(RealtimeEventType.iceCandidate, data));
    });

    // ==========================================================
    // CALL CONNECTED
    // ==========================================================

    for (final entry
        in {
          'CALL_RECONNECTING': RealtimeEventType.callReconnecting,
          'CALL_RECONNECTED': RealtimeEventType.callReconnected,
        }.entries) {
      socket.on(entry.key, (data) {
        if (isCurrentSocket()) _push(_typed(entry.value, data));
      });
    }

    socket.on('CALL_CONNECTED', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.callConnected, data));
    });

    // ==========================================================
    // CALL ENDED
    // ==========================================================

    socket.on('CALL_ENDED', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      _push(_typed(RealtimeEventType.callEnded, data));
    });

    // ==========================================================
    // SERVER ERROR
    // ==========================================================

    socket.on('ERROR', (data) {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] server ERROR: $data');

      final event = _typed(RealtimeEventType.error, data);

      _push(event);

      if (event.rawErrorCode == 'UNAUTHORIZED') {
        unawaited(_onAuthRejected(socket));
      }
    });

    // ==========================================================
    // START SOCKET
    // ==========================================================

    socket.connect();

    // ==========================================================
    // WAIT FOR SERVER AUTHENTICATION
    // ==========================================================

    try {
      await authenticated.future.timeout(_authenticationTimeout);
    } on TimeoutException {
      if (!isCurrentSocket()) {
        return;
      }

      debugPrint('[WS] server authentication timeout');

      _completeAuthentication();

      _heartbeat?.cancel();
      _heartbeat = null;

      _teardownSpecificSocket(socket);

      if (!_manualDisconnect) {
        _setConnection(RealtimeConnectionState.disconnected);

        _scheduleReconnect();
      }
    } finally {
      if (identical(_authenticationCompleter, authenticated)) {
        _authenticationCompleter = null;
      }
    }
  }

  // ============================================================
  // AUTHENTICATION COMPLETER
  // ============================================================

  void _completeAuthentication() {
    final completer = _authenticationCompleter;

    if (completer == null) {
      return;
    }

    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  // ============================================================
  // AUTH REJECTED
  // ============================================================

  Future<void> _onAuthRejected(io.Socket rejectedSocket) async {
    if (_manualDisconnect) {
      return;
    }

    // Ignore an old socket.
    if (!identical(_socket, rejectedSocket)) {
      return;
    }

    debugPrint(
      '[WS] authentication rejected '
      '- refreshing token',
    );

    _setConnection(RealtimeConnectionState.unauthorized);

    _heartbeat?.cancel();
    _heartbeat = null;

    /**
     * IMPORTANT:
     *
     * Release `_doConnect()` immediately.
     *
     * Without this, `_doConnect()` waits the complete 10-second
     * authentication timeout after an explicit UNAUTHORIZED event.
     */
    _completeAuthentication();

    // ----------------------------------------------------------
    // Remove rejected socket FIRST.
    //
    // This prevents its disconnect callback from being treated
    // as the current socket.
    // ----------------------------------------------------------

    if (identical(_socket, rejectedSocket)) {
      _socket = null;
    }

    try {
      rejectedSocket.disconnect();
      rejectedSocket.dispose();
    } catch (_) {}

    // ----------------------------------------------------------
    // Refresh token
    // ----------------------------------------------------------

    try {
      final freshToken = await _tokens.forceRefresh();

      if (freshToken == null || freshToken.isEmpty) {
        debugPrint(
          '[WS] token refresh failed '
          '- session unavailable',
        );

        _setConnection(RealtimeConnectionState.disconnected);

        return;
      }

      debugPrint('[WS] token refreshed successfully');
    } catch (e) {
      debugPrint('[WS] force refresh failed: $e');

      _setConnection(RealtimeConnectionState.disconnected);

      return;
    }

    if (_manualDisconnect) {
      return;
    }

    // ----------------------------------------------------------
    // Reconnect after short backoff.
    // ----------------------------------------------------------

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(_nextBackoff(), () {
      _reconnectTimer = null;

      if (_manualDisconnect) {
        return;
      }

      unawaited(connect());
    });
  }

  // ============================================================
  // RECONNECT
  // ============================================================

  void _scheduleReconnect() {
    if (_manualDisconnect) {
      return;
    }

    if (_reconnectTimer != null) {
      return;
    }

    if (isAuthenticated) {
      return;
    }

    final delay = _nextBackoff();

    debugPrint(
      '[WS] reconnect scheduled '
      'in ${delay.inSeconds}s',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;

      if (_manualDisconnect) {
        return;
      }

      _setConnection(RealtimeConnectionState.reconnecting);

      unawaited(connect());
    });
  }

  Duration _nextBackoff() {
    final index =
        _reconnectAttempt < _backoffDelays.length
            ? _reconnectAttempt
            : _backoffDelays.length - 1;

    _reconnectAttempt++;

    return _backoffDelays[index];
  }

  // ============================================================
  // HEARTBEAT
  // ============================================================

  void _startHeartbeat() {
    _heartbeat?.cancel();

    debugPrint('[WS] heartbeat started');

    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      if (isAuthenticated) {
        heartbeat();
      }
    });
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect() async {
    _manualDisconnect = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _heartbeat?.cancel();
    _heartbeat = null;

    _completeAuthentication();

    _teardownSocket();

    _setConnection(RealtimeConnectionState.disconnected);

    _push(RealtimeEvent(RealtimeEventType.disconnected, {}));
  }

  void _teardownSocket() {
    _heartbeat?.cancel();
    _heartbeat = null;

    final socket = _socket;

    _socket = null;

    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {}
  }

  void _teardownSpecificSocket(io.Socket socket) {
    if (identical(_socket, socket)) {
      _socket = null;
    }

    try {
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
  }

  // ============================================================
  // EVENTS
  // ============================================================

  void _push(RealtimeEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _setConnection(RealtimeConnectionState state) {
    if (_connection == state) {
      return;
    }

    _connection = state;

    if (!_connectionController.isClosed) {
      _connectionController.add(state);
    }
  }

  RealtimeEvent _typed(RealtimeEventType type, dynamic data) {
    final Map<String, dynamic> map;

    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else {
      map = <String, dynamic>{};
    }

    return RealtimeEvent(type, map, callId: map['callId'] as String?);
  }

  // ============================================================
  // LIVE
  // ============================================================

  void startLive() {
    if (!isAuthenticated) {
      debugPrint(
        '[LIVE] LIVE_START ignored '
        '- socket not authenticated',
      );

      return;
    }

    debugPrint('[LIVE] LIVE_START');

    _emit('LIVE_START', {});
  }

  void stopLive() {
    if (!isAuthenticated) {
      debugPrint(
        '[LIVE] LIVE_STOP ignored '
        '- socket not authenticated',
      );

      return;
    }

    debugPrint('[LIVE] LIVE_STOP');

    _emit('LIVE_STOP', {});
  }

  void heartbeat() {
    if (!isAuthenticated) {
      return;
    }

    _emit('HEARTBEAT', {});
  }

  // ============================================================
  // MATCHMAKING
  // ============================================================

  void sendStartMatch(Map<String, dynamic> filters) {
    if (!isAuthenticated) {
      debugPrint(
        '[MATCH] START_MATCH ignored '
        '- socket not authenticated',
      );

      return;
    }

    debugPrint('[MATCH] START_MATCH');

    _emit('START_MATCH', {'filters': filters});
  }

  void cancelMatch() {
    if (!isAuthenticated) {
      debugPrint(
        '[MATCH] START_MATCH_CANCEL ignored '
        '- socket not authenticated',
      );

      return;
    }

    debugPrint('[MATCH] START_MATCH_CANCEL');

    _emit('START_MATCH_CANCEL', {});
  }

  // ============================================================
  // CALL SIGNALING
  // ============================================================

  void sendOffer(String callId, dynamic sdp) {
    if (!isAuthenticated) {
      debugPrint(
        '[CALL] CALL_OFFER skipped '
        '- socket not authenticated',
      );

      return;
    }

    debugPrint(
      '[CALL] CALL_OFFER send '
      'callId=$callId',
    );

    _emit('CALL_OFFER', {'callId': callId, 'data': sdp});
  }

  void sendAnswer(String callId, dynamic sdp) {
    if (!isAuthenticated) {
      debugPrint(
        '[CALL] CALL_ANSWER skipped '
        '- socket not authenticated',
      );

      return;
    }

    debugPrint(
      '[CALL] CALL_ANSWER send '
      'callId=$callId',
    );

    _emit('CALL_ANSWER', {'callId': callId, 'data': sdp});
  }

  void sendIce(String callId, dynamic candidate) {
    if (!isAuthenticated) {
      debugPrint(
        '[CALL] ICE_CANDIDATE skipped '
        '- socket not authenticated',
      );

      return;
    }

    _emit('ICE_CANDIDATE', {'callId': callId, 'data': candidate});
  }

  void requestCallRecovery(String callId) {
    if (isAuthenticated) _emit('CALL_RECONNECTING', {'callId': callId});
  }

  void reportCallConnected(String callId) {
    if (!isAuthenticated) {
      debugPrint(
        '[CALL] CALL_CONNECTED skipped '
        '- socket not authenticated',
      );

      return;
    }

    _emit('CALL_CONNECTED', {'callId': callId});
  }

  void endCall(String callId) {
    if (!isAuthenticated) {
      debugPrint(
        '[CALL] END_CALL skipped '
        '- socket not authenticated',
      );

      return;
    }

    _emit('END_CALL', {'callId': callId});
  }

  void reportCallFailed(String callId, [String? reason]) {
    if (!isAuthenticated) {
      debugPrint(
        '[CALL] CALL_FAILED skipped '
        '- socket not authenticated',
      );

      return;
    }

    _emit('CALL_FAILED', {'callId': callId, 'reason': reason});
  }

  // ============================================================
  // EMIT
  // ============================================================

  void _emit(String event, dynamic data) {
    final socket = _socket;

    if (socket == null || !socket.connected || !isAuthenticated) {
      debugPrint(
        '[WS] emit skipped '
        'event=$event '
        'socket_not_authenticated',
      );

      return;
    }

    socket.emit(event, data);
  }

  // ============================================================
  // CLOSE
  // ============================================================

  Future<void> close() async {
    await disconnect();

    await _events.close();

    await _connectionController.close();
  }
}
