import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/live_user.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_socket_service.dart';
import 'live_presence_repository.dart';

/// Immutable snapshot of the live-presence domain as known by
/// [LivePresenceService].
class LivePresenceSnapshot {
  const LivePresenceSnapshot({
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

  LivePresenceSnapshot copyWith({
    bool? connected,
    int? totalCount,
    List<LiveUser>? users,
    bool? selfLive,
    String? selfId,
    bool clearSelfId = false,
  }) {
    return LivePresenceSnapshot(
      connected: connected ?? this.connected,
      totalCount: totalCount ?? this.totalCount,
      users: users ?? this.users,
      selfLive: selfLive ?? this.selfLive,
      selfId: clearSelfId ? null : (selfId ?? this.selfId),
    );
  }
}

/// Owns the user's live presence.
///
/// Important lifecycle:
///
///   socket connect
///        ↓
///   backend CONNECTED
///        ↓
///   LIVE_START
///        ↓
///   AVAILABLE
///        ↓
///   user presses Start Match
///        ↓
///   matchmaking service handles START_MATCH
///
/// This service does NOT start matchmaking.
///
/// AVAILABLE means only:
/// "the user is live and visible".
///
/// SEARCHING is controlled by the matchmaking service.
class LivePresenceService {
  LivePresenceService({
    required RealtimeSocketService socket,
    required LivePresenceRepository repo,
  }) : _socket = socket,
       _repo = repo {
    _sub = _socket.events.listen(_onEvent);
  }

  final RealtimeSocketService _socket;
  final LivePresenceRepository _repo;

  StreamSubscription<RealtimeEvent>? _sub;

  final StreamController<LivePresenceSnapshot> _snapshotController =
      StreamController<LivePresenceSnapshot>.broadcast();

  Stream<LivePresenceSnapshot> get snapshotStream => _snapshotController.stream;

  LivePresenceSnapshot _snapshot = const LivePresenceSnapshot();

  LivePresenceSnapshot get snapshot => _snapshot;

  /// Whether the user still wants to remain in the live section.
  bool _wantLive = false;

  /// Prevents multiple enter() operations from running at the
  /// same time.
  Future<bool>? _liveLock;

  /// Incremented whenever the live intent changes.
  ///
  /// This protects against:
  ///
  /// enter()
  ///   ↓
  /// user exits
  ///   ↓
  /// old enter response arrives
  ///
  /// The old operation then becomes invalid.
  int _transitionId = 0;

  /// Completer used when Socket.IO has connected but our application-level
  /// CONNECTED event has not arrived yet.
  Completer<void>? _connectedCompleter;

  // ============================================================
  // ENTER LIVE
  // ============================================================

  /// Enter the live section.
  ///
  /// This does NOT start matchmaking.
  ///
  /// Result:
  ///
  ///   Socket connected
  ///        ↓
  ///   backend CONNECTED
  ///        ↓
  ///   LIVE_START
  ///        ↓
  ///   REST live/start
  ///        ↓
  ///   AVAILABLE
  ///
  /// The operation is idempotent for concurrent callers.
  Future<bool> enter() {
    final existing = _liveLock;

    if (existing != null) {
      return existing;
    }

    final future = _doEnter();

    _liveLock = future;

    return future.whenComplete(() {
      if (identical(_liveLock, future)) {
        _liveLock = null;
      }
    });
  }

  Future<bool> _doEnter() async {
    final int transition = ++_transitionId;

    _wantLive = true;

    debugPrint('[LIVE] enter requested transition=$transition');

    try {
      // --------------------------------------------------------
      // STEP 1
      // Make sure the realtime socket is connected.
      // --------------------------------------------------------

      if (!_socket.isConnected) {
        debugPrint('[LIVE] socket not connected -> connecting');

        _prepareConnectedWaiter();

        await _socket.connect();
      }

      // --------------------------------------------------------
      // STEP 2
      // Wait for application-level CONNECTED.
      //
      // This is important.
      //
      // Socket.IO "connect" is not the same thing as our NestJS
      // CONNECTED event.
      // --------------------------------------------------------

      if (!_snapshot.connected) {
        debugPrint('[LIVE] waiting for backend CONNECTED');

        await _waitForConnected();
      }

      // --------------------------------------------------------
      // User may have left while we were waiting.
      // --------------------------------------------------------

      if (!_isTransitionCurrent(transition)) {
        debugPrint(
          '[LIVE] enter cancelled before LIVE_START '
          'transition=$transition',
        );

        return false;
      }

      // --------------------------------------------------------
      // STEP 3
      // Tell backend that the user wants to be live.
      //
      // IMPORTANT:
      // This only makes the user AVAILABLE.
      //
      // It does NOT start matchmaking.
      // --------------------------------------------------------

      debugPrint(
        '[LIVE] sending LIVE_START '
        'transition=$transition',
      );

      _socket.startLive();

      // --------------------------------------------------------
      // STEP 4
      // REST confirmation.
      //
      // Keep this because your existing architecture uses the
      // REST endpoint as an additional confirmation.
      // --------------------------------------------------------

      final ok = await _restLiveStart();

      // --------------------------------------------------------
      // User may have exited while REST request was running.
      // --------------------------------------------------------

      if (!_isTransitionCurrent(transition)) {
        debugPrint(
          '[LIVE] enter result ignored because user exited '
          'transition=$transition',
        );

        return false;
      }

      if (!ok) {
        // _restLiveStart() already attempts the realtime rollback when the
        // REST call throws. Keep the local state explicitly non-live here.
        _emit(_snapshot.copyWith(selfLive: false));

        return false;
      }

      if (_snapshot.users.isEmpty) {
        await _refreshRestCount();
      }

      debugPrint(
        '[LIVE] enter success '
        'transition=$transition',
      );

      return true;
    } on Exception catch (e) {
      debugPrint(
        '[LIVE] enter failed '
        'transition=$transition error=$e',
      );

      if (_isTransitionCurrent(transition)) {
        _emit(_snapshot.copyWith(selfLive: false));
      }

      return false;
    }
  }

  // ============================================================
  // REST LIVE START
  // ============================================================

  Future<bool> _restLiveStart() async {
    try {
      await _repo.liveStart();

      if (!_wantLive) {
        debugPrint(
          '[LIVE] REST live/start succeeded after exit; '
          'ignoring local live state',
        );

        return false;
      }

      _emit(_snapshot.copyWith(selfLive: true));

      return true;
    } on Exception catch (e) {
      debugPrint('[LIVE] REST live/start failed: $e');

      // LIVE_START is sent over realtime before the REST confirmation.
      // If REST confirmation fails, roll back the realtime presence so the
      // backend does not remain AVAILABLE while the client reports not-live.
      if (_socket.isConnected) {
        try {
          _socket.stopLive();
        } catch (stopError) {
          debugPrint(
            '[LIVE] realtime rollback after live/start failure failed: '
            '$stopError',
          );
        }
      }

      return false;
    }
  }

  // ============================================================
  // EXIT LIVE
  // ============================================================

  /// Explicitly leave the live section.
  ///
  /// If currently SEARCHING, the backend LIVE_STOP handler will
  /// cancel matchmaking before setting the user OFFLINE.
  ///
  /// This service itself does not call START_MATCH_CANCEL because
  /// matchmaking ownership belongs to the matchmaking layer.
  void exit() {
    if (!_wantLive && !_snapshot.selfLive) {
      return;
    }

    // Invalidate any pending enter operation.
    ++_transitionId;

    _wantLive = false;

    debugPrint('[LIVE] exit live');

    // ----------------------------------------------------------
    // Realtime stop
    // ----------------------------------------------------------

    if (_socket.isConnected) {
      _socket.stopLive();
    }

    // ----------------------------------------------------------
    // REST fallback
    //
    // Backend endpoint should be idempotent.
    // ----------------------------------------------------------

    unawaited(_restLiveStop());

    // ----------------------------------------------------------
    // Immediately update local UI.
    // ----------------------------------------------------------

    _emit(_snapshot.copyWith(selfLive: false));
  }

  Future<void> _restLiveStop() async {
    try {
      await _repo.liveStop();
    } on Exception catch (e) {
      debugPrint('[LIVE] REST live/stop fallback failed: $e');
    }
  }

  // ============================================================
  // CONNECTED WAITING
  // ============================================================

  void _prepareConnectedWaiter() {
    if (_snapshot.connected) {
      return;
    }

    final existing = _connectedCompleter;

    if (existing != null && !existing.isCompleted) {
      return;
    }

    _connectedCompleter = Completer<void>();
  }

  Future<void> _waitForConnected() async {
    if (_snapshot.connected) {
      return;
    }

    _prepareConnectedWaiter();

    final completer = _connectedCompleter;

    if (completer == null) {
      if (_snapshot.connected) {
        return;
      }

      throw StateError('Unable to wait for realtime CONNECTED');
    }

    await completer.future;
  }

  void _completeConnectedWaiter() {
    final completer = _connectedCompleter;

    if (completer == null) {
      return;
    }

    if (!completer.isCompleted) {
      completer.complete();
    }

    _connectedCompleter = null;
  }

  // ============================================================
  // REALTIME EVENTS
  // ============================================================

  Future<void> _onEvent(RealtimeEvent event) async {
    switch (event.type) {
      // --------------------------------------------------------
      // CONNECTED
      // --------------------------------------------------------

      case RealtimeEventType.connected:
        await _handleConnected(event);
        break;

      // --------------------------------------------------------
      // LIVE STARTED
      // --------------------------------------------------------

      case RealtimeEventType.liveStarted:
        _handleLiveStarted(event);
        break;

      // --------------------------------------------------------
      // LIVE STOPPED
      // --------------------------------------------------------

      case RealtimeEventType.liveStopped:
        _handleLiveStopped();
        break;

      // --------------------------------------------------------
      // LIVE USERS
      // --------------------------------------------------------

      case RealtimeEventType.liveUsers:
        _handleLiveUsers(event);
        break;

      // --------------------------------------------------------
      // LIVE COUNT
      // --------------------------------------------------------

      case RealtimeEventType.liveCount:
        _handleLiveCount(event);
        break;

      // --------------------------------------------------------
      // DISCONNECTED
      // --------------------------------------------------------

      case RealtimeEventType.disconnected:
        _handleDisconnected();
        break;

      default:
        break;
    }
  }

  // ============================================================
  // CONNECTED EVENT
  // ============================================================

  Future<void> _handleConnected(RealtimeEvent event) async {
    final userId = event.data['userId'];

    debugPrint('[LIVE] backend CONNECTED userId=$userId');

    if (userId is String) {
      _emit(_snapshot.copyWith(connected: true, selfId: userId));
    } else {
      _emit(_snapshot.copyWith(connected: true));
    }

    // Release anyone waiting for application-level CONNECTED.
    _completeConnectedWaiter();

    // ----------------------------------------------------------
    // Reconnect recovery
    //
    // If the user still wants to be live, restore AVAILABLE.
    //
    // Do NOT call START_MATCH here.
    // ----------------------------------------------------------

    if (_wantLive) {
      debugPrint('[LIVE] reconnect recovery -> restoring live');

      unawaited(enter());
    }
  }

  // ============================================================
  // LIVE STARTED EVENT
  // ============================================================

  void _handleLiveStarted(RealtimeEvent event) {
    final userId = event.data['userId'];

    debugPrint('[LIVE] LIVE_STARTED userId=$userId');

    // ----------------------------------------------------------
    // If the user already exited, ignore a late LIVE_STARTED.
    // ----------------------------------------------------------

    if (!_wantLive) {
      debugPrint(
        '[LIVE] ignoring late LIVE_STARTED because '
        'user no longer wants live',
      );

      return;
    }

    _emit(
      _snapshot.copyWith(
        connected: true,
        selfLive: true,
        selfId: userId is String ? userId : _snapshot.selfId,
      ),
    );
  }

  // ============================================================
  // LIVE STOPPED EVENT
  // ============================================================

  void _handleLiveStopped() {
    debugPrint('[LIVE] LIVE_STOPPED');

    _emit(_snapshot.copyWith(selfLive: false));
  }

  // ============================================================
  // LIVE USERS
  // ============================================================

  void _handleLiveUsers(RealtimeEvent event) {
    final rawCount = event.data['count'];

    final count = rawCount is num ? rawCount.toInt() : _snapshot.totalCount;

    final rawUsers = (event.data['users'] as List?) ?? const [];

    final users =
        rawUsers
            .whereType<Map>()
            .map((m) => LiveUser.fromJson(m.cast<String, dynamic>()))
            .toList();

    debugPrint(
      '[LIVE] LIVE_USERS '
      'count=$count '
      'users=${users.length}',
    );

    // ----------------------------------------------------------
    // IMPORTANT
    //
    // Do NOT derive selfLive from LIVE_USERS.
    //
    // The user's own presence state is controlled by:
    //
    // LIVE_STARTED
    // LIVE_STOPPED
    // REST live/start
    // REST live/stop
    //
    // LIVE_USERS is only a directory/snapshot.
    // ----------------------------------------------------------

    _emit(_snapshot.copyWith(connected: true, totalCount: count, users: users));
  }

  // ============================================================
  // LIVE COUNT
  // ============================================================

  void _handleLiveCount(RealtimeEvent event) {
    final count = event.data['count'];

    if (count is num) {
      _emit(_snapshot.copyWith(totalCount: count.toInt()));
    }
  }

  // ============================================================
  // DISCONNECTED
  // ============================================================

  void _handleDisconnected() {
    debugPrint('[LIVE] socket disconnected');

    // A disconnected realtime socket can no longer be treated as an
    // authoritative live session. The backend also removes/corrects presence
    // on socket disconnect. Keep the local snapshot aligned until reconnect
    // recovery restores LIVE_START.
    _emit(_snapshot.copyWith(connected: false, selfLive: false));

    final completer = _connectedCompleter;
    if (completer != null && !completer.isCompleted) {
      // Do not leave an enter() operation waiting forever when the socket
      // disconnects before the application-level CONNECTED event arrives.
      completer.completeError(
        StateError('Realtime socket disconnected before CONNECTED'),
      );
      _connectedCompleter = null;
    }
  }

  // ============================================================
  // REST COUNT
  // ============================================================

  Future<void> _refreshRestCount() async {
    try {
      final count = await _repo.liveCount();

      if (!_snapshotController.isClosed) {
        _emit(_snapshot.copyWith(totalCount: count));
      }
    } on Exception catch (e) {
      debugPrint('[LIVE] REST live/count failed: $e');

      // Realtime LIVE_USERS remains the source of truth.
    }
  }

  // ============================================================
  // TRANSITION VALIDATION
  // ============================================================

  bool _isTransitionCurrent(int transition) {
    return transition == _transitionId &&
        _wantLive &&
        !_snapshotController.isClosed;
  }

  // ============================================================
  // SNAPSHOT
  // ============================================================

  void _emit(LivePresenceSnapshot next) {
    _snapshot = next;

    if (!_snapshotController.isClosed) {
      _snapshotController.add(next);
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  /// Clear local state for logout/account switch.
  ///
  /// The caller should normally call exit() before reset() if the
  /// realtime connection is still active.
  void reset() {
    ++_transitionId;

    _wantLive = false;

    final completer = _connectedCompleter;

    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    _connectedCompleter = null;

    _emit(const LivePresenceSnapshot());
  }

  // ============================================================
  // CLOSE
  // ============================================================

  Future<void> close() async {
    ++_transitionId;

    _wantLive = false;

    final completer = _connectedCompleter;

    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }

    _connectedCompleter = null;

    await _sub?.cancel();

    await _snapshotController.close();
  }
}
