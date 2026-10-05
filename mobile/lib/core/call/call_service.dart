import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../models/call.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../realtime/realtime_event.dart';
import '../realtime/realtime_socket_service.dart';
import 'call_repository.dart';
import 'webrtc_service.dart';

enum CallServiceEventType { connected, reconnecting, ended, failed }

class CallServiceEvent {
  const CallServiceEvent(this.type, {this.error});

  final CallServiceEventType type;
  final String? error;
}

/// Owns a single voice-call session.
///
/// Flow:
///
/// MATCH_FOUND
///     ↓
/// CallService.start()
///     ↓
/// create PeerConnection
///     ↓
/// caller -> CALL_OFFER
///     ↓
/// callee -> CALL_ANSWER
///     ↓
/// ICE candidates
///     ↓
/// WebRTC connected
///     ↓
/// CALL_CONNECTED
///
/// Important:
/// - Signaling messages can arrive before CallService.start() finishes.
/// - Offers/answers/ICE are buffered by callId.
/// - ICE candidates are buffered until remote SDP exists.
/// - ICE buffers are isolated per callId.
/// - Only one WebRTC call is active at a time.
class CallService {
  CallService({
    required RealtimeSocketService socket,
    required CallRepository repo,
    required WebRtcService webRtc,
  }) : _socket = socket,
       _repo = repo,
       _webrtc = webRtc {
    _sub = _socket.events.listen(_onEvent);
  }

  final RealtimeSocketService _socket;
  final CallRepository _repo;
  final WebRtcService _webrtc;

  StreamSubscription<RealtimeEvent>? _sub;

  final StreamController<CallServiceEvent> _events =
      StreamController<CallServiceEvent>.broadcast();

  Stream<CallServiceEvent> get events => _events.stream;

  ActiveWebRtcCall? _webrtcCall;

  String? _callId;

  String? _role;

  bool _callActive = false;

  bool _connected = false;
  bool _reconnecting = false;
  bool _peerUnavailable = false;
  bool _recoveryBusy = false;

  /// The single reconnect grace period used by this service.
  ///
  /// The backend advertises its own value in `CONNECTED`
  /// (`callReconnectTimeoutSeconds`); this default only covers the case of an
  /// older server. Never duplicate the value inline.
  static const reconnectTimeout = Duration(seconds: 15);

  /// How often the recovery loop re-checks the existing peer connection.
  static const _retryInterval = Duration(seconds: 2);

  Timer? _reconnectTimer;
  Timer? _recoveryRetry;
  Duration _reconnectTimeout = reconnectTimeout;
  Map<String, dynamic>? _restartOffer;
  String? _answeredRestartSdp;
  Map<String, dynamic>? _restartAnswer;
  final List<Map<String, dynamic>> _recoveryIce = [];
  final Set<String> _pendingHangups = {};
  Future<void> _signalWork = Future<void>.value();

  bool _remoteDescriptionSet = false;

  bool _starting = false;

  /// Signaling events can arrive before the CallService has completed
  /// initialization for this call.
  ///
  /// They are stored by callId so events from an old call cannot
  /// accidentally be processed by a new call.
  final Map<String, List<RealtimeEvent>> _pendingSignals = {};

  /// ICE candidates can arrive before remote SDP is available.
  ///
  /// IMPORTANT:
  /// This is also keyed by callId. This prevents ICE from an old call
  /// being applied to a new call.
  final Map<String, List<Map<String, dynamic>>> _pendingIceCandidates = {};

  bool get isCallActive => _callActive;

  String? get callId => _callId;

  bool get isConnected => _connected;

