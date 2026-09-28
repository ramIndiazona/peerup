import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/call/call_service.dart';
import '../../../models/profile.dart';
import 'call_state.dart';

/// Thin UI projection of [CallService]. WebRTC + socket signaling live in the
/// service; this cubit only tracks the visible CallState (phase, timer, mute).
class CallCubit extends Cubit<CallState> {
  CallCubit({required CallService call})
    : _call = call,
      super(const CallState()) {
    _sub = _call.events.listen(_onEvent);
  }

  final CallService _call;
  StreamSubscription<CallServiceEvent>? _sub;
  Timer? _timer;
  String? _role;

  bool get isCaller => _role == 'caller';

  Future<void> start({
    required String callId,
    required String role,
    required PublicProfile peer,
  }) async {
    _role = role;
    await _call.start(callId: callId, role: role, peer: peer);
  }

  void toggleMute() {
    emit(state.copyWith(muted: !state.muted));
  }

  Future<void> hangUp() => _call.hangUp();

  /// Reset UI state (used when leaving the call screen).
  void reset() {
    _stopTimer();
    _role = null;
    // Dispose session resources without emitting an extra ended event.
    unawaited(_call.teardown());
    emit(const CallState());
  }

  void _onEvent(CallServiceEvent event) {
    switch (event.type) {
      case CallServiceEventType.connected:
        _startTimer();
        debugPrint('[Call] connected');
        emit(state.copyWith(phase: CallPhase.connected, hasRemoteAudio: true));
      case CallServiceEventType.ended:
        _stopTimer();
        debugPrint('[Call] ended');
        emit(state.copyWith(phase: CallPhase.ended, hasRemoteAudio: false));
      case CallServiceEventType.failed:
        _stopTimer();
        emit(state.copyWith(phase: CallPhase.failed, error: event.error));
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() async {
    _stopTimer();
    await _sub?.cancel();
    await _call.close();
    await super.close();
  }
}
