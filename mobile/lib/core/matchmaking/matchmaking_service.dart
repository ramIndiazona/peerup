import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/call.dart';
import '../../models/matchmaking.dart';
import '../live/live_presence_service.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_socket_service.dart';
import 'matchmaking_repository.dart';

enum MatchmakingEventType {
  /// Socket became connected AND authenticated by the backend.
  connected,

  /// MATCH_FOUND delivered by backend.
  matched,

  /// MATCH_CANCELLED delivered by backend.
  cancelled,

  /// MATCH_TIMEOUT delivered by backend.
  timeout,
}

class MatchmakingEvent {
  const MatchmakingEvent(this.type, {this.match});

  final MatchmakingEventType type;
  final MatchFoundData? match;
}

enum RecoverOutcome { none, searching, matched }

class RecoverResult {
  const RecoverResult(this.outcome, {this.match});

  final RecoverOutcome outcome;
  final MatchFoundData? match;
}

/// Coordinates:
///
/// Flutter
///   ↓
/// LivePresenceService
///   ↓
/// authenticated realtime socket
///   ↓
/// REST matchmaking start/status/cancel
///   ↓
/// MATCH_FOUND realtime event
///
/// Important:
/// - REST is the durable source for start/cancel/status.
/// - Socket is used for realtime events.
/// - Backend MATCH_FOUND is authoritative.
/// - This service must never create duplicate searches.
/// - Only an explicit start request creates matchmaking intent.
/// - Reconnect recovery may restore an existing search, but must not
///   restart a search after the user explicitly cancelled it.
class MatchmakingService {
  MatchmakingService({
    required RealtimeSocketService socket,
    required MatchmakingRepository repo,
    required LivePresenceService live,
  }) : _socket = socket,
       _repo = repo,
       _live = live {
    _sub = _socket.events.listen(_onEvent);
  }

  final RealtimeSocketService _socket;
  final MatchmakingRepository _repo;
  final LivePresenceService _live;

  StreamSubscription<RealtimeEvent>? _sub;

  final StreamController<MatchmakingEvent> _events =
      StreamController<MatchmakingEvent>.broadcast();

  Stream<MatchmakingEvent> get events => _events.stream;

  bool _starting = false;
  bool _recovering = false;
  bool _cancelling = false;

  /// True only after the user has explicitly requested matchmaking.
  ///
  /// This prevents reconnect recovery from unexpectedly starting a new
  /// search after the user has pressed Cancel.
  bool _searchRequested = false;

  /// Used to invalidate stale asynchronous operations.
  ///
  /// Example:
  ///
  /// start()
  ///   ↓
  /// cancel()
  ///   ↓
  /// old start operation finishes
  ///
  /// The old operation must not recreate matchmaking state.
  int _operationId = 0;

  MatchFoundData? _lastMatch;

  /// Start matchmaking.
  ///
  /// Flow:
  ///
  /// 1. Mark matchmaking as explicitly requested.
  /// 2. Ensure realtime socket is authenticated.
  /// 3. Ensure live presence is AVAILABLE.
  /// 4. POST /matchmaking/start.
  ///
  /// The backend remains responsible for actual matching.
  Future<bool> start(MatchFilters filters) async {
    if (_starting) {
      debugPrint('[MATCH] start ignored: already starting');
      return false;
    }

    if (_cancelling) {
      debugPrint('[MATCH] start ignored: cancellation in progress');
      return false;
    }

    _starting = true;

    final int operationId = ++_operationId;

    // This is the important intent flag.
    //
    // Only an explicit call to start() sets this to true.
    _searchRequested = true;

    try {
      debugPrint('[MATCH] ensuring authenticated realtime connection');

      final connected = await _ensureConnected();

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] start aborted: operation became stale');
        return false;
      }

      if (!connected) {
        debugPrint('[MATCH] socket not authenticated -> abort');
        return false;
      }

      debugPrint('[MATCH] ensuring live presence');