  Future<void> start({
    required String callId,
    required String role,
    required PublicProfile peer,
  }) async {
    if (_callActive && _callId == callId) return;
    if (_starting) {
      debugPrint('[CALL] start ignored: already starting');
      return;
    }

    if (_callActive && _callId != null && _callId != callId) {
      debugPrint(
        '[CALL] another call is already active '
        'active=$_callId requested=$callId',
      );
      return;
    }

    _starting = true;

    _callId = callId;
    _role = role;
    _callActive = true;
    _connected = false;
    _remoteDescriptionSet = false;

    debugPrint(
      '[CALL] start '
      'callId=$callId '
      'role=$role '
      'peer=${peer.id}',
    );

    try {
      // ------------------------------------------------------------
      // 1. Ensure realtime socket is authenticated.
      // ------------------------------------------------------------
      await _socket.connect();

      if (!_socket.isAuthenticated) {
        throw StateError('Realtime socket is not authenticated');
      }

      // ------------------------------------------------------------
      // 2. Best-effort call verification.
      // ------------------------------------------------------------
      try {
        await _repo.getCall(callId);

        debugPrint('[CALL] verified call=$callId');
      } on Exception catch (e) {
        debugPrint(
          '[CALL] getCall verification failed '
          '(best effort): $e',
        );
      }

      // ------------------------------------------------------------
      // 3. Create PeerConnection BEFORE processing buffered
      //    signaling events.
      // ------------------------------------------------------------
      _webrtcCall = await _webrtc.createCall(
        onSendIceCandidate: _sendIce,
        onRemoteStream: (stream) {
          final active = _webrtcCall;

          if (active == null) {
            return;
          }

          active.remoteStream = stream;

          debugPrint(
            '[CALL] remote audio stream received '
            'callId=$callId',
          );

          // Do NOT call _markConnected() here.
          //
          // The authoritative connection state is the
          // RTCPeerConnectionStateConnected event.
        },
        onState: _onPeerState,
      );

      debugPrint(
        '[CALL] PeerConnection ready '
        'callId=$callId '
        'role=$role',
      );

      // ------------------------------------------------------------
      // 4. Process signals that arrived before PeerConnection
      //    creation.
      // ------------------------------------------------------------
      await _processPendingSignals(callId);

      // ------------------------------------------------------------
      // 5. Caller creates the offer.
      // ------------------------------------------------------------
      if (role == 'caller') {
        final call = _webrtcCall;

        if (call == null) {
          throw StateError('WebRTC call was not created');
        }

        final offer = await _webrtc.createOffer(call);

        debugPrint(
          '[CALL] sending CALL_OFFER '
          'callId=$callId',
        );

        _socket.sendOffer(callId, offer);
      }

      // ------------------------------------------------------------
      // 6. Process anything that may have arrived while the
      //    offer was being created.
      // ------------------------------------------------------------
      await _processPendingSignals(callId);
    } on Exception catch (e) {
      debugPrint('[CALL] start failed: $e');

      final activeCallId = _callId;

      if (activeCallId != null) {
        _socket.reportCallFailed(activeCallId, 'call start failed');
      }

      _add(CallServiceEvent(CallServiceEventType.failed, error: '$e'));

      await end(notifyBackend: false);
    } finally {
      _starting = false;
    }
  }

  // ---------------------------------------------------------------------------
  // WEBRTC CONNECTION STATE
  // ---------------------------------------------------------------------------

