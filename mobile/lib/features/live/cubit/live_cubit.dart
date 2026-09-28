import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/live/live_presence_service.dart';
import 'live_state.dart';

/// Thin UI projection of [LivePresenceService]. All presence orchestration
/// (connect, LIVE_START, REST live/start, heartbeat, reconnect recovery) lives
/// in the service; this cubit only maps snapshots to [LiveState].
class LiveCubit extends Cubit<LiveState> {
  LiveCubit({required LivePresenceService service})
    : _service = service,
      super(const LiveState()) {
    _sub = _service.snapshotStream.listen(_onSnapshot);
  }

  final LivePresenceService _service;
  StreamSubscription<LivePresenceSnapshot>? _sub;

  /// User wants to be live on the Match section.
  Future<bool> enter() => _service.enter();

  /// Explicitly leave the live/match session.
  void exit() => _service.exit();

  /// Clear state for logout / account switch.
  void reset() => _service.reset();

  void _onSnapshot(LivePresenceSnapshot snapshot) {
    if (isClosed) return;
    emit(
      LiveState(
        connected: snapshot.connected,
        totalCount: snapshot.totalCount,
        users: snapshot.users,
        selfLive: snapshot.selfLive,
        selfId: snapshot.selfId,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await super.close();
  }
}