      final liveOk = await _live.enter();

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] start aborted after live enter: stale operation');
        return false;
      }

      if (!liveOk) {
        debugPrint('[MATCH] not live -> abort before matchmaking start');
        return false;
      }

      /**
       * The socket may have disconnected while LIVE_START
       * was being performed.
       *
       * Check again before starting matchmaking.
       */
      final stillConnected = await _ensureConnected();

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] start aborted before REST call: stale operation');
        return false;
      }

      if (!stillConnected) {
        debugPrint('[MATCH] socket lost before matchmaking start');
        return false;
      }

      /**
       * Another operation could have cancelled the request.
       */
      if (!_searchRequested) {
        debugPrint('[MATCH] start aborted: search request was cancelled');
        return false;
      }

      debugPrint('[MATCH] POST /matchmaking/start');

      await _repo.start(filters);

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] start request completed but operation is stale');
        return false;
      }

      if (!_searchRequested) {
        debugPrint('[MATCH] start completed after cancellation');
        return true;
      }

      debugPrint('[MATCH] matchmaking start success');

      return true;
    } on Exception catch (e) {
      debugPrint('[MATCH] start failed: $e');

      return false;
    } finally {
      _starting = false;
    }
  }

  /// Recover current backend state.
  ///
  /// This is important after:
  /// - app restart
  /// - reconnect
  /// - navigation back to matchmaking
  /// - deep link
  ///
  /// We first ask the backend what the state actually is.
  Future<RecoverResult> recover(MatchFilters filters) async {
    if (_recovering) {
      debugPrint('[MATCH] recover ignored: already recovering');

      return const RecoverResult(RecoverOutcome.none);
    }

    _recovering = true;

    final int operationId = ++_operationId;

    try {
      final status = await _repo.status();

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] recover aborted: operation became stale');

        return const RecoverResult(RecoverOutcome.none);
      }

      /**
       * Backend says search is still active.
       *
       * Do not call start().
       */
      if (status.searching) {
        debugPrint('[MATCH] recovered: already searching');

        _searchRequested = true;

        final connected = await _ensureConnected();

        if (!connected) {
          debugPrint('[MATCH] recovery socket unavailable');
        }

        return const RecoverResult(RecoverOutcome.searching);
      }

      /**
       * Backend says a call already exists.
       */
      final callId = status.callId;
      final peer = status.peer;

      if (callId != null && callId.isNotEmpty && peer != null) {
        debugPrint(
          '[MATCH] recovered: matched '
          'call=$callId peer=${peer.id}',
        );

        final connected = await _ensureConnected();

        if (!connected) {
          debugPrint('[MATCH] matched recovery socket unavailable');
        }

        final match = MatchFoundData(
          callId: callId,
          role: status.role ?? 'callee',
          peer: peer,
        );

        _lastMatch = match;

        return RecoverResult(RecoverOutcome.matched, match: match);
      }

      /**
       * Nothing active on backend.
       *
       * IMPORTANT:
       *
       * recover() itself never automatically starts a new search.
       *
       * The UI must explicitly call start().
       */
      debugPrint('[MATCH] no active search/call on backend');

      return const RecoverResult(RecoverOutcome.none);
    } on Exception catch (e) {
      debugPrint('[MATCH] status check failed: $e');

      return const RecoverResult(RecoverOutcome.none);
    } finally {
      _recovering = false;
    }
  }

  /// Restore search after a realtime reconnect.
  ///
  /// Rules:
  ///
  /// 1. Socket must be authenticated.
  /// 2. Check backend status first.
  /// 3. If backend search still exists -> do nothing.
  /// 4. If backend already matched -> restore match.
  /// 5. If backend search disappeared:
  ///      restart ONLY if the user still has active matchmaking intent.
  ///
  /// This prevents:
  ///
  /// User presses Cancel
  ///       ↓
  /// Socket reconnects
  ///       ↓
  /// Search missing
  ///       ↓
  /// ❌ automatically start again
  Future<void> restoreAfterReconnect(MatchFilters filters) async {
    if (_recovering) {
      debugPrint('[MATCH] restore ignored: recovery already running');
      return;
    }

    if (_cancelling) {
      debugPrint('[MATCH] restore ignored: cancellation in progress');
      return;
    }

    /**
     * If the user never explicitly started matchmaking,
     * reconnect must never create a search.
     */
    if (!_searchRequested) {
      debugPrint('[MATCH] restore skipped: no active search intent');
      return;
    }

    _recovering = true;

    final int operationId = ++_operationId;

    try {
      /**
       * Make sure the socket is actually authenticated
       * before attempting anything.
       */
      final connected = await _ensureConnected();

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] restore aborted: operation became stale');
        return;
      }

      if (!connected) {
        debugPrint('[MATCH] restore skipped: socket unavailable');
        return;
      }

      /**
       * Re-check the user's intent after awaiting socket connection.
       *
       * The user could have pressed Cancel while connect() was running.
       */
      if (!_searchRequested) {
        debugPrint('[MATCH] restore aborted: search was cancelled');
        return;
      }

      final status = await _repo.status();

      if (!_isOperationCurrent(operationId)) {
        debugPrint('[MATCH] restore aborted after status: stale operation');
        return;
      }

      /**
       * Search survived reconnect.
       */
      if (status.searching) {
        debugPrint('[MATCH] restore: still searching on backend');

        return;
      }

      /**
       * Backend may already have matched us.
       *
       * Do NOT create another search.
       */
      if (status.callId != null &&
          status.callId!.isNotEmpty &&
          status.peer != null) {
        debugPrint(
          '[MATCH] restore: backend already matched '
          'call=${status.callId}',
        );

        final match = MatchFoundData(
          callId: status.callId!,
          role: status.role ?? 'callee',
          peer: status.peer!,
        );

        _lastMatch = match;

        _emitMatchedIfNew(match);

        return;
      }

      /**
       * Search was actually lost.
       *
       * Before restarting, check the user's intent one more time.
       */
      if (!_searchRequested) {
        debugPrint('[MATCH] restore: search lost but user cancelled');
        return;
      }

      /**
       * Do not call start() while another start operation is active.
       */
      if (_starting) {
        debugPrint('[MATCH] restore: start already in progress');
        return;
      }

      debugPrint('[MATCH] restore: server search lost, restarting');

      await start(filters);
    } on Exception catch (e) {
      debugPrint('[MATCH] restore failed (best effort): $e');
    } finally {
      _recovering = false;
    }
  }

  /// Cancel active matchmaking.
  ///
  /// Cancellation immediately removes local matchmaking intent.
  ///
  /// This is important because a reconnect happening during cancellation
  /// must NOT restart the search.
  Future<void> cancel() async {
    if (_cancelling) {
      debugPrint('[MATCH] cancel ignored: already cancelling');
      return;
    }

    _cancelling = true;

    /**
     * Invalidate all previous async operations immediately.
     *
     * Any pending start/recovery operation must become stale.
     */
    ++_operationId;

    /**
     * Most important part:
     *
     * From this moment onward, reconnect recovery must NOT recreate
     * matchmaking.
     */
    _searchRequested = false;

    try {
      await _repo.cancel();

      debugPrint('[MATCH] REST cancel success');
    } on Exception catch (e) {
      debugPrint('[MATCH] cancel failed: $e');
    }

    /**
     * This is only local/socket-side notification.
     *
     * REST remains the durable cancellation operation.
     */
    try {
      _socket.cancelMatch();
    } catch (e) {
      debugPrint('[MATCH] socket cancel failed: $e');
    } finally {
      _cancelling = false;
    }
  }

  /// Ensure that the socket is connected AND authenticated.
  ///
  /// Important:
  ///
  /// Socket.IO's low-level `connect` event is NOT enough.
  ///
  /// The backend sends:
  ///
  /// CONNECTED
  ///
  /// only after JWT validation and authentication.
  Future<bool> _ensureConnected() async {
    if (_socket.isAuthenticated) {
      return true;
    }

    try {
      debugPrint('[MATCH] connecting realtime socket...');

      await _socket.connect();

      if (_socket.isAuthenticated) {
        debugPrint('[MATCH] realtime socket authenticated');

        return true;
      }

      debugPrint('[MATCH] socket connected but not authenticated');

      return false;
    } catch (e) {
      debugPrint('[MATCH] realtime connection failed: $e');

      return false;
    }
  }

  /// Check whether an asynchronous matchmaking operation is still valid.
  bool _isOperationCurrent(int operationId) {
    return operationId == _operationId && _searchRequested && !_cancelling;
  }

  /// Handle shared realtime events.
  void _onEvent(RealtimeEvent event) {
    switch (event.type) {
      case RealtimeEventType.connected:
        debugPrint('[MATCH] realtime CONNECTED');

        _add(const MatchmakingEvent(MatchmakingEventType.connected));

        break;

      // case RealtimeEventType.matchFound:
      //   try {
      //     final data = MatchFoundData.fromJson(
      //       event.data,
      //     );

      //     debugPrint(
      //       '[MATCH] MATCH_FOUND '
      //       'callId=${data.callId} '
      //       'partnerId=${data.peer.id} '
      //       'role=${data.role}',
      //     );

      //     _lastMatch = data;

      //     /**
      //      * A MATCH_FOUND event can race with recovery.
      //      *
      //      * If recovery already restored this exact call,
      //      * don't notify the UI twice.
      //      */
      //     _emitMatchedIfNew(data);
      //   } catch (e) {
      //     debugPrint(
      //       '[MATCH] invalid MATCH_FOUND payload: $e',
      //     );
      //   }

      //   break;

      case RealtimeEventType.matchFound:
        try {
          final data = MatchFoundData.fromJson(event.data);

          debugPrint(
            '[MATCH] MATCH_FOUND '
            'callId=${data.callId} '
            'partnerId=${data.peer.id} '
            'role=${data.role}',
          );

          _emitMatchedIfNew(data);
        } catch (e) {
          debugPrint('[MATCH] invalid MATCH_FOUND payload: $e');
        }

        break;

      case RealtimeEventType.matchCancelled:
        debugPrint('[MATCH] MATCH_CANCELLED');

        /**
         * Backend cancellation is authoritative.
         *
         * Clear the local search intent so reconnect cannot recreate it.
         */
        _searchRequested = false;
        ++_operationId;

        _add(const MatchmakingEvent(MatchmakingEventType.cancelled));

        break;

      case RealtimeEventType.matchTimeout:
        debugPrint('[MATCH] MATCH_TIMEOUT');

        /**
         * Backend search timed out.
         *
         * The user is no longer actively searching.
         *
         * If the UI wants another search, it must explicitly call start().
         */
        _searchRequested = false;
        ++_operationId;

        _add(const MatchmakingEvent(MatchmakingEventType.timeout));

        break;

      default:
        break;
    }
  }

  /// Emit a matched event only once for a particular call.
  // void _emitMatchedIfNew(MatchFoundData match) {
  //   final previousCallId = _lastMatch?.callId;

  //   if (previousCallId == match.callId) {
  //     /**
  //      * If this is the first assignment, allow it.
  //      *
  //      * The check below is mainly for duplicate realtime/recovery events.
  //      */
  //     if (_lastMatch != null) {
  //       debugPrint(
  //         '[MATCH] duplicate MATCH_FOUND ignored '
  //         'callId=${match.callId}',
  //       );

  //       return;
  //     }
  //   }

  //   _lastMatch = match;

  //   /**
  //    * Once matched, there is no longer an active search request.
  //    *
  //    * The backend now owns the call state.
  //    */
  //   _searchRequested = false;

  //   _add(MatchmakingEvent(MatchmakingEventType.matched, match: match));
  // }

  void _emitMatchedIfNew(MatchFoundData match) {
    final previous = _lastMatch;

    if (previous?.callId == match.callId) {
      debugPrint(
        '[MATCH] duplicate MATCH_FOUND ignored '
        'callId=${match.callId}',
      );
      return;
    }

    _lastMatch = match;

    _searchRequested = false;

    _add(MatchmakingEvent(MatchmakingEventType.matched, match: match));
  }

  void _add(MatchmakingEvent event) {
    if (_events.isClosed) {
      return;
    }

    _events.add(event);
  }

  MatchFoundData? get lastMatch => _lastMatch;

  /// Whether this service currently has an explicit matchmaking request.
  ///
  /// Useful for UI/debugging if needed.
  bool get isSearchRequested => _searchRequested;

  /// Whether start() is currently running.
  bool get isStarting => _starting;

  /// Whether recovery is currently running.
  bool get isRecovering => _recovering;

  /// Whether cancellation is currently running.
  bool get isCancelling => _cancelling;

  Future<void> close() async {
    /**
     * Invalidate any outstanding async operation.
     */
    ++_operationId;
    _searchRequested = false;

    await _sub?.cancel();
    _sub = null;

    await _events.close();
  }
}