  void _onPeerState(RTCPeerConnectionState state) {
    debugPrint(
      '[CALL] peer connection state=$state '
      'callId=$_callId',
    );

    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _markConnected();
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        if (_connected) {
          _beginRecovery();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          final id = _callId;
          if (id != null) {
            _socket.reportCallFailed(id, 'peer connection failed');
          }
          unawaited(end(notifyBackend: false));
        }
        break;

      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        if (_callActive) {
          unawaited(end());
        }
        break;

      default:
        break;
    }
  }

  /// The peer connection reported a live media path.
  ///
  /// During recovery this clears the reconnect state, keeps the same call
  /// session and keeps the call timer running.
  void _markConnected() {
    if (_reconnecting) {
      if (!_socket.isAuthenticated) return;
      _clearRecovery();
      final id = _callId;
      if (id != null) {
        _socket.reportCallConnected(id);
      }
      _add(const CallServiceEvent(CallServiceEventType.connected));
      return;
    }
    if (_connected) return;

    if (!_callActive) {
      return;
    }

    _connected = true;

    final callId = _callId;

    if (callId != null) {
      _socket.reportCallConnected(callId);

      debugPrint(
        '[CALL] CALL_CONNECTED '
        'callId=$callId',
      );
    }

    _add(const CallServiceEvent(CallServiceEventType.connected));
  }

  void _beginRecovery({bool notifyPeer = true}) {
    if (!_callActive || !_connected) return;
    if (!_reconnecting) {
      _reconnecting = true;
      _add(const CallServiceEvent(CallServiceEventType.reconnecting));
      final id = _callId;
      _reconnectTimer = Timer(_reconnectTimeout, () {
        if (_callActive && _reconnecting && _callId == id) {
          // The normal ending path owns local cleanup and END_CALL delivery.
          unawaited(end());
        }
      });
      _recoveryRetry = Timer.periodic(_retryInterval, (_) {
        unawaited(_attemptRecovery());
      });
      if (notifyPeer && id != null) _socket.requestCallRecovery(id);
    }
    unawaited(_attemptRecovery());
  }

  Future<void> _attemptRecovery() async {
    final call = _webrtcCall;
    final id = _callId;
    if (!_reconnecting ||
        !_callActive ||
        call == null ||
        id == null ||
        _recoveryBusy) {
      return;
    }

    _recoveryBusy = true;

    try {
      // ------------------------------------------------------------
      // A working media path is authoritative.
      //
      // A signaling-only interruption (socket blip, peer ICE
      // restart) must not freeze or end a call whose audio is
      // still flowing, so this is checked before the socket guards.
      // ------------------------------------------------------------
      if (await _isMediaHealthy(call)) {
        if (_webrtcCall != call || !_reconnecting) return;
        if (_socket.isAuthenticated) {
          _markConnected();
        }
        return;
      }

      if (!_socket.isAuthenticated || _peerUnavailable) return;

      if (_role != 'caller') {
        // Only the original caller offers, preventing offer glare.
        _socket.requestCallRecovery(id);
        return;
      }

      final signaling = await call.pc.getSignalingState();
      if (_webrtcCall != call || !_reconnecting) return;
      if (signaling == RTCSignalingState.RTCSignalingStateStable) {
        _remoteDescriptionSet = false;
        _recoveryIce.clear();
        _restartOffer = await _webrtc.createOffer(call, iceRestart: true);
      }
      if (_webrtcCall != call || !_reconnecting) return;
      final offer = _restartOffer;
      if (offer != null) {
        // Retry the same pending offer if its answer was lost while offline.
        _socket.sendOffer(id, {...offer, 'iceRestart': true});
        for (final ice in _recoveryIce) {
          _socket.sendIce(id, ice);
        }
      }
    } catch (error) {
      debugPrint('[CALL] recovery attempt failed: $error');
      // Keep the original deadline; transient signaling errors are retryable.
    } finally {
      _recoveryBusy = false;
    }
  }

  /// True when the existing peer connection still carries audio.
  ///
  /// Both states are required: `connected` alone can be reported while ICE
  /// consent checks are already failing, which would cancel recovery on a
  /// dead media path.
  Future<bool> _isMediaHealthy(ActiveWebRtcCall call) async {
    final connection = await call.pc.getConnectionState();

    if (connection != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      return false;
    }

    final ice = await call.pc.getIceConnectionState();

    return ice == null ||
        ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        ice == RTCIceConnectionState.RTCIceConnectionStateCompleted;
  }

  Future<void> _socketRestored() async {
    for (final id in _pendingHangups.toList()) {
      _socket.endCall(id);
      _pendingHangups.remove(id);
    }
    final id = _callId;
    if (!_callActive || !_connected || id == null) return;
    try {
      final details = await _repo.getCall(id);
      if (_callId != id || !_callActive) return;
      if (details.call.status == CallStatus.ended ||
          details.call.status == CallStatus.cancelled) {
        await end(notifyBackend: false);
        return;
      }
      await _attemptRecovery();
    } catch (error) {
      debugPrint('[CALL] recovery verification failed: $error');
    }
  }

  void _clearRecovery() {
    _reconnectTimer?.cancel();
    _recoveryRetry?.cancel();
    _reconnectTimer = null;
    _recoveryRetry = null;
    _reconnecting = false;
    _peerUnavailable = false;
    _restartOffer = null;
    _restartAnswer = null;
    _answeredRestartSdp = null;
    _recoveryIce.clear();
  }

  // ---------------------------------------------------------------------------
  // HANG UP / END
  // ---------------------------------------------------------------------------

  Future<void> hangUp() async {
    final callId = _callId;

    if (callId != null && _callActive) {
      debugPrint('[CALL] user hangup callId=$callId');

      if (!_socket.isAuthenticated) _pendingHangups.add(callId);
      _socket.endCall(callId);
    }

    await end(notifyBackend: false);
  }

  /// Finish the local WebRTC session.
  ///
  /// [notifyBackend] should be false when the backend has already received
  /// CALL_FAILED / CALL_ENDED.
  Future<void> end({bool notifyBackend = true}) async {
    final callId = _callId;

    if (!_callActive && _webrtcCall == null) {
      return;
    }

    _clearRecovery();
    _callActive = false;
    _connected = false;
    _remoteDescriptionSet = false;

    debugPrint('[CALL] ending callId=$callId');

    // ------------------------------------------------------------
    // Tell backend to end the call when required.
    // ------------------------------------------------------------
    if (notifyBackend && callId != null) {
      if (!_socket.isAuthenticated) _pendingHangups.add(callId);
      try {
        _socket.endCall(callId);
      } catch (e) {
        debugPrint('[CALL] end signaling failed: $e');
      }
    }

    // ------------------------------------------------------------
    // Dispose WebRTC.
    // ------------------------------------------------------------
    final webrtc = _webrtcCall;

    _webrtcCall = null;

    if (webrtc != null) {
      try {
        await _webrtc.dispose(webrtc);
      } catch (e) {
        debugPrint('[CALL] WebRTC dispose failed: $e');
      }
    }

    // ------------------------------------------------------------
    // Remove only buffers belonging to this call.
    // ------------------------------------------------------------
    if (callId != null) {
      _pendingSignals.remove(callId);

      _pendingIceCandidates.remove(callId);
    }

    _callId = null;
    _role = null;

    _add(const CallServiceEvent(CallServiceEventType.ended));
  }

  /// Dispose local WebRTC resources without sending lifecycle events.
  ///
  /// Used by the UI when resetting state.
  Future<void> teardown() async {
    _clearRecovery();
    _callActive = false;
    _connected = false;
    _remoteDescriptionSet = false;

    final webrtc = _webrtcCall;

    _webrtcCall = null;

    if (webrtc != null) {
      try {
        await _webrtc.dispose(webrtc);
      } catch (e) {
        debugPrint('[CALL] teardown failed: $e');
      }
    }

    final callId = _callId;

    if (callId != null) {
      _pendingSignals.remove(callId);

      _pendingIceCandidates.remove(callId);
    }

    _callId = null;
    _role = null;
  }

  // ---------------------------------------------------------------------------
  // LOCAL ICE
  // ---------------------------------------------------------------------------

  void _sendIce(Map<String, dynamic> ice) {
    final callId = _callId;

    if (callId == null || !_callActive) {
      return;
    }

    debugPrint(
      '[CALL] sending ICE '
      'callId=$callId',
    );

    if (_reconnecting) _recoveryIce.add(ice);
    _socket.sendIce(callId, ice);
  }

  // ---------------------------------------------------------------------------
  // REALTIME EVENTS
  // ---------------------------------------------------------------------------

  void _onEvent(RealtimeEvent event) {
    switch (event.type) {
      case RealtimeEventType.disconnected:
        _beginRecovery(notifyPeer: false);
        break;
      case RealtimeEventType.connected:
        final seconds = event.data['callReconnectTimeoutSeconds'];
        if (seconds is num && seconds > 0) {
          _reconnectTimeout = Duration(milliseconds: (seconds * 1000).round());
        }
        unawaited(_socketRestored());
        break;
      case RealtimeEventType.callReconnecting:
        if (event.callId == _callId) {
          if (event.data['reason'] == 'socket_disconnected') {
            _peerUnavailable = true;
          }
          _beginRecovery(notifyPeer: false);
        }
        break;
      case RealtimeEventType.callReconnected:
        if (event.callId == _callId) {
          _peerUnavailable = false;
          _beginRecovery(notifyPeer: false);
        }
        break;
      case RealtimeEventType.callOffer:
      case RealtimeEventType.callAnswer:
      case RealtimeEventType.iceCandidate:
        _handleSignalingEvent(event);
        break;

      case RealtimeEventType.callConnected:
        if (event.callId == _callId) {
          debugPrint(
            '[CALL] backend CALL_CONNECTED '
            'callId=${event.callId}',
          );
        }
        break;

      case RealtimeEventType.callEnded:
        if (event.callId == _callId) {
          debugPrint(
            '[CALL] CALL_ENDED '
            'callId=${event.callId}',
          );

          unawaited(end(notifyBackend: false));
        }
        break;

      case RealtimeEventType.error:
        if (event.rawErrorCode == 'MULTIPLE_DEVICE') {
          debugPrint('[CALL] MULTIPLE_DEVICE');

          unawaited(end(notifyBackend: false));
        }
        break;

      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // SIGNALING BUFFER
  // ---------------------------------------------------------------------------

  void _handleSignalingEvent(RealtimeEvent event) {
    final data = SignalingData.fromJson(event.data);

    final callId = data.callId;

    if (callId.isEmpty) {
      debugPrint(
        '[CALL] signaling event has empty callId '
        'type=${event.type}',
      );
      return;
    }

    // ------------------------------------------------------------
    // If this call has not been initialized yet, buffer it.
    // ------------------------------------------------------------
    if (_callId != callId || _webrtcCall == null) {
      debugPrint(
        '[CALL] buffering signaling event '
        'type=${event.type} '
        'callId=$callId '
        'active=$_callId',
      );

      final list = _pendingSignals.putIfAbsent(callId, () => <RealtimeEvent>[]);

      list.add(event);

      return;
    }

    _enqueueSignal(event);
  }

  /// Serialize signaling handling so offer/answer/ICE always apply in order.
  ///
  /// The chain must never end in an error: a single failed event would
  /// otherwise skip every later callback and silently drop the rest of the
  /// negotiation.
  void _enqueueSignal(RealtimeEvent event) {
    _signalWork = _signalWork.then(
      (_) => _processSignalingEvent(event),
      onError: (Object _) => _processSignalingEvent(event),
    );

    unawaited(
      _signalWork.catchError((Object _) {
        debugPrint(
          '[CALL] signaling task failed '
          'type=${event.type}',
        );
      }),
    );
  }

  Future<void> _processPendingSignals(String callId) async {
    final pending = _pendingSignals.remove(callId);

    if (pending == null || pending.isEmpty) {
      return;
    }

    debugPrint(
      '[CALL] processing ${pending.length} buffered signals '
      'callId=$callId',
    );

    for (final event in pending) {
      if (!_callActive || _callId != callId) {
        return;
      }

      await _processSignalingEvent(event);
    }
  }

  Future<void> _processSignalingEvent(RealtimeEvent event) async {
    final data = SignalingData.fromJson(event.data);

    if (data.callId != _callId) {
      debugPrint(
        '[CALL] ignoring signaling for different call '
        'eventCallId=${data.callId} '
        'activeCallId=$_callId',
      );
      return;
    }

    if (!_callActive) {
      return;
    }

    if (data.data is! Map) {
      debugPrint(
        '[CALL] invalid signaling data '
        'type=${event.type}',
      );
      return;
    }

    final payload = (data.data as Map).cast<String, dynamic>();

    try {
      switch (event.type) {
        case RealtimeEventType.callOffer:
          await _handleOffer(payload);
          break;

        case RealtimeEventType.callAnswer:
          await _handleAnswer(payload);
          break;

        case RealtimeEventType.iceCandidate:
          await _handleIce(data.callId, payload);
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint(
        '[CALL] signaling processing failed '
        'type=${event.type} error=$e',
      );

      if (_connected) {
        _beginRecovery();
        return;
      }
      final callId = _callId;

      if (callId != null) {
        _socket.reportCallFailed(callId, 'signaling processing failed');
      }

      await end(notifyBackend: false);
    }
  }

  // ---------------------------------------------------------------------------
  // OFFER
  // ---------------------------------------------------------------------------

  Future<void> _handleOffer(Map<String, dynamic> offer) async {
    final webrtc = _webrtcCall;
    final callId = _callId;

    if (webrtc == null || callId == null) {
      return;
    }

    // Only callee should process an incoming offer.
    if (_role != 'callee') {
      debugPrint('[CALL] ignoring offer because role=$_role');
      return;
    }

    debugPrint(
      '[CALL] received CALL_OFFER '
      'callId=$callId',
    );

    final restarting = offer['iceRestart'] == true && _connected;
    if (restarting) {
      if (_answeredRestartSdp == offer['sdp'] && _restartAnswer != null) {
        _socket.sendAnswer(callId, _restartAnswer!);
        for (final ice in _recoveryIce) {
          _socket.sendIce(callId, ice);
        }
        return;
      }
      _beginRecovery(notifyPeer: false);
      _remoteDescriptionSet = false;
      _recoveryIce.clear();
    }
    await _webrtc.acceptOffer(webrtc, offer);

    _remoteDescriptionSet = true;

    // ------------------------------------------------------------
    // ICE candidates that arrived before the offer can now be added.
    // ------------------------------------------------------------
    await _flushPendingIce(callId);

    final answer = await _webrtc.createAnswer(webrtc);

    debugPrint(
      '[CALL] sending CALL_ANSWER '
      'callId=$callId',
    );

    if (_webrtcCall != webrtc || !_callActive) return;
    if (restarting) {
      _answeredRestartSdp = offer['sdp'] as String?;
      _restartAnswer = answer;
    }
    _socket.sendAnswer(callId, answer);
  }

  // ---------------------------------------------------------------------------
  // ANSWER
  // ---------------------------------------------------------------------------

  Future<void> _handleAnswer(Map<String, dynamic> answer) async {
    final webrtc = _webrtcCall;
    final callId = _callId;

    if (webrtc == null || callId == null) {
      return;
    }

    // Only caller should process answer.
    if (_role != 'caller') {
      debugPrint('[CALL] ignoring answer because role=$_role');
      return;
    }

    debugPrint(
      '[CALL] received CALL_ANSWER '
      'callId=$callId',
    );

    // A repeated answer after a successful retry must not fail a stable call.
    if (_connected &&
        await webrtc.pc.getSignalingState() ==
            RTCSignalingState.RTCSignalingStateStable)
      return;
    await _webrtc.acceptAnswer(webrtc, answer);
    if (_webrtcCall != webrtc || !_callActive) return;

    _remoteDescriptionSet = true;

    await _flushPendingIce(callId);
  }

  // ---------------------------------------------------------------------------
  // REMOTE ICE
  // ---------------------------------------------------------------------------

  Future<void> _handleIce(String callId, Map<String, dynamic> ice) async {
    final webrtc = _webrtcCall;

    if (webrtc == null) {
      debugPrint(
        '[CALL] ICE received before PeerConnection '
        'callId=$callId',
      );
      return;
    }

    if (!_callActive || _callId != callId) {
      debugPrint(
        '[CALL] ignoring ICE for inactive/different call '
        'iceCallId=$callId '
        'activeCallId=$_callId',
      );
      return;
    }

    // ------------------------------------------------------------
    // Remote SDP has not arrived yet.
    //
    // Store ICE under its callId so it cannot leak into another
    // call session.
    // ------------------------------------------------------------
    if (!_remoteDescriptionSet) {
      debugPrint(
        '[CALL] queueing ICE until remote description '
        'callId=$callId',
      );

      final list = _pendingIceCandidates.putIfAbsent(
        callId,
        () => <Map<String, dynamic>>[],
      );

      list.add(ice);

      return;
    }

    await _webrtc.addIceCandidate(webrtc, ice);
  }

  // ---------------------------------------------------------------------------
  // FLUSH QUEUED ICE
  // ---------------------------------------------------------------------------

  Future<void> _flushPendingIce(String callId) async {
    final webrtc = _webrtcCall;

    if (webrtc == null ||
        !_remoteDescriptionSet ||
        !_callActive ||
        _callId != callId) {
      return;
    }

    final candidates = _pendingIceCandidates.remove(callId);

    if (candidates == null || candidates.isEmpty) {
      return;
    }

    debugPrint(
      '[CALL] flushing ${candidates.length} ICE candidates '
      'callId=$callId',
    );

    for (final candidate in candidates) {
      if (!_callActive || _callId != callId) {
        return;
      }

      try {
        await _webrtc.addIceCandidate(webrtc, candidate);
      } catch (e) {
        debugPrint('[CALL] queued ICE failed: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // EVENTS
  // ---------------------------------------------------------------------------

  void _add(CallServiceEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  // ---------------------------------------------------------------------------
  // CLOSE
  // ---------------------------------------------------------------------------

  Future<void> close() async {
    await _sub?.cancel();

    _sub = null;

    await teardown();

    _pendingSignals.clear();
    _pendingIceCandidates.clear();

    await _events.close();
  }
}
